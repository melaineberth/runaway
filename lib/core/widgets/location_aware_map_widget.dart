import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/services/location_preload_service.dart';
import 'package:runaway/config/extensions.dart';

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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
      begin: 0.3,
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
      print('🌍 Pré-chargement de la géolocalisation...');
      
      // Si on doit restaurer depuis le cache et qu'on a une position valide
      if (widget.restoreFromCache && LocationPreloadService.instance.hasValidPosition) {
        _initialPosition = LocationPreloadService.instance.lastKnownPosition;
        print('✅ Position restaurée depuis le cache');
        _showMapWithPosition();
        return;
      }

      // Charger la position via le service
      final position = await LocationPreloadService.instance.initializeLocation();
      _initialPosition = position;
      
      print('✅ Géolocalisation pré-chargée: ${position.latitude}, ${position.longitude}');
      _showMapWithPosition();
      
    } catch (e) {
      print('❌ Erreur pré-chargement géolocalisation: $e');
      setState(() {
        _locationError = true;
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  /// Affiche la carte avec la position obtenue
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
    if (error is LocationException) {
      return error.message;
    }
    return 'Impossible d\'obtenir votre position';
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
        // Carte (affichée seulement quand la position est prête)
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

        // Loader de géolocalisation
        if (_isLoadingLocation)
          _buildLocationLoader(),

        // Écran d'erreur
        if (_locationError)
          _buildErrorState(),
      ],
    );
  }

  /// Loader élégant pendant le chargement de la géolocalisation
  Widget _buildLocationLoader() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a1a),
            Color(0xFF0d1117),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animation de localisation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withOpacity(0.2),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      HugeIcons.strokeRoundedLocationShare02,
                      size: 50,
                      color: Colors.blue,
                    ),
                  ),
                );
              },
            ),
            
            32.h,
            
            // Texte de chargement
            Text(
              'Localisation en cours...',
              style: context.bodyLarge?.copyWith(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            16.h,
            
            Text(
              'Recherche de votre position',
              style: context.bodyMedium?.copyWith(
                color: Colors.white60,
                fontSize: 16,
              ),
            ),
            
            32.h,
            
            // Indicateur de progression
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Écran d'erreur avec options de retry
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
            Color(0xFF0d1117),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône d'erreur
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  HugeIcons.strokeRoundedAlert02,
                  size: 50,
                  color: Colors.red,
                ),
              ),
              
              32.h,
              
              // Message d'erreur
              Text(
                'Erreur de localisation',
                style: context.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              16.h,
              
              Text(
                _errorMessage ?? 'Impossible d\'obtenir votre position',
                style: context.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              
              48.h,
              
              // Boutons d'action
              Column(
                children: [
                  // Bouton retry
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      onPressed: _retryLocation,
                      icon: Icon(HugeIcons.strokeRoundedRefresh),
                      label: Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  16.h,
                  
                  // Bouton continuer sans localisation
                  SizedBox(
                    width: 200,
                    child: TextButton.icon(
                      onPressed: _continueWithoutLocation,
                      icon: Icon(HugeIcons.strokeRoundedArrowRight01),
                      label: Text('Continuer sans GPS'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white60,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Réessaye d'obtenir la localisation
  void _retryLocation() {
    setState(() {
      _isLoadingLocation = true;
      _locationError = false;
      _errorMessage = null;
    });
    
    // Recommencer l'animation de pulse
    _pulseController.repeat(reverse: true);
    
    _initializeLocation();
  }

  /// Continue sans localisation (utilise position par défaut)
  void _continueWithoutLocation() {
    // Utiliser Paris comme position par défaut
    _initialPosition = gl.Position(
      latitude: 48.8566,
      longitude: 2.3522,
      timestamp: DateTime.now(),
      accuracy: 100.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    
    print('🔄 Utilisation position par défaut: Paris');
    _showMapWithPosition();
  }
}