import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de cache optimisé avec sérialisation JSON simplifiée
class CacheService {
  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();
  CacheService._();

  SharedPreferences? _prefs;
  final Map<String, Timer> _expirationTimers = {};
  final Map<String, StreamController<CacheEvent>> _listeners = {};

  // Configuration des durées de cache par type
  static const Map<String, Duration> _cacheDurations = {
    'user_credits': Duration(minutes: 15),
    'credit_plans': Duration(hours: 2),
    'saved_routes': Duration(minutes: 30),
    'activity_stats': Duration(minutes: 10),
    'route_generation': Duration(minutes: 5),
    'user_profile': Duration(minutes: 30),
  };

  /// Initialise le service de cache
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _cleanupExpiredEntries();
  }

  /// Met en cache une valeur avec expiration automatique
  Future<void> set<T>(
    String key, 
    T value, {
    Duration? customExpiration,
    bool notifyListeners = true,
  }) async {
    await _ensureInitialized();
    
    try {
      final expiration = customExpiration ?? _getDefaultExpiration(key);
      
      // ✅ Sérialisation simplifiée - convertir en JSON sérialisable
      final jsonData = _convertToJson(value);
      final entryJson = {
        'value': jsonData,
        'timestamp': DateTime.now().toIso8601String(),
        'expiration_ms': expiration.inMilliseconds,
      };
      
      await _prefs!.setString(key, jsonEncode(entryJson));
      
      // Programmer l'expiration automatique
      _scheduleExpiration(key, expiration);
      
      if (notifyListeners) {
        _notifyListeners(key, CacheEvent.updated(key, value));
      }
      
      print('💾 Cache mis à jour: $key (expire dans ${expiration.inMinutes}min)');
    } catch (e) {
      print('❌ Erreur mise en cache $key: $e');
      // Continuer silencieusement en cas d'erreur de cache
    }
  }

  /// Récupère une valeur du cache avec désérialisation corrigée pour les listes
  Future<T?> get<T>(String key, {bool renewIfClose = true}) async {
    await _ensureInitialized();
    
    final jsonStr = _prefs!.getString(key);
    if (jsonStr == null) return null;
    
    try {
      final entryData = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      final timestamp = DateTime.parse(entryData['timestamp']);
      final expiration = Duration(milliseconds: entryData['expiration_ms']);
      
      // Vérifier l'expiration
      if (DateTime.now().difference(timestamp) > expiration) {
        await remove(key);
        return null;
      }
      
      // Renouveler si proche de l'expiration (derniers 20% de la durée)
      final elapsed = DateTime.now().difference(timestamp);
      if (renewIfClose && elapsed > expiration * 0.8) {
        _scheduleExpiration(key, expiration);
        print('🔄 Cache renouvelé: $key');
      }
      
      final rawValue = entryData['value'];
      
      // ✅ FIX: Gestion spéciale pour les listes typées
      if (key.contains('credit_plans') && rawValue is List) {
        // Retourner la List<dynamic> - le repository fera la conversion
        return rawValue as T?;
      }
      
      if (key.contains('credit_transactions') && rawValue is List) {
        // Retourner la List<dynamic> - le repository fera la conversion  
        return rawValue as T?;
      }
      
      if (key.contains('saved_routes') && rawValue is List) {
        // Retourner la List<dynamic> - le repository fera la conversion
        return rawValue as T?;
      }
      
      // Pour les autres types, retour direct
      return rawValue as T?;
      
    } catch (e) {
      print('❌ Erreur lecture cache $key: $e');
      await remove(key);
      return null;
    }
  }

  /// Supprime une entrée du cache
  Future<void> remove(String key, {bool notifyListeners = true}) async {
    await _ensureInitialized();
    
    await _prefs!.remove(key);
    _expirationTimers[key]?.cancel();
    _expirationTimers.remove(key);
    
    if (notifyListeners) {
      _notifyListeners(key, CacheEvent.removed(key));
    }
    
    print('🗑️ Cache supprimé: $key');
  }

  /// Invalide le cache selon des critères
  Future<void> invalidate({
    List<String>? keys,
    String? pattern,
    Duration? olderThan,
  }) async {
    await _ensureInitialized();
    
    final allKeys = _prefs!.getKeys().where((k) => k.startsWith('cache_')).toList();
    final keysToRemove = <String>[];
    
    for (final key in allKeys) {
      bool shouldRemove = false;
      
      // Filtre par clés spécifiques
      if (keys != null && keys.contains(key)) {
        shouldRemove = true;
      }
      
      // Filtre par pattern
      if (pattern != null && key.contains(pattern)) {
        shouldRemove = true;
      }
      
      // Filtre par ancienneté
      if (olderThan != null) {
        final jsonStr = _prefs!.getString(key);
        if (jsonStr != null) {
          try {
            final entryData = jsonDecode(jsonStr) as Map<String, dynamic>;
            final timestamp = DateTime.parse(entryData['timestamp']);
            if (DateTime.now().difference(timestamp) > olderThan) {
              shouldRemove = true;
            }
          } catch (e) {
            shouldRemove = true; // Supprimer les entrées corrompues
          }
        }
      }
      
      if (shouldRemove) {
        keysToRemove.add(key);
      }
    }
    
    // Supprimer les entrées sélectionnées
    for (final key in keysToRemove) {
      await remove(key);
    }
    
    print('🧹 Cache invalidé: ${keysToRemove.length} entrées supprimées');
  }

  /// Vide complètement le cache
  Future<void> clear() async {
    await _ensureInitialized();
    
    final allKeys = _prefs!.getKeys().where((k) => k.startsWith('cache_')).toList();
    
    for (final key in allKeys) {
      await remove(key, notifyListeners: false);
    }
    
    print('🗑️ Cache complètement vidé');
  }

  /// Écoute les changements du cache
  Stream<CacheEvent> listen(String key) {
    _listeners[key] ??= StreamController<CacheEvent>.broadcast();
    return _listeners[key]!.stream;
  }

  /// Stratégies d'invalidation automatique
  Future<void> invalidateCreditsCache() async {
    await invalidate(pattern: 'credit');
    print('💳 Cache crédits invalidé');
  }

  Future<void> invalidateRoutesCache() async {
    await invalidate(pattern: 'route');
    print('🛤️ Cache routes invalidé');
  }

  Future<void> invalidateActivityCache() async {
    await invalidate(pattern: 'activity');
    print('🏃 Cache activité invalidé');
  }

  /// Nettoyage intelligent selon l'utilisation mémoire
  Future<void> smartCleanup() async {
    await _ensureInitialized();
    
    // Supprimer les entrées expirées
    await invalidate(olderThan: Duration.zero);
    
    // Si plus de 100 entrées, supprimer les plus anciennes
    final allKeys = _prefs!.getKeys().where((k) => k.startsWith('cache_')).toList();
    if (allKeys.length > 100) {
      final oldEntries = <String, DateTime>{};
      
      for (final key in allKeys) {
        final jsonStr = _prefs!.getString(key);
        if (jsonStr != null) {
          try {
            final entryData = jsonDecode(jsonStr) as Map<String, dynamic>;
            final timestamp = DateTime.parse(entryData['timestamp']);
            oldEntries[key] = timestamp;
          } catch (e) {
            await remove(key);
          }
        }
      }
      
      // Trier par ancienneté et supprimer les plus anciennes
      final sortedEntries = oldEntries.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      final toRemove = sortedEntries.take(20).map((e) => e.key).toList();
      await invalidate(keys: toRemove);
      
      print('🧹 Nettoyage intelligent: ${toRemove.length} anciennes entrées supprimées');
    }
  }

  // ===== SÉRIALISATION SIMPLIFIÉE =====

  /// ✅ Convertit une valeur en JSON sérialisable de manière sécurisée
  dynamic _convertToJson(dynamic value) {
    if (value == null) return null;
    
    // Types primitifs JSON
    if (value is String || value is num || value is bool) {
      return value;
    }
    
    // Map
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (e) {
        return value.toString();
      }
    }
    
    // List
    if (value is List) {
      try {
        return value.map((item) => _convertToJson(item)).toList();
      } catch (e) {
        return value.toString();
      }
    }
    
    // Essayer d'appeler toJson() dynamiquement
    try {
      final dynamic dynamicValue = value;
      // ✅ Vérification runtime safe pour toJson
      if (dynamicValue != null && 
          dynamicValue.runtimeType.toString().contains('UserCredits') ||
          dynamicValue.runtimeType.toString().contains('CreditPlan') ||
          dynamicValue.runtimeType.toString().contains('SavedRoute') ||
          dynamicValue.runtimeType.toString().contains('ActivityStats')) {
        
        // Essayer d'appeler toJson via reflection dynamique
        return (dynamicValue as dynamic).toJson();
      }
    } catch (e) {
      // Ignore l'erreur et continue
    }
    
    // Fallback: convertir en string
    return value.toString();
  }

  // ===== MÉTHODES PRIVÉES =====

  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await initialize();
    }
  }

  Duration _getDefaultExpiration(String key) {
    for (final entry in _cacheDurations.entries) {
      if (key.contains(entry.key)) {
        return entry.value;
      }
    }
    return const Duration(minutes: 15); // Durée par défaut
  }

  void _scheduleExpiration(String key, Duration expiration) {
    _expirationTimers[key]?.cancel();
    _expirationTimers[key] = Timer(expiration, () {
      remove(key);
    });
  }

  void _notifyListeners(String key, CacheEvent event) {
    _listeners[key]?.add(event);
  }

  Future<void> _cleanupExpiredEntries() async {
    final allKeys = _prefs!.getKeys().where((k) => k.startsWith('cache_')).toList();
    
    for (final key in allKeys) {
      final jsonStr = _prefs!.getString(key);
      if (jsonStr != null) {
        try {
          final entryData = jsonDecode(jsonStr) as Map<String, dynamic>;
          final timestamp = DateTime.parse(entryData['timestamp']);
          final expiration = Duration(milliseconds: entryData['expiration_ms']);
          
          if (DateTime.now().difference(timestamp) > expiration) {
            await remove(key, notifyListeners: false);
          }
        } catch (e) {
          await remove(key, notifyListeners: false);
        }
      }
    }
  }

  /// Dispose le service
  void dispose() {
    for (final timer in _expirationTimers.values) {
      timer.cancel();
    }
    _expirationTimers.clear();
    
    for (final controller in _listeners.values) {
      controller.close();
    }
    _listeners.clear();
  }
}

/// Événement de cache
class CacheEvent {
  final String key;
  final CacheEventType type;
  final dynamic value;

  CacheEvent._(this.key, this.type, this.value);

  factory CacheEvent.updated(String key, dynamic value) => 
    CacheEvent._(key, CacheEventType.updated, value);
  
  factory CacheEvent.removed(String key) => 
    CacheEvent._(key, CacheEventType.removed, null);
}

enum CacheEventType { updated, removed }