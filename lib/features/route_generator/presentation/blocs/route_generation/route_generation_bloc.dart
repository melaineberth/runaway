
import 'dart:math' as math;
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/core/services/screenshot_service.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import '../../../data/repositories/routes_repository.dart';
import '../../../data/services/graphhopper_api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'route_generation_event.dart';
import 'route_generation_state.dart';

/// BLoC pour gérer l'analyse de zone et la génération de parcours
class RouteGenerationBloc extends HydratedBloc<RouteGenerationEvent, RouteGenerationState> {
  final RoutesRepository _routesRepository;

  RouteGenerationBloc({RoutesRepository? routesRepository}) 
      : _routesRepository = routesRepository ?? RoutesRepository(),
        super(const RouteGenerationState()) {
    on<ZoneAnalysisRequested>(_onZoneAnalysisRequested);
    on<RouteGenerationRequested>(_onRouteGenerationRequested);
    on<GeneratedRouteSaved>(_onGeneratedRouteSaved);
    on<SavedRouteLoaded>(_onSavedRouteLoaded);
    on<ZoneAnalysisCleared>(_onZoneAnalysisCleared);
    on<SavedRouteDeleted>(_onSavedRouteDeleted);
    on<SavedRoutesRequested>(_onSavedRoutesRequested);
    on<RouteUsageUpdated>(_onRouteUsageUpdated);
    on<SyncPendingRoutesRequested>(_onSyncPendingRoutesRequested);
    on<RouteStateReset>(_onRouteStateReset);
  }

  /// 🆕 Reset complet de l'état pour une nouvelle génération propre
  Future<void> _onRouteStateReset(
    RouteStateReset event,
    Emitter<RouteGenerationState> emit,
  ) async {
    final resetId = DateTime.now().millisecondsSinceEpoch.toString();
    print('🔄 === DÉBUT RESET COMPLET ÉTAT (ID: $resetId) ===');
    
    // Reset complet vers l'état initial
    emit(RouteGenerationState(
      pois: const [],
      isAnalyzingZone: false,
      isGeneratingRoute: false,
      generatedRoute: null,
      usedParameters: null,
      errorMessage: null,
      zoneStats: null,
      savedRoutes: state.savedRoutes, // Garder les parcours sauvegardés
      routeMetadata: null,
      routeInstructions: null,
      isLoadedFromHistory: false,
      stateId: '$resetId-reset',
    ));
    
    print('✅ === FIN RESET COMPLET ÉTAT (RESET: $resetId-reset) ===');
  }

  /// Analyse de zone simplifiée
  Future<void> _onZoneAnalysisRequested(
    ZoneAnalysisRequested event,
    Emitter<RouteGenerationState> emit,
  ) async {
    emit(state.copyWith(
      isAnalyzingZone: true,
      errorMessage: null,
    ));

    try {
      await Future.delayed(Duration(milliseconds: 500));

      final stats = ZoneStatistics(
        parksCount: 0,
        waterPointsCount: 0,
        viewPointsCount: 0,
        drinkingWaterCount: 0,
        toiletsCount: 0,
        greenSpaceRatio: 0.3,
        suitabilityLevel: 'good',
      );

      emit(state.copyWith(
        isAnalyzingZone: false,
        pois: [_createDummyPoi(event.latitude, event.longitude)],
        zoneStats: stats,
        errorMessage: null,
      ));

    } catch (e) {
      emit(state.copyWith(
        isAnalyzingZone: false,
        errorMessage: 'Erreur lors de l\'analyse de la zone: $e',
      ));
    }
  }

  /// Génération via API GraphHopper
  Future<void> _onRouteGenerationRequested(
    RouteGenerationRequested event,
    Emitter<RouteGenerationState> emit,
  ) async {
    final generationId = DateTime.now().millisecondsSinceEpoch.toString();
    print('🚀 === DÉBUT GÉNÉRATION PARCOURS (ID: $generationId) ===');
    
    emit(state.copyWith(
      isGeneratingRoute: true, // 🔑 Démarre le loading
      errorMessage: null,
      isLoadedFromHistory: false,
      stateId: generationId,
      generatedRoute: null,
      usedParameters: null,
      routeMetadata: null,
      routeInstructions: null,
    ));

    try {
      // 1. GÉNÉRATION
      print('🛣️ Génération de parcours via API GraphHopper...');
      final result = await GraphHopperApiService.generateRoute(
        parameters: event.parameters,
      );

      final routeCoordinates = result.coordinatesForUI;
      if (routeCoordinates.isEmpty) {
        emit(state.copyWith(
          isGeneratingRoute: false,
          errorMessage: 'Impossible de générer un parcours avec ces paramètres',
          stateId: '$generationId-error',
        ));
        return;
      }

      final completeMetadata = {
        'distanceKm': result.distanceKm,
        'distance': (result.distanceKm * 1000).round(),
        'durationMinutes': result.durationMinutes,
        'elevationGain': result.elevationGain,
        'points_count': routeCoordinates.length,
        'is_loop': event.parameters.isLoop,
        ...result.metadata,
        'generatedAt': DateTime.now().toIso8601String(),
        'parameters': event.parameters.toJson(),
      };

      // 🔑 IMPORTANT : MAINTENIR isGeneratingRoute = true
      emit(state.copyWith(
        isGeneratingRoute: true, // ← Ne pas passer à false
        generatedRoute: routeCoordinates,
        usedParameters: event.parameters,
        routeMetadata: completeMetadata,
        routeInstructions: result.instructions,
        errorMessage: null,
        isLoadedFromHistory: false,
        stateId: '$generationId-generated',
      ));

      print('✅ Route générée: ${routeCoordinates.length} points, ${result.distanceKm.toStringAsFixed(1)}km');

      // 2. SAUVEGARDE AUTOMATIQUE
      if (sb.Supabase.instance.client.auth.currentUser != null) {
        print('💾 Démarrage sauvegarde automatique...');
        
        final routeName = _generateAutoRouteName(event.parameters, result.distanceKm);
        await _performAutoSave(routeName, event.mapboxMap, emit, generationId);
      } else {
        print('🚫 Pas de sauvegarde - utilisateur non connecté');
        emit(state.copyWith(
          isGeneratingRoute: false, // ← Fin du loading
          stateId: '$generationId-success-no-save',
        ));
      }

    } catch (e) {
      print('❌ Erreur génération: $e');
      emit(state.copyWith(
        isGeneratingRoute: false,
        errorMessage: 'Erreur lors de la génération du parcours: $e',
        stateId: '$generationId-exception',
      ));
    }
  }

  Future<void> _performAutoSave(
    String routeName, 
    MapboxMap? mapboxMap,
    Emitter<RouteGenerationState> emit,
    String generationId,
  ) async {
    try {
      print('🚀 Début sauvegarde avec screenshot: $routeName');

      // 1. Screenshot
      String? screenshotUrl;
      if (mapboxMap != null) {
        try {
          screenshotUrl = await ScreenshotService.captureAndUploadMapSnapshot(
            liveMap: mapboxMap,
            routeCoords: state.generatedRoute!,
            routeId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
            userId: 'temp_user',
          );
          print('✅ Screenshot capturé: $screenshotUrl');
        } catch (e) {
          print('❌ Erreur screenshot: $e');
          screenshotUrl = null;
        }
      }

      // 2. Sauvegarde
      final actualDistanceKm = state.routeMetadata?['distanceKm'] as double? ?? 
          _calculateRouteDistance(state.generatedRoute!);
      
      final savedRoute = await _routesRepository.saveRoute(
        name: routeName,
        parameters: state.usedParameters!,
        coordinates: state.generatedRoute!,
        actualDistance: actualDistanceKm,
        estimatedDuration: state.routeMetadata?['durationMinutes'] as int?,
        imageUrl: screenshotUrl,
      );

      // 3. Finaliser
      final updatedRoutes = List<SavedRoute>.from(state.savedRoutes)..add(savedRoute);

      emit(state.copyWith(
        isGeneratingRoute: false, // 🔑 FIN du loading
        savedRoutes: updatedRoutes,
        errorMessage: null,
        stateId: '$generationId-success',
      ));

      print('✅ Parcours sauvegardé: ${savedRoute.name}');
      print('🖼️ Image: ${savedRoute.hasImage ? "✅ Capturée" : "❌ Aucune"}');

    } catch (e) {
      print('❌ Erreur sauvegarde: $e');
      emit(state.copyWith(
        isGeneratingRoute: false,
        errorMessage: 'Erreur lors de la sauvegarde: $e',
        stateId: '$generationId-save-error',
      ));
    }
  }

  String _generateAutoRouteName(RouteParameters parameters, double realDistanceKm) {
    final now = DateTime.now();
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateString = '${now.day}/${now.month}';
    return '${parameters.activityType.title} ${realDistanceKm.toStringAsFixed(0)}km - $timeString ($dateString)';
  }

  /// 🆕 Sauvegarde du parcours via RoutesRepository
  Future<void> _onGeneratedRouteSaved(
    GeneratedRouteSaved event,
    Emitter<RouteGenerationState> emit,
  ) async {
    if (!state.hasGeneratedRoute || state.usedParameters == null) {
      emit(state.copyWith(
        errorMessage: 'Aucun parcours à sauvegarder',
      ));
      return;
    }

    emit(state.copyWith(
      isGeneratingRoute: true,
      errorMessage: null,
    ));

    try {
      print('🚀 Début sauvegarde avec screenshot pour: ${event.name}');

      // 1. 📸 Capturer le screenshot de la carte
      String? screenshotUrl;
      try {
        print('📸 Capture du screenshot...');
        screenshotUrl = await ScreenshotService.captureAndUploadMapSnapshot(
          liveMap: event.map,
          routeCoords: state.generatedRoute!,
          routeId: 'temp_${DateTime.now().millisecondsSinceEpoch}', // ID temporaire
          userId: 'temp_user', // ID temporaire, sera remplacé
        );

        if (screenshotUrl != null) {
          print('✅ Screenshot capturé avec succès: $screenshotUrl');
        } else {
          print('⚠️ Screenshot non capturé, sauvegarde sans image');
        }
      } catch (screenshotError) {
        print('❌ Erreur capture screenshot: $screenshotError');
        // Continuer la sauvegarde sans image
        screenshotUrl = null;
      }

      // 2. 💾 Sauvegarder le parcours avec l'URL de l'image
      final actualDistanceKm = state.routeMetadata?['distanceKm'] as double? ?? 
          _calculateRouteDistance(state.generatedRoute!);
      
      final savedRoute = await _routesRepository.saveRoute(
        name: event.name,
        parameters: state.usedParameters!,
        coordinates: state.generatedRoute!,
        actualDistance: actualDistanceKm,
        estimatedDuration: state.routeMetadata?['durationMinutes'] as int?,
        imageUrl: screenshotUrl, // 🆕 Utiliser l'URL capturée
      );

      // 3. 🔄 Mettre à jour la liste des parcours sauvegardés
      final updatedRoutes = List<SavedRoute>.from(state.savedRoutes)
        ..add(savedRoute);

      emit(state.copyWith(
        isGeneratingRoute: false,
        savedRoutes: updatedRoutes,
        errorMessage: null,
      ));

      print('✅ Parcours sauvegardé avec succès: ${savedRoute.name} (${savedRoute.formattedDistance})');
      print('🖼️ Image: ${savedRoute.hasImage ? "✅ Capturée" : "❌ Aucune"}');

    } catch (e) {
      print('❌ Erreur sauvegarde complète: $e');
      emit(state.copyWith(
        isGeneratingRoute: false,
        errorMessage: 'Erreur lors de la sauvegarde: ${e.toString()}',
      ));
    }
  }

  /// 🆕 Chargement des parcours sauvegardés
  Future<void> _onSavedRoutesRequested(
    SavedRoutesRequested event,
    Emitter<RouteGenerationState> emit,
  ) async {
    try {
      emit(state.copyWith(isAnalyzingZone: true));

      final routes = await _routesRepository.getUserRoutes();

      emit(state.copyWith(
        isAnalyzingZone: false,
        savedRoutes: routes,
        errorMessage: null,
      ));

      print('✅ ${routes.length} parcours chargés');

    } catch (e) {
      emit(state.copyWith(
        isAnalyzingZone: false,
        errorMessage: 'Erreur lors du chargement des parcours: $e',
      ));
    }
  }

  /// 🆕 Suppression d'un parcours
  Future<void> _onSavedRouteDeleted(
    SavedRouteDeleted event,
    Emitter<RouteGenerationState> emit,
  ) async {
    try {
      await _routesRepository.deleteRoute(event.routeId);

      final updatedRoutes = state.savedRoutes
          .where((r) => r.id != event.routeId)
          .toList();

      emit(state.copyWith(
        savedRoutes: updatedRoutes,
      ));

      print('✅ Parcours supprimé: ${event.routeId}');

    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Erreur lors de la suppression: $e',
      ));
    }
  }

  /// Chargement d'un parcours sauvegardé
  void _onSavedRouteLoaded(
    SavedRouteLoaded event,
    Emitter<RouteGenerationState> emit,
  ) {
    final loadId = DateTime.now().millisecondsSinceEpoch.toString();
    print('📂 === DÉBUT CHARGEMENT HISTORIQUE (ID: $loadId) ===');
    print('📂 Route ID demandé: ${event.routeId}');

    try {
      final route = state.savedRoutes.firstWhere(
        (r) => r.id == event.routeId,
        orElse: () => throw Exception('Parcours non trouvé'),
      );

      print('📂 Parcours trouvé: ${route.name} (${route.coordinates.length} points)');

      emit(state.copyWith(
        generatedRoute: route.coordinates,
        usedParameters: route.parameters,
        routeMetadata: {
          'distanceKm': route.actualDistance ?? route.parameters.distanceKm,
          'distance': ((route.actualDistance ?? route.parameters.distanceKm) * 1000).round(),
          'durationMinutes': route.actualDuration ?? route.parameters.estimatedDuration.inMinutes,
          'points_count': route.coordinates.length,
          'is_loop': route.parameters.isLoop,
        },
        isLoadedFromHistory: true, // 🔧 CRUCIAL : Marquer comme chargé depuis l'historique
        errorMessage: null, // Reset les erreurs
        stateId: '$loadId-loaded', // 🆕 ID unique pour le chargement
      ));

      // Mettre à jour les statistiques d'utilisation
      add(RouteUsageUpdated(event.routeId));

      print('✅ === FIN CHARGEMENT HISTORIQUE (SUCCESS: $loadId-loaded) ===');

    } catch (e) {
      print('❌ Erreur chargement: $e');
      emit(state.copyWith(
        errorMessage: 'Parcours non trouvé',
        isLoadedFromHistory: false,
        stateId: '$loadId-error', // 🆕 ID d'erreur
      ));
    }
  }

  /// 🆕 Mise à jour des statistiques d'utilisation
  Future<void> _onRouteUsageUpdated(
    RouteUsageUpdated event,
    Emitter<RouteGenerationState> emit,
  ) async {
    try {
      await _routesRepository.updateRouteUsage(event.routeId);
      
      // Mettre à jour localement aussi
      final updatedRoutes = state.savedRoutes.map((route) {
        if (route.id == event.routeId) {
          return route.copyWith(
            timesUsed: route.timesUsed + 1,
            lastUsedAt: DateTime.now(),
          );
        }
        return route;
      }).toList();

      emit(state.copyWith(savedRoutes: updatedRoutes));

    } catch (e) {
      print('❌ Erreur mise à jour statistiques: $e');
    }
  }

  /// 🆕 Synchronisation des parcours en attente
  Future<void> _onSyncPendingRoutesRequested(
    SyncPendingRoutesRequested event,
    Emitter<RouteGenerationState> emit,
  ) async {
    try {
      emit(state.copyWith(isAnalyzingZone: true));

      await _routesRepository.syncPendingRoutes();
      
      // Recharger les parcours après sync
      final routes = await _routesRepository.getUserRoutes();

      emit(state.copyWith(
        isAnalyzingZone: false,
        savedRoutes: routes,
      ));

      print('✅ Synchronisation terminée');

    } catch (e) {
      emit(state.copyWith(
        isAnalyzingZone: false,
        errorMessage: 'Erreur de synchronisation: $e',
      ));
    }
  }

  /// Effacement de l'analyse
  void _onZoneAnalysisCleared(
    ZoneAnalysisCleared event,
    Emitter<RouteGenerationState> emit,
  ) {
    final clearId = DateTime.now().millisecondsSinceEpoch.toString();
    print('🧹 === DÉBUT NETTOYAGE COMPLET (ID: $clearId) ===');
    
    // 🔧 RESET COMPLET de tous les champs liés aux parcours
    emit(state.copyWith(
      pois: [],
      zoneStats: null,
      generatedRoute: null,
      usedParameters: null,
      routeMetadata: null,
      routeInstructions: null,
      isLoadedFromHistory: false, // 🔧 IMPORTANT : Reset du flag
      errorMessage: null, // 🔧 Reset des erreurs
      stateId: '$clearId-cleared', // 🆕 Nouvel ID pour l'état vide
    ));

    print('✅ === FIN NETTOYAGE COMPLET (CLEARED: $clearId-cleared) ===');
  }

  // === MÉTHODES UTILITAIRES ===

  Map<String, dynamic> _createDummyPoi(double lat, double lon) {
    return {
      'id': 'start_point',
      'name': 'Point de départ',
      'type': 'start',
      'coordinates': [lon, lat],
      'tags': {},
      'distance': 0.0,
    };
  }

  double _calculateRouteDistance(List<List<double>> coordinates) {
    if (coordinates.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      final lat1 = coordinates[i][1];
      final lon1 = coordinates[i][0];
      final lat2 = coordinates[i + 1][1];
      final lon2 = coordinates[i + 1][0];
      
      totalDistance += _calculateHaversineDistance(lat1, lon1, lat2, lon2);
    }
    
    return totalDistance / 1000; // Convertir en kilomètres
  }

  /// Calcule la distance haversine entre deux points
  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Rayon de la Terre en mètres
    final double dLat = (lat2 - lat1) * (3.14159265359 / 180);
    final double dLon = (lon2 - lon1) * (3.14159265359 / 180);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        lat1 * math.cos(3.14159265359 / 180) * lat2 * math.cos(3.14159265359 / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }


  /// Persistance locale uniquement pour les données de session
  @override
  RouteGenerationState? fromJson(Map<String, dynamic> json) {
    try {
      // Ne persister que les données temporaires, pas les parcours sauvegardés
      return const RouteGenerationState();
    } catch (e) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(RouteGenerationState state) {
    try {
      // Stocker seulement les métadonnées de session
      return {
        'last_generation_timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return null;
    }
  }
}