import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/services/location_preload_service.dart';

/// Widget qui charge la géolocalisation AVANT d'afficher la carte
/// pour un démarrage fluide comme Apple Plans
class LocationAwareMapWidget extends StatefulWidget {
  final String styleUri;
  final Function(mp.MapboxMap) onMapCreated;
  final ValueKey mapKey;
  final bool restoreFromCache;

  const LocationAwareMapWidget({
    super.key,
    required this.styleUri,
    required this.onMapCreated,
    required this.mapKey,
    this.restoreFromCache = false,
  });

  @override
  State<LocationAwareMapWidget> createState() => _LocationAwareMapWidgetState();
}

class _LocationAwareMapWidgetState extends State<LocationAwareMapWidget>
    with TickerProviderStateMixin {
  
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
        print('✅ Position restaurée depuis le cache');
        _showMapWithPosition();
        return;
      }

      // Charger la position via le service (avec timeout court pour UX fluide)
      final position = await LocationPreloadService.instance.initializeLocation()
          .timeout(Duration(seconds: 5)); // Timeout plus court pour UX
      
      _initialPosition = position;
      print('✅ Géolocalisation chargée: ${position.latitude}, ${position.longitude}');
      _showMapWithPosition();
      
    } catch (e) {
      print('❌ Erreur géolocalisation: $e');
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
              key: widget.mapKey,
              styleUri: widget.styleUri,
              cameraOptions: mp.CameraOptions(
                center: mp.Point(
                  coordinates: mp.Position(
                    _initialPosition!.longitude,
                    _initialPosition!.latitude,
                  ),
                ),
                zoom: 15.0,
                pitch: 0.0,
                bearing: 0.0,
              ),
              onMapCreated: widget.onMapCreated,
            ),
          ),

        // 🔄 LOADER DE GÉOLOCALISATION (style Apple Maps)
        if (_isLoadingLocation)
          _buildAppleMapsLoader(),

        // ❌ ÉCRAN D'ERREUR
        if (_locationError)
          _buildErrorState(),
      ],
    );
  }

  /// 🔄 Loader élégant style Apple Maps
  Widget _buildAppleMapsLoader() {
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
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withValues(alpha: 0.2),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: _pulseAnimation.value),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
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
                        HugeIcons.strokeRoundedLocation01,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            SizedBox(height: 24),
            
            // Texte de chargement
            Text(
              'Localisation...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            SizedBox(height: 8),
            
            Text(
              'Recherche de votre position',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ❌ État d'erreur avec possibilité de retry
  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a1a),
            Color(0xFF2d2d2d),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              HugeIcons.solidSharpLocation01,
              color: Colors.red,
              size: 48,
            ),
            
            SizedBox(height: 16),
            
            Text(
              _errorMessage ?? 'Erreur de localisation',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _locationError = false;
                  _isLoadingLocation = true;
                });
                _initializeLocation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}