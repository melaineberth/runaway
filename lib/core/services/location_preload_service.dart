import 'dart:async';
import 'package:geolocator/geolocator.dart' as gl;

/// Service pour pré-charger la géolocalisation avant l'affichage de la carte
class LocationPreloadService {
  static LocationPreloadService? _instance;
  static LocationPreloadService get instance => _instance ??= LocationPreloadService._();
  LocationPreloadService._();

  // Cache de la dernière position connue
  gl.Position? _lastKnownPosition;
  DateTime? _lastPositionUpdate;
  
  // Completer pour l'initialisation
  Completer<gl.Position>? _initializationCompleter;
  bool _isInitialized = false;
  
  // Timeout pour l'obtention de la position
  static const Duration _locationTimeout = Duration(seconds: 8);
  static const Duration _cacheExpiration = Duration(minutes: 5);

  /// Initialise le service et pré-charge la position
  Future<gl.Position> initializeLocation() async {
    print('🌍 === INITIALISATION GÉOLOCALISATION ===');
    
    // Si déjà initialisé et que la position est récente, la retourner
    if (_isInitialized && _lastKnownPosition != null && _isPositionCacheValid()) {
      print('✅ Position en cache valide: ${_formatPosition(_lastKnownPosition!)}');
      return _lastKnownPosition!;
    }

    // Si une initialisation est déjà en cours, attendre le résultat
    if (_initializationCompleter != null) {
      print('⏳ Initialisation en cours, attente...');
      return await _initializationCompleter!.future;
    }

    // Démarrer une nouvelle initialisation
    _initializationCompleter = Completer<gl.Position>();
    
    try {
      print('🔍 Recherche de la position utilisateur...');
      
      // 1. Vérifier les permissions
      await _checkAndRequestPermissions();
      
      // 2. Essayer d'obtenir la dernière position connue (rapide)
      final lastPosition = await _tryGetLastKnownPosition();
      if (lastPosition != null) {
        _updatePosition(lastPosition);
        _initializationCompleter!.complete(lastPosition);
        print('✅ Position récupérée depuis le cache système');
        return lastPosition;
      }
      
      // 3. Obtenir la position actuelle (plus lent mais précis)
      final currentPosition = await _getCurrentPositionWithTimeout();
      _updatePosition(currentPosition);
      _initializationCompleter!.complete(currentPosition);
      
      print('✅ Position actuelle obtenue: ${_formatPosition(currentPosition)}');
      return currentPosition;
      
    } catch (e) {
      print('❌ Erreur géolocalisation: $e');
      
      // Fallback: utiliser une position par défaut (Paris)
      final fallbackPosition = _createFallbackPosition();
      _updatePosition(fallbackPosition);
      _initializationCompleter!.complete(fallbackPosition);
      
      print('🔄 Utilisation position par défaut: ${_formatPosition(fallbackPosition)}');
      return fallbackPosition;
      
    } finally {
      _isInitialized = true;
      _initializationCompleter = null;
    }
  }

  /// Vérifie et demande les permissions de géolocalisation
  Future<void> _checkAndRequestPermissions() async {
    bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Service de géolocalisation désactivé');
    }

    gl.LocationPermission permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        throw LocationException('Permission de géolocalisation refusée');
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      throw LocationException('Permission de géolocalisation refusée définitivement');
    }
  }

  /// Essaie d'obtenir la dernière position connue
  Future<gl.Position?> _tryGetLastKnownPosition() async {
    try {
      return await gl.Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: false,
      );
    } catch (e) {
      print('⚠️ Impossible d\'obtenir la dernière position: $e');
      return null;
    }
  }

  /// Obtient la position actuelle avec timeout
  Future<gl.Position> _getCurrentPositionWithTimeout() async {
    return await gl.Geolocator.getCurrentPosition(
      locationSettings: gl.LocationSettings(
        accuracy: gl.LocationAccuracy.high,
        distanceFilter: 0,
        timeLimit: _locationTimeout,
      ),
    ).timeout(_locationTimeout);
  }

  /// Met à jour la position en cache
  void _updatePosition(gl.Position position) {
    _lastKnownPosition = position;
    _lastPositionUpdate = DateTime.now();
  }

  /// Vérifie si la position en cache est encore valide
  bool _isPositionCacheValid() {
    if (_lastPositionUpdate == null) return false;
    return DateTime.now().difference(_lastPositionUpdate!) < _cacheExpiration;
  }

  /// Crée une position de fallback (Paris)
  gl.Position _createFallbackPosition() {
    return gl.Position(
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
  }

  /// Formate la position pour l'affichage
  String _formatPosition(gl.Position position) {
    return '(${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
  }

  /// Getters pour accéder aux données
  gl.Position? get lastKnownPosition => _lastKnownPosition;
  bool get isInitialized => _isInitialized;
  bool get hasValidPosition => _lastKnownPosition != null && _isPositionCacheValid();

  /// Nettoie le service
  void dispose() {
    print('🗑️ Nettoyage LocationPreloadService');
    _lastKnownPosition = null;
    _lastPositionUpdate = null;
    _initializationCompleter = null;
    _isInitialized = false;
  }
}

/// Exception personnalisée pour les erreurs de géolocalisation
class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
}