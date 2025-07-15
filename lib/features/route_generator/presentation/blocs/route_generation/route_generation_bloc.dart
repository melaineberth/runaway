import 'dart:math' as math;
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/extensions/monitoring_extensions.dart';
import 'package:runaway/core/services/monitoring_service.dart';
import 'package:runaway/core/services/screenshot_service.dart';
import 'package:runaway/features/credits/data/services/credit_verification_service.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import '../../../data/repositories/routes_repository.dart';
import '../../../data/services/graphhopper_api_service.dart';

import 'route_generation_event.dart';
import 'route_generation_state.dart';

/// BLoC pour gérer l'analyse de zone et la génération de parcours
class RouteGenerationBloc extends HydratedBloc<RouteGenerationEvent, RouteGenerationState> {
  final RoutesRepository _routesRepository;
  final CreditVerificationService _creditService; // 🆕 Service dédié aux crédits
  final AppDataBloc? _appDataBloc;

  RouteGenerationBloc({
    RoutesRepository? routesRepository,
    required CreditVerificationService creditService, // 🆕 Injection du service
    AppDataBloc? appDataBloc,
  }) : _routesRepository = routesRepository ?? RoutesRepository(),
       _creditService = creditService, // 🆕 Service injecté
       _appDataBloc = appDataBloc,
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

  // ===== MÉTHODES PUBLIQUES SIMPLIFIÉES =====

  /// Vérifie si l'utilisateur peut générer une route
  Future<bool> canGenerateRoute() => _creditService.canGenerateRoute();

  /// Récupère le nombre de crédits disponibles
  Future<int> getAvailableCredits() => _creditService.getAvailableCredits();

  /// Déclenche le pré-chargement des crédits si nécessaire
  void ensureCreditDataLoaded() => _creditService.ensureCreditDataLoaded();

  // ===== HANDLERS D'ÉVÉNEMENTS =====

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

  /// 🆕 Génération avec architecture UI First pour les crédits
  Future<void> _onRouteGenerationRequested(
    RouteGenerationRequested event,
    Emitter<RouteGenerationState> emit,
  ) async {
    const int REQUIRED_CREDITS = 1; // Coût d'une génération
    final generationId = DateTime.now().millisecondsSinceEpoch.toString();

    trackEvent(event, data: {
      'activity_type': event.parameters.activityType,
      'distance_km': event.parameters.distanceKm,
      'terrain_type': event.parameters.terrainType,
      'start_lat': event.parameters.startLatitude,
      'start_lng': event.parameters.startLongitude,
    });

    final operationId = MonitoringService.instance.trackOperation(
      'route_generation',
      description: 'Génération complète d\'un parcours',
      data: {
        'activity_type': event.parameters.activityType,
        'distance_km': event.parameters.distanceKm,
        'terrain_type': event.parameters.terrainType,
        'urban_density': event.parameters.urbanDensity,
        'start_coordinates': [event.parameters.startLatitude, event.parameters.startLongitude],
      },
    );
    
    try {
      print('🚀 === DÉBUT GÉNÉRATION UI FIRST (ID: $generationId) ===');
      print('🏁 Bypass credit check: ${event.bypassCreditCheck}');

      emit(state.copyWith(
        isGeneratingRoute: true,
        errorMessage: null,
        stateId: '$generationId-start',
      ));

      // ===== VÉRIFICATION DES CRÉDITS (SEULEMENT SI NÉCESSAIRE) =====
      
      if (!event.bypassCreditCheck) {
        print('💳 === VÉRIFICATION CRÉDITS POUR UTILISATEUR AUTHENTIFIÉ ===');
        
        // Utiliser le service dédié pour la vérification
        final creditCheck = await _creditService.verifyCreditsForGeneration(
          requiredCredits: REQUIRED_CREDITS,
        );

        if (!creditCheck.isValid) {
          emit(state.copyWith(
            isGeneratingRoute: false,
            errorMessage: creditCheck.errorMessage ?? 
              'Crédits insuffisants pour générer un parcours. Vous avez ${creditCheck.availableCredits} crédits, mais il en faut ${creditCheck.requiredCredits}.',
            stateId: '$generationId-credit-error',
          ));
          return;
        }

        print('✅ Crédits suffisants, lancement de la génération');
      } else {
        print('🆕 === MODE GUEST - BYPASS VÉRIFICATION CRÉDITS ===');
      }
      
      // ===== GÉNÉRATION DU PARCOURS =====

      // 🆕 Tracking du début de génération
      MonitoringService.instance.recordMetric(
        'route_generation_started',
        1,
        tags: {
          'activity_type': event.parameters.activityType,
          'distance_range': _getDistanceRange(event.parameters.distanceKm),
          'terrain': event.parameters.terrainType,
        },
      );
      
      print('🛣️ Génération du parcours via API...');
      final result = await GraphHopperApiService.generateRoute(parameters: event.parameters);
      print('✅ Génération réussie: ${result.coordinates.length} points, ${result.distanceKm}km');

      // ===== CONSOMMATION DES CRÉDITS (SEULEMENT POUR UTILISATEURS AUTHENTIFIÉS) =====
      
      if (!event.bypassCreditCheck) {
        print('💳 Consommation de $REQUIRED_CREDITS crédit(s)...');

        final consumptionResult = await _creditService.consumeCreditsForGeneration(
          amount: REQUIRED_CREDITS,
          generationId: generationId,
          metadata: {
            'activity_type': event.parameters.activityType.name,
            'distance_km': event.parameters.distanceKm,
            'terrain_type': event.parameters.terrainType.name,
            'urban_density': event.parameters.urbanDensity.name,
          },
        );

        if (!consumptionResult.success) {
          emit(state.copyWith(
            isGeneratingRoute: false,
            errorMessage: consumptionResult.errorMessage ?? 'Erreur lors de l\'utilisation des crédits',
            stateId: '$generationId-consumption-error',
          ));
          return;
        }

        print('✅ Consommation réussie. Nouveau solde: ${consumptionResult.newBalance}');

      } else {
        print('🆕 === GÉNÉRATION GUEST - PAS D\'UTILISATION DE CRÉDITS ===');
      }

      // ===== FINALISATION =====

      // Mettre à jour l'état avec le parcours généré
      emit(state.copyWith(
        generatedRoute: result.coordinates,
        isGeneratingRoute: false,
        usedParameters: event.parameters,
        routeMetadata: result.metadata,
        errorMessage: null,
        stateId: '$generationId-success',
      ));

      if (!event.bypassCreditCheck) {
        print('✅ === FIN GÉNÉRATION UI FIRST (SUCCESS: $generationId) ===');
        print('💳 $REQUIRED_CREDITS crédit(s) utilisé(s)');
      } else {
        print('✅ === FIN GÉNÉRATION GUEST (SUCCESS: $generationId) ===');
        print('🆓 Génération gratuite utilisée');
      }

      MonitoringService.instance.finishOperation(
        operationId,
        success: true,
        data: {
          'actual_distance_km': result.distanceKm,
          'actual_duration_min': result.durationMinutes,
          'points_count': result.coordinates.length,
        },
      );

      // 🆕 Métriques business importantes
      MonitoringService.instance.recordMetric(
        'route_generation_success',
        1,
        tags: {
          'activity_type': event.parameters.activityType,
          'requested_distance': event.parameters.distanceKm.toString(),
          'actual_distance': result.distanceKm.toString(),
        },
      );

      // 🆕 Utilisation des crédits
      MonitoringService.instance.recordMetric(
        'credits_used',
        1,
        tags: {
          'purpose': 'route_generation',
          'activity_type': event.parameters.activityType,
        },
      );

    } catch (err, stackTrace) {

      captureError(err, stackTrace, event: event, state: state, extra: {
        'operation_id': operationId,
        'parameters': event.parameters.toJson(),
        'start_coordinates': [event.parameters.startLatitude, event.parameters.startLongitude],
      });

      emit(state.copyWith(
        isGeneratingRoute: false,
        errorMessage: 'Erreur lors de la génération: $err',
        stateId: '$generationId-error',
      ));

      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: err.toString(),
      );

      // 🆕 Métrique d'échec avec catégorisation
      MonitoringService.instance.recordMetric(
        'route_generation_failure',
        1,
        tags: {
          'error_type': err.runtimeType.toString(),
          'activity_type': event.parameters.activityType,
          'error_category': _categorizeError(err),
        },
      );
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
      isSavingRoute: true,
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
          routeId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'temp_user',
        );

        if (screenshotUrl != null) {
          print('✅ Screenshot capturé avec succès: $screenshotUrl');
        } else {
          print('⚠️ Screenshot non capturé, sauvegarde sans image');
        }
      } catch (screenshotError) {
        print('❌ Erreur capture screenshot: $screenshotError');
        screenshotUrl = null;
      }

      // 2. 💾 Sauvegarder le parcours avec l'URL de l'image
      final actualDistanceKm = state.routeMetadata?['distanceKm'] as double? ?? _calculateRouteDistance(state.generatedRoute!);
      
      final savedRoute = await _routesRepository.saveRoute(
        name: event.name,
        parameters: state.usedParameters!,
        coordinates: state.generatedRoute!,
        actualDistance: actualDistanceKm,
        estimatedDuration: state.routeMetadata?['durationMinutes'] as int?,
        imageUrl: screenshotUrl,
      );

      // 3. 🆕 Synchroniser avec AppDataBloc pour l'historique
      _appDataBloc?.add(SavedRouteAddedToAppData(
        name: event.name,
        parameters: state.usedParameters!,
        coordinates: state.generatedRoute!,
        actualDistance: actualDistanceKm,
        estimatedDuration: state.routeMetadata?['durationMinutes'] as int?,
        map: event.map,
      ));

      // 4. 🔄 Mettre à jour la liste des parcours sauvegardés
      final updatedRoutes = List<SavedRoute>.from(state.savedRoutes)..add(savedRoute);

      emit(state.copyWith(
        isSavingRoute: false,
        savedRoutes: updatedRoutes,
        errorMessage: null,
      ));

      print('✅ Parcours sauvegardé avec succès: ${savedRoute.name} (${savedRoute.formattedDistance})');
      print('🖼️ Image: ${savedRoute.hasImage ? "✅ Capturée" : "❌ Aucune"}');

    } catch (e) {
      print('❌ Erreur sauvegarde complète: $e');
      emit(state.copyWith(
        isSavingRoute: false,
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

      // 🆕 Prioriser AppDataBloc si disponible
      List<SavedRoute> routes;
      if (_appDataBloc != null && _appDataBloc.state.hasHistoricData) {
        routes = _appDataBloc.state.savedRoutes;
        print('📦 Parcours chargés depuis AppDataBloc (${routes.length})');
      } else {
        routes = await _routesRepository.getUserRoutes();
        print('🌐 Parcours chargés depuis API (${routes.length})');
      }

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

      // 🆕 Synchroniser avec AppDataBloc
      _appDataBloc?.add(SavedRouteDeletedFromAppData(event.routeId));

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
  Future<void> _onSavedRouteLoaded(
    SavedRouteLoaded event,
    Emitter<RouteGenerationState> emit,
  ) async {
    try {
      print('🔄 Chargement du parcours sauvegardé: ${event.routeId}');
      
      // 🆕 Prioriser AppDataBloc si disponible
      SavedRoute? route;
      if (_appDataBloc != null && _appDataBloc.state.hasHistoricData) {
        route = _appDataBloc.state.savedRoutes.firstWhere(
          (r) => r.id == event.routeId,
          orElse: () => throw Exception('Parcours non trouvé'),
        );
        print('📦 Parcours chargé depuis AppDataBloc');
      } else {
        final routes = await _routesRepository.getUserRoutes();
        route = routes.firstWhere(
          (r) => r.id == event.routeId,
          orElse: () => throw Exception('Parcours non trouvé'),
        );
        print('🌐 Parcours chargé depuis API');
      }

      // Calculer les métadonnées
      final metadata = {
        'distanceKm': route.actualDistance ?? route.parameters.distanceKm,
        'distance': ((route.actualDistance ?? route.parameters.distanceKm) * 1000).round(),
        'durationMinutes': route.actualDuration ?? 0,
        'points_count': route.coordinates.length,
        'is_loop': route.parameters.isLoop,
      };

      // Mettre à jour l'état avec le parcours chargé
      emit(state.copyWith(
        generatedRoute: route.coordinates,
        usedParameters: route.parameters,
        routeMetadata: metadata,
        isLoadedFromHistory: true,
        errorMessage: null,
        stateId: 'loaded-${event.routeId}',
      ));

      print('✅ Parcours chargé avec succès: ${route.name}');

    } catch (e) {
      print('❌ Erreur chargement parcours: $e');
      emit(state.copyWith(
        errorMessage: 'Erreur lors du chargement du parcours: $e',
        stateId: 'error-${event.routeId}',
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
      
      // 🆕 Synchroniser avec AppDataBloc
      _appDataBloc?.add(SavedRouteUsageUpdatedInAppData(event.routeId));
      
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
      
      // 🆕 Déclencher la synchronisation dans AppDataBloc
      _appDataBloc?.add(const HistoricDataRefreshRequested());
      
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
    
    emit(state.copyWith(
      pois: [],
      zoneStats: null,
      generatedRoute: null,
      usedParameters: null,
      routeMetadata: null,
      routeInstructions: null,
      isLoadedFromHistory: false,
      errorMessage: null,
      stateId: '$clearId-cleared',
    ));

    print('✅ === FIN NETTOYAGE COMPLET (CLEARED: $clearId-cleared) ===');
  }

  /// 🆕 Reset complet de l'état pour une nouvelle génération propre
  Future<void> _onRouteStateReset(
    RouteStateReset event,
    Emitter<RouteGenerationState> emit,
  ) async {
    final resetId = DateTime.now().millisecondsSinceEpoch.toString();
    print('🔄 === DÉBUT RESET COMPLET ÉTAT (ID: $resetId) ===');
    
    emit(RouteGenerationState(
      pois: const [],
      isAnalyzingZone: false,
      isGeneratingRoute: false,
      isSavingRoute: false,
      generatedRoute: null,
      usedParameters: null,
      errorMessage: null,
      zoneStats: null,
      savedRoutes: state.savedRoutes,
      routeMetadata: null,
      routeInstructions: null,
      isLoadedFromHistory: false,
      stateId: '$resetId-reset',
    ));
    
    print('✅ === FIN RESET COMPLET ÉTAT (RESET: $resetId-reset) ===');
  }

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
    
    return totalDistance / 1000;
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final double dLat = (lat2 - lat1) * (3.14159265359 / 180);
    final double dLon = (lon2 - lon1) * (3.14159265359 / 180);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        lat1 * math.cos(3.14159265359 / 180) * lat2 * math.cos(3.14159265359 / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  // 🆕 Helpers pour catégoriser les données
  String _getDistanceRange(double? distance) {
    if (distance == null) return 'unknown';
    if (distance < 5) return '0-5km';
    if (distance < 10) return '5-10km';
    if (distance < 20) return '10-20km';
    return '20km+';
  }

  String _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('credit') || errorString.contains('insufficient')) {
      return 'credits';
    } else if (errorString.contains('network') || errorString.contains('timeout')) {
      return 'network';
    } else if (errorString.contains('location') || errorString.contains('coordinates')) {
      return 'location';
    } else {
      return 'unknown';
    }
  }

  @override
  RouteGenerationState? fromJson(Map<String, dynamic> json) {
    try {
      return const RouteGenerationState();
    } catch (e) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(RouteGenerationState state) {
    try {
      return {
        'last_generation_timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return null;
    }
  }
}