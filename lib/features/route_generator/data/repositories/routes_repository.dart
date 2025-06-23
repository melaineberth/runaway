import 'dart:convert';
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

  /// Sauvegarde un nouveau parcours
  Future<SavedRoute> saveRoute({
    required String name,
    required RouteParameters parameters,
    required List<List<double>> coordinates,
    double? actualDistance,
    int? estimatedDuration,
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
    );

    print('🔧 Génération route avec UUID: ${route.id}');

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
        // 🔧 FIX: Nettoyer les routes en attente avant la sync
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

  /// 🆕 Nettoie les routes en attente qui n'existent plus localement
  Future<void> _cleanupInvalidPendingRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingSyncKey) ?? [];
    
    if (pending.isEmpty) return;

    final localRoutes = await _getLocalRoutes();
    final localRouteIds = localRoutes.map((r) => r.id).toSet();
    
    // Garder seulement les IDs qui existent encore localement
    final validPending = pending.where((id) => localRouteIds.contains(id)).toList();
    
    if (validPending.length != pending.length) {
      await prefs.setStringList(_pendingSyncKey, validPending);
      print('🧹 Nettoyé ${pending.length - validPending.length} routes pendantes invalides');
    }
  }

  /// Supprime un parcours
  Future<void> deleteRoute(String routeId) async {
    final user = _supabase.auth.currentUser;
    
    // 1. Supprimer localement
    await _deleteRouteLocally(routeId);
    
    // 2. Supprimer de la liste des routes en attente
    await _removeFromPendingSync(routeId);

    // 3. Supprimer de Supabase si connecté
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

  /// 🆕 Supprime une route de la liste de synchronisation en attente
  Future<void> _removeFromPendingSync(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingSyncKey) ?? [];
    pending.remove(routeId);
    await prefs.setStringList(_pendingSyncKey, pending);
  }

  /// Met à jour les statistiques d'utilisation d'un parcours
  Future<void> updateRouteUsage(String routeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      if (await _isConnected()) {
        // 🔧 FIX: Utiliser une requête d'incrémentation
        await _supabase.rpc('increment_route_usage', params: {
          'route_id': routeId,
          'user_id': user.id,
        });
        print('✅ Usage mis à jour pour: $routeId');
      }
    } catch (e) {
      print('❌ Erreur mise à jour usage: $e');
      // Fallback : mise à jour manuelle
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

  /// Synchronise tous les parcours en attente
  Future<void> syncPendingRoutes() async {
    final user = _supabase.auth.currentUser;
    if (user == null || !await _isConnected()) return;

    await _cleanupInvalidPendingRoutes();
    await _syncPendingRoutes();
  }

  // === MÉTHODES PRIVÉES ===

  /// Sauvegarde un parcours dans Supabase
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
      });
      
      print('✅ Route sauvée dans Supabase: ${route.id}');
    } catch (e) {
      print('❌ Erreur sauvegarde Supabase détaillée: $e');
      rethrow;
    }
  }

  /// Récupère les parcours depuis Supabase
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
        isSynced: true, // 🔧 FIX: Marquer comme synchronisé depuis Supabase
        timesUsed: data['times_used'] ?? 0,
        lastUsedAt: data['last_used_at'] != null 
            ? DateTime.parse(data['last_used_at']) 
            : null,
      );
    }).toList();
  }

  /// Sauvegarde locale avec SharedPreferences
  Future<void> _saveRouteLocally(SavedRoute route) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await _getLocalRoutes();
    
    // 🔧 FIX: Éviter les doublons
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
          // Continuer avec les autres routes
        }
      }
      
      return routes;
    } catch (e) {
      print('❌ Erreur parsing routes locales: $e');
      // 🔧 FIX: Sauvegarder une liste vide pour éviter les erreurs futures
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

  /// Synchronise les parcours en attente avec gestion d'erreurs robuste
  Future<void> _syncPendingRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingSyncKey) ?? [];
    final user = _supabase.auth.currentUser;
    
    if (pending.isEmpty || user == null) return;

    final localRoutes = await _getLocalRoutes();
    final syncedRoutes = <String>[];
    
    for (final routeId in List.from(pending)) {
      try {
        // 🔧 FIX: Vérifier que la route existe localement
        final route = localRoutes.where((r) => r.id == routeId).firstOrNull;
        
        if (route == null) {
          print('⚠️ Route $routeId introuvable localement, suppression de la liste');
          syncedRoutes.add(routeId); // Marquer pour suppression
          continue;
        }
        
        await _saveRouteToSupabase(route, user.id);
        syncedRoutes.add(routeId);
        print('✅ Parcours $routeId synchronisé');
      } catch (e) {
        print('❌ Erreur sync parcours $routeId: $e');
        // Ne pas supprimer de la liste en cas d'erreur réseau
      }
    }
    
    // Supprimer les routes synchronisées de la liste
    for (final syncedId in syncedRoutes) {
      await _markRouteSynced(syncedId);
    }
    
    if (syncedRoutes.isNotEmpty) {
      print('✅ ${syncedRoutes.length} routes synchronisées');
    }
  }

  /// Vérifie la connectivité
  Future<bool> _isConnected() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      return connectivity.contains(ConnectivityResult.mobile) || 
             connectivity.contains(ConnectivityResult.wifi);
    } catch (e) {
      print('❌ Erreur vérification connectivité: $e');
      return false;
    }
  }

  // Méthodes de parsing pour les enums
  ActivityType _parseActivityType(String type) {
    return ActivityType.values.firstWhere(
      (e) => e.id == type,
      orElse: () => ActivityType.running,
    );
  }

  TerrainType _parseTerrainType(String type) {
    return TerrainType.values.firstWhere(
      (e) => e.id == type,
      orElse: () => TerrainType.mixed,
    );
  }

  UrbanDensity _parseUrbanDensity(String density) {
    return UrbanDensity.values.firstWhere(
      (e) => e.id == density,
      orElse: () => UrbanDensity.mixed,
    );
  }
}