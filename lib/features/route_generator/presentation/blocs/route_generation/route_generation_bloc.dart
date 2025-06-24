
import 'dart:math' as math;
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:runaway/core/services/screenshot_service.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import '../../../data/repositories/routes_repository.dart';
import '../../../data/services/graphhopper_api_service.dart';
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
    emit(state.copyWith(
      isGeneratingRoute: true,
      errorMessage: null,
    ));

    try {
      final result = await GraphHopperApiService.generateRoute(
        parameters: event.parameters,
      );

      final routeCoordinates = result.coordinatesForUI;

      if (routeCoordinates.isEmpty) {
        emit(state.copyWith(
          isGeneratingRoute: false,
          errorMessage: 'Impossible de générer un parcours avec ces paramètres',
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

      emit(state.copyWith(
        isGeneratingRoute: false,
        generatedRoute: routeCoordinates,
        usedParameters: event.parameters,
        routeMetadata: completeMetadata,
        routeInstructions: result.instructions,
        errorMessage: null,
      ));

      print('✅ Route générée via API GraphHopper: ${routeCoordinates.length} points, ${result.distanceKm.toStringAsFixed(1)}km');

    } catch (e) {
      emit(state.copyWith(
        isGeneratingRoute: false,
        errorMessage: 'Erreur lors de la génération du parcours: $e',
      ));
    }
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
    try {
      final route = state.savedRoutes.firstWhere(
        (r) => r.id == event.routeId,
        orElse: () => throw Exception('Parcours non trouvé'),
      );

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
      ));

      // Mettre à jour les statistiques d'utilisation
      add(RouteUsageUpdated(event.routeId));

    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Parcours non trouvé',
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
    emit(state.copyWith(
      pois: [],
      zoneStats: null,
      generatedRoute: null,
      usedParameters: null,
      routeMetadata: null,
      routeInstructions: null,
    ));
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