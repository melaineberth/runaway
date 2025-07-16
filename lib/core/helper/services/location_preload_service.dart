import 'dart:async';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:runaway/core/helper/services/monitoring_service.dart';

/// Service pour pré-charger la géolocalisation avant l'affichage de la carte
class LocationPreloadService {
  static LocationPreloadService? _instance;
  static LocationPreloadService get instance => _instance ??= LocationPreloadService._();
  LocationPreloadService._();

  // Cache de la dernière position connue (NOTRE cache, pas celui du système)
  gl.Position? _lastKnownPosition;
  DateTime? _lastPositionUpdate;
  
  // Completer pour l'initialisation
  Completer<gl.Position>? _initializationCompleter;
  bool _isInitialized = false;
  
  // Timeout et cache
  static const Duration _locationTimeout = Duration(seconds: 8); // Timeout suffisant
  static const Duration _cacheExpiration = Duration(minutes: 2); // Cache court

  /// Getters pour vérifier l'état
  bool get hasValidPosition => _lastKnownPosition != null && _isPositionCacheValid();
  gl.Position? get lastKnownPosition => _lastKnownPosition;

  /// Initialise le service et pré-charge la position
  Future<gl.Position> initializeLocation() async {
    print('🌍 === INITIALISATION GÉOLOCALISATION ACTUELLE ===');
    
    // STRATÉGIE 1: Notre cache valide - Retour immédiat
    if (_isInitialized && _lastKnownPosition != null && _isPositionCacheValid()) {
      print('⚡ NOTRE cache valide - Position immédiate: ${_formatPosition(_lastKnownPosition!)}');
      return _lastKnownPosition!;
    }

    // STRATÉGIE 2: Initialisation en cours - Attendre
    if (_initializationCompleter != null) {
      print('⏳ Initialisation en cours...');
      return await _initializationCompleter!.future;
    }

    // STRATÉGIE 3: Nouvelle géolocalisation FRAÎCHE
    _initializationCompleter = Completer<gl.Position>();
    
    try {
      // Obtenir position actuelle (pas de cache système)
      final position = await _getFreshLocation();
      
      _updatePosition(position);
      _initializationCompleter!.complete(position);
      print('✅ Position fraîche obtenue et mise en cache');
      return position;
      
    } catch (e) {
      print('❌ Erreur géolocalisation: $e');
      _initializationCompleter!.completeError(e);
      rethrow;
    } finally {
      _initializationCompleter = null;
    }
  }

  /// 🎯 Obtenir une position FRAÎCHE (pas de cache système douteux)
  Future<gl.Position> _getFreshLocation() async {
    print('🎯 Obtention de la position ACTUELLE (pas de cache système)...');

    final operationId = MonitoringService.instance.trackOperation(
      'get_current_position',
      description: 'Obtention de la position GPS actuelle',
    );
    
    // 1. Vérifier les permissions
    await _checkAndRequestPermissions();
    
    // 2. FORCER une géolocalisation fraîche
    try {
      print('📍 Demande de position actuelle...');
      
      final currentPosition = await gl.Geolocator.getCurrentPosition(
        locationSettings: gl.LocationSettings(
          accuracy: gl.LocationAccuracy.high,
          timeLimit: _locationTimeout,
        ),
      ).timeout(_locationTimeout);
      
      print('✅ Position actuelle obtenue: ${_formatPosition(currentPosition)}');
      print('📅 Timestamp: ${currentPosition.timestamp}');

      MonitoringService.instance.finishOperation(operationId, success: true, data: {
        'latitude': currentPosition.latitude,
        'longitude': currentPosition.longitude,
        'accuracy': currentPosition.accuracy,
      });

      // 🆕 Métrique de géolocalisation
      MonitoringService.instance.recordMetric(
        'location_obtained',
        1,
        tags: {
          'accuracy': currentPosition.accuracy.toString(),
          'source': 'gps',
        },
      );
      
      return currentPosition;
      
    } catch (e, stackTrace) {
      print('❌ Erreur getCurrentPosition: $e');

      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: e.toString(),
      );

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'LocationPreloadService.getCurrentPosition',
      );
      
      // 3. Fallback: essayer lastKnownPosition SEULEMENT si vraiment récente
      final fallbackPosition = await _tryRecentFallback();
      if (fallbackPosition != null) {
        return fallbackPosition;
      }
      
      throw LocationException('Impossible d\'obtenir la position actuelle');
    }
  }

  /// 🚨 Fallback: Position système SEULEMENT si très récente (< 1 minute)
  Future<gl.Position?> _tryRecentFallback() async {
    try {
      print('🚨 Tentative de fallback avec position système...');
      
      final lastPosition = await gl.Geolocator.getLastKnownPosition();
      if (lastPosition == null) {
        print('❌ Aucune position système disponible');
        return null;
      }
      
      final age = DateTime.now().difference(lastPosition.timestamp);
      print('📅 Position système datée de: ${lastPosition.timestamp}');
      print('⏰ Âge: ${age.inMinutes} minutes');
      
      // TRÈS STRICT: Seulement si moins d'1 minute
      if (age.inMinutes < 1) {
        print('✅ Position système acceptable (< 1 min): ${_formatPosition(lastPosition)}');
        return lastPosition;
      } else {
        print('❌ Position système trop ancienne (${age.inMinutes} min), rejetée');
        return null;
      }
      
    } catch (e) {
      print('❌ Erreur fallback position système: $e');
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
    
    print('✅ Permissions de géolocalisation OK');
  }

  /// Met à jour la position en cache
  void _updatePosition(gl.Position position) {
    _lastKnownPosition = position;
    _lastPositionUpdate = DateTime.now();
    _isInitialized = true;
    print('💾 Position mise à jour en NOTRE cache: ${_formatPosition(position)}');
    print('💾 Sauvegardé à: $_lastPositionUpdate');
  }

  /// Vérifie si NOTRE position en cache est encore valide
  bool _isPositionCacheValid() {
    if (_lastPositionUpdate == null) {
      print('❌ Pas de timestamp de cache');
      return false;
    }
    
    final now = DateTime.now();
    final age = now.difference(_lastPositionUpdate!);
    final isValid = age < _cacheExpiration;
    
    print('🕒 Âge de notre cache: ${age.inMinutes} minutes (valide: $isValid)');
    return isValid;
  }

  /// Formate une position pour les logs
  String _formatPosition(gl.Position position) {
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }

  /// Nettoie le cache (pour tests ou reset)
  void clearCache() {
    _lastKnownPosition = null;
    _lastPositionUpdate = null;
    _isInitialized = false;
    _initializationCompleter = null;
    print('🧹 Cache de géolocalisation nettoyé');
  }

  /// 🛠️ Méthode de debug pour forcer une nouvelle géolocalisation
  Future<gl.Position> forceRefresh() async {
    print('🛠️ Force refresh demandé - suppression du cache');
    clearCache();
    return await initializeLocation();
  }
}

/// Exception personnalisée pour la géolocalisation
class LocationException implements Exception {
  final String message;
  
  const LocationException(this.message);
  
  @override
  String toString() => 'LocationException: $message';
}