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
  
  // Timeout optimisé pour UX rapide
  static const Duration _locationTimeout = Duration(seconds: 4); // Plus court
  static const Duration _cacheExpiration = Duration(minutes: 3); // Plus court pour fraîcheur

  /// Getters pour vérifier l'état
  bool get hasValidPosition => _lastKnownPosition != null && _isPositionCacheValid();
  gl.Position? get lastKnownPosition => _lastKnownPosition;

  /// Initialise le service et pré-charge la position
  Future<gl.Position> initializeLocation() async {
    print('🌍 === INITIALISATION GÉOLOCALISATION RAPIDE ===');
    
    // STRATÉGIE 1: Cache valide - Retour immédiat
    if (_isInitialized && _lastKnownPosition != null && _isPositionCacheValid()) {
      print('⚡ Cache valide - Position immédiate: ${_formatPosition(_lastKnownPosition!)}');
      return _lastKnownPosition!;
    }

    // STRATÉGIE 2: Initialisation en cours - Attendre
    if (_initializationCompleter != null) {
      print('⏳ Initialisation en cours...');
      return await _initializationCompleter!.future;
    }

    // STRATÉGIE 3: Nouvelle initialisation rapide
    _initializationCompleter = Completer<gl.Position>();
    
    try {
      // Approche multi-étapes pour UX optimale
      final position = await _getFastLocation();
      
      _updatePosition(position);
      _initializationCompleter!.complete(position);
      print('✅ Position obtenue rapidement');
      return position;
      
    } catch (e) {
      print('❌ Erreur géolocalisation: $e');
      _initializationCompleter!.completeError(e);
      rethrow;
    } finally {
      _initializationCompleter = null;
    }
  }

  /// 🚀 Stratégie rapide pour obtenir la position
  Future<gl.Position> _getFastLocation() async {
    print('🚀 Stratégie rapide de géolocalisation...');
    
    // 1. Vérifier les permissions (rapide)
    await _checkAndRequestPermissions();
    
    // 2. Essayer position système en cache (très rapide)
    final cachedPosition = await _tryGetLastKnownPosition();
    if (cachedPosition != null && _isRecentPosition(cachedPosition)) {
      print('⚡ Position système récente utilisée');
      return cachedPosition;
    }
    
    // 3. Position actuelle avec timeout court (pour UX)
    try {
      final currentPosition = await gl.Geolocator.getCurrentPosition(
        locationSettings: gl.LocationSettings(
          accuracy: gl.LocationAccuracy.high,
          timeLimit: _locationTimeout,
        ),
      ).timeout(_locationTimeout);
      
      print('🎯 Position fraîche obtenue');
      return currentPosition;
      
    } catch (e) {
      // 4. Fallback: utiliser position cache même si vieille
      if (cachedPosition != null) {
        print('⚠️ Fallback sur position cache');
        return cachedPosition;
      }
      
      throw LocationException('Impossible d\'obtenir la position');
    }
  }

  /// Vérifie si une position est récente (moins de 5 minutes)
  bool _isRecentPosition(gl.Position position) {
    final now = DateTime.now();
    final positionTime = position.timestamp;
    final age = now.difference(positionTime);
    return age.inMinutes < 5;
  }

  /// Essaie d'obtenir la dernière position connue du système
  Future<gl.Position?> _tryGetLastKnownPosition() async {
    try {
      return await gl.Geolocator.getLastKnownPosition();
    } catch (e) {
      print('⚠️ Pas de position système en cache');
      return null;
    }
  }

  /// Vérifie et demande les permissions de géolocalisation
  Future<void> _checkAndRequestPermissions() async {
    bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Service de localisation désactivé');
    }

    gl.LocationPermission permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        throw LocationException('Permission de localisation refusée');
      }
    }
    
    if (permission == gl.LocationPermission.deniedForever) {
      throw LocationException('Permission de localisation refusée définitivement');
    }
  }

  /// Met à jour la position en cache
  void _updatePosition(gl.Position position) {
    _lastKnownPosition = position;
    _lastPositionUpdate = DateTime.now();
    _isInitialized = true;
    print('💾 Position mise à jour en cache: ${_formatPosition(position)}');
  }

  /// Vérifie si la position en cache est encore valide
  bool _isPositionCacheValid() {
    if (_lastPositionUpdate == null) return false;
    
    final now = DateTime.now();
    final age = now.difference(_lastPositionUpdate!);
    return age < _cacheExpiration;
  }

  /// Formate une position pour les logs
  String _formatPosition(gl.Position position) {
    return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  /// Nettoie le cache (pour tests ou reset)
  void clearCache() {
    _lastKnownPosition = null;
    _lastPositionUpdate = null;
    _isInitialized = false;
    _initializationCompleter = null;
    print('🧹 Cache de géolocalisation nettoyé');
  }
}

/// Exception personnalisée pour la géolocalisation
class LocationException implements Exception {
  final String message;
  
  const LocationException(this.message);
  
  @override
  String toString() => 'LocationException: $message';
}