// ignore_for_file: unused_label

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/services/location_preload_service.dart';

class LocationAwareMapWidget extends StatefulWidget {
  final String styleUri;
  final Function(mp.MapboxMap) onMapCreated;
  final bool restoreFromCache;
  final VoidCallback? onLocationPermissionDenied;

  const LocationAwareMapWidget({
    super.key,
    required this.styleUri,
    required this.onMapCreated,
    this.restoreFromCache = false,
    this.onLocationPermissionDenied,
  });

  @override
  State<LocationAwareMapWidget> createState() => _LocationAwareMapWidgetState();
}

class _LocationAwareMapWidgetState extends State<LocationAwareMapWidget> with TickerProviderStateMixin {
  // Génération d'une clé unique pour éviter les conflits de platform view
  static int _mapInstanceCounter = 0;
  late final ValueKey _uniqueMapKey;
  
  // 🔧 ÉTAT : La carte ne peut être affichée qu'une fois la position définie
  bool _isPositionReady = false;
  gl.Position? _initialPosition;
  
  // Position par défaut (Paris)
  static const double _defaultLatitude = 48.8566;
  static const double _defaultLongitude = 2.3522;
  
  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Démarrer l'animation immédiatement
    _fadeController.forward();
  }

  /// Initialise la géolocalisation en attendant que le service soit prêt
  Future<void> _initializeLocation() async {
    try {
      LogConfig.logInfo('🌍 LocationAwareMapWidget: Initialisation géolocalisation...');
      
      // Attendre que le LocationPreloadService soit vraiment prêt
      await _waitForLocationService();
      
    } catch (e) {
      LogConfig.logError('❌ Erreur géolocalisation: $e');
      _handleLocationError(e);
      
      // Position par défaut seulement en cas d'échec
      _setDefaultPosition();
      LogConfig.logInfo('📍 Fallback sur position par défaut (Paris)');
    }
  }

  /// Attendre que le LocationPreloadService soit prêt
  Future<void> _waitForLocationService() async {
    const int maxAttempts = 30; // 3 secondes max
    int attempts = 0;
    
    while (attempts < maxAttempts && mounted) {
      // Vérifier si le service a une position valide
      if (LocationPreloadService.instance.hasValidPosition) {
        final position = LocationPreloadService.instance.lastKnownPosition;
        if (position != null) {
          setState(() {
            _initialPosition = position;
            _isPositionReady = true; // 🔧 PERMETTRE l'affichage de la carte
            _defaultLatitude: position.longitude;
            _defaultLongitude: position.longitude;
          });
          LogConfig.logSuccess('✅ Position trouvée depuis le service: ${position.latitude}, ${position.longitude}');
          return;
        }
      }
      
      // Attendre un peu et réessayer
      await Future.delayed(Duration(milliseconds: 100));
      attempts++;
    }
    
    // Si on arrive ici, le service n'a pas de position après 3 secondes
    LogConfig.logInfo('⏰ Timeout atteint - tentative géolocalisation directe');
    
    // Dernière tentative : géolocalisation directe
    await _loadLocationDirectly();
  }

  /// Tentative de géolocalisation directe
  Future<void> _loadLocationDirectly() async {
    try {
      final position = await LocationPreloadService.instance.initializeLocation().timeout(Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _initialPosition = position;
          _isPositionReady = true; // 🔧 PERMETTRE l'affichage de la carte
        });
        LogConfig.logSuccess('✅ Géolocalisation directe réussie: ${position.latitude}, ${position.longitude}');
      }
      
    } catch (e) {
      LogConfig.logInfo('❌ Géolocalisation directe échouée: $e');
      _handleLocationError(e);
      
      // Utiliser Paris par défaut en dernier recours
      if (_initialPosition == null) {
        _setDefaultPosition();
      }
    }
  }

  /// Gestion des erreurs de géolocalisation avec détection des permissions
  void _handleLocationError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();
    
    // Détecter spécifiquement les erreurs de permissions
    if (errorMessage.contains('permission') && 
        (errorMessage.contains('refusée') || errorMessage.contains('denied'))) {
      
      LogConfig.logError('🚨 Permissions géolocalisation refusées - notification du parent');
      
      // Notifier le parent que les permissions sont refusées
      if (widget.onLocationPermissionDenied != null) {
        widget.onLocationPermissionDenied!();
      }
    }
  }

  /// Définit la position par défaut (Paris) - UNIQUEMENT en cas d'échec géolocalisation
  void _setDefaultPosition() {
    setState(() {
      _initialPosition = gl.Position(
        latitude: _defaultLatitude,
        longitude: _defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      _isPositionReady = true; // 🔧 PERMETTRE l'affichage de la carte même avec Paris
    });
    
    LogConfig.logInfo('📍 Position par défaut définie: Paris ($_defaultLatitude, $_defaultLongitude)');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latitude = _initialPosition?.latitude ?? _defaultLatitude;
    final longitude = _initialPosition?.longitude ?? _defaultLongitude;

    LogConfig.logInfo('🗺️ Création de la carte avec position: $latitude, $longitude');

    return FadeTransition(
      opacity: _fadeAnimation,
      child: mp.MapWidget(
        key: _uniqueMapKey,
        styleUri: widget.styleUri,
        cameraOptions: mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(longitude, latitude),
          ),
          zoom: 12.0,
          pitch: 0.0,
          bearing: 0.0,
        ),
        onMapCreated: widget.onMapCreated,
      ),
    );
  }
}