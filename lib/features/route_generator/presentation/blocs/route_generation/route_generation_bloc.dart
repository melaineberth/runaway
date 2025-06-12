import 'dart:math' as math;

import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../data/services/graphhopper_api_service.dart';
import 'route_generation_event.dart';
import 'route_generation_state.dart';

/// BLoC pour gérer l'analyse de zone et la génération de parcours
class RouteGenerationBloc extends HydratedBloc<RouteGenerationEvent, RouteGenerationState> {
  final _uuid = const Uuid();

  RouteGenerationBloc() : super(const RouteGenerationState()) {
    on<ZoneAnalysisRequested>(_onZoneAnalysisRequested);
    on<RouteGenerationRequested>(_onRouteGenerationRequested);
    on<GeneratedRouteSaved>(_onGeneratedRouteSaved);
    on<SavedRouteLoaded>(_onSavedRouteLoaded);
    on<ZoneAnalysisCleared>(_onZoneAnalysisCleared);
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
      // Avec l'API GraphHopper, pas besoin d'analyse préalable
      // On simule une analyse réussie pour maintenir l'UX
      await Future.delayed(Duration(milliseconds: 500));

      // Créer des statistiques basiques pour la zone (compatible avec l'API GraphHopper)
      final stats = ZoneStatistics(
        parksCount: 0,
        waterPointsCount: 0,
        viewPointsCount: 0,
        drinkingWaterCount: 0,
        toiletsCount: 0,
        greenSpaceRatio: 0.3, // Ratio fictif pour maintenir l'UX
        suitabilityLevel: 'good', // Niveau par défaut
      );

      emit(state.copyWith(
        isAnalyzingZone: false,
        pois: [_createDummyPoi(event.latitude, event.longitude)], // POI fictif pour maintenir la compatibilité
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
      // REMPLACER L'ANCIEN CODE PAR L'APPEL API
      final result = await GraphHopperApiService.generateRoute(
        parameters: event.parameters,
      );

      // Convertir le résultat pour l'UI existante
      final routeCoordinates = result.coordinatesForUI;

      if (routeCoordinates.isEmpty) {
        emit(state.copyWith(
          isGeneratingRoute: false,
          errorMessage: 'Impossible de générer un parcours avec ces paramètres',
        ));
        return;
      }

      emit(state.copyWith(
        isGeneratingRoute: false,
        generatedRoute: routeCoordinates,
        usedParameters: event.parameters,
        routeMetadata: result.metadata, // Nouveaux métadonnées
        routeInstructions: result.instructions, // Nouvelles instructions
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

  // Méthode helper pour créer un POI fictif (compatibilité)
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

  /// Gestion de la sauvegarde du parcours
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

    final newRoute = SavedRoute(
      id: _uuid.v4(),
      name: event.name,
      parameters: state.usedParameters!,
      coordinates: state.generatedRoute!,
      createdAt: DateTime.now(),
      actualDistance: _calculateRouteDistance(state.generatedRoute!),
    );

    final updatedRoutes = List<SavedRoute>.from(state.savedRoutes)
      ..add(newRoute);

    emit(state.copyWith(
      savedRoutes: updatedRoutes,
    ));
  }

  /// Gestion du chargement d'un parcours sauvegardé
  void _onSavedRouteLoaded(
    SavedRouteLoaded event,
    Emitter<RouteGenerationState> emit,
  ) {
    final route = state.savedRoutes.firstWhere(
      (r) => r.id == event.routeId,
      orElse: () => throw Exception('Parcours non trouvé'),
    );

    emit(state.copyWith(
      generatedRoute: route.coordinates,
      usedParameters: route.parameters,
    ));
  }

  /// Gestion de l'effacement de l'analyse
  void _onZoneAnalysisCleared(
    ZoneAnalysisCleared event,
    Emitter<RouteGenerationState> emit,
  ) {
    emit(state.copyWith(
      pois: [],
      zoneStats: null,
      generatedRoute: null,
      usedParameters: null,
    ));
  }

  /// Calculer la distance totale d'un parcours
  double _calculateRouteDistance(List<List<double>> coordinates) {
    if (coordinates.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      totalDistance += _calculateDistance(
        coordinates[i][1], // lat1
        coordinates[i][0], // lon1
        coordinates[i + 1][1], // lat2
        coordinates[i + 1][0], // lon2
      );
    }

    return totalDistance / 1000; // Convertir en km
  }

  /// Calculer la distance entre deux points (formule de Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // mètres
    final double dLat = (lat2 - lat1) * 3.14159265359 / 180;
    final double dLon = (lon2 - lon1) * 3.14159265359 / 180;
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * 3.14159265359 / 180) * 
        math.cos(lat2 * 3.14159265359 / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Restauration depuis le stockage
  @override
  RouteGenerationState? fromJson(Map<String, dynamic> json) {
    try {
      return const RouteGenerationState();
    } catch (e) {
      return null;
    }
  }

  /// Sauvegarde dans le stockage
  @override
  Map<String, dynamic>? toJson(RouteGenerationState state) {
    try {
      return {
        'saved_routes': state.savedRoutes.map((r) => {
          'id': r.id,
          'name': r.name,
          'created_at': r.createdAt.toIso8601String(),
        }).toList(),
      };
    } catch (e) {
      return null;
    }
  }
}
