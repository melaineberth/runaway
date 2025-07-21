import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/location_preload_service.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';

/// Widget qui charge la géolocalisation AVANT d'afficher la carte
/// pour un démarrage fluide comme Apple Plans
class LocationAwareMapWidget extends StatefulWidget {
  final String styleUri;
  final Function(mp.MapboxMap) onMapCreated;
  final bool restoreFromCache;

  const LocationAwareMapWidget({
    super.key,
    required this.styleUri,
    required this.onMapCreated,
    this.restoreFromCache = false,
  });

  @override
  State<LocationAwareMapWidget> createState() => _LocationAwareMapWidgetState();
}

class _LocationAwareMapWidgetState extends State<LocationAwareMapWidget> with TickerProviderStateMixin {
  // Génération d'une clé unique pour éviter les conflits de platform view
  static int _mapInstanceCounter = 0;
  late final ValueKey _uniqueMapKey;
  
  // États de chargement
  bool _isLoadingLocation = true;
  bool _locationError = false;
  String? _errorMessage;
  gl.Position? _initialPosition;
  
  // Animations
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Générer une clé unique pour cette instance
    _uniqueMapKey = ValueKey("mapWidget_${++_mapInstanceCounter}_${DateTime.now().millisecondsSinceEpoch}");

    _initializeAnimations();
    _initializeLocation();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600), // Plus rapide
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200), // Plus fluide
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Démarrer l'animation de pulse
    _pulseController.repeat(reverse: true);
  }

  /// Initialise la géolocalisation avant d'afficher la carte
  Future<void> _initializeLocation() async {
    try {
      print('🌍 LocationAwareMapWidget: Initialisation géolocalisation...');
      
      // Si on doit restaurer depuis le cache et qu'on a une position valide
      if (widget.restoreFromCache && LocationPreloadService.instance.hasValidPosition) {
        _initialPosition = LocationPreloadService.instance.lastKnownPosition;
        LogConfig.logSuccess('Position restaurée depuis le cache');
        _showMapWithPosition();
        return;
      }

      // Charger la position via le service (avec timeout court pour UX fluide)
      final position = await LocationPreloadService.instance.initializeLocation()
          .timeout(Duration(seconds: 5)); // Timeout plus court pour UX
      
      _initialPosition = position;
      LogConfig.logSuccess('Géolocalisation chargée: ${position.latitude}, ${position.longitude}');
      _showMapWithPosition();
      
    } catch (e) {
      LogConfig.logError('❌ Erreur géolocalisation: $e');
      setState(() {
        _locationError = true;
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  /// Affiche la carte avec la position obtenue (transition fluide)
  void _showMapWithPosition() {
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocation = false;
    });
    
    // Animation de transition fluide
    _fadeController.forward();
  }

  /// Convertit les erreurs en messages utilisateur
  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('LocationException')) {
      return 'Localisation indisponible';
    }
    if (error.toString().contains('timeout')) {
      return 'Localisation trop lente';
    }
    return 'Erreur de localisation';
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🗺️ CARTE (affichée seulement quand la position est prête)
        if (!_isLoadingLocation && _initialPosition != null)
          FadeTransition(
            opacity: _fadeAnimation,
            child: mp.MapWidget(
              key: _uniqueMapKey,
              styleUri: widget.styleUri,
              cameraOptions: mp.CameraOptions(
                center: mp.Point(
                  coordinates: mp.Position(
                    _initialPosition!.longitude,
                    _initialPosition!.latitude,
                  ),
                ),
                zoom: 12.0,
                pitch: 0.0,
                bearing: 0.0,
              ),
              onMapCreated: widget.onMapCreated,
            ),
          ),

        // 🔄 LOADER DE GÉOLOCALISATION
        if (_isLoadingLocation)
          _buildMapsLoader(),

        // ❌ ÉCRAN D'ERREUR
        if (_locationError)
          _buildErrorState(),
      ],
    );
  }

  /// 🔄 Loader élégant
  Widget _buildMapsLoader() {
    final double circleSize = 120.0;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a1a), // Sombre en haut
            Color(0xFF2d2d2d), // Légèrement plus clair en bas
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indicateur de géolocalisation animé
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return AvatarGlow(
                  glowCount: 2,
                  glowColor: Colors.blue,
                  child: Center(
                    child: Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        HugeIcons.solidRoundedMapsGlobal01,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            30.h,
            
            // Texte de chargement
            Text(
              context.l10n.locationInProgress,
              style: context.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
                        
            Text(
              context.l10n.searchingPosition,
              style: context.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ❌ État d'erreur avec possibilité de retry
  Widget _buildErrorState() {
    final double circleSize = 120.0;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a1a), // Sombre en haut
            Color(0xFF2d2d2d), // Légèrement plus clair en bas
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return AvatarGlow(
                  glowCount: 2,
                  glowColor: Colors.red,
                  child: Center(
                    child: Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        HugeIcons.solidRoundedMapsGlobal01,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                );
              },
            ),

            30.h,
            
            // Texte de chargement
            Text(
              _errorMessage ?? context.l10n.trackingError,
              style: context.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            
            24.h,       

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 40.0,
              ),
              child: SquircleBtn(
                label: context.l10n.retry,
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onTap: () {
                  setState(() {
                    _locationError = false;
                    _isLoadingLocation = true;
                  });
                  _initializeLocation();
                },
              ),
            ),     
          ],
        ),
      ),
    );
  }
}