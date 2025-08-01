import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/monitoring_extensions.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/features/route_generator/data/services/screenshot_service.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/data/services/iap_service.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/features/home/data/services/map_state_service.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'app_data_event.dart';
import 'app_data_state.dart';

/// BLoC principal pour orchestrer le pré-chargement et la gestion des données de l'application
class AppDataBloc extends Bloc<AppDataEvent, AppDataState> {
  final RoutesRepository _routesRepository;
  final MapStateService _mapStateService; // Injection du service
  final CreditsRepository _creditsRepository; // Ajout du repository crédits
  
  // Cache avec expiration optimisé
  static const Duration _cacheExpiration = Duration(minutes: 30);
  DateTime? _lastCacheUpdate;
  DateTime? _lastHistoricUpdate;
  DateTime? _lastCreditUpdate;
  
  // 🛡️ Protection contre les synchronisations multiples
  bool _isHistoricSyncInProgress = false;
  bool _isCreditSyncInProgress = false;
  bool _isFullSyncInProgress = false;
  
  // 🕒 Timing pour éviter les appels trop fréquents
  static const Duration _minSyncInterval = Duration(seconds: 5);
  DateTime? _lastHistoricSync;
  DateTime? _lastCreditSync;
  DateTime? _lastFullSync;

  AppDataBloc({
    required RoutesRepository routesRepository,
    required MapStateService mapStateService,
    required CreditsRepository creditsRepository, // Paramètre requis
  })  : _routesRepository = routesRepository,
        _mapStateService = mapStateService,
        _creditsRepository = creditsRepository,
        super(const AppDataState()) {
    on<AppDataPreloadRequested>(_onPreloadRequested);
    on<AppDataRefreshRequested>(_onRefreshRequested);
    on<AppDataClearRequested>(_onClearRequested);
    on<HistoricDataRefreshRequested>(_onHistoricDataRefresh);
    on<RouteAddedDataSync>(_onRouteAddedSync);
    on<RouteDeletedDataSync>(_onRouteDeletedSync);
    on<ForceDataSyncRequested>(_onForceDataSync);
    on<SavedRouteRenamedInAppData>(_onRouteRenamed);

    // Handlers pour les parcours
    on<SavedRouteAddedToAppData>(_onRouteAdded);
    on<SavedRouteDeletedFromAppData>(_onRouteDeleted);
    on<SavedRouteUsageUpdatedInAppData>(_onRouteUsageUpdated);

    // Handlers pour les crédits
    on<CreditDataRefreshRequested>(_onCreditDataRefresh);
    on<CreditDataPreloadRequested>(_onCreditDataPreload);
    on<CreditUsageCompletedInAppData>(_onCreditUsageCompleted);
    on<CreditPurchaseCompletedInAppData>(_onCreditPurchaseCompleted);
    on<CreditBalanceUpdatedInAppData>(_onCreditBalanceUpdated);
    on<CreditDataClearRequested>(_onCreditDataClear);
    on<CreditsForceSyncRequested>(_onCreditsForceSyncRequested);

    on<UserSessionChangedInAppData>(_onUserSessionChangedHandler);
  }

  /// Handler pour le changement de session
  Future<void> _onUserSessionChangedHandler(
    UserSessionChangedInAppData event,
    Emitter<AppDataState> emit,
  ) async {
    await _onUserSessionChanged(event.newUserId, emit);
  }

  /// Nettoyage complet lors d'un changement d'utilisateur
  Future<void> _onUserSessionChanged(
    String newUserId,
    Emitter<AppDataState> emit,
  ) async {
    LogConfig.logInfo('👤 Changement de session utilisateur: $newUserId');
    
    // Reset complet de l'état
    emit(const AppDataState()); // État initial vide
    
    // Nettoyer toutes les variables internes
    _lastCacheUpdate = null;
    _lastHistoricUpdate = null;
    _lastCreditUpdate = null;
    _lastHistoricSync = null;
    _lastCreditSync = null;
    _lastFullSync = null;
    
    // Reset des flags de synchronisation
    _isHistoricSyncInProgress = false;
    _isCreditSyncInProgress = false;
    _isFullSyncInProgress = false;
    
    LogConfig.logInfo('✅ État AppDataBloc réinitialisé pour nouveau utilisateur');
  }

  /// Handler pour la synchronisation forcée
  Future<void> _onCreditsForceSyncRequested(
    CreditsForceSyncRequested event,
    Emitter<AppDataState> emit,
  ) async {
    LogConfig.logInfo('🔄 Synchronisation forcée des crédits - raison: ${event.reason}');
    
    // Nettoyer complètement l'état
    emit(state.copyWith(
      userCredits: null,
      creditPlans: [],
      creditTransactions: [],
      isCreditDataLoaded: false,
      lastError: null,
    ));
    
    // Invalider le cache
    try {
      await _creditsRepository.invalidateCreditsCache();
    } catch (e) {
      LogConfig.logError('❌ Erreur invalidation cache: $e');
    }
    
    // Forcer le rechargement complet
    try {
      await _onCreditDataPreload(CreditDataPreloadRequested(), emit);
      LogConfig.logInfo('✅ Synchronisation forcée terminée');
    } catch (e) {
      LogConfig.logError('❌ Erreur synchronisation forcée: $e');
      emit(state.copyWith(
        lastError: 'Erreur lors de la synchronisation: $e',
      ));
    }
  }

  /// Chargement initial des données de crédits
  Future<void> _onCreditDataPreload(
    CreditDataPreloadRequested event,
    Emitter<AppDataState> emit,
  ) async {
    if (_isCreditSyncInProgress) {
      LogConfig.logInfo('⚠️ Sync crédits déjà en cours, abandon');
      return;
    }

    _isCreditSyncInProgress = true;
    LogConfig.logInfo('🚀 Pré-chargement des données de crédits...');

    try {
      // Charger toutes les données de crédits en parallèle
      final futures = await Future.wait([
        _creditsRepository.getUserCredits(),
        _creditsRepository.getCreditPlans(),
        _creditsRepository.getCreditTransactions(limit: 50),
      ]);

      final userCredits = futures[0] as UserCredits;
      final creditPlans = futures[1] as List<CreditPlan>;
      final transactions = futures[2] as List<CreditTransaction>;

      _lastCreditUpdate = DateTime.now();

      emit(state.copyWith(
        userCredits: userCredits,
        creditPlans: creditPlans,
        creditTransactions: transactions,
        isCreditDataLoaded: true,
        lastError: null,
      ));

      LogConfig.logInfo('Données de crédits pré-chargées: ${userCredits.availableCredits} crédits, ${creditPlans.length} plans, ${transactions.length} transactions');

    } catch (e) {
      LogConfig.logError('❌ Erreur pré-chargement crédits: $e');
      emit(state.copyWith(
        lastError: 'Erreur lors du chargement des crédits: $e',
      ));
    } finally {
      _isCreditSyncInProgress = false;
    }
  }

  /// Rafraîchissement des données de crédits
  Future<void> _onCreditDataRefresh(
    CreditDataRefreshRequested event,
    Emitter<AppDataState> emit,
  ) async {
    await _refreshCreditData(emit, showLoading: true);
  }

  /// Synchronisation après utilisation de crédits
  Future<void> _onCreditUsageCompleted(
    CreditUsageCompletedInAppData event,
    Emitter<AppDataState> emit,
  ) async {
    LogConfig.logInfo('Synchronisation après utilisation de ${event.amount} crédits');
    
    try {
      // Rafraîchir les données sans loading pour une UX fluide
      await _refreshCreditData(emit, showLoading: false);
      
      LogConfig.logInfo('Synchronisation post-utilisation réussie');
    } catch (e) {
      LogConfig.logError('❌ Erreur synchronisation post-utilisation: $e');
      // Ne pas émettre d'erreur pour ne pas perturber l'UX
    }
  }

  /// Synchronisation après achat de crédits
  Future<void> _onCreditPurchaseCompleted(
    CreditPurchaseCompletedInAppData event,
    Emitter<AppDataState> emit,
  ) async {
    LogConfig.logInfo('Synchronisation après achat de ${event.creditsAdded} crédits');
    
    try {
      // Rafraîchir les données sans loading
      await _refreshCreditData(emit, showLoading: false);
      
      LogConfig.logInfo('Synchronisation post-achat réussie');
    } catch (e) {
      LogConfig.logError('❌ Erreur synchronisation post-achat: $e');
    }
  }

  /// Mise à jour optimiste du solde
  Future<void> _onCreditBalanceUpdated(
    CreditBalanceUpdatedInAppData event,
    Emitter<AppDataState> emit,
  ) async {
    if (state.userCredits == null) return;
    
    final updatedCredits = state.userCredits!.copyWith(
      availableCredits: event.newBalance,
    );
    
    emit(state.copyWith(userCredits: updatedCredits));
    
    if (event.isOptimistic) {
      LogConfig.logInfo('Mise à jour optimiste du solde: ${event.newBalance} crédits');
    } else {
      LogConfig.logInfo('Confirmation du solde: ${event.newBalance} crédits');
    }
  }

  /// Nettoyage des données de crédits
  Future<void> _onCreditDataClear(
    CreditDataClearRequested event,
    Emitter<AppDataState> emit,
  ) async {
    LogConfig.logInfo('🗑️ Nettoyage des données de crédits');
    
    emit(state.copyWith(
      userCredits: null,
      creditPlans: [],
      creditTransactions: [],
      isCreditDataLoaded: false,
    ));
    
    _lastCreditUpdate = null;
    _lastCreditSync = null;
  }

  /// Méthode helper pour rafraîchir les données de crédits
  Future<void> _refreshCreditData(Emitter<AppDataState> emit, {bool showLoading = true}) async {
    if (_isCreditSyncInProgress) return;
    
    // Vérifier le timing pour éviter les appels trop fréquents
    if (_lastCreditSync != null && 
        DateTime.now().difference(_lastCreditSync!) < _minSyncInterval) {
      LogConfig.logInfo('⏱️ Sync crédits trop récente, abandon');
      return;
    }

    _isCreditSyncInProgress = true;
    _lastCreditSync = DateTime.now();

    if (showLoading && !state.isLoading) {
      emit(state.copyWith(isLoading: true));
    }

    try {
      final creditData = await _loadCreditData();
      
      if (creditData != null) {
        _lastCreditUpdate = DateTime.now();
        emit(state.copyWith(
          userCredits: creditData.userCredits,
          creditPlans: creditData.creditPlans,
          creditTransactions: creditData.transactions,
          isCreditDataLoaded: true,
          isLoading: false,
          lastError: null,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        lastError: 'Erreur lors du rafraîchissement des crédits: $e',
      ));
    } finally {
      _isCreditSyncInProgress = false;
    }
  }

  /// Charge les données de crédits depuis le repository
  Future<CreditDataResult?> _loadCreditData() async {
    try {
      LogConfig.logInfo('Chargement des données de crédits...');
      
      final futures = await Future.wait([
        _creditsRepository.getUserCredits(),
        _creditsRepository.getCreditPlans(),
        _creditsRepository.getCreditTransactions(limit: 50),
      ]);

      final userCredits = futures[0] as UserCredits;
      final creditPlans = futures[1] as List<CreditPlan>;
      final transactions = futures[2] as List<CreditTransaction>;

      // Pré-charger les produits IAP pour les achats
      try {
        await IAPService.preloadProducts(creditPlans);
        LogConfig.logInfo('Produits IAP pré-chargés pour ${creditPlans.length} plans');
      } catch (e) {
        LogConfig.logInfo('Erreur pré-chargement IAP: $e');
        // Ne pas faire échouer le chargement pour autant
      }

      return CreditDataResult(
        userCredits: userCredits,
        creditPlans: creditPlans,
        transactions: transactions,
      );
    } catch (e) {
      LogConfig.logError('❌ Erreur chargement données crédits: $e');
      return null;
    }
  }

  Future<void> _onRouteAdded(
    SavedRouteAddedToAppData event,
    Emitter<AppDataState> emit,
  ) async {
    LogConfig.logInfo('Sauvegarde de parcours via AppDataBloc: ${event.name}');

    // 0️⃣ → signale le début
    emit(state.copyWith(isSavingRoute: true));
    
    try {
      // 1. 📸 Capturer le screenshot de la carte
      String? screenshotUrl;
      try {
        LogConfig.logInfo('Capture du screenshot...');
        screenshotUrl = await ScreenshotService.captureAndUploadMapSnapshot(
          liveMap: event.map,
          routeCoords: event.coordinates,
          routeId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'temp_user',
          mapStateService: _mapStateService,
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
      final savedRoute = await _routesRepository.saveRoute(
        name: event.name,
        parameters: event.parameters,
        coordinates: event.coordinates,
        actualDistance: event.actualDistance,
        estimatedDuration: event.estimatedDuration,
        imageUrl: screenshotUrl,
      );

      // 3. 🔄 Recharger les données d'historique pour mettre à jour l'interface
      await _refreshHistoricData(emit, showLoading: false);
      
      // 3️⃣ → fin OK
      emit(state.copyWith(isSavingRoute: false));
      
      LogConfig.logInfo('Parcours sauvegardé avec succès: ${savedRoute.name}');
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de la sauvegarde du parcours: $e');
      emit(state.copyWith(
        lastError: 'Erreur lors de la sauvegarde du parcours: $e',
      ));
    }
  }

  Future<void> _onRouteDeleted(
    SavedRouteDeletedFromAppData event,
    Emitter<AppDataState> emit,
  ) async {
    LogConfig.logInfo('🗑️ Suppression de parcours via AppDataBloc: ${event.routeId}');
    
    try {
      // Supprimer le parcours
      await _routesRepository.deleteRoute(event.routeId);
      
      // Recharger les données d'historique
      await _refreshHistoricData(emit, showLoading: false);
      
      LogConfig.logInfo('Parcours supprimé avec succès');
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de la suppression du parcours: $e');
      // Ne pas écraser isHistoricDataLoaded si l'erreur est liée aux crédits
      if (state.isHistoricDataLoaded) {
        emit(state.copyWith(
          lastError: 'Erreur lors de la suppression du parcours: $e',
        ));
      } else {
        emit(state.copyWith(
          lastError: 'Erreur lors de la suppression du parcours: $e',
        ));
      }
    }
  }

  Future<void> _onRouteUsageUpdated(
    SavedRouteUsageUpdatedInAppData event,
    Emitter<AppDataState> emit,
  ) async {
    LogConfig.logInfo('📊 Mise à jour statistiques d\'utilisation: ${event.routeId}');
    
    try {
      // Mettre à jour les statistiques d'utilisation
      await _routesRepository.updateRouteUsage(event.routeId);
      
      // Recharger les données d'historique (sans loading)
      await _refreshHistoricData(emit, showLoading: false);
      
      LogConfig.logInfo('Statistiques d\'utilisation mises à jour');
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de la mise à jour des statistiques: $e');
      // Préserver isHistoricDataLoaded en cas d'erreur
      emit(state.copyWith(
        lastError: 'Erreur lors de la mise à jour des statistiques: $e',
      ));
    }
  }

  Future<void> _onRouteRenamed(
    SavedRouteRenamedInAppData event,
    Emitter<AppDataState> emit,
  ) async {
    LogConfig.logInfo('✏️ Renommage de parcours via AppDataBloc: ${event.routeId} -> ${event.newName}');
    
    try {
      // Renommer le parcours via le repository
      await _routesRepository.renameRoute(event.routeId, event.newName);
      
      // Recharger les données d'historique pour mettre à jour l'interface
      await _refreshHistoricData(emit, showLoading: false);
      
      LogConfig.logInfo('Parcours renommé avec succès');
    } catch (e) {
      LogConfig.logError('❌ Erreur lors du renommage du parcours: $e');
      // Préserver isHistoricDataLoaded en cas d'erreur
      emit(state.copyWith(
        lastError: 'Erreur lors du renommage du parcours: $e',
      ));
    }
  }

  Future<void> _refreshHistoricData(Emitter<AppDataState> emit, {bool showLoading = true}) async {
    if (showLoading) {
      emit(state.copyWith(isLoading: true));
    }

    try {
      final historicData = await _loadHistoricData();
      
      if (historicData != null) {
        _lastHistoricUpdate = DateTime.now();
        emit(state.copyWith(
          savedRoutes: historicData,
          isHistoricDataLoaded: true,
          isLoading: false,
          lastError: null,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        lastError: 'Erreur lors du rafraîchissement: $e',
      ));
    }
  }

  /// Pré-charge toutes les données nécessaires
  Future<void> _onPreloadRequested(
    AppDataPreloadRequested event,
    Emitter<AppDataState> emit,
  ) async {
    trackEvent(event);

    final operationId = MonitoringService.instance.trackOperation(
      'app_data_preload',
      description: 'Pré-chargement des données de l\'application',
    );

    if (_isFullSyncInProgress) {
      LogConfig.logInfo('Sync complète déjà en cours, abandon');
      return;
    }

    _isFullSyncInProgress = true;
    
    // Vérifie si le cache est encore valide pour éviter un rechargement
    if (_isCacheValid() && _hasCompleteData()) {
      LogConfig.logInfo('📦 Cache valide, pas de rechargement nécessaire');
      _isFullSyncInProgress = false;
      return;
    }

    LogConfig.logInfo('🚀 Pré-chargement complet des données...');
    emit(state.copyWith(isLoading: true));

    try {
      // Charger les données en parallèle
      final futures = await Future.wait([
        _loadHistoricData(),
        _loadCreditData(), // Ajout des crédits
      ]);
      
      final historicData = futures[0] as List<SavedRoute>?;
      final creditData = futures[1] as CreditDataResult?;

      // Mettre à jour le cache
      final now = DateTime.now();
      _lastCacheUpdate = now;
      _lastHistoricUpdate = now;
      _lastCreditUpdate = now;
      _lastFullSync = now;

      emit(state.copyWith(
        // Historique
        savedRoutes: historicData ?? [],
        isHistoricDataLoaded: true,
        
        // Crédits
        userCredits: creditData?.userCredits,
        creditPlans: creditData?.creditPlans ?? [],
        creditTransactions: creditData?.transactions ?? [],
        isCreditDataLoaded: creditData != null,
        
        // État
        isLoading: false,
        lastError: null,
        lastUpdate: DateTime.now(),
        isDataLoaded: true,
        lastCacheUpdate: _lastCacheUpdate,
      ));

      LogConfig.logInfo('Pré-chargement complet terminé');
      LogConfig.logInfo('📚 Historique: ${historicData?.length ?? 0} parcours');
      LogConfig.logInfo('Crédits: ${creditData?.userCredits.availableCredits ?? 0} disponibles');

      MonitoringService.instance.finishOperation(operationId, success: true);

      // Métriques de performance des données
      MonitoringService.instance.recordMetric(
        'app_data_loaded',
        1,
        tags: {
          'routes_count': state.savedRoutes.length.toString(),
        },
      );
      
    } catch (e, stackTrace) {
      captureError(e, stackTrace, event: event, state: state);

      emit(state.copyWith(
        isLoading: false,
        lastError: 'Erreur lors du chargement: ${e.toString()}',
      ));

      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: e.toString(),
      );
    } finally {
      _isFullSyncInProgress = false;
    }
  }

  /// Rafraîchit toutes les données avec protection contre les doublons
  Future<void> _onRefreshRequested(
    AppDataRefreshRequested event,
    Emitter<AppDataState> emit,
  ) async {
    if (_isFullSyncInProgress) return;

    _isFullSyncInProgress = true;
    LogConfig.logInfo('🔄 Rafraîchissement complet...');

    emit(state.copyWith(isLoading: true));

    try {
      // Rafraîchir toutes les données
      await Future.wait([
        _refreshHistoricData(emit, showLoading: false),
        _refreshCreditData(emit, showLoading: false),
      ]);

      _lastCacheUpdate = DateTime.now();
      
      emit(state.copyWith(
        isLoading: false,
        lastError: null,
        lastUpdate: DateTime.now(),
      ));

      LogConfig.logInfo('Rafraîchissement complet terminé');

    } catch (e) {
      LogConfig.logError('❌ Erreur rafraîchissement: $e');
      emit(state.copyWith(
        isLoading: false,
        lastError: 'Erreur lors du rafraîchissement: $e',
      ));
    } finally {
      _isFullSyncInProgress = false;
    }
  }

  /// Rafraîchissement optimisé des données d'historique
  Future<void> _onHistoricDataRefresh(
    HistoricDataRefreshRequested event,
    Emitter<AppDataState> emit,
  ) async {
    // 🛡️ Protection contre les appels multiples
    if (_isHistoricSyncInProgress) {
      LogConfig.logInfo('Sync historique déjà en cours, ignorée');
      return;
    }
    
    if (_lastHistoricSync != null && 
        DateTime.now().difference(_lastHistoricSync!) < _minSyncInterval) {
      LogConfig.logInfo('Sync historique trop récente, ignorée');
      return;
    }

    _isHistoricSyncInProgress = true;
    _lastHistoricSync = DateTime.now();
    
    try {
      LogConfig.logInfo('📚 Rafraîchissement historique...');
      
      final historicData = await _loadHistoricData();
      if (historicData != null) {
        _lastHistoricUpdate = DateTime.now();
        emit(state.copyWith(
          savedRoutes: historicData,
          isHistoricDataLoaded: true,
          lastCacheUpdate: _lastHistoricUpdate,
        ));
        LogConfig.logInfo('Historique mis à jour (${historicData.length} routes)');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur rafraîchissement historique: $e');
    } finally {
      _isHistoricSyncInProgress = false;
    }
  }

  /// Synchronisation optimisée lors d'ajout de route
  Future<void> _onRouteAddedSync(
    RouteAddedDataSync event,
    Emitter<AppDataState> emit,
  ) async {
    print('➕ Sync optimisée - Route ajoutée: ${event.routeName}');
  }

  /// Synchronisation optimisée lors de suppression de route
  Future<void> _onRouteDeletedSync(
    RouteDeletedDataSync event,
    Emitter<AppDataState> emit,
  ) async {
    print('Sync optimisée – Route supprimée : ${event.routeName}');

    // Éviter de lancer une deuxième sync si l’une est déjà en cours
    if (_isHistoricSyncInProgress) {
      LogConfig.logInfo('Sync déjà en cours pour suppression de route');
      return;
    }

    try {
      // On attend la fin des deux tâches AVANT de sortir du handler
      await Future.wait<void>([
        _performSafeHistoricSync(emit),
      ]);
    } catch (e, st) {
      // On capture l’erreur proprement ; on peut aussi émettre un état d’erreur ici
      LogConfig.logError('❌ Erreur sync suppression : $e\n$st');
      // Préserver isHistoricDataLoaded en cas d'erreur
      if (state.isHistoricDataLoaded) {
        emit(state.copyWith(
          lastError: 'Erreur de synchronisation: $e',
        ));
      }
    }
  }

  /// Synchronisation forcée avec nettoyage complet
  Future<void> _onForceDataSync(
    ForceDataSyncRequested event,
    Emitter<AppDataState> emit,
  ) async {
    LogConfig.logInfo('🔄 Synchronisation forcée des données');
    
    // Nettoyer tous les verrous et timestamps
    _isHistoricSyncInProgress = false;
    _isFullSyncInProgress = false;
    _lastHistoricSync = null;
    _lastCreditUpdate = null;
    _lastFullSync = null;
    
    // Forcer le rechargement complet en ignorant le cache
    _lastCacheUpdate = null;
    add(const AppDataPreloadRequested());
  }

  /// 🛡️ Sync sécurisée de l'historique
  Future<void> _performSafeHistoricSync(Emitter<AppDataState> emit) async {
    if (_isHistoricSyncInProgress) return;
    
    _isHistoricSyncInProgress = true;
    try {
      final historicData = await _loadHistoricData();
      if (historicData != null) {
        _lastHistoricUpdate = DateTime.now();
        emit(state.copyWith(
          savedRoutes: historicData,
          isHistoricDataLoaded: true,
          lastCacheUpdate: _lastHistoricUpdate,
        ));
        LogConfig.logInfo('Sync historique sécurisée terminée');
      }
    } finally {
      _isHistoricSyncInProgress = false;
    }
  }

  /// Vide le cache et remet à zéro
  Future<void> _onClearRequested(
    AppDataClearRequested event,
    Emitter<AppDataState> emit,
  ) async {
    LogConfig.logInfo('🗑️ Nettoyage du cache des données');
    
    // Nettoyer tous les timestamps et verrous
    _lastCacheUpdate = null;
    _lastHistoricUpdate = null;
    _lastCreditUpdate = null;
    _lastHistoricSync = null;
    _lastCreditSync = null;
    _lastFullSync = null;
    _isHistoricSyncInProgress = false;
    _isFullSyncInProgress = false;
    
    emit(const AppDataState());
  }

  /// Charge les données d'historique (inchangé)
  Future<List<SavedRoute>?> _loadHistoricData() async {
    try {
      LogConfig.logInfo('📚 Chargement de l\'historique...');
      return await _routesRepository.getUserRoutes();
    } catch (e) {
      LogConfig.logError('❌ Erreur chargement historique: $e');
      return null;
    }
  }

  /// Vérifie si le cache est encore valide
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiration;
  }

  /// Vérifie si l'état contient des données complètes
  bool _hasCompleteData() {
    return state.hasHistoricData && 
           state.isCreditDataLoaded;
  }

  /// Accesseur pour vérifier si les données sont prêtes
  bool get isDataReady => state.isDataLoaded && !state.isLoading;
}

/// Classe helper pour les résultats de crédits
class CreditDataResult {
  final UserCredits userCredits;
  final List<CreditPlan> creditPlans;
  final List<CreditTransaction> transactions;

  CreditDataResult({
    required this.userCredits,
    required this.creditPlans,
    required this.transactions,
  });
}

enum SyncType {
  historicOnly,
  full,
}