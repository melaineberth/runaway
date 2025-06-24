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

  /// 🆕 Sauvegarde un nouveau parcours avec capture de screenshot optionnelle
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

    final route = SavedRoute(
      id: _uuid.v4(),
      name: name,
      parameters: parameters,
      coordinates: coordinates,
      createdAt: DateTime.now(),
      actualDistance: actualDistance,
      actualDuration: estimatedDuration,
      imageUrl: imageUrl,
    );

    // Créer la route finale avec l'URL de l'image
    final finalRoute = route.copyWith(imageUrl: imageUrl);

    // 2. Sauvegarder localement immédiatement
    await _saveRouteLocally(finalRoute);

    // 3. Essayer de synchroniser avec Supabase
    try {
      if (await _isConnected()) {
        await _saveRouteToSupabase(finalRoute, user.id);
        // Marquer comme synchronisé
        await _markRouteSynced(finalRoute.id);
        print('✅ Route synchronisée avec Supabase: ${finalRoute.id}');
      } else {
        // Marquer pour synchronisation ultérieure
        await _markRouteForSync(finalRoute.id);
        print('📱 Route marquée pour sync ultérieure: ${finalRoute.id}');
      }
    } catch (e) {
      print('❌ Erreur sync Supabase, sauvegarde en local: $e');
      await _markRouteForSync(finalRoute.id);
    }

    return finalRoute;
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
        'created_at': route.createdAt.toIso8601String(),
        'times_used': 0,
        'last_used_at': null,
        'image_url': route.imageUrl, // 🆕 Inclure l'URL de l'image
      });
      
      print('✅ Route sauvée dans Supabase: ${route.id}');
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
        createdAt: DateTime.parse(data['created_at']),
        actualDistance: data['actual_distance_km']?.toDouble(),
        actualDuration: data['estimated_duration_minutes'],
        isSynced: true,
        timesUsed: data['times_used'] ?? 0,
        lastUsedAt: data['last_used_at'] != null 
            ? DateTime.parse(data['last_used_at']) 
            : null,
        imageUrl: data['image_url'] as String?, // 🆕 Récupérer l'URL de l'image
      );
    }).toList();
  }

  /// Met à jour les statistiques d'utilisation d'un parcours
  Future<void> updateRouteUsage(String routeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      if (await _isConnected()) {
        await _supabase.rpc('increment_route_usage', params: {
          'route_id': routeId,
          'user_id': user.id,
        });
        print('✅ Usage mis à jour pour: $routeId');
      }
    } catch (e) {
      print('❌ Erreur mise à jour usage: $e');
      try {
        await _supabase
            .from('user_routes')
            .update({
              'last_used_at': DateTime.now().toIso8601String(),
            })
            .eq('id', routeId)
            .eq('user_id', user.id);
      } catch (fallbackError) {
        print('❌ Erreur fallback usage: $fallbackError');
      }
    }
  }

  /// Nettoie les routes en attente qui n'existent plus localement
  Future<void> _cleanupInvalidPendingRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingSyncKey) ?? [];
    
    if (pending.isEmpty) return;

    final localRoutes = await _getLocalRoutes();
    final localRouteIds = localRoutes.map((r) => r.id).toSet();
    
    final validPending = pending.where((id) => localRouteIds.contains(id)).toList();
    
    if (validPending.length != pending.length) {
      await prefs.setStringList(_pendingSyncKey, validPending);
      print('🧹 Nettoyé ${pending.length - validPending.length} routes pendantes invalides');
    }
  }

  /// Supprime une route de la liste de synchronisation en attente
  Future<void> _removeFromPendingSync(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingSyncKey) ?? [];
    pending.remove(routeId);
    await prefs.setStringList(_pendingSyncKey, pending);
  }

  /// Sauvegarde locale avec SharedPreferences
  Future<void> _saveRouteLocally(SavedRoute route) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await _getLocalRoutes();
    
    routes.removeWhere((r) => r.id == route.id);
    routes.add(route);
    
    final jsonList = routes.map((r) => r.toJson()).toList();
    await prefs.setString(_localCacheKey, jsonEncode(jsonList));
    print('💾 Route sauvée localement: ${route.name}');
  }

  /// Récupère les parcours locaux avec gestion d'erreurs robuste
  Future<List<SavedRoute>> _getLocalRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_localCacheKey);
    
    if (jsonString == null) return [];
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      final routes = <SavedRoute>[];
      
      for (final json in jsonList) {
        try {
          routes.add(SavedRoute.fromJson(json));
        } catch (e) {
          print('❌ Erreur parsing route individuelle: $e');
        }
      }
      
      return routes;
    } catch (e) {
      print('❌ Erreur parsing routes locales: $e');
      await prefs.setString(_localCacheKey, jsonEncode([]));
      return [];
    }
  }

  /// Met à jour le cache local
  Future<void> _updateLocalCache(List<SavedRoute> routes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = routes.map((r) => r.toJson()).toList();
    await prefs.setString(_localCacheKey, jsonEncode(jsonList));
  }

  /// Supprime un parcours localement
  Future<void> _deleteRouteLocally(String routeId) async {
    final routes = await _getLocalRoutes();
    routes.removeWhere((r) => r.id == routeId);
    await _updateLocalCache(routes);
  }

  /// Marque un parcours comme devant être synchronisé
  Future<void> _markRouteForSync(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingSyncKey) ?? [];
    if (!pending.contains(routeId)) {
      pending.add(routeId);
      await prefs.setStringList(_pendingSyncKey, pending);
    }
  }

  /// Marque un parcours comme synchronisé
  Future<void> _markRouteSynced(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingSyncKey) ?? [];
    pending.remove(routeId);
    await prefs.setStringList(_pendingSyncKey, pending);
  }

  /// Synchronise les parcours en attente
  Future<void> _syncPendingRoutes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingSyncKey) ?? [];
    
    if (pending.isEmpty) return;

    final localRoutes = await _getLocalRoutes();
    
    for (final routeId in List.from(pending)) {
      try {
        final route = localRoutes.firstWhere((r) => r.id == routeId);
        await _saveRouteToSupabase(route, user.id);
        await _markRouteSynced(routeId);
        print('✅ Route synchronisée: $routeId');
      } catch (e) {
        print('❌ Erreur sync route $routeId: $e');
      }
    }
  }

  /// Vérifie la connectivité
  Future<bool> _isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
           connectivityResult.contains(ConnectivityResult.wifi);
  }

  /// Parse les enums depuis les données Supabase
  ActivityType _parseActivityType(String id) {
    return ActivityType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => ActivityType.running,
    );
  }

  TerrainType _parseTerrainType(String id) {
    return TerrainType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => TerrainType.flat,
    );
  }

  UrbanDensity _parseUrbanDensity(String id) {
    return UrbanDensity.values.firstWhere(
      (density) => density.id == id,
      orElse: () => UrbanDensity.mixed,
    );
  }
}