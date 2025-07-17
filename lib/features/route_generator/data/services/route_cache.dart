import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runaway/core/helper/services/cache_service.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/core/helper/config/log_config.dart';

/// Service de cache optimisé pour les parcours
class RouteCache {
  static const Duration cacheExpiry = Duration(hours: 24);
  static const int maxCacheSize = 50; // Limite le nombre de routes en cache
  static const int maxRouteDataSize = 1024 * 1024; // 1MB par route max
  
  static RouteCache? _instance;
  static RouteCache get instance => _instance ??= RouteCache._();
  RouteCache._();

  final CacheService _cacheService = CacheService.instance;
  SharedPreferences? _prefs;

  /// Initialise le service de cache
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _cacheService.initialize();
    await _cleanupOldCache();
  }

  /// Met en cache un parcours avec optimisations
  Future<void> cacheRoute(String key, SavedRoute route) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Validation de la taille des données
      final routeJson = route.toJson();
      final routeData = jsonEncode(routeJson);
      
      if (routeData.length > maxRouteDataSize) {
        LogConfig.logInfo('Route trop volumineuse pour le cache: ${routeData.length} bytes');
        return;
      }

      // Données du cache avec métadonnées
      final cacheData = {
        'route': routeJson,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'size': routeData.length,
        'version': '1.0',
      };

      // Sauvegarder dans le cache principal
      await _cacheService.set(
        'route_$key', 
        cacheData,
        customExpiration: cacheExpiry,
      );

      // Mettre à jour les statistiques de cache
      await _updateCacheStats(key, routeData.length);

      stopwatch.stop();
      
      // Métriques de performance
      MonitoringService.instance.recordMetric(
        'route_cache_write',
        stopwatch.elapsedMicroseconds,
        tags: {
          'route_id': route.id,
          'size_bytes': routeData.length.toString(),
        },
      );

      LogConfig.logInfo('Route mise en cache: $key (${routeData.length} bytes, ${stopwatch.elapsedMilliseconds}ms)');

    } catch (e, stackTrace) {
      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'RouteCache.cacheRoute',
        extra: {'route_key': key, 'route_id': route.id},
      );
      LogConfig.logError('❌ Erreur cache route: $e');
    }
  }

  /// Récupère un parcours depuis le cache
  Future<SavedRoute?> getRoute(String key) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      final cacheData = await _cacheService.get<Map>('route_$key');
      
      if (cacheData == null) {
        print('📭 Route non trouvée en cache: $key');
        return null;
      }

      // Convertir en Map<String, dynamic>
      final dataMap = Map<String, dynamic>.from(cacheData);
      
      // Vérifier l'expiration manuelle (double sécurité)
      final timestamp = dataMap['timestamp'] as int;
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      
      if (DateTime.now().difference(cacheDate) > cacheExpiry) {
        print('⏰ Cache expiré pour: $key');
        await _cacheService.remove('route_$key');
        return null;
      }

      // Extraire et convertir les données de la route
      final routeData = Map<String, dynamic>.from(dataMap['route']);
      final route = SavedRoute.fromJson(routeData);

      stopwatch.stop();
      
      // Métriques de performance
      MonitoringService.instance.recordMetric(
        'route_cache_read',
        stopwatch.elapsedMicroseconds,
        tags: {
          'route_id': route.id,
          'cache_hit': 'true',
        },
      );

      LogConfig.logInfo('Route récupérée du cache: $key (${stopwatch.elapsedMilliseconds}ms)');
      
      return route;

    } catch (e, stackTrace) {
      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'RouteCache.getRoute',
        extra: {'route_key': key},
      );
      
      // En cas d'erreur, supprimer l'entrée corrompue
      await _cacheService.remove('route_$key');
      LogConfig.logError('❌ Erreur récupération cache route $key: $e');
      return null;
    }
  }

  /// Met en cache plusieurs parcours en batch
  Future<void> cacheRoutes(Map<String, SavedRoute> routes) async {
    final futures = routes.entries.map((entry) => 
      cacheRoute(entry.key, entry.value)
    );
    
    await Future.wait(futures);
    LogConfig.logInfo('${routes.length} routes mises en cache');
  }

  /// Récupère plusieurs parcours depuis le cache
  Future<Map<String, SavedRoute>> getRoutes(List<String> keys) async {
    final results = <String, SavedRoute>{};
    
    final futures = keys.map((key) async {
      final route = await getRoute(key);
      if (route != null) {
        results[key] = route;
      }
    });
    
    await Future.wait(futures);
    return results;
  }

  /// Supprime un parcours du cache
  Future<void> removeRoute(String key) async {
    await _cacheService.remove('route_$key');
    await _updateCacheStatsOnRemoval(key);
    LogConfig.logInfo('🗑️ Route supprimée du cache: $key');
  }

  /// Nettoie le cache expiré
  Future<void> cleanupExpiredCache() async {
    try {
      await _cacheService.smartCleanup();
      await _cleanupOldCache();
      LogConfig.logInfo('🧹 Nettoyage du cache terminé');
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage cache: $e');
    }
  }

  /// Vide complètement le cache des parcours
  Future<void> clearAllRoutes() async {
    await _cacheService.invalidate(pattern: 'route_');
    await _clearCacheStats();
    LogConfig.logInfo('🧹 Cache des parcours vidé');
  }

  /// Vérifie si une route est en cache et valide
  Future<bool> hasValidRoute(String key) async {
    final route = await getRoute(key);
    return route != null;
  }

  /// Obtient les statistiques du cache
  Future<RouteCacheStats> getCacheStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString('route_cache_stats');
    
    if (statsJson == null) {
      return RouteCacheStats.empty();
    }
    
    try {
      final stats = jsonDecode(statsJson) as Map<String, dynamic>;
      return RouteCacheStats.fromJson(stats);
    } catch (e) {
      LogConfig.logError('❌ Erreur lecture stats cache: $e');
      return RouteCacheStats.empty();
    }
  }

  /// Met à jour les statistiques du cache
  Future<void> _updateCacheStats(String key, int size) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await getCacheStats();
    
    final updatedStats = stats.copyWith(
      totalRoutes: stats.totalRoutes + 1,
      totalSizeBytes: stats.totalSizeBytes + size,
      lastUpdated: DateTime.now(),
    );
    
    await prefs.setString('route_cache_stats', jsonEncode(updatedStats.toJson()));
  }

  /// Met à jour les stats lors de la suppression
  Future<void> _updateCacheStatsOnRemoval(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await getCacheStats();
    
    if (stats.totalRoutes > 0) {
      final updatedStats = stats.copyWith(
        totalRoutes: stats.totalRoutes - 1,
        lastUpdated: DateTime.now(),
      );
      
      await prefs.setString('route_cache_stats', jsonEncode(updatedStats.toJson()));
    }
  }

  /// Nettoie les anciennes données de cache
  Future<void> _cleanupOldCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('route_')).toList();
    
    if (keys.length > maxCacheSize) {
      // Supprimer les plus anciennes entrées
      final toRemove = keys.length - maxCacheSize;
      for (int i = 0; i < toRemove; i++) {
        await prefs.remove(keys[i]);
      }
      LogConfig.logInfo('🧹 ${toRemove} anciennes entrées supprimées du cache');
    }
  }

  /// Vide les statistiques du cache
  Future<void> _clearCacheStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('route_cache_stats');
  }
}

/// Statistiques du cache des parcours
class RouteCacheStats {
  final int totalRoutes;
  final int totalSizeBytes;
  final DateTime lastUpdated;

  const RouteCacheStats({
    required this.totalRoutes,
    required this.totalSizeBytes,
    required this.lastUpdated,
  });

  factory RouteCacheStats.empty() {
    return RouteCacheStats(
      totalRoutes: 0,
      totalSizeBytes: 0,
      lastUpdated: DateTime.now(),
    );
  }

  factory RouteCacheStats.fromJson(Map<String, dynamic> json) {
    return RouteCacheStats(
      totalRoutes: json['totalRoutes'] ?? 0,
      totalSizeBytes: json['totalSizeBytes'] ?? 0,
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRoutes': totalRoutes,
      'totalSizeBytes': totalSizeBytes,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  RouteCacheStats copyWith({
    int? totalRoutes,
    int? totalSizeBytes,
    DateTime? lastUpdated,
  }) {
    return RouteCacheStats(
      totalRoutes: totalRoutes ?? this.totalRoutes,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Taille formatée pour affichage
  String get formattedSize {
    if (totalSizeBytes < 1024) return '${totalSizeBytes}B';
    if (totalSizeBytes < 1024 * 1024) return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  String toString() {
    return 'RouteCacheStats(routes: $totalRoutes, size: $formattedSize, updated: $lastUpdated)';
  }
}