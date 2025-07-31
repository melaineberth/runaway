import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/features/route_generator/data/services/geocoding_service.dart';
import 'package:runaway/core/widgets/rounded_text_field.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';

/// 🍎 Courbes d'animation personnalisées inspirées d'Apple
class AppleCurves {
  static const Curve easeOutBack = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Curve easeInOutQuart = Cubic(0.76, 0, 0.24, 1);
  static const Curve springyEaseOut = Cubic(0.25, 0.46, 0.45, 0.94);
  static const Curve gentleSpring = Cubic(0.175, 0.885, 0.32, 1.275);
  static const Curve softEaseOut = Cubic(0.25, 0.1, 0.25, 1.0);
}

/// Widget de recherche de localisation avec gestion automatique du clavier
class FloatingLocationSearchSheet extends StatefulWidget {
  const FloatingLocationSearchSheet({
    super.key,
    this.onLocationSelected,
    this.userLongitude,
    this.userLatitude,
    this.onProfile,
    required this.searchButtonKey,
  });

  final Function(double longitude, double latitude, String placeName)? onLocationSelected;
  final double? userLongitude;
  final double? userLatitude;
  final Function()? onProfile;
  final GlobalKey searchButtonKey;

  @override
  State<FloatingLocationSearchSheet> createState() => _FloatingLocationSearchSheetState();
}

class _FloatingLocationSearchSheetState extends State<FloatingLocationSearchSheet> with TickerProviderStateMixin {
  // 📏 Constants de design -----------------------------------------------
  late final ScrollController _scrollController;

  // 🆕 Hauteurs dynamiques calculées
  static const double _kSearchBarHeight = 60.0;
  static const double _kCollapsedPadding = 8.0;
  
  static const double _kSnapMidRatio = 0.45;
  static const double _kMaxRatio = 0.93;
  static const Duration _kDebounceDelay = Duration(milliseconds: 500);
  static const Duration _kAnimationDelay = Duration(milliseconds: 100);
  
  // Animation durations
  static const Duration _kExpandDuration = Duration(milliseconds: 400);
  static const Duration _kCollapseDuration = Duration(milliseconds: 300);
  static const Duration _kMidDuration = Duration(milliseconds: 350);

  bool _isCutByTop = false;

  // Controllers et états ------------------------------------------------
  late StreamSubscription<bool> _keyboardSubscription;
  late AnimationController _pillAnimationController;
  
  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<AddressSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isKeyboardVisible = false;
  bool _isAnimatingSheet = false;
  bool _isDisposed = false;
  
  Timer? _debounce;

  // Helpers -------------------------------------------------------------
  
  /// 🛡️ S'assure que l'opacité reste dans les limites valides
  double _clampOpacity(double value) => value.clamp(0.0, 1.0);
  
  /// 🎯 Vérifie si la modal doit être dans un état "expanded"
  bool get _shouldBeExpanded => _suggestions.isNotEmpty || _isKeyboardVisible || _searchController.text.isNotEmpty;

  double _getMinimumCollapsedRatio(BuildContext context) {
    final media = MediaQuery.of(context);
    final minimumHeight = _calculateMinimumContentHeight(context);
    
    // Calculer le ratio mais avec une limite basse raisonnable
    final ratio = minimumHeight / media.size.height;
    
    return ratio;
  }

  /// 📐 Calcule la hauteur minimale nécessaire pour afficher le contenu
  double _calculateMinimumContentHeight(BuildContext context) {
    final additionalHeight = Platform.isAndroid ? 20.0 : 17.0;
    // Hauteur de base = barre de recherche + paddings
    double baseHeight = _kSearchBarHeight + additionalHeight; // +16px pour le padding intérieur (8px top + 8px bottom)
        
    return baseHeight;
  }
  
  /// 📐 Calcule le ratio collapsed basé sur l'état actuel
  double _calculateCollapsedRatio(BuildContext context) {
    final media = MediaQuery.of(context);
    final minRatio = _getMinimumCollapsedRatio(context);
    
    if (_shouldBeExpanded) {
      // Pour l'état expanded, utiliser plus d'espace pour les suggestions
      final expandedHeight = _calculateMinimumContentHeight(context) + media.padding.bottom + 100; // +100 pour suggestions
      final expandedRatio = (expandedHeight / media.size.height).clamp(minRatio, _kMaxRatio);
      return expandedRatio;
    } else {
      // Pour l'état collapsed, utiliser exactement la hauteur du contenu
      return minRatio;
    }
  }

  /// 📐 Calcule le padding horizontal en fonction de la position de la sheet
  double _calculateHorizontalPadding(double currentPosition) {
    final minRatio = _getMinimumCollapsedRatio(context);
    // Position entre 0.0 (collapsed) et 1.0 (expanded)
    final progress = ((currentPosition - minRatio) / (_kMaxRatio - minRatio)).clamp(0.0, 1.0);

    // Interpolation inversée : 20px (collapsed) vers 0px (expanded)
    return 20.0 - (progress * 20.0);
  }

  /// 📐 Calcule le padding bottom en fonction de la plateforme
  double _calculateBottomPadding(BuildContext context, double horizontalPadding) {
    final media = MediaQuery.of(context);
  
    // Sur Android, ajouter le padding système pour la barre de navigation
    if (Platform.isAndroid) {
      // Utiliser la hauteur minimale comme base + padding système
      return math.max(horizontalPadding, media.padding.bottom + 8.0);
    }
    
    // Sur iOS, garder le comportement existant mais avec minimum
    return horizontalPadding;
  }

  // Lifecycle -----------------------------------------------------------
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupKeyboardListener();
    _setupFocusListener();

    _scrollController = ScrollController()
      ..addListener(() => _updateEdgeState(_scrollController.position));

    // Vérification initiale après le premier build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndResetSheetPosition();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Vérifier et réinitialiser la position quand on revient sur cette page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndResetSheetPosition();
    });
  }

  /// 🔄 Vérifie et réinitialise la position du sheet si nécessaire
  void _checkAndResetSheetPosition() {
    if (_isDisposed || !mounted) return;

    // Vérifier l'état actuel du clavier
    final keyboardController = KeyboardVisibilityController();
    final currentKeyboardState = keyboardController.isVisible;
    
    // 🆕 Ne pas réagir si on n'est pas sur l'écran principal
    if (!_isCurrentRouteHome()) {
      return;
    }
    
    // Mettre à jour l'état du clavier si nécessaire
    if (_isKeyboardVisible != currentKeyboardState) {
      _isKeyboardVisible = currentKeyboardState;
    }

    // Si le clavier est fermé, pas de suggestions et pas de texte
    final shouldCollapse = !_isKeyboardVisible && 
                          _suggestions.isEmpty && 
                          _searchController.text.isEmpty;

    if (shouldCollapse && _sheetCtrl.isAttached) {
      // Vérifier si le sheet n'est pas déjà en position minimale
      final currentSize = _sheetCtrl.size;
      final minRatio = _getMinimumCollapsedRatio(context); // 🔧 CHANGEMENT
      if (currentSize > minRatio + 0.01) {
        // Fermer le sheet avec animation
        _scheduleConditionalCollapse();
      }
    }
  }

  /// 🆕 Vérifie si on est sur la route Home
  bool _isCurrentRouteHome() {
    try {
      // Méthode 1: Vérifier si le widget est dans l'arbre visible
      final renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) {
        return false;
      }
      
      // Méthode 2: Vérifier si le widget parent (HomeScreen) est toujours là
      final homeScreenContext = context.findAncestorWidgetOfExactType<Scaffold>();
      if (homeScreenContext == null) {
        return false;
      }
      
      // Méthode 3: Vérifier que le focus n'est pas sur un autre écran
      // Si un TextField a le focus mais ce n'est pas le nôtre, on est probablement sur un autre écran
      final currentFocus = FocusScope.of(context).focusedChild;
      if (currentFocus != null && currentFocus != _focusNode && !_focusNode.hasFocus) {
        // Un autre champ a le focus, vérifier si c'est dans notre arbre
        final isInOurTree = _focusNode.context != null;
        if (!isInOurTree) {
          return false;
        }
      }
      
      return true;
    } catch (_) {
      return false;
    }
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _cleanupResources();
    super.dispose();
  }

  void _updateEdgeState(ScrollMetrics m) {
    final cut = _scrollController.offset > 0;
    if (cut != _isCutByTop) {
      setState(() => _isCutByTop = cut);
    }
  }

  /// 🏗️ Initialise les contrôleurs d'animation
  void _initializeControllers() {
    _pillAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  /// 🧹 Nettoie toutes les ressources
  void _cleanupResources() {
    _debounce?.cancel();
    _keyboardSubscription.cancel();
    _pillAnimationController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _sheetCtrl.dispose();
  }

  /// 👂 Configure l'écoute du clavier
  void _setupKeyboardListener() {
    final keyboardController = KeyboardVisibilityController();
    _isKeyboardVisible = keyboardController.isVisible;
    
    _keyboardSubscription = keyboardController.onChange.listen((bool visible) {
      if (_isDisposed || !mounted) return;
      
      // 🆕 Ne réagir aux événements du clavier que si on est sur HomeScreen
      if (!_isCurrentRouteHome()) {
        debugPrint('🎹 Keyboard event ignored - not on home screen');
        return;
      }
      
      debugPrint('🎹 Keyboard visibility: $visible');
      
      // 🆕 Éviter setState pendant le build
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed && _isCurrentRouteHome()) {
            setState(() => _isKeyboardVisible = visible);
            _handleKeyboardAnimation(visible);
          }
        });
        return;
      }
      
      setState(() => _isKeyboardVisible = visible);
      _handleKeyboardAnimation(visible);
    });
  }

  /// 👂 Configure l'écoute du focus
  void _setupFocusListener() {
    _focusNode.addListener(() {
      if (_isDisposed || !mounted) return;
      setState(() {});
    });
  }

  // Animation Logic -----------------------------------------------------

  /// 🎬 Gère les animations de la modal en fonction du clavier
  Future<void> _handleKeyboardAnimation(bool keyboardVisible) async {
    if (_isAnimatingSheet || _isDisposed || !mounted) return;
    
    // 🆕 Éviter setState pendant le build
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          _handleKeyboardAnimation(keyboardVisible);
        }
      });
      return;
    }
    
    _isAnimatingSheet = true;
    
    try {
      final collapsedRatio = _calculateCollapsedRatio(context);
      
      if (keyboardVisible) {
        await _expandForKeyboard();
      } else {
        await _collapseForKeyboard(collapsedRatio);
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de l\'animation de la modal: $e');
    } finally {
      if (mounted && !_isDisposed) {
        _isAnimatingSheet = false;
      }
    }
  }

  /// ▶️ Expand la modal pour le clavier
  Future<void> _expandForKeyboard() async {
    final targetRatio = _suggestions.isNotEmpty ? _kMaxRatio : _kSnapMidRatio;
    
    await _sheetCtrl.animateTo(
      targetRatio,
      duration: _kExpandDuration,
      curve: AppleCurves.springyEaseOut,
    );
  }

  /// 🔽 Collapse la modal après fermeture du clavier
  Future<void> _collapseForKeyboard(double collapsedRatio) async {
    if (_searchController.text.isEmpty && _suggestions.isEmpty) {
      // Réduire complètement si tout est vide
      _scheduleConditionalCollapse();
    } else {
      // Garder ouvert selon le contenu
      final targetRatio = _suggestions.isNotEmpty ? _kMaxRatio : _kSnapMidRatio;
      await _sheetCtrl.animateTo(
        targetRatio,
        duration: _kMidDuration,
        curve: AppleCurves.softEaseOut,
      );
    }
  }

  /// 🎯 Méthode publique pour expandre la modal
  Future<void> expandSheet({double? targetRatio}) async {
    if (_isAnimatingSheet || _isDisposed || !mounted) return;
    
    try {
      _isAnimatingSheet = true;
      final ratio = targetRatio ?? _kSnapMidRatio;
      
      await _sheetCtrl.animateTo(
        ratio,
        duration: _kExpandDuration,
        curve: AppleCurves.springyEaseOut,
      );
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de l\'expansion: $e');
    } finally {
      if (mounted && !_isDisposed) {
        _isAnimatingSheet = false;
      }
    }
  }

  /// 🎯 Méthode publique pour réduire la modal
  Future<void> collapseSheet() async {
    if (_isAnimatingSheet || _isDisposed || !mounted) return;
    
    try {
      _isAnimatingSheet = true;
      
      final minRatio = _getMinimumCollapsedRatio(context); // 🔧 CHANGEMENT
      await _sheetCtrl.animateTo(
        minRatio,
        duration: _kCollapseDuration,
        curve: AppleCurves.easeInOutQuart,
      );
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de la réduction: $e');
    } finally {
      if (mounted && !_isDisposed) {
        _isAnimatingSheet = false;
      }
    }
  }

  // Search Logic --------------------------------------------------------

  /// 🔍 Gère les changements de texte de recherche
  void _onSearchChanged(String value) {
    if (_isDisposed) return;
    
    _cancelPreviousSearch();
    
    if (value.isEmpty) {
      _clearSuggestions();
      _adjustSheetForEmptySearch();
      return;
    }

    _startLoading();
    _debounceSearch(value);
  }

  /// ❌ Annule la recherche précédente
  void _cancelPreviousSearch() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
  }

  /// 🧹 Vide les suggestions
  void _clearSuggestions() {
    setState(() {
      _suggestions = [];
      _isLoading = false;
    });
  }

  /// ⏳ Démarre le loading
  void _startLoading() {
    setState(() => _isLoading = true);
  }

  /// 🎬 Ajuste la sheet pour une recherche vide
  void _adjustSheetForEmptySearch() {
    if (_isKeyboardVisible && !_isAnimatingSheet) {
      _handleKeyboardAnimation(true);
    }
  }

  /// ⏰ Lance une recherche avec debounce
  void _debounceSearch(String value) {
    _debounce = Timer(_kDebounceDelay, () => _performSearch(value));
  }

  /// 🔎 Effectue la recherche
  Future<void> _performSearch(String value) async {
    if (_isDisposed || !mounted) return;
    
    try {
      LogConfig.logInfo('🔍 Début de recherche pour: "$value"');
      
      final results = await GeocodingService.searchAddress(
        value,
        longitude: widget.userLongitude,
        latitude: widget.userLatitude,
        limit: 30, 
      );

      if (_isDisposed || !mounted) return;

      LogConfig.logInfo('🔍 Résultats reçus dans FloatingLocationSearchSheet: ${results.length}');
      
      // 🐛 DEBUG: Afficher tous les résultats
      for (int i = 0; i < results.length; i++) {
        LogConfig.logInfo('🔍 Résultat $i: ${results[i].placeName}');
      }

      setState(() {
        _suggestions = results;
        _isLoading = false;
      });

      LogConfig.logInfo('🔍 _suggestions mis à jour avec ${_suggestions.length} éléments');

      _adjustSheetForNewSuggestions(results);
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de la recherche: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    }
  }

  /// 🎬 Ajuste la sheet pour de nouvelles suggestions
  void _adjustSheetForNewSuggestions(List<AddressSuggestion> results) {
    if (_isKeyboardVisible && results.isNotEmpty && !_isAnimatingSheet) {
      expandSheet(targetRatio: _kMaxRatio);
    }
  }

  /// 📍 Sélectionne une suggestion
  void _selectSuggestion(AddressSuggestion suggestion) {
    if (_isDisposed) return;
    
    _searchController.text = suggestion.placeName.split(',').first;
    
    widget.onLocationSelected?.call(
      suggestion.center[0],
      suggestion.center[1],
      suggestion.placeName,
    );
    
    _clearSearch();
  }

  /// 🧹 Vide la recherche
  void _clearSearch() {
    if (_isDisposed) return;
    
    FocusScope.of(context).unfocus();
    _searchController.clear();
    _suggestions = [];
    setState(() {});
    
    _scheduleConditionalCollapse();
  }

  /// ⏰ Programme la réduction conditionnelle
  void _scheduleConditionalCollapse() {
    Timer(_kAnimationDelay, () {
      if (mounted && !_isDisposed && !_isKeyboardVisible) {
        collapseSheet();
      }
    });
  }

  // UI Building ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final desiredRatio = _calculateCollapsedRatio(context);
    final minRatio = _getMinimumCollapsedRatio(context); // 🔧 AJOUT

    // 🔧 CHANGEMENT: Initialiser _currentCollapsedRatio si pas encore fait
    double? currentCollapsedRatio = desiredRatio;

    // ‼️ évite setState durant le build
    if ((desiredRatio - currentCollapsedRatio).abs() > 1e-4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          setState(() => currentCollapsedRatio = desiredRatio);
        }
      });
    }

    return AnimatedBuilder(
      animation: _sheetCtrl,
      builder: (context, child) {
        final currentPosition = _sheetCtrl.isAttached ? _sheetCtrl.size : minRatio;
        final horizontalPadding = _calculateHorizontalPadding(currentPosition);

        // 🆕 Calcul du padding bottom spécifique à la plateforme
        final bottomPadding = _calculateBottomPadding(context, horizontalPadding);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            bottomPadding,
          ),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  spreadRadius: 2,
                  blurRadius: 30,
                  offset: Offset(0,0,), // changes position of shadow
                ),
              ],
              borderRadius: BorderRadius.circular(40),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Container(
                decoration: BoxDecoration(
                  color: context.adaptiveBackground,
                ),
                child: _buildDraggableSheet(currentCollapsedRatio!),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 📜 Construit la sheet draggable (REMPLACEZ cette méthode)
  Widget _buildDraggableSheet(double collapsedRatio) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        // 🆕 Empêcher les notifications pendant le build
        if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
          return true; // Bloquer la notification
        }
        return false; // Laisser passer la notification
      },
      child: DraggableScrollableSheet(
        controller: _sheetCtrl,
        minChildSize: collapsedRatio,
        maxChildSize: _kMaxRatio,
        initialChildSize: collapsedRatio,
        snap: true,
        snapSizes: [collapsedRatio, _kSnapMidRatio, _kMaxRatio],
        expand: false,
        builder: (context, scrollController) => _buildScrollView(scrollController),
      ),
    );
  }

  /// 📋 Construit la vue scrollable
  Widget _buildScrollView(ScrollController scrollController) {
  return SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildSearchBar(),
        ),
        CustomScrollView(
          shrinkWrap: true,
          controller: scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 300),
              sliver: _buildSuggestionsList(),
            ),
          ],
        ),
      ],
    ),
  );
}

  /// 🔍 Construit la barre de recherche
  Widget _buildSearchBar() {
    return Row(
      key: widget.searchButtonKey,
      children: [
        Expanded(child: _buildSearchField()),
        _buildProfileButton(),
      ],
    );
  }

  /// 📝 Construit le champ de recherche
  Widget _buildSearchField() {
    return Container(
      height: _kSearchBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: context.adaptiveDisabled.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Icon(
            HugeIcons.solidRoundedSearch01,
            size: 22,
            color: context.adaptiveDisabled,
          ),
          12.w,
          Expanded(
            child: RoundedTextField(
              hint: context.l10n.searchAdress,
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          if (_searchController.text.isNotEmpty) _buildActionButton(),
        ],
      ),
    );
  }

  /// ⚡ Construit le bouton d'action (loading/clear)
  Widget _buildActionButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.easeIn,
          reverseCurve: Curves.easeOut,
        ),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: _isLoading ? _buildLoadingIndicator() : _buildClearButton(),
    );
  }

  /// ⏳ Construit l'indicateur de chargement
  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(context.adaptiveDisabled),
      ),
    );
  }

  /// ❌ Construit le bouton clear
  Widget _buildClearButton() {
    return GestureDetector(
      onTap: _clearSearch,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: 1.0,
        child: HugeIcon(
          icon: HugeIcons.solidRoundedCancelCircle,
          size: 25,
          color: context.adaptiveDisabled,
        ),
      ),
    );
  }

  /// 👤 Construit le bouton de profil
  Widget _buildProfileButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          return GestureDetector(
            onTap: widget.onProfile,
            child: authState is Authenticated 
                ? _buildAuthenticatedAvatar(authState.profile)
                : _buildDefaultAvatar(),
          );
        },
      ),
    );
  }

  /// 👤 Construit l'avatar utilisateur authentifié
  Widget _buildAuthenticatedAvatar(dynamic user) {
    final color = Color(int.parse(user.color));

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HSLColor.fromColor(color).withLightness(0.8).toColor(),
      ),
      child: user.avatarUrl != null 
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: user.avatarUrl!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => _buildInitials(user.initials, color),
              ),
            ) 
          : _buildInitials(user.initials, color),
    );
  }

  /// 📝 Construit les initiales
  Widget _buildInitials(String initials, Color color) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darken(color),
        ),
      ),
    );
  }

  /// 👤 Construit l'avatar par défaut
  Widget _buildDefaultAvatar() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.adaptivePrimary,
      ),
      child: const Center(
        child: Icon(
          HugeIcons.solidRoundedUserCircle02,
          color: Colors.white,
          size: 25.0,
        ),
      ),
    );
  }

  /// 📜 Construit la liste des suggestions (REMPLACEZ cette méthode)
  Widget _buildSuggestionsList() {
    return SliverList(
        delegate: SliverChildBuilderDelegate((context, i) {
          return _buildSuggestionItem(i); // HERE goes your list item
        },
        childCount: _suggestions.length,
      ),
    );
  }

  /// 📍 Construit un élément de suggestion
  Widget _buildSuggestionItem(int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 60)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: AppleCurves.easeOutBack,
      builder: (context, value, child) {
        if (!mounted || _isDisposed) return const SizedBox.shrink();
        
        final clampedValue = _clampOpacity(value);
        final suggestion = _suggestions[index];
        
        return Transform.translate(
          offset: Offset(30 * (1 - clampedValue), 0),
          child: Transform.scale(
            scale: 0.9 + (0.1 * clampedValue),
            child: Opacity(
              opacity: clampedValue,
              child: _buildSuggestionContent(suggestion),
            ),
          ),
        );
      },
    );
  }

  /// 📍 Contenu d'une suggestion
  Widget _buildSuggestionContent(AddressSuggestion suggestion) {
    return InkWell(
      onTap: () => _selectSuggestion(suggestion),
      borderRadius: BorderRadius.circular(12),
      splashColor: context.adaptiveTextSecondary.withValues(alpha: 0.1),
      highlightColor: context.adaptiveTextSecondary.withValues(alpha: 0.05),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Row(
          children: [
            _buildSuggestionIcon(),
            12.w,
            Expanded(child: _buildSuggestionText(suggestion)),
          ],
        ),
      ),
    );
  }

  /// 🏷️ Icône d'une suggestion
  Widget _buildSuggestionIcon() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
    );
  }

  /// 📝 Texte d'une suggestion
  Widget _buildSuggestionText(AddressSuggestion suggestion) {
    final parts = suggestion.placeName.split(',');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.first,
          style: context.bodyMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (parts.length > 1) ...[
          2.h,
          Text(
            parts.skip(1).join(',').trim(),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.adaptiveTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
