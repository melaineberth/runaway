// lib/features/route_generator/data/repositories/routes_repository.dart

import 'dart:convert';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
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
  static const String _localCacheKey = 'cached_user_routes';
  static const String _pendingSyncKey = 'pending_sync_routes';

  // 🆕 Helper pour catégoriser les distances
  String _getDistanceRange(double distance) {
    if (distance < 5) return '0-5km';
    if (distance < 10) return '5-10km';
    if (distance < 20) return '10-20km';
    return '20km+';
  }

  /// 🆕 Sauvegarde un nouveau parcours avec image_url
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
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Générer un ID unique pour le parcours
      final routeId = _uuid.v4();

      // 🔧 S'assurer que la date est en temps local
      final now = DateTime.now().toLocal();

      print('💾 Sauvegarde parcours: $name');
      print('🖼️ Image URL: ${imageUrl ?? "Aucune"}');

      final route = SavedRoute(
        id: routeId,
        name: name,
        parameters: parameters,
        coordinates: coordinates,
        createdAt: now,
        actualDistance: actualDistance,
        actualDuration: estimatedDuration,
        imageUrl: imageUrl, // Utiliser l'URL fournie (peut être null)
      );

      // 1. Sauvegarder localement immédiatement
      await _saveRouteLocally(route);

      // 2. Essayer de synchroniser avec Supabase
      try {
        if (await _isConnected()) {
          await _saveRouteToSupabase(route, user.id);
          // Marquer comme synchronisé
          await _markRouteSynced(route.id);
          print('✅ Route synchronisée avec Supabase: ${route.id}');
        } else {
          // Marquer pour synchronisation ultérieure
          await _markRouteForSync(route.id);
          print('📱 Route marquée pour sync ultérieure: ${route.id}');
        }

        // 🆕 Métrique business - parcours sauvegardé
        MonitoringService.instance.recordMetric(
          'route_saved_repository',
          1,
          tags: {
            'activity_type': parameters.activityType,
            'distance_range': _getDistanceRange(parameters.distanceKm),
            'coordinates_count': coordinates.length.toString(),
            'has_terrain': (parameters.terrainType != null).toString(),
          },
        );
      } catch (e, stackTrace) {
        print('❌ Erreur sync Supabase, sauvegarde en local: $e');

        MonitoringService.instance.captureError(
          e,
          stackTrace,
          context: 'RoutesRepository.saveRoute',
          extra: {
            'user_id': user.id,
            'activity_type': parameters.activityType,
            'distance_km': parameters.distanceKm,
            'coordinates_count': coordinates.length,
          },
        );

        await _markRouteForSync(route.id);
      }

      return route;
    });
  }

  /// Récupère tous les parcours de l'utilisateur
  Future<List<SavedRoute>> getUserRoutes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return await _getLocalRoutes();
    }

    try {
      if (await _isConnected()) {
        // Nettoyer les routes en attente avant la sync
        await _cleanupInvalidPendingRoutes();
        
        // 1. Synchroniser les parcours en attente
        await _syncPendingRoutes();
        
        // 2. Récupérer depuis Supabase
        final routes = await _getRoutesFromSupabase(user.id);
        
        // 3. Mettre à jour le cache local
        await _updateLocalCache(routes);

        // 🆕 Métrique de chargement des parcours
        MonitoringService.instance.recordMetric(
          'user_routes_loaded',
          routes.length,
          tags: {
            'user_id': user.id,
            'routes_count': routes.length.toString(),
          },
        );
        
        return routes;
      } else {
        // Mode hors ligne : retourner le cache local
        return await _getLocalRoutes();
      }
    } catch (e, stackTrace) {
      print('❌ Erreur récupération Supabase, utilisation cache local: $e');

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'RoutesRepository.getUserRoutes',
        extra: {
          'user_id': user.id,
        },
      );

      return await _getLocalRoutes();
    }
  }

  /// Supprime un parcours
  Future<void> deleteRoute(String routeId) async {
    final user = _supabase.auth.currentUser;
    
    // 1. Récupérer la route pour obtenir l'URL de l'image
    final routes = await _getLocalRoutes();
    final route = routes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => throw Exception('Route introuvable'),
    );

    // 2. Supprimer l'image du storage si elle existe
    if (route.hasImage) {
      try {
        await ScreenshotService.deleteScreenshot(route.imageUrl!);
        print('✅ Screenshot supprimée du storage');
      } catch (e) {
        print('❌ Erreur suppression screenshot: $e');
        // Continue quand même avec la suppression de la route
      }
    }
    
    // 3. Supprimer localement
    await _deleteRouteLocally(routeId);
    
    // 4. Supprimer de la liste des routes en attente
    await _removeFromPendingSync(routeId);

    // 5. Supprimer de Supabase si connecté
    if (user != null) {
      try {
        if (await _isConnected()) {
          await _supabase
              .from('user_routes')
              .delete()
              .eq('id', routeId)
              .eq('user_id', user.id);
          print('✅ Route supprimée de Supabase: $routeId');
        }

        // 🆕 Métrique de suppression
        MonitoringService.instance.recordMetric(
          'route_deleted',
          1,
          tags: {
            'user_id': user.id,
          },
        );
      } catch (e, stackTrace) {
        MonitoringService.instance.captureError(
          e,
          stackTrace,
          context: 'RoutesRepository.deleteRoute',
          extra: {
            'route_id': routeId,
            'user_id': user.id,
          },
        );

        print('❌ Erreur suppression Supabase: $e');
        // La suppression locale a déjà été faite
      }
    }
  }

  /// Renomme un parcours sauvegardé
  Future<void> renameRoute(String routeId, String newName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    print('✏️ Renommage du parcours: $routeId -> $newName');

    // 1. Mise à jour locale
    await _renameRouteLocally(routeId, newName);

    // 2. Synchronisation avec Supabase si connecté
    try {
      if (await _isConnected()) {
        // 🆕 Vérifier d'abord si la route existe dans Supabase
        final routeExists = await _checkRouteExistsInSupabase(routeId, user.id);
        
        if (routeExists) {
          // Route existe → UPDATE
          await _updateRouteNameInSupabase(routeId, newName, user.id);
          print('✅ Nom du parcours mis à jour dans Supabase');
        } else {
          // Route n'existe pas → marquer pour synchronisation complète
          await _markRouteForSync(routeId);
          print('📝 Route marquée pour synchronisation complète (n\'existe pas encore sur le serveur)');
        }
      } else {
        // Marquer pour synchronisation ultérieure si hors ligne
        await _markRouteForSync(routeId);
        print('📱 Parcours renommé localement, synchronisation en attente');
      }
    } catch (e) {
      print('❌ Erreur sync renommage Supabase: $e');
      await _markRouteForSync(routeId);
    }
  }

  /// 🆕 Vérifie si une route existe dans Supabase
  Future<bool> _checkRouteExistsInSupabase(String routeId, String userId) async {
    try {
      final response = await _supabase
          .from('user_routes') // 🔧 Correction : saved_routes → user_routes
          .select('id')
          .eq('id', routeId)
          .eq('user_id', userId)
          .maybeSingle();
      
      final exists = response != null;
      print('🔍 Route $routeId existe dans Supabase: $exists');
      return exists;
    } catch (e) {
      print('❌ Erreur vérification existence route: $e');
      return false;
    }
  }

  /// 🆕 Met à jour uniquement le nom d'une route existante dans Supabase
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

      print('✅ Nom du parcours mis à jour dans Supabase: $routeId');
    } catch (e) {
      print('❌ Erreur mise à jour nom Supabase: $e');
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
      print('✅ Parcours renommé localement: $routeId');
    } catch (e) {
      print('❌ Erreur renommage local: $e');
      throw Exception('Erreur lors du renommage local du parcours');
    }
  }

  /// 🔧 Met à jour les statistiques d'utilisation d'un parcours - CORRIGÉ
  Future<void> updateRouteUsage(String routeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      if (await _isConnected()) {
        // Méthode 1: Utiliser RPC pour incrémenter atomiquement côté serveur
        // Cette approche est plus efficace et évite les conditions de course
        try {
          await _supabase.rpc('increment_route_usage', params: {
            'route_id': routeId,
            'user_id': user.id,
          });
          print('✅ Statistiques mises à jour via RPC: $routeId');
        } catch (rpcError) {
          print('⚠️ RPC non disponible, utilisation de la méthode alternative');
          
          // Méthode 2: Récupérer puis mettre à jour (fallback)
          final currentRoute = await _supabase
              .from('user_routes')
              .select('times_used')
              .eq('id', routeId)
              .eq('user_id', user.id)
              .single();

          final currentTimesUsed = (currentRoute['times_used'] as int?) ?? 0;
          
          await _supabase
              .from('user_routes')
              .update({
                'times_used': currentTimesUsed + 1,
                'last_used_at': DateTime.now().toIso8601String(),
              })
              .eq('id', routeId)
              .eq('user_id', user.id);
          
          print('✅ Statistiques mises à jour: $routeId (${currentTimesUsed + 1}x)');
        }

        // Mettre à jour le cache local aussi
        await _updateLocalRouteUsage(routeId);
        
      } else {
        // Mode hors ligne : mettre à jour seulement le cache local
        await _updateLocalRouteUsage(routeId);
        print('📱 Statistiques mises à jour localement (hors ligne): $routeId');
      }
    } catch (e) {
      print('❌ Erreur mise à jour usage: $e');
      // Essayer au moins de mettre à jour localement
      try {
        await _updateLocalRouteUsage(routeId);
      } catch (localError) {
        print('❌ Erreur mise à jour locale: $localError');
      }
    }
  }

  /// 🆕 Met à jour les statistiques d'usage dans le cache local
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
        
        print('✅ Cache local mis à jour pour: $routeId');
      }
    } catch (e) {
      print('❌ Erreur mise à jour cache local: $e');
    }
  }

  /// Synchronise tous les parcours en attente
  Future<void> syncPendingRoutes() async {
    final user = _supabase.auth.currentUser;
    if (user == null || !await _isConnected()) return;

    await _cleanupInvalidPendingRoutes();
    await _syncPendingRoutes();
  }

  // === MÉTHODES PRIVÉES ===

  /// 🆕 Sauvegarde un parcours dans Supabase avec image_url
  Future<void> _saveRouteToSupabase(SavedRoute route, String userId) async {
    try {
      print('📤 Envoi vers Supabase: ${route.id}');
      
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

      print('✅ Route sauvée dans Supabase avec image: ${route.id}');
      if (route.hasImage) {
        print('🖼️ Image URL: ${route.imageUrl}');
      }
    } catch (e) {
      print('❌ Erreur sauvegarde Supabase détaillée: $e');
      rethrow;
    }
  }

  /// 🆕 Récupère les parcours depuis Supabase avec image_url
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
        
        print('🕒 Date Supabase: $createdAtString');
        print('   -> UTC: $utcDate');  
        print('   -> Local: $createdAt');
      } catch (e) {
        print('❌ Erreur parsing date: $e');
        createdAt = DateTime.now().toLocal(); // Fallback
      }
      
      if (data['last_used_at'] != null) {
        try {
          final lastUsedAtString = data['last_used_at'] as String;
          final utcLastUsed = DateTime.parse(lastUsedAtString).toUtc();
          lastUsedAt = utcLastUsed.toLocal();
        } catch (e) {
          print('❌ Erreur parsing last_used_at: $e');
          lastUsedAt = null;
        }
      }

      // 🆕 Construire ElevationRange depuis les nouvelles colonnes ou fallback ancien
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
      print('✅ ${routes.length} routes sauvegardées localement');
    } catch (e) {
      print('❌ Erreur sauvegarde locale: $e');
      throw Exception('Erreur lors de la sauvegarde locale');
    }
  }

  /// 🆕 Sauvegarde locale avec support image_url
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
    
    print('💾 Route sauvée localement: ${route.id} - Image: ${route.hasImage ? "✅" : "❌"}');
  }

  // Méthode de parsing manquante :
  DifficultyLevel _parseDifficulty(String? id) {
    if (id == null) return DifficultyLevel.moderate;
    return DifficultyLevel.values.firstWhere(
      (difficulty) => difficulty.id == id,
      orElse: () => DifficultyLevel.moderate,
    );
  }

  /// 🆕 Récupération locale avec support image_url
  Future<List<SavedRoute>> _getLocalRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routesJson = prefs.getString(_localCacheKey);
      
      if (routesJson == null) return [];
      
      final routesList = jsonDecode(routesJson) as List;
      return routesList.map((json) {
        try {
          return SavedRoute.fromJson(json);
        } catch (e) {
          print('❌ Erreur parsing route locale: $e');
          print('📄 JSON problématique: $json');
          // Retourner null pour filtrer cette route corrompue
          return null;
        }
      }).whereType<SavedRoute>().toList(); // 🔧 Filtrer les nulls
    } catch (e) {
      print('❌ Erreur lecture cache local: $e');
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
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('❌ Erreur vérification connectivité: $e');
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
        print('📝 Route marquée pour sync: $routeId');
      }
    } catch (e) {
      print('❌ Erreur marquage sync: $e');
    }
  }

  Future<void> _markRouteSynced(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingIds = prefs.getStringList(_pendingSyncKey) ?? [];
    pendingIds.remove(routeId);
    await prefs.setStringList(_pendingSyncKey, pendingIds);
  }

  Future<void> _removeFromPendingSync(String routeId) async {
    await _markRouteSynced(routeId);
  }

  Future<void> _syncPendingRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingSync = prefs.getStringList(_pendingSyncKey) ?? [];
      
      if (pendingSync.isEmpty) {
        print('📝 Aucune route en attente de synchronisation');
        return;
      }

      print('🔄 Synchronisation de ${pendingSync.length} routes en attente...');
      
      final localRoutes = await _getLocalRoutes();
      final user = _supabase.auth.currentUser;
      
      if (user == null) {
        print('❌ Utilisateur non connecté pour la sync');
        return;
      }

      final successfulSyncs = <String>[];
      
      for (final routeId in pendingSync) {
        try {
          final route = localRoutes.firstWhere(
            (r) => r.id == routeId,
            orElse: () => throw Exception('Route locale introuvable: $routeId'),
          );

          // 🆕 Vérifier si la route existe déjà sur le serveur
          final exists = await _checkRouteExistsInSupabase(routeId, user.id);
          
          if (exists) {
            // Route existe → UPDATE complet
            await _updateCompleteRouteInSupabase(route, user.id);
            print('✅ Route mise à jour dans Supabase: $routeId');
          } else {
            // Route n'existe pas → INSERT
            await _saveRouteToSupabase(route, user.id);
            print('✅ Route insérée dans Supabase: $routeId');
          }
          
          successfulSyncs.add(routeId);
          await _markRouteSynced(routeId);
          
        } catch (e) {
          print('❌ Erreur sync route $routeId: $e');
          // Continue avec les autres routes
        }
      }

      // Nettoyer la liste des routes synchronisées avec succès
      if (successfulSyncs.isNotEmpty) {
        final remainingPending = pendingSync.where((id) => !successfulSyncs.contains(id)).toList();
        await prefs.setStringList(_pendingSyncKey, remainingPending);
        print('✅ ${successfulSyncs.length} routes synchronisées avec succès');
      }

    } catch (e) {
      print('❌ Erreur synchronisation générale: $e');
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
      print('❌ Erreur mise à jour complète Supabase: $e');
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
      print('🧹 ${pendingIds.length - validPendingIds.length} routes en attente nettoyées');
    }
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
}