// lib/features/route_generator/data/repositories/routes_repository.dart

import 'dart:convert';
import 'package:runaway/core/services/screenshot_service.dart';
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

  /// 🆕 Sauvegarde un nouveau parcours avec image_url
  Future<SavedRoute> saveRoute({
    required String name,
    required RouteParameters parameters,
    required List<List<double>> coordinates,
    double? actualDistance,
    int? estimatedDuration,
    String? imageUrl,
  }) async {
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
    } catch (e) {
      print('❌ Erreur sync Supabase, sauvegarde en local: $e');
      await _markRouteForSync(route.id);
    }

    return route;
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
        
        return routes;
      } else {
        // Mode hors ligne : retourner le cache local
        return await _getLocalRoutes();
      }
    } catch (e) {
      print('❌ Erreur récupération Supabase, utilisation cache local: $e');
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
      } catch (e) {
        print('❌ Erreur suppression Supabase: $e');
        // La suppression locale a déjà été faite
      }
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
    print('📤 Envoi vers Supabase: ${route.id}');
    
    try {
      // 🔧 Convertir explicitement en UTC pour Supabase
      final createdAtUtc = route.createdAt.toUtc().toIso8601String();
      final lastUsedAtUtc = route.lastUsedAt?.toUtc().toIso8601String();
      
      print('🕒 Sauvegarde date UTC: $createdAtUtc (original local: ${route.createdAt})');
      
      await _supabase.from('user_routes').insert({
        'id': route.id,
        'user_id': userId,
        'name': route.name,
        'activity_type': route.parameters.activityType.id,
        'terrain_type': route.parameters.terrainType.id,
        'urban_density': route.parameters.urbanDensity.id,
        'distance_km': route.parameters.distanceKm,
        'elevation_gain': route.parameters.elevationGain,
        'is_loop': route.parameters.isLoop,
        'avoid_traffic': route.parameters.avoidTraffic,
        'prefer_scenic': route.parameters.preferScenic,
        'coordinates': route.coordinates,
        'start_latitude': route.parameters.startLatitude,
        'start_longitude': route.parameters.startLongitude,
        'actual_distance_km': route.actualDistance,
        'estimated_duration_minutes': route.actualDuration,
        'created_at': createdAtUtc, // 🔧 UTC explicite
        'times_used': 0,
        'last_used_at': lastUsedAtUtc, // 🔧 UTC explicite
        'image_url': route.imageUrl,
      });
      
      print('✅ Route sauvée dans Supabase avec image: ${route.id}');
      print('🖼️ Image URL: ${route.imageUrl ?? "Aucune"}');
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

      return SavedRoute(
        id: data['id'],
        name: data['name'],
        parameters: RouteParameters(
          activityType: _parseActivityType(data['activity_type']),
          terrainType: _parseTerrainType(data['terrain_type']),
          urbanDensity: _parseUrbanDensity(data['urban_density']),
          distanceKm: (data['distance_km'] as num).toDouble(),
          elevationGain: (data['elevation_gain'] as num).toDouble(),
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
        createdAt: createdAt, // 🔧 Date correctement convertie
        actualDistance: data['actual_distance_km']?.toDouble(),
        actualDuration: data['estimated_duration_minutes'],
        isSynced: true,
        timesUsed: data['times_used'] ?? 0,
        lastUsedAt: lastUsedAt, // 🔧 Date correctement convertie
        imageUrl: data['image_url'],
      );
    }).toList();
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
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _markRouteForSync(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingIds = prefs.getStringList(_pendingSyncKey) ?? [];
    if (!pendingIds.contains(routeId)) {
      pendingIds.add(routeId);
      await prefs.setStringList(_pendingSyncKey, pendingIds);
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
    final prefs = await SharedPreferences.getInstance();
    final pendingIds = prefs.getStringList(_pendingSyncKey) ?? [];
    final user = _supabase.auth.currentUser;
    
    if (user == null || pendingIds.isEmpty) return;

    final localRoutes = await _getLocalRoutes();
    
    for (final routeId in List.from(pendingIds)) {
      try {
        final route = localRoutes.firstWhere(
          (r) => r.id == routeId,
          orElse: () => throw Exception('Route introuvable localement'),
        );
        
        await _saveRouteToSupabase(route, user.id);
        await _markRouteSynced(routeId);
        
        print('✅ Route synchronisée: $routeId');
      } catch (e) {
        print('❌ Erreur sync route $routeId: $e');
      }
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