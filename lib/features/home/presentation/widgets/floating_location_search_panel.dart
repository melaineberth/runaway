import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/rounded_text_field.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';

import '../../../route_generator/data/services/geocoding_service.dart';

// 🍎 Courbes d'animation personnalisées inspirées d'Apple
class AppleCurves {
  static const Curve easeOutBack = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Curve easeInOutQuart = Cubic(0.76, 0, 0.24, 1);
  static const Curve springyEaseOut = Cubic(0.25, 0.46, 0.45, 0.94);
  static const Curve gentleSpring = Cubic(0.175, 0.885, 0.32, 1.275);
  static const Curve softEaseOut = Cubic(0.25, 0.1, 0.25, 1.0);
}

class FloatingLocationSearchPanel extends StatefulWidget {
  final Function(double longitude, double latitude, String placeName)? onLocationSelected;
  final double? userLongitude;
  final double? userLatitude;
  final Function()? onPressed;
  final Function()? onProfile;

  const FloatingLocationSearchPanel({
    super.key,
    this.onLocationSelected,
    this.userLongitude,
    this.userLatitude,
    this.onPressed,
    this.onProfile,
  });

  @override
  State<FloatingLocationSearchPanel> createState() => _FloatingLocationSearchPanelState();
}

class _FloatingLocationSearchPanelState extends State<FloatingLocationSearchPanel> with TickerProviderStateMixin {
  
  // 🎬 Animation Controllers
  late AnimationController _slideController;
  late AnimationController _expandController;
  late AnimationController _fadeController;
  late AnimationController _contentController;
  late AnimationController _blurController;
  
  // 🎬 Animations principales
  late Animation<Offset> _slideAnimation;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;
  
  // 🎬 Animations secondaires (style Apple)
  late Animation<double> _contentFadeAnimation;
  late Animation<double> _contentScaleAnimation;
  late Animation<double> _shadowAnimation;
  late Animation<double> _borderRadiusAnimation;
  late Animation<double> _blurAnimation;
  
  // 📱 Keyboard & Search
  late StreamSubscription<bool> keyboardSubscription;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<AddressSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isKeyboardVisible = false;
  Timer? _debounce;

  // 🛡️ Helper pour s'assurer que l'opacité reste valide
  double _clampOpacity(double value) {
    return value.clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupKeyboardListener();
    _focusNode.addListener(_onFocusChange);
  }

  void _initializeAnimations() {
    // 🎬 Slide animation (entrée depuis le bas) - Plus fluide
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Départ plus bas pour effet dramatique
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: AppleCurves.gentleSpring,
    ));

    // 🎬 Expand animation - Style Apple avec spring
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 320), // Ouverture
      reverseDuration: const Duration(milliseconds: 450), // Fermeture plus lente
      vsync: this,
    );
    
    _expandAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: AppleCurves.springyEaseOut,
      reverseCurve: AppleCurves.softEaseOut,
    ));

    // 🎬 Content animations - Cascade effect
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 380), // Fermeture plus douce
      vsync: this,
    );
    
    _contentFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
    
    _contentScaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Interval(0.0, 0.8, curve: AppleCurves.easeOutBack),
    ));

    // 🎬 Shadow animation - Intensité progressive
    _shadowAnimation = Tween<double>(
      begin: 0.15,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    ));

    // 🎬 Border radius animation - Transition douce
    _borderRadiusAnimation = Tween<double>(
      begin: 35.0,
      end: 25.0,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: AppleCurves.easeInOutQuart,
    ));

    // 🎬 Blur animation
    _blurController = AnimationController(
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 300), // Fermeture plus graduelle
      vsync: this,
    );
    
    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _blurController,
      curve: Curves.easeOut,
    ));

    // 🎬 Fade animation - Plus subtil
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    // ▶️ Séquence d'animations d'entrée
    _slideController.forward();
    _fadeController.forward();
  }

  void _setupKeyboardListener() {
    var keyboardVisibilityController = KeyboardVisibilityController();
    
    _isKeyboardVisible = keyboardVisibilityController.isVisible;
    
    keyboardSubscription = keyboardVisibilityController.onChange.listen((bool visible) {
      if (!mounted) return; // 🛡️ Protection contre les appels après dispose
      
      print('🎹 Keyboard visibility: $visible');
      
      setState(() {
        _isKeyboardVisible = visible;
      });
      
      // 🎬 Séquence d'animations coordonnées avec nouvelle logique
      if (visible) {
        // ▶️ Clavier apparaît : toujours expand
        _expandController.forward();
        _blurController.forward();
        // Délai pour l'animation du contenu
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _contentController.forward();
          }
        });
      } else {
        // 🔍 Clavier disparaît : garder ouvert si suggestions présentes
        if (_shouldKeepPanelOpen()) {
          // Garder le panel étendu mais réduire légèrement l'effet blur
          _blurController.animateTo(0.7);
          print('🎯 Panel reste ouvert : suggestions présentes');
        } else {
          // Fermer complètement
          _contentController.reverse();
          _blurController.reverse();
          Future.delayed(const Duration(milliseconds: 80), () {
            if (mounted) {
              _expandController.reverse();
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _slideController.dispose();
    _expandController.dispose();
    _fadeController.dispose();
    _contentController.dispose();
    _blurController.dispose();
    _searchController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    keyboardSubscription.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return; // 🛡️ Protection supplémentaire
    
  }

  // 🎯 Nouvelle méthode pour vérifier si le panel doit rester ouvert
  bool _shouldKeepPanelOpen() {
    final shouldKeep = _suggestions.isNotEmpty || 
           _searchController.text.isNotEmpty || 
           _isKeyboardVisible || 
           _focusNode.hasFocus;
    
    print('🎯 Should keep panel open: $shouldKeep (suggestions: ${_suggestions.length}, text: "${_searchController.text}", keyboard: $_isKeyboardVisible, focus: ${_focusNode.hasFocus})');
    return shouldKeep;
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (value.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });

      return;
    }

    setState(() {
      _isLoading = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return; // 🛡️ Protection contre les appels après dispose
      
      final results = await GeocodingService.searchAddress(
        value,
        longitude: widget.userLongitude,
        latitude: widget.userLatitude,
      );

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
        
        // 🎯 Si on a des résultats et que le panel n'est pas encore étendu, l'étendre
        if (results.isNotEmpty && !_isKeyboardVisible && _expandController.value < 1.0) {
          _expandController.forward();
          _contentController.forward();
          _blurController.animateTo(0.7);
        }
      }
    });
  }

  void _selectSuggestion(AddressSuggestion suggestion) {
    _searchController.text = suggestion.placeName.split(',').first;
    _focusNode.unfocus();
    
    widget.onLocationSelected?.call(
      suggestion.center[0],
      suggestion.center[1],
      suggestion.placeName,
    );

    _clearSearch();
  }

  void _clearSearch() {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    _suggestions = [];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _slideAnimation, 
        _expandAnimation, 
        _fadeAnimation,
        _shadowAnimation,
        _borderRadiusAnimation,
        _blurAnimation,
      ]),
      builder: (context, child) {        
        // 📏 Calculs de taille avec interpolation non-linéaire
        final normalHeight = 70.0;
        final maxHeight = MediaQuery.of(context).size.height * 0.85;
        
        // 🎯 Hauteur adaptée selon l'état
        double targetHeight;
        if (_isKeyboardVisible) {
          // Clavier visible : hauteur maximale
          targetHeight = maxHeight;
        } else if (_suggestions.isNotEmpty || _searchController.text.isNotEmpty) {
          // Suggestions présentes : hauteur moyenne
          targetHeight = MediaQuery.of(context).size.height * 0.5;
        } else {
          // État compact
          targetHeight = normalHeight;
        }
        
        // Courbe d'expansion personnalisée pour un effet plus naturel
        final expansionCurve = Curves.easeOutQuart.transform(_expandAnimation.value);
        final currentHeight = normalHeight + ((targetHeight - normalHeight) * expansionCurve);

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildPanel(context, currentHeight),
          ),
        );
      },
    );
  }

  Widget _buildPanel(BuildContext context, double height) {
    // 🎨 Calculs dynamiques pour les propriétés visuelles
    final horizontalPadding = _isKeyboardVisible 
        ? 0.0
        : 20.0;
        
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isKeyboardVisible)
          // 🎨 Bouton générateur avec effet de pulsation
          Align(
            alignment: Alignment.bottomRight,
            child: AnimatedScale(
              duration: Duration(milliseconds: 200),
              scale: 1.0 - (0.05 * _expandAnimation.value),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 6.0,
                ),
                decoration: BoxDecoration(
                  color: context.adaptiveBackground,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      spreadRadius: 2,
                      blurRadius: 30,
                      offset: Offset(0, 0), // changes position of shadow
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    HugeIcons.solidRoundedAiMagic,
                    size: 30.0,
                  ),
                  onPressed: widget.onPressed,
                ),
              ),
            ),
          ),

          12.h,

          AnimatedContainer(
            duration: Duration(milliseconds: 100),
            height: height,
            decoration: BoxDecoration(
              color: context.adaptiveBackground,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  spreadRadius: 2,
                  blurRadius: 30,
                  offset: Offset(0, 0), // changes position of shadow
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_borderRadiusAnimation.value),
              child: Column(
                children: [
                  // 🔍 Barre de recherche avec animation de scale subtile
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.all(5.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            curve: AppleCurves.easeInOutQuart,
                            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            height: 60,
                            decoration: BoxDecoration(
                              color: context.adaptiveDisabled.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              children: [
                                AnimatedScale(
                                  duration: Duration(milliseconds: 200),
                                  scale: 1.0 + (0.1 * _expandAnimation.value),
                                  child: HugeIcon(
                                    icon: HugeIcons.solidRoundedSearch01,
                                    size: 22,
                                    color: context.adaptiveDisabled,
                                  ),
                                ),
                                12.w,
                                Expanded(
                                  child: RoundedTextField(
                                    controller: _searchController,
                                    focusNode: _focusNode,
                                    onChanged: _onSearchChanged,
                                    textCapitalization: TextCapitalization.sentences,
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                AnimatedSwitcher(
                                  duration: Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) => ScaleTransition(
                                    scale: CurvedAnimation(
                                      parent: animation,
                                      curve: AppleCurves.easeOutBack,
                                      reverseCurve: AppleCurves.softEaseOut,
                                    ),
                                    child: FadeTransition(opacity: animation, child: child),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(context.adaptiveDisabled),
                                        ),
                                      )
                                      : GestureDetector(
                                      onTap: _clearSearch,
                                      child: AnimatedScale(
                                        duration: Duration(milliseconds: 150),
                                        scale: 1.0,
                                        child: HugeIcon(
                                          icon: HugeIcons.solidRoundedCancelCircle,
                                          size: 25,
                                          color: context.adaptiveDisabled,
                                        ),
                                      ),
                                    ),
                                ),
                              ],
                            ),
                          ),
                        ),
          
                        // 🎨 Bouton générateur avec effet de pulsation
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (_, authState) {      
                            // Si l'utilisateur est connecté, afficher le contenu
                            if (authState is Authenticated) {
                              final user = authState.profile;
                              final initialColor = math.Random().nextInt(Colors.primaries.length);
                              final color = Colors.primaries[initialColor];

                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 8.0,
                                ),
                                child: AnimatedScale(
                                  duration: Duration(milliseconds: 200),
                                  scale: 1.0 - (0.05 * _expandAnimation.value),
                                  child: GestureDetector(
                                    onTap: widget.onProfile,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: HSLColor.fromColor(color).withLightness(0.8).toColor(),
                                      ),
                                      child: user.avatarUrl != null 
                                        ? ClipOval(
                                          // <-- ou CircleAvatar, comme vous préférez
                                          child: CachedNetworkImage(
                                            imageUrl: user.avatarUrl!,
                                            fit: BoxFit.cover,
                                          ),
                                        ) 
                                        : Center(
                                          child: Text(
                                            user.initials,
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                          ),
                                        ),
                                      )
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 8.0,
                              ),
                              child: AnimatedScale(
                                duration: Duration(milliseconds: 200),
                                scale: 1.0 - (0.05 * _expandAnimation.value),
                                child: GestureDetector(
                                  onTap: widget.onProfile,
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.adaptivePrimary,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        HugeIcons.solidRoundedUserCircle02,
                                        color: Colors.white,
                                        size: 25.0,
                                      ),
                                    )
                                  ),
                                ),
                              ),
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                  
                  // 📋 Zone des suggestions avec animation en cascade
                  // 🎯 Afficher si clavier visible OU si suggestions présentes
                  if (_isKeyboardVisible || _suggestions.isNotEmpty)
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _contentFadeAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _contentScaleAnimation.value,
                            child: Opacity(
                              opacity: _contentFadeAnimation.value,
                              child: _buildSuggestionsArea(),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsArea() {
    return Container(
      margin: EdgeInsets.all(5.0),
      child: _suggestions.isNotEmpty 
        ? _buildSuggestionsList()
        : _buildEmptyState(),
    );
  }

  Widget _buildSuggestionsList() {
    return BlurryPage(
      children: [
        ..._suggestions.asMap().entries.map((entry) {
          final index = entry.key;
          final suggestion = entry.value;
          return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 400 + (index * 60)), // Cascade plus prononcée
          tween: Tween(begin: 0.0, end: 1.0),
          curve: AppleCurves.easeOutBack,
          builder: (context, value, child) {
            // 🛡️ S'assurer que les valeurs sont valides
            if (!mounted) return SizedBox.shrink();
            
            final clampedValue = _clampOpacity(value);
            
            return Transform.translate(
              offset: Offset(30 * (1 - clampedValue), 0), // Glissement horizontal
              child: Transform.scale(
                scale: 0.9 + (0.1 * clampedValue),
                child: Opacity(
                  opacity: clampedValue,
                  child: InkWell(
                    onTap: () => _selectSuggestion(suggestion),
                    borderRadius: BorderRadius.circular(12),
                    splashColor: context.adaptiveTextSecondary.withValues(alpha: 0.1),
                    highlightColor: context.adaptiveTextSecondary.withValues(alpha: 0.05),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            child: SquircleContainer(
                              radius: 30,
                              isGlow: true,
                              color: context.adaptivePrimary,
                              padding: const EdgeInsets.all(15),
                              child: HugeIcon(
                                icon: HugeIcons.solidRoundedLocation01,
                                color: Colors.white,
                                size: 25,
                              ),
                            ),
                          ),
                          12.w,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.placeName.split(',').first,
                                  style: context.bodyMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (suggestion.placeName.contains(',')) ...[
                                  2.h,
                                  Text(
                                    suggestion.placeName.split(',').skip(1).join(',').trim(),
                                    style: context.bodyMedium?.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: context.adaptiveTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
        })
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: AppleCurves.gentleSpring,
            builder: (context, value, child) {
              // 🛡️ Protection contre les valeurs invalides
              if (!mounted) return SizedBox.shrink();
              
              final clampedValue = _clampOpacity(value);
              
              return Transform.scale(
                scale: 0.6 + (0.4 * clampedValue),
                child: Opacity(
                  opacity: clampedValue,
                  child: Icon(
                    HugeIcons.solidRoundedSearch01,
                    size: 48,
                    color: context.adaptiveTextSecondary.withValues(alpha: 0.4),
                  ),
                ),
              );
            },
          ),
          16.h,
          AnimatedOpacity(
            duration: Duration(milliseconds: 600),
            opacity: 1.0,
            child: Text(
              _isLoading 
                ? 'Recherche en cours...'
                : _searchController.text.isEmpty
                  ? 'Tapez pour rechercher un lieu'
                  : 'Aucun résultat trouvé',
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}