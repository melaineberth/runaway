import 'dart:math' as math;
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/errors/api_exceptions.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/monitoring_extensions.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/features/route_generator/data/services/screenshot_service.dart';
import 'package:runaway/features/credits/data/services/credit_verification_service.dart';
import 'package:runaway/features/route_generator/domain/models/graphhopper_route_result.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import '../../../data/repositories/routes_repository.dart';
import '../../../data/services/graphhopper_api_service.dart';

import 'route_generation_event.dart';
import 'route_generation_state.dart';

/// BLoC pour gérer l'analyse de zone et la génération de parcours
class RouteGenerationBloc extends HydratedBloc<RouteGenerationEvent, RouteGenerationState> {
  final RoutesRepository _routesRepository;
  final CreditVerificationService _creditService;
  final AppDataBloc? _appDataBloc;

  // Constantes pour le retry
  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 2);

  RouteGenerationBloc({
    RoutesRepository? routesRepository,
    required CreditVerificationService creditService,
    AppDataBloc? appDataBloc,
  }) : _routesRepository = routesRepository ?? RoutesRepository(),
       _creditService = creditService,
       _appDataBloc = appDataBloc,
       super(const RouteGenerationState()) {
    
    // === GESTION DES ÉVÉNEMENTS ===
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

  /// Génération avec architecture UI First pour les crédits
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

    // Variables pour assurer la finalisation
    bool generationCompleted = false;
    GraphHopperRouteResult? result;
    
    try {
      LogConfig.logInfo('🚀 === DÉBUT GÉNÉRATION UI FIRST (ID: $generationId) ===');
      print('🏁 Bypass credit check: ${event.bypassCreditCheck}');

      emit(state.copyWith(
        isGeneratingRoute: true,
        errorMessage: null,
        stateId: '$generationId-start',
      ));

      // ===== VÉRIFICATION DE CONNECTIVITÉ AVANT TOUT =====
      
      LogConfig.logInfo('🌐 === VÉRIFICATION CONNECTIVITÉ ===');
      
      // Attendre l'initialisation du service avec timeout court
      await ConnectivityService.instance.waitForInitialization(
        timeout: const Duration(seconds: 2)
      );

      // Vérifier si on est hors ligne
      if (ConnectivityService.instance.isOffline) {
        LogConfig.logError('❌ Mode hors-ligne détecté');
        emit(state.copyWith(
          isGeneratingRoute: false,
          errorMessage: 'Vérifiez votre connexion internet pour générer un parcours.',
          stateId: '$generationId-offline',
        ));

        MonitoringService.instance.finishOperation(
          operationId,
          success: false,
          errorMessage: 'Génération impossible - mode hors ligne',
        );
        return;
      }
      
      LogConfig.logInfo('Connectivité confirmée');

      // ===== VÉRIFICATION DES CRÉDITS (SANS CONSOMMER) =====
    
      if (!event.bypassCreditCheck) {
        LogConfig.logInfo('💳 === VÉRIFICATION CRÉDITS (SANS CONSOMMER) ===');

        final creditVerification = await _creditService.verifyCreditsForGeneration(
          requiredCredits: REQUIRED_CREDITS,
        );

        if (!creditVerification.isValid) {
          LogConfig.logError('❌ Crédits insuffisants: ${creditVerification.errorMessage}');
          emit(state.copyWith(
            isGeneratingRoute: false,
            errorMessage: creditVerification.errorMessage ?? 'Crédits insuffisants',
            stateId: '$generationId-insufficient-credits',
          ));

          MonitoringService.instance.finishOperation(
            operationId,
            success: false,
            errorMessage: 'Insufficient credits',
          );
          return;
        }

        LogConfig.logInfo('✅ Crédits suffisants (${creditVerification.availableCredits} disponibles)');
      }
      
      // ===== GÉNÉRATION DU PARCOURS =====
      LogConfig.logInfo('🛣️ === GÉNÉRATION DE ROUTE AVEC RETRY ===');

      // Tracking du début de génération
      MonitoringService.instance.recordMetric(
        'route_generation_started',
        1,
        tags: {
          'activity_type': event.parameters.activityType,
          'distance_range': _getDistanceRange(event.parameters.distanceKm),
          'terrain': event.parameters.terrainType,
        },
      );
      
      try {
        // Retry automatique avec backoff exponentiel
        result = await _retryWithBackoff(() => 
          GraphHopperApiService.generateRoute(parameters: event.parameters)
        );
        
        LogConfig.logInfo('✅ Parcours généré avec succès');
        LogConfig.logInfo('Distance: ${result!.distanceKm} km');
        LogConfig.logInfo('Durée: ${result.durationMinutes} min');
        LogConfig.logInfo('Points: ${result.coordinates.length}');

      } on NetworkException catch (e) {
        LogConfig.logError('❌ Erreur réseau lors de la génération: ${e.message}');
        emit(state.copyWith(
          isGeneratingRoute: false,
          errorMessage: 'Problème de connexion. ${e.message}',
          stateId: '$generationId-network-error',
        ));
        
        MonitoringService.instance.finishOperation(
          operationId,
          success: false,
          errorMessage: 'Network error: ${e.message}',
        );
        return;
        
      } on RouteGenerationException catch (e) {
        LogConfig.logError('❌ Erreur de génération: ${e.message}');
        emit(state.copyWith(
          isGeneratingRoute: false,
          errorMessage: e.message,
          stateId: '$generationId-generation-error',
        ));
        
        MonitoringService.instance.finishOperation(
          operationId,
          success: false,
          errorMessage: 'Generation error: ${e.message}',
        );
        return;
      }

      // Marquer que la génération est réussie AVANT la consommation des crédits
      generationCompleted = true;
      LogConfig.logInfo('🎯 Génération terminée avec succès, finalisation en cours...');

      // ===== CONSOMMATION DES CRÉDITS (SEULEMENT POUR UTILISATEURS AUTHENTIFIÉS) =====
      
      if (!event.bypassCreditCheck) {
        LogConfig.logInfo('💳 === CONSOMMATION CRÉDITS (APRÈS GÉNÉRATION RÉUSSIE) ===');
        LogConfig.logInfo('💳 Consommation de $REQUIRED_CREDITS crédit(s)...');

        try {
          // Timeout sur la consommation de crédits pour éviter les blocages
          final consumptionResult = await _creditService.consumeCreditsForGeneration(
            amount: REQUIRED_CREDITS,
            generationId: generationId,
            metadata: {
              'activity_type': event.parameters.activityType.name,
              'distance_km': event.parameters.distanceKm,
              'terrain_type': event.parameters.terrainType.name,
              'urban_density': event.parameters.urbanDensity.name,
              'actual_distance_km': result.distanceKm,
              'actual_duration_min': result.durationMinutes,
              'points_count': result.coordinates.length,
            },
          ).timeout(const Duration(seconds: 10)); // 🔧 FIX: Timeout de 10s sur la consommation

          if (!consumptionResult.success) {
            LogConfig.logError('❌ Échec consommation crédits: ${consumptionResult.errorMessage}');
            // Ne pas bloquer si la consommation échoue - on a déjà la route générée
            LogConfig.logInfo('⚠️ Consommation échouée mais route générée - finalisation quand même');
          } else {
            LogConfig.logInfo('✅ Consommation réussie. Nouveau solde: ${consumptionResult.newBalance}');
          }

        } catch (e) {
          LogConfig.logError('❌ Erreur lors de la consommation des crédits: $e');
          LogConfig.logInfo('⚠️ Erreur consommation mais route générée - finalisation quand même');
          // Ne pas bloquer - on a déjà la route générée
        }

      } else {
        LogConfig.logInfo('🆕 === GÉNÉRATION GUEST - PAS D\'UTILISATION DE CRÉDITS ===');
      }

    } catch (err, stackTrace) {
      // Catch global pour s'assurer que isGeneratingRoute est toujours remis à false
      LogConfig.logError('❌ Erreur globale dans _onRouteGenerationRequested: $err');

      captureError(err, stackTrace, event: event, state: state, extra: {
        'operation_id': operationId,
        'parameters': event.parameters.toJson(),
        'start_coordinates': [event.parameters.startLatitude, event.parameters.startLongitude],
        'generation_completed': generationCompleted,
      });

      emit(state.copyWith(
        isGeneratingRoute: false,
        errorMessage: err.toString(),
        stateId: '$generationId-error',
      ));

      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: err.toString(),
      );

      // Métrique d'échec avec catégorisation
      MonitoringService.instance.recordMetric(
        'route_generation_failure',
        1,
        tags: {
          'error_type': err.runtimeType.toString(),
          'activity_type': event.parameters.activityType,
          'error_category': _categorizeError(err),
        },
      );
      return; // Return explicite pour éviter la finalisation
    }

    // Cette section s'exécute TOUJOURS si result != null
    if (generationCompleted && result != null) {
      LogConfig.logInfo('🎯 === FINALISATION GÉNÉRATION ===');
      
      // Mettre à jour l'état avec le parcours généré
      emit(state.copyWith(
        generatedRoute: result.coordinates,
        isGeneratingRoute: false, // S'assurer que le loader s'arrête
        usedParameters: event.parameters,
        routeMetadata: result.metadata,
        errorMessage: null,
        stateId: '$generationId-success',
      ));

      MonitoringService.instance.finishOperation(
        operationId,
        success: true,
        data: {
          'actual_distance_km': result.distanceKm,
          'actual_duration_min': result.durationMinutes,
          'points_count': result.coordinates.length,
        },
      );

      // Métriques business importantes
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

      LogConfig.logInfo('🎉 === GÉNÉRATION TERMINÉE AVEC SUCCÈS (ID: $generationId) ===');
    } else {
      // Sécurité supplémentaire - s'assurer que isGeneratingRoute est false
      LogConfig.logError('❌ Finalisation impossible - résultat manquant');
      emit(state.copyWith(
        isGeneratingRoute: false,
        errorMessage: 'Erreur de génération - résultat invalide',
        stateId: '$generationId-invalid-result',
      ));

      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: 'Invalid result',
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
      LogConfig.logInfo('🚀 Début sauvegarde avec screenshot pour: ${event.name}');

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
          LogConfig.logInfo('Screenshot capturé avec succès: $screenshotUrl');
        } else {
          LogConfig.logInfo('Screenshot non capturé, sauvegarde sans image');
        }
      } catch (screenshotError) {
        LogConfig.logError('❌ Erreur capture screenshot: $screenshotError');
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

      LogConfig.logInfo('Parcours sauvegardé avec succès: ${savedRoute.name} (${savedRoute.formattedDistance})');
      print('🖼️ Image: ${savedRoute.hasImage ? "✅ Capturée" : "❌ Aucune"}');

    } catch (e) {
      LogConfig.logError('❌ Erreur sauvegarde complète: $e');
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
        LogConfig.logInfo('📦 Parcours chargés depuis AppDataBloc (${routes.length})');
      } else {
        routes = await _routesRepository.getUserRoutes();
        LogConfig.logInfo('🌐 Parcours chargés depuis API (${routes.length})');
      }

      emit(state.copyWith(
        isAnalyzingZone: false,
        savedRoutes: routes,
        errorMessage: null,
      ));

      LogConfig.logInfo('${routes.length} parcours chargés');

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

      LogConfig.logInfo('Parcours supprimé: ${event.routeId}');

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
      LogConfig.logInfo('🔄 Chargement du parcours sauvegardé: ${event.routeId}');
      
      // 🆕 Prioriser AppDataBloc si disponible
      SavedRoute? route;
      if (_appDataBloc != null && _appDataBloc.state.hasHistoricData) {
        route = _appDataBloc.state.savedRoutes.firstWhere(
          (r) => r.id == event.routeId,
          orElse: () => throw Exception('Parcours non trouvé'),
        );
        LogConfig.logInfo('📦 Parcours chargé depuis AppDataBloc');
      } else {
        final routes = await _routesRepository.getUserRoutes();
        route = routes.firstWhere(
          (r) => r.id == event.routeId,
          orElse: () => throw Exception('Parcours non trouvé'),
        );
        LogConfig.logInfo('🌐 Parcours chargé depuis API');
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

      LogConfig.logInfo('Parcours chargé avec succès: ${route.name}');

    } catch (e) {
      LogConfig.logError('❌ Erreur chargement parcours: $e');
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
      LogConfig.logError('❌ Erreur mise à jour statistiques: $e');
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

      LogConfig.logInfo('Synchronisation terminée');

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
    LogConfig.logInfo('🧹 === DÉBUT NETTOYAGE COMPLET (ID: $clearId) ===');
    
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

    LogConfig.logInfo('=== FIN NETTOYAGE COMPLET (CLEARED: $clearId-cleared) ===');
  }

  /// 🆕 Reset complet de l'état pour une nouvelle génération propre
  Future<void> _onRouteStateReset(
    RouteStateReset event,
    Emitter<RouteGenerationState> emit,
  ) async {
    final resetId = DateTime.now().millisecondsSinceEpoch.toString();
    LogConfig.logInfo('🔄 === DÉBUT RESET COMPLET ÉTAT (ID: $resetId) ===');
    
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
    
    LogConfig.logInfo('=== FIN RESET COMPLET ÉTAT (RESET: $resetId-reset) ===');
  }

  // ===== MÉTHODES PUBLIQUES =====

  /// Vérifie si l'utilisateur peut générer une route
  Future<bool> canGenerateRoute() => _creditService.canGenerateRoute();

  /// Récupère le nombre de crédits disponibles
  Future<int> getAvailableCredits() => _creditService.getAvailableCredits();

  /// Déclenche le pré-chargement des crédits si nécessaire
  void ensureCreditDataLoaded() => _creditService.ensureCreditDataLoaded();

  // ===== MÉTHODE UTILITAIRE POUR LE RETRY =====
  
  /// Retry automatique avec backoff exponentiel
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxRetries = _maxRetries,
    Duration baseDelay = _baseDelay,
  }) async {
    int attempt = 0;
    
    while (attempt <= maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        // Si c'est le dernier essai ou si c'est une erreur non-récupérable, on relance
        if (attempt > maxRetries || _isNonRecoverableError(e)) {
          LogConfig.logError('❌ Abandon après $attempt tentative(s): $e');
          rethrow;
        }
        
        // Calculer le délai avec backoff exponentiel
        final delay = Duration(
          milliseconds: (baseDelay.inMilliseconds * (1 << (attempt - 1))).clamp(
            baseDelay.inMilliseconds, 
            30000, // Max 30 secondes
          ),
        );
        
        LogConfig.logInfo('⏳ Tentative $attempt/$maxRetries échouée: $e');
        LogConfig.logInfo('🔄 Retry dans ${delay.inSeconds}s...');
        
        await Future.delayed(delay);
      }
    }
    
    throw Exception('Toutes les tentatives ont échoué');
  }
  
  /// Détermine si une erreur est récupérable avec un retry
  bool _isNonRecoverableError(dynamic error) {
    if (error is NetworkException) {
      // Erreurs réseau récupérables : timeout, connexion
      return error.code == 'NO_INTERNET'; // Pas récupérable immédiatement
    }
    
    if (error is RouteGenerationException) {
      // Erreurs de validation sont généralement non-récupérables
      return true;
    }
    
    if (error is ValidationException) {
      // Erreurs de validation définitivement non-récupérables
      return true;
    }
    
    // Erreurs serveur 5xx sont récupérables, 4xx ne le sont pas
    if (error is ServerException) {
      return error.statusCode < 500;
    }
    
    return false; // Par défaut, on considère que c'est récupérable
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