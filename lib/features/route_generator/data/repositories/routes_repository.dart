// lib/features/route_generator/data/repositories/routes_repository.dart

import 'dart:convert';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/features/route_generator/data/services/route_cache.dart';
import 'package:runaway/features/route_generator/data/services/route_persistence_service.dart';
import 'package:runaway/features/route_generator/data/services/screenshot_service.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/route_parameters.dart';

class RoutesRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();
  final RouteCache _routeCache = RouteCache.instance;
  final RoutePersistenceService _persistenceService = RoutePersistenceService.instance;
  
  static const String _localCacheKey = 'cached_user_routes';
  static const String _pendingSyncKey = 'pending_sync_routes';
  static const String _lastSyncKey = 'last_routes_sync';

  // Durées de cache intelligentes
  static const Duration _routesCacheDuration = Duration(minutes: 30);
  static const Duration _syncInterval = Duration(minutes: 5);

  /// Initialise le repository avec le cache optimisé et la persistance avancée
  Future<void> initialize() async {
    await _routeCache.initialize();
    
    // Validation d'intégrité au démarrage
    final integrityReport = await _persistenceService.validateDataIntegrity();
    if (!integrityReport.isHealthy) {
      LogConfig.logInfo('Problèmes d\'intégrité détectés: ${integrityReport.errors.length} erreurs');
      
      // Tentative de restauration automatique
      final restoredRoutes = await _persistenceService.restoreFromLatestBackup();
      if (restoredRoutes != null) {
        await _updateLocalCache(restoredRoutes);
        LogConfig.logInfo('🔄 Données restaurées depuis la sauvegarde: ${restoredRoutes.length} routes');
      }
    }
    
    // Migration des données si nécessaire
    await _persistenceService.migrateDataFormat();
    
    // Optimisation en arrière-plan
    _persistenceService.performBackgroundOptimization();

    // Maintenance automatique en arrière-plan toutes les 24h
    _schedulePeriodicMaintenance();
    
    await _performSmartSync();
  }

  /// Sauvegarde un nouveau parcours avec image_url
  Future<SavedRoute> saveRoute({
    required String name,
    required RouteParameters parameters,
    required List<List<double>> coordinates,
    double? actualDistance,
    int? estimatedDuration,
    String? imageUrl,
  }) async {
    return await withValidSession(() async {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final routeId = _uuid.v4();
      final now = DateTime.now().toLocal();

      LogConfig.logInfo('💾 Sauvegarde parcours avec persistance avancée: $name');

      final route = SavedRoute(
        id: routeId,
        name: name,
        parameters: parameters,
        coordinates: coordinates,
        createdAt: now,
        actualDistance: actualDistance,
        actualDuration: estimatedDuration,
        imageUrl: imageUrl,
      );

      // 1. Cache rapide immédiat
      await _routeCache.cacheRoute(routeId, route);

      // 2. Sauvegarde locale immédiate
      await _saveRouteLocally(route);

      // 3. Créer une sauvegarde de sécurité après chaque 5e route
      await _createSecurityBackupIfNeeded();

      // 4. Tentative de sync cloud (non bloquante)
      _performAsyncCloudSync(route, user.id);

      // 5. Invalider les caches existants pour forcer le refresh
      await _invalidateRoutesCache();

      LogConfig.logInfo('Parcours sauvé avec persistance avancée: $routeId');
      return route;
    });
  }

  /// Récupère tous les parcours de l'utilisateur
  Future<List<SavedRoute>> getUserRoutes({
    bool forceRefresh = false,
    int? limit,
    int? offset,
  }) async {
    return await withValidSession(() async {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final stopwatch = Stopwatch()..start();
      
      try {
        // Cache rapide (si pas de forceRefresh ET pas de pagination)
        if (!forceRefresh && limit == null && offset == null) {
          final cachedRoutes = await _getRoutesFromFastCache();
          if (cachedRoutes.isNotEmpty && !await _needsSync()) {
            stopwatch.stop();
            LogConfig.logInfo('Routes depuis cache rapide: ${cachedRoutes.length} (${stopwatch.elapsedMilliseconds}ms)');
            return cachedRoutes;
          }
        }

        // Vérifier la connectivité pour le cache cloud
        if (await _isConnected()) {
          // Si pagination demandée, récupérer directement depuis Supabase
          if (limit != null || offset != null) {
            final routes = await _getRoutesFromSupabasePaginated(user.id, limit: limit, offset: offset);
            stopwatch.stop();
            LogConfig.logInfo('Routes paginées depuis Supabase: ${routes.length} (${stopwatch.elapsedMilliseconds}ms)');
            return routes;
          }

          // Synchroniser d'abord les routes en attente
          await _syncPendingRoutes();
          
          // Récupérer depuis Supabase
          final routes = await _getRoutesFromSupabase(user.id);
          
          // Mettre à jour tous les niveaux de cache
          await _updateAllCacheLevels(routes);
          await _updateLastSyncTime();

          // Créer une sauvegarde de sécurité après récupération réussie
          if (routes.isNotEmpty) {
            await _persistenceService.createSecurityBackup(routes);
          }

          stopwatch.stop();

          // Métriques détaillées avec stats système
          final systemStats = await getSystemStats();
          MonitoringService.instance.recordMetric(
            'user_routes_loaded',
            stopwatch.elapsedMilliseconds,
            tags: {
              'source': 'supabase',
              'routes_count': routes.length.toString(),
              'user_id': user.id,
              'cache_health': systemStats['integrity']['is_healthy'].toString(),
            },
          );
          
          print('☁️ Routes depuis Supabase: ${routes.length} (${stopwatch.elapsedMilliseconds}ms)');
          return routes;

        } else {
          // Cache local (mode hors ligne)
          final localRoutes = await _getLocalRoutes();
          stopwatch.stop();
          
          LogConfig.logInfo('📱 Routes depuis cache local: ${localRoutes.length} (${stopwatch.elapsedMilliseconds}ms)');
          return localRoutes;
        }

      } catch (e, stackTrace) {
        stopwatch.stop();
        
        LogConfig.logError('❌ Erreur récupération routes, tentative de restauration: $e');

        // Tentative de restauration automatique en cas d'erreur
        final restoredRoutes = await _persistenceService.restoreFromLatestBackup();
        if (restoredRoutes != null && restoredRoutes.isNotEmpty) {
          LogConfig.logInfo('🔄 Routes restaurées depuis backup: ${restoredRoutes.length}');
          return restoredRoutes;
        }
        
        MonitoringService.instance.captureError(
          e,
          stackTrace,
          context: 'RoutesRepository.getUserRoutes',
          extra: {
            'user_id': user.id,
            'force_refresh': forceRefresh.toString(),
            'elapsed_ms': stopwatch.elapsedMilliseconds.toString(),
          },
        );

        // Fallback vers le cache local
        return await _getLocalRoutes();
      }
    });
  }

  /// Récupère les routes depuis Supabase avec pagination
  Future<List<SavedRoute>> _getRoutesFromSupabasePaginated(String userId, {int? limit, int? offset}) async {
    try {
      var query = _supabase
          .from('user_routes')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 20) - 1);
      }

      final response = await query;
      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        final createdAtUtc = DateTime.parse(item['created_at']).toUtc();
        final createdAt = createdAtUtc.toLocal();

        DateTime? lastUsedAt;
        if (item['last_used_at'] != null) {
          final lastUsedUtc = DateTime.parse(item['last_used_at']).toUtc();
          lastUsedAt = lastUsedUtc.toLocal();
        }

        // Construire ElevationRange depuis les nouvelles colonnes ou fallback ancien
        ElevationRange elevationRange;
        if (item['elevation_range_min'] != null && item['elevation_range_max'] != null) {
          elevationRange = ElevationRange(
            min: (item['elevation_range_min'] as num).toDouble(),
            max: (item['elevation_range_max'] as num).toDouble(),
          );
        } else {
          // Fallback vers elevation_gain pour compatibilité
          final elevationGain = (item['elevation_gain'] as num?)?.toDouble() ?? 0.0;
          elevationRange = ElevationRange(min: 0, max: elevationGain);
        }

        return SavedRoute(
          id: item['id'],
          name: item['name'],
          parameters: RouteParameters(
            activityType: _parseActivityType(item['activity_type']),
            terrainType: _parseTerrainType(item['terrain_type']),
            urbanDensity: _parseUrbanDensity(item['urban_density']),
            distanceKm: (item['distance_km'] as num).toDouble(),
            elevationRange: elevationRange,
            difficulty: _parseDifficulty(item['difficulty'] as String?),
            maxInclinePercent: (item['max_incline_percent'] as num?)?.toDouble() ?? 12.0,
            preferredWaypoints: item['preferred_waypoints'] as int? ?? 3,
            avoidHighways: item['avoid_highways'] as bool? ?? true,
            prioritizeParks: item['prioritize_parks'] as bool? ?? false,
            surfacePreference: (item['surface_preference'] as num?)?.toDouble() ?? 0.5,
            startLongitude: (item['start_longitude'] as num).toDouble(),
            startLatitude: (item['start_latitude'] as num).toDouble(),
            isLoop: item['is_loop'] ?? true,
            avoidTraffic: item['avoid_traffic'] ?? true,
            preferScenic: item['prefer_scenic'] ?? true,
          ),
          coordinates: List<List<double>>.from(
            (item['coordinates'] as List).map((coord) => 
              List<double>.from(coord)
            )
          ),
          createdAt: createdAt,
          actualDistance: item['actual_distance_km']?.toDouble(),
          actualDuration: item['estimated_duration_minutes'],
          isSynced: true,
          timesUsed: item['times_used'] ?? 0,
          lastUsedAt: lastUsedAt,
          imageUrl: item['image_url'],
        );
      }).toList();
    } catch (e) {
      LogConfig.logError('❌ Erreur _getRoutesFromSupabasePaginated: $e');
      throw Exception('Erreur lors du chargement paginé: $e');
    }
  }

  /// Supprime un parcours
  Future<void> deleteRoute(String routeId) async {
    final user = _supabase.auth.currentUser;
    
    try {
      // 1. Récupérer la route depuis le cache rapide d'abord
      SavedRoute? route = await _routeCache.getRoute(routeId);
      
      // Fallback vers cache local si pas en cache rapide
      if (route == null) {
        final routes = await _getLocalRoutes();
        route = routes.firstWhere(
          (r) => r.id == routeId,
          orElse: () => throw Exception('Route introuvable'),
        );
      }

      // 2. Supprimer l'image du storage si elle existe
      if (route.hasImage) {
        try {
          await ScreenshotService.deleteScreenshot(route.imageUrl!);
          LogConfig.logInfo('Screenshot supprimée du storage');
        } catch (e) {
          LogConfig.logError('❌ Erreur suppression screenshot: $e');
        }
      }
      
      // 3. Nettoyage de tous les caches
      await _routeCache.removeRoute(routeId);
      await _deleteRouteLocally(routeId);
      await _removeFromPendingSync(routeId);

      // 4. Suppression cloud (si connecté)
      if (user != null && await _isConnected()) {
        try {
          await _supabase.from('user_routes').delete().eq('id', routeId);
          print('☁️ Route supprimée de Supabase: $routeId');
        } catch (e) {
          LogConfig.logError('❌ Erreur suppression Supabase: $e');
          // Marquer pour suppression ultérieure
          await _markForDeletion(routeId);
        }
      }

      // 5. Créer une sauvegarde après suppression importante
      final remainingRoutes = await _getLocalRoutes();
      if (remainingRoutes.isNotEmpty) {
        await _persistenceService.createSecurityBackup(remainingRoutes);
      }

      // 6. Invalider les caches
      await _invalidateRoutesCache();

      LogConfig.logInfo('🗑️ Route supprimée avec nettoyage persistant complet: $routeId');

    } catch (e, stackTrace) {
      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'RoutesRepository.deleteRoute',
        extra: {'route_id': routeId},
      );
      rethrow;
    }
  }

  /// Renomme un parcours sauvegardé
  Future<void> renameRoute(String routeId, String newName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    LogConfig.logInfo('✏️ Renommage du parcours: $routeId -> $newName');

    // 1. Mise à jour locale
    await _renameRouteLocally(routeId, newName);

    // 2. Mettre à jour le cache individuel de la route
    final cachedRoute = await _routeCache.getRoute(routeId);
    if (cachedRoute != null) {
      final updatedRoute = cachedRoute.copyWith(name: newName);
      await _routeCache.cacheRoute(routeId, updatedRoute);
      LogConfig.logSuccess('✅ Cache individuel mis à jour pour: $routeId');
    }

    // 3. Invalider le cache rapide pour forcer le refresh
    await _invalidateRoutesCache();

    // 2. Synchronisation avec Supabase si connecté
    try {
      if (await _isConnected()) {
        // Vérifier d'abord si la route existe dans Supabase
        final routeExists = await _checkRouteExistsInSupabase(routeId, user.id);
        
        if (routeExists) {
          // Route existe → UPDATE
          await _updateRouteNameInSupabase(routeId, newName, user.id);
          LogConfig.logSuccess('✅ Nom du parcours mis à jour dans Supabase');
        } else {
          // Route n'existe pas → marquer pour synchronisation complète
          await _markRouteForSync(routeId);
          LogConfig.logInfo('📝 Route marquée pour synchronisation complète (n\'existe pas encore sur le serveur)');
        }
      } else {
        // Marquer pour synchronisation ultérieure si hors ligne
        await _markRouteForSync(routeId);
        LogConfig.logInfo('📱 Parcours renommé localement, synchronisation en attente');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur sync renommage Supabase: $e');
      await _markRouteForSync(routeId);
    }
  }

  /// Vérifie si une route existe dans Supabase
  Future<bool> _checkRouteExistsInSupabase(String routeId, String userId) async {
    try {
      final response = await _supabase
          .from('user_routes') // 🔧 Correction : saved_routes → user_routes
          .select('id')
          .eq('id', routeId)
          .eq('user_id', userId)
          .maybeSingle();
      
      final exists = response != null;
      LogConfig.logInfo('🔍 Route $routeId existe dans Supabase: $exists');
      return exists;
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification existence route: $e');
      return false;
    }
  }

  /// Met à jour uniquement le nom d'une route existante dans Supabase
  Future<void> _updateRouteNameInSupabase(String routeId, String newName, String userId) async {
    try {
      final response = await _supabase
          .from('user_routes') // 🔧 Correction : saved_routes → user_routes
          .update({
            'name': newName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', routeId)
          .eq('user_id', userId)
          .select('id')
          .maybeSingle();

      if (response == null) {
        throw Exception('Route non trouvée lors de la mise à jour');
      }

      LogConfig.logInfo('Nom du parcours mis à jour dans Supabase: $routeId');
    } catch (e) {
      LogConfig.logError('❌ Erreur mise à jour nom Supabase: $e');
      throw Exception('Erreur lors de la mise à jour du nom sur le serveur');
    }
  }

  /// Met à jour le nom d'un parcours localement
  Future<void> _renameRouteLocally(String routeId, String newName) async {
    try {
      final routes = await _getLocalRoutes();
      final updatedRoutes = routes.map((route) {
        if (route.id == routeId) {
          return route.copyWith(name: newName);
        }
        return route;
      }).toList();

      await _saveRoutesToLocal(updatedRoutes);
      LogConfig.logInfo('Parcours renommé localement: $routeId');
    } catch (e) {
      LogConfig.logError('❌ Erreur renommage local: $e');
      throw Exception('Erreur lors du renommage local du parcours');
    }
  }

  /// 🔧 Met à jour les statistiques d'utilisation d'un parcours - CORRIGÉ
  Future<void> updateRouteUsage(String routeId) async {
    try {
      // 1. Mettre à jour le cache rapide
      final cachedRoute = await _routeCache.getRoute(routeId);
      if (cachedRoute != null) {
        final updatedRoute = cachedRoute.copyWith(
          timesUsed: cachedRoute.timesUsed + 1,
          lastUsedAt: DateTime.now(),
        );
        await _routeCache.cacheRoute(routeId, updatedRoute);
      }

      // 2. Mettre à jour le cache local
      await _updateLocalRouteUsage(routeId);

      // 3. Marquer pour sync si connecté
      if (await _isConnected()) {
        await _markRouteForSync(routeId);
      }

      LogConfig.logInfo('📊 Statistiques d\'usage mises à jour: $routeId');

    } catch (e) {
      LogConfig.logError('❌ Erreur mise à jour usage: $e');
    }
  }

  /// Met à jour les statistiques d'usage dans le cache local
  Future<void> _updateLocalRouteUsage(String routeId) async {
    try {
      final routes = await _getLocalRoutes();
      final routeIndex = routes.indexWhere((r) => r.id == routeId);
      
      if (routeIndex != -1) {
        final route = routes[routeIndex];
        final updatedRoute = route.copyWith(
          timesUsed: route.timesUsed + 1,
          lastUsedAt: DateTime.now(),
        );
        
        routes[routeIndex] = updatedRoute;
        await _updateLocalCache(routes);
        
        LogConfig.logInfo('Cache local mis à jour pour: $routeId');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur mise à jour cache local: $e');
    }
  }

  /// Synchronise tous les parcours en attente
  Future<void> syncPendingRoutes() async {
    final user = _supabase.auth.currentUser;
    if (user == null || !await _isConnected()) return;

    await _cleanupInvalidPendingRoutes();
    await _syncPendingRoutes();
    
    // Compression des anciennes données après sync réussie
    await _persistenceService.compressOldRoutes();

    // Logs des statistiques après sync
    final stats = await getSystemStats();
    LogConfig.logInfo('📊 Stats post-sync: ${stats['cache']['total_routes']} routes, ${stats['cache']['size_formatted']}');
  }

  /// Planifie la maintenance périodique (toutes les 24h)
  void _schedulePeriodicMaintenance() {
    // Maintenance en arrière-plan sans bloquer l'utilisateur
    Future.delayed(Duration(hours: 24), () async {
      try {
        await performMaintenanceTasks();
        // Replanifier pour dans 24h
        _schedulePeriodicMaintenance();
      } catch (e) {
        LogConfig.logError('❌ Erreur maintenance périodique: $e');
        // Replanifier quand même pour dans 24h
        _schedulePeriodicMaintenance();
      }
    });
  }

  /// Méthode de maintenance complète
  Future<void> performMaintenanceTasks() async {
    LogConfig.logInfo('🔧 Démarrage des tâches de maintenance...');
    
    try {
      // 1. Validation d'intégrité
      final report = await _persistenceService.validateDataIntegrity();
      LogConfig.logInfo('📊 Rapport d\'intégrité: ${report.toString()}');
      
      // 2. Compression des anciennes données
      await _persistenceService.compressOldRoutes();
      
      // 3. Nettoyage des caches
      await _routeCache.cleanupExpiredCache();
      await _cleanupOldPendingSync();
      
      // 4. Sauvegarde de sécurité
      final routes = await _getLocalRoutes();
      if (routes.isNotEmpty) {
        await _persistenceService.createSecurityBackup(routes);
      }
      
      // 5. Optimisation en arrière-plan
      await _persistenceService.performBackgroundOptimization();
      
      LogConfig.logInfo('Tâches de maintenance terminées');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur maintenance: $e');
    }
  }

  /// Crée une sauvegarde de sécurité si nécessaire (toutes les 5 routes)
  Future<void> _createSecurityBackupIfNeeded() async {
    try {
      final routes = await _getLocalRoutes();
      
      // Créer un backup tous les 5 parcours ou si plus de 10 routes
      if (routes.length % 5 == 0 || routes.length >= 10) {
        await _persistenceService.createSecurityBackup(routes);
        print('🛡️ Sauvegarde de sécurité automatique créée');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur création backup automatique: $e');
    }
  }

  /// Obtient les statistiques complètes du système
  Future<Map<String, dynamic>> getSystemStats() async {
    final cacheStats = await _routeCache.getCacheStats();
    final integrityReport = await _persistenceService.validateDataIntegrity();
    
    return {
      'cache': {
        'total_routes': cacheStats.totalRoutes,
        'size_formatted': cacheStats.formattedSize,
        'last_updated': cacheStats.lastUpdated.toIso8601String(),
      },
      'integrity': {
        'is_healthy': integrityReport.isHealthy,
        'has_warnings': integrityReport.hasWarnings,
        'cache_routes': integrityReport.totalRoutesInCache,
        'backup_count': integrityReport.backupCount,
        'errors': integrityReport.errors,
        'warnings': integrityReport.warnings,
      },
    };
  }

  /// Sauvegarde un parcours dans Supabase avec image_url
  Future<void> _saveRouteToSupabase(SavedRoute route, String userId) async {
    try {
      LogConfig.logInfo('📤 Envoi vers Supabase: ${route.id}');
      
      // Convertir la date en UTC pour la sauvegarde
      final createdAtUtc = route.createdAt.toUtc();
      print('🕒 Sauvegarde date UTC: ${createdAtUtc.toIso8601String()} (original local: ${route.createdAt})');
      
      await _supabase.from('user_routes').insert({
        'id': route.id,
        'user_id': userId,
        'name': route.name,
        'activity_type': route.parameters.activityType.id,
        'distance_km': route.parameters.distanceKm,
        'terrain_type': route.parameters.terrainType.id,
        'urban_density': route.parameters.urbanDensity.id,
        'is_loop': route.parameters.isLoop,
        'avoid_traffic': route.parameters.avoidTraffic,
        'elevation_gain': route.parameters.elevationGain, // 🔄 Utilise le getter de compatibilité
        'coordinates': route.coordinates,
        'start_latitude': route.coordinates.isNotEmpty ? route.coordinates.first[1] : null,
        'start_longitude': route.coordinates.isNotEmpty ? route.coordinates.first[0] : null,
        'actual_distance_km': route.actualDistance,
        'estimated_duration_minutes': route.actualDuration,
        'created_at': createdAtUtc.toIso8601String(),
        'updated_at': createdAtUtc.toIso8601String(),
        'times_used': route.timesUsed,
        'last_used_at': route.lastUsedAt?.toUtc().toIso8601String(),
        'image_url': route.imageUrl,
        'difficulty': route.parameters.difficulty.id,
        'max_incline_percent': route.parameters.maxInclinePercent,
        'preferred_waypoints': route.parameters.preferredWaypoints,
        'avoid_highways': route.parameters.avoidHighways,
        'prioritize_parks': route.parameters.prioritizeParks,
        'surface_preference': route.parameters.surfacePreference,
        'elevation_range_min': route.parameters.elevationRange.min,
        'elevation_range_max': route.parameters.elevationRange.max,
      });

      LogConfig.logInfo('Route sauvée dans Supabase avec image: ${route.id}');
      if (route.hasImage) {
        print('🖼️ Image URL: ${route.imageUrl}');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur sauvegarde Supabase détaillée: $e');
      rethrow;
    }
  }

  /// Récupère les parcours depuis Supabase avec image_url
  Future<List<SavedRoute>> _getRoutesFromSupabase(String userId) async {
    final response = await _supabase
        .from('user_routes')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((data) {
      // 🔧 Parser les dates depuis UTC vers local de façon EXPLICITE
      DateTime createdAt;
      DateTime? lastUsedAt;
      
      try {
        final createdAtString = data['created_at'] as String;
        // Parse en UTC puis convertir en local
        final utcDate = DateTime.parse(createdAtString).toUtc();
        createdAt = utcDate.toLocal();
        
      } catch (e) {
        LogConfig.logError('❌ Erreur parsing date: $e');
        createdAt = DateTime.now().toLocal(); // Fallback
      }
      
      if (data['last_used_at'] != null) {
        try {
          final lastUsedAtString = data['last_used_at'] as String;
          final utcLastUsed = DateTime.parse(lastUsedAtString).toUtc();
          lastUsedAt = utcLastUsed.toLocal();
        } catch (e) {
          LogConfig.logError('❌ Erreur parsing last_used_at: $e');
          lastUsedAt = null;
        }
      }

      // Construire ElevationRange depuis les nouvelles colonnes ou fallback ancien
      ElevationRange elevationRange;
      if (data['elevation_range_min'] != null && data['elevation_range_max'] != null) {
        elevationRange = ElevationRange(
          min: (data['elevation_range_min'] as num).toDouble(),
          max: (data['elevation_range_max'] as num).toDouble(),
        );
      } else {
        // Fallback vers elevation_gain pour compatibilité
        final elevationGain = (data['elevation_gain'] as num?)?.toDouble() ?? 0.0;
        elevationRange = ElevationRange(min: 0, max: elevationGain);
      }

      return SavedRoute(
        id: data['id'],
        name: data['name'],
        parameters: RouteParameters(
          activityType: _parseActivityType(data['activity_type']),
          terrainType: _parseTerrainType(data['terrain_type']),
          urbanDensity: _parseUrbanDensity(data['urban_density']),
          distanceKm: (data['distance_km'] as num).toDouble(),
          elevationRange: elevationRange,
          difficulty: _parseDifficulty(data['difficulty'] as String?),
          maxInclinePercent: (data['max_incline_percent'] as num?)?.toDouble() ?? 12.0,
          preferredWaypoints: data['preferred_waypoints'] as int? ?? 3,
          avoidHighways: data['avoid_highways'] as bool? ?? true,
          prioritizeParks: data['prioritize_parks'] as bool? ?? false,
          surfacePreference: (data['surface_preference'] as num?)?.toDouble() ?? 0.5,
          startLongitude: (data['start_longitude'] as num).toDouble(),
          startLatitude: (data['start_latitude'] as num).toDouble(),
          isLoop: data['is_loop'] ?? true,
          avoidTraffic: data['avoid_traffic'] ?? true,
          preferScenic: data['prefer_scenic'] ?? true,
        ),
        coordinates: List<List<double>>.from(
          (data['coordinates'] as List).map((coord) => 
            List<double>.from(coord)
          )
        ),
        createdAt: createdAt,
        actualDistance: data['actual_distance_km']?.toDouble(),
        actualDuration: data['estimated_duration_minutes'],
        isSynced: true,
        timesUsed: data['times_used'] ?? 0,
        lastUsedAt: lastUsedAt,
        imageUrl: data['image_url'],
      );
    }).toList();
  }

  /// Sauvegarde une liste de routes en local
  Future<void> _saveRoutesToLocal(List<SavedRoute> routes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routesJson = routes.map((route) => route.toJson()).toList();
      await prefs.setString(_localCacheKey, jsonEncode(routesJson));
      LogConfig.logInfo('${routes.length} routes sauvegardées localement');
    } catch (e) {
      LogConfig.logError('❌ Erreur sauvegarde locale: $e');
      throw Exception('Erreur lors de la sauvegarde locale');
    }
  }

  /// Sauvegarde locale avec support image_url
  Future<void> _saveRouteLocally(SavedRoute route) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await _getLocalRoutes();
    
    // Supprimer l'ancienne version si elle existe
    routes.removeWhere((r) => r.id == route.id);
    
    // Ajouter la nouvelle version
    routes.add(route);
    
    // Sauvegarder
    final routesJson = routes.map((r) => r.toJson()).toList();
    await prefs.setString(_localCacheKey, jsonEncode(routesJson));
    
    LogConfig.logInfo('💾 Route sauvée localement: ${route.id} - Image: ${route.hasImage ? "✅" : "❌"}');
  }

  /// Récupération locale avec support image_url
  Future<List<SavedRoute>> _getLocalRoutes({int? limit, int? offset}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routesJson = prefs.getString(_localCacheKey);
      
      if (routesJson == null) return [];

      final List<dynamic> data = jsonDecode(routesJson);
      final allRoutes = data.map((item) => SavedRoute.fromJson(item)).toList();
      
      // Trier par date de création (plus récent en premier)
      allRoutes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Appliquer la pagination si demandée
      if (offset != null) {
        if (offset >= allRoutes.length) return [];
        
        final endIndex = limit != null 
            ? (offset + limit).clamp(0, allRoutes.length)
            : allRoutes.length;
        
        return allRoutes.sublist(offset, endIndex);
      }
      
      // Si limit seul est spécifié
      if (limit != null) {
        return allRoutes.take(limit).toList();
      }
      
      return allRoutes;
    } catch (e) {
      LogConfig.logError('❌ Erreur _getLocalRoutes: $e');
      return [];
    }
  }

  Future<void> _updateLocalCache(List<SavedRoute> routes) async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = routes.map((r) => r.toJson()).toList();
    await prefs.setString(_localCacheKey, jsonEncode(routesJson));
  }

  Future<void> _deleteRouteLocally(String routeId) async {
    final routes = await _getLocalRoutes();
    routes.removeWhere((r) => r.id == routeId);
    await _updateLocalCache(routes);
  }

  Future<bool> _isConnected() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      
      // Vérifier si au moins une connexion est disponible
      return connectivityResults.any((result) => 
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet
      );
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification connectivité: $e');
      return false;
    }
  }

  Future<void> _markRouteForSync(String routeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingSync = prefs.getStringList(_pendingSyncKey) ?? [];
      
      if (!pendingSync.contains(routeId)) {
        pendingSync.add(routeId);
        await prefs.setStringList(_pendingSyncKey, pendingSync);
        LogConfig.logInfo('📝 Route marquée pour sync: $routeId');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur marquage sync: $e');
    }
  }

  Future<void> _markRouteSynced(String routeId) async {
    try {
      // Retirer de la liste des synchronisations en attente
      final prefs = await SharedPreferences.getInstance();
      final pendingIds = prefs.getStringList(_pendingSyncKey) ?? [];
      pendingIds.remove(routeId);
      await prefs.setStringList(_pendingSyncKey, pendingIds);
      
      // Mettre à jour la route locale pour marquer isSynced = true
      await _updateLocalRouteSyncStatus(routeId, true);
      
      LogConfig.logInfo('✅ Route marquée comme synchronisée: $routeId');
    } catch (e) {
      LogConfig.logError('❌ Erreur marquage route synchronisée: $e');
    }
  }

  /// Met à jour le statut de synchronisation d'une route dans le cache local
  Future<void> _updateLocalRouteSyncStatus(String routeId, bool isSynced) async {
    try {
      final routes = await _getLocalRoutes();
      final routeIndex = routes.indexWhere((r) => r.id == routeId);
      
      if (routeIndex != -1) {
        final route = routes[routeIndex];
        final updatedRoute = route.copyWith(isSynced: isSynced);
        
        routes[routeIndex] = updatedRoute;
        await _updateLocalCache(routes);
        
        // Mettre à jour aussi le cache rapide
        await _routeCache.cacheRoute(routeId, updatedRoute);
        
        LogConfig.logInfo('🔄 Statut sync mis à jour pour route: $routeId -> $isSynced');
      } else {
        LogConfig.logError('❌ Route non trouvée pour mise à jour sync: $routeId');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur mise à jour statut sync: $e');
    }
  }

  Future<void> _removeFromPendingSync(String routeId) async {
    await _markRouteSynced(routeId);
  }

  Future<void> _syncPendingRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingSync = prefs.getStringList(_pendingSyncKey) ?? [];
      
      if (pendingSync.isEmpty) {
        LogConfig.logInfo('📝 Aucune route en attente de synchronisation');
        return;
      }

      LogConfig.logInfo('🔄 Synchronisation de ${pendingSync.length} routes en attente...');
      
      final localRoutes = await _getLocalRoutes();
      final user = _supabase.auth.currentUser;
      
      if (user == null) {
        LogConfig.logError('❌ Utilisateur non connecté pour la sync');
        return;
      }

      final successfulSyncs = <String>[];
      
      for (final routeId in pendingSync) {
        try {
          final route = localRoutes.firstWhere(
            (r) => r.id == routeId,
            orElse: () => throw Exception('Route locale introuvable: $routeId'),
          );

          // Vérifier si la route existe déjà sur le serveur
          final exists = await _checkRouteExistsInSupabase(routeId, user.id);
          
          if (exists) {
            // Route existe → UPDATE complet
            await _updateCompleteRouteInSupabase(route, user.id);
            LogConfig.logInfo('Route mise à jour dans Supabase: $routeId');
          } else {
            // Route n'existe pas → INSERT
            await _saveRouteToSupabase(route, user.id);
            LogConfig.logInfo('Route insérée dans Supabase: $routeId');
          }
          
          successfulSyncs.add(routeId);
          await _markRouteSynced(routeId);
          
        } catch (e) {
          LogConfig.logError('❌ Erreur sync route $routeId: $e');
          // Continue avec les autres routes
        }
      }

      // Nettoyer la liste des routes synchronisées avec succès
      if (successfulSyncs.isNotEmpty) {
        final remainingPending = pendingSync.where((id) => !successfulSyncs.contains(id)).toList();
        await prefs.setStringList(_pendingSyncKey, remainingPending);
        LogConfig.logInfo('${successfulSyncs.length} routes synchronisées avec succès');
      }

    } catch (e) {
      LogConfig.logError('❌ Erreur synchronisation générale: $e');
    }
  }

  Future<void> _updateCompleteRouteInSupabase(SavedRoute route, String userId) async {
    try {
      await _supabase.from('user_routes').update({ // 🔧 Correction : saved_routes → user_routes
        'name': route.name,
        'activity_type': route.parameters.activityType.id,
        'distance_km': route.parameters.distanceKm,
        'terrain_type': route.parameters.terrainType.id,
        'urban_density': route.parameters.urbanDensity.id,
        'is_loop': route.parameters.isLoop,
        'avoid_traffic': route.parameters.avoidTraffic,
        'elevation_gain': route.parameters.elevationGain,
        'coordinates': route.coordinates,
        'start_latitude': route.coordinates.isNotEmpty ? route.coordinates.first[1] : null,
        'start_longitude': route.coordinates.isNotEmpty ? route.coordinates.first[0] : null,
        'actual_distance_km': route.actualDistance,
        'estimated_duration_minutes': route.actualDuration,
        'image_url': route.imageUrl,
        'times_used': route.timesUsed,
        'last_used_at': route.lastUsedAt?.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', route.id).eq('user_id', userId);

    } catch (e) {
      LogConfig.logError('❌ Erreur mise à jour complète Supabase: $e');
      rethrow;
    }
  }

  Future<void> _cleanupInvalidPendingRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingIds = prefs.getStringList(_pendingSyncKey) ?? [];
    final localRoutes = await _getLocalRoutes();
    final localIds = localRoutes.map((r) => r.id).toSet();
    
    // Retirer les IDs qui n'existent plus localement
    final validPendingIds = pendingIds.where((id) => localIds.contains(id)).toList();
    
    if (validPendingIds.length != pendingIds.length) {
      await prefs.setStringList(_pendingSyncKey, validPendingIds);
      LogConfig.logInfo('🧹 ${pendingIds.length - validPendingIds.length} routes en attente nettoyées');
    }
  }

  /// Cache rapide multiniveau
  Future<List<SavedRoute>> _getRoutesFromFastCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fastCacheJson = prefs.getString('fast_cache_routes');
      
      if (fastCacheJson == null) return [];
      
      final cacheData = jsonDecode(fastCacheJson) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp']);
      
      // Vérifier l'expiration du cache rapide (5 minutes)
      if (DateTime.now().difference(timestamp) > Duration(minutes: 5)) {
        await prefs.remove('fast_cache_routes');
        return [];
      }
      
      final routesList = cacheData['routes'] as List;
      return routesList.map((json) => SavedRoute.fromJson(json)).toList();
      
    } catch (e) {
      LogConfig.logError('❌ Erreur cache rapide: $e');
      return [];
    }
  }

  /// Met à jour tous les niveaux de cache
  Future<void> _updateAllCacheLevels(List<SavedRoute> routes) async {
    // 1. Cache rapide
    final prefs = await SharedPreferences.getInstance();
    final fastCacheData = {
      'routes': routes.map((r) => r.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString('fast_cache_routes', jsonEncode(fastCacheData));

    // 2. Cache local standard
    await _updateLocalCache(routes);

    // 3. Cache individuel pour chaque route
    final routeMap = {for (var route in routes) route.id: route};
    await _routeCache.cacheRoutes(routeMap);

    LogConfig.logInfo('🔄 Tous les niveaux de cache mis à jour: ${routes.length} routes');
  }

  /// Vérifica si une synchronisation est nécessaire
  Future<bool> _needsSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    
    if (lastSyncStr == null) return true;
    
    final lastSync = DateTime.parse(lastSyncStr);
    return DateTime.now().difference(lastSync) > _syncInterval;
  }

  /// Met à jour le timestamp de dernière sync
  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Synchronisation cloud asynchrone (non bloquante)
  void _performAsyncCloudSync(SavedRoute route, String userId) {
    // Lancement en arrière-plan sans bloquer l'UI
    Future.microtask(() async {
      try {
        if (await _isConnected()) {
          LogConfig.logInfo('☁️ Tentative sync immédiate: ${route.id}');
          
          // Tenter la synchronisation immédiate
          await _saveRouteToSupabase(route, userId);
          
          // Marquer comme synchronisée après succès
          await _updateLocalRouteSyncStatus(route.id, true);
          
          LogConfig.logInfo('✅ Sync cloud réussie et route marquée: ${route.id}');
        } else {
          await _markRouteForSync(route.id);
          LogConfig.logInfo('📡 Pas de connexion - Route marquée pour sync ultérieure: ${route.id}');
        }
      } catch (e) {
        LogConfig.logError('❌ Erreur sync cloud asynchrone: $e');
        await _markRouteForSync(route.id);
      }
    });
  }

  /// Synchronisation intelligente au démarrage
  Future<void> _performSmartSync() async {
    try {
      if (!await _needsSync() || !await _isConnected()) return;
      
      LogConfig.logInfo('🔄 Synchronisation intelligente en cours...');
      
      // Sync les routes en attente en arrière-plan
      Future.microtask(() async {
        try {
          await syncPendingRoutes();
          await _cleanupOldPendingSync();
        } catch (e) {
          LogConfig.logError('❌ Erreur sync intelligente: $e');
        }
      });
      
    } catch (e) {
      LogConfig.logError('❌ Erreur sync intelligente: $e');
    }
  }

  /// Invalide tous les caches
  Future<void> _invalidateRoutesCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fast_cache_routes');
    await _routeCache.cleanupExpiredCache();
  }

  /// Marque une route pour suppression différée
  Future<void> _markForDeletion(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    final deletionList = prefs.getStringList('pending_deletions') ?? [];
    
    if (!deletionList.contains(routeId)) {
      deletionList.add(routeId);
      await prefs.setStringList('pending_deletions', deletionList);
    }
  }

  /// Nettoie les anciennes sync en attente
  Future<void> _cleanupOldPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingRoutes = prefs.getStringList(_pendingSyncKey) ?? [];
    
    if (pendingRoutes.length > 20) {
      // Garder seulement les 20 plus récentes
      final cleanedRoutes = pendingRoutes.take(20).toList();
      await prefs.setStringList(_pendingSyncKey, cleanedRoutes);
      LogConfig.logInfo('🧹 Nettoyage des anciennes routes en attente: ${pendingRoutes.length - 20} supprimées');
    }
  }

  /// Obtient les statistiques de cache
  Future<RouteCacheStats> getCacheStats() async {
    return await _routeCache.getCacheStats();
  }

  // Parsers pour les enums
  ActivityType _parseActivityType(String id) {
    return ActivityType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => ActivityType.running,
    );
  }

  TerrainType _parseTerrainType(String id) {
    return TerrainType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => TerrainType.mixed,
    );
  }

  UrbanDensity _parseUrbanDensity(String id) {
    return UrbanDensity.values.firstWhere(
      (density) => density.id == id,
      orElse: () => UrbanDensity.mixed,
    );
  }

  DifficultyLevel _parseDifficulty(String? id) {
    if (id == null) return DifficultyLevel.moderate;
    return DifficultyLevel.values.firstWhere(
      (difficulty) => difficulty.id == id,
      orElse: () => DifficultyLevel.moderate,
    );
  }
}