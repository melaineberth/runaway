import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/services/screenshot_service.dart';
import 'package:runaway/features/activity/data/repositories/activity_repository.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/data/services/iap_service.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/features/home/data/services/map_state_service.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/features/activity/domain/models/activity_stats.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'app_data_event.dart';
import 'app_data_state.dart';

/// BLoC principal pour orchestrer le pré-chargement et la gestion des données de l'application
class AppDataBloc extends Bloc<AppDataEvent, AppDataState> {
  final ActivityRepository _activityRepository;
  final RoutesRepository _routesRepository;
  final MapStateService _mapStateService; // 🆕 Injection du service
  final CreditsRepository _creditsRepository; // 🆕 Ajout du repository crédits
  
  // Cache avec expiration optimisé
  static const Duration _cacheExpiration = Duration(minutes: 30);
  DateTime? _lastCacheUpdate;
  DateTime? _lastActivityUpdate;
  DateTime? _lastHistoricUpdate;
  DateTime? _lastCreditUpdate; // 🆕
  
  // 🛡️ Protection contre les synchronisations multiples
  bool _isActivitySyncInProgress = false;
  bool _isHistoricSyncInProgress = false;
  bool _isCreditSyncInProgress = false; // 🆕
  bool _isFullSyncInProgress = false;
  
  // 🕒 Timing pour éviter les appels trop fréquents
  static const Duration _minSyncInterval = Duration(seconds: 5);
  DateTime? _lastActivitySync;
  DateTime? _lastHistoricSync;
  DateTime? _lastCreditSync; // 🆕
  DateTime? _lastFullSync;

  AppDataBloc({
    required ActivityRepository activityRepository,
    required RoutesRepository routesRepository,
    required MapStateService mapStateService,
    required CreditsRepository creditsRepository, // 🆕 Paramètre requis
  })  : _activityRepository = activityRepository,
        _routesRepository = routesRepository,
        _mapStateService = mapStateService,
        _creditsRepository = creditsRepository, // 🆕
        super(const AppDataState()) {
    on<AppDataPreloadRequested>(_onPreloadRequested);
    on<AppDataRefreshRequested>(_onRefreshRequested);
    on<AppDataClearRequested>(_onClearRequested);
    on<ActivityDataRefreshRequested>(_onActivityDataRefresh);
    on<HistoricDataRefreshRequested>(_onHistoricDataRefresh);
    on<RouteAddedDataSync>(_onRouteAddedSync);
    on<RouteDeletedDataSync>(_onRouteDeletedSync);
    on<ForceDataSyncRequested>(_onForceDataSync);
    on<SavedRouteRenamedInAppData>(_onRouteRenamed);

    // Handlers d'objectifs
    on<PersonalGoalAddedToAppData>(_onGoalAdded);
    on<PersonalGoalUpdatedInAppData>(_onGoalUpdated);
    on<PersonalGoalDeletedFromAppData>(_onGoalDeleted);
    on<PersonalGoalsResetInAppData>(_onGoalsReset);

    // Handlers pour les parcours
    on<SavedRouteAddedToAppData>(_onRouteAdded);
    on<SavedRouteDeletedFromAppData>(_onRouteDeleted);
    on<SavedRouteUsageUpdatedInAppData>(_onRouteUsageUpdated);

    // 🆕 Handlers pour les crédits
    on<CreditDataRefreshRequested>(_onCreditDataRefresh);
    on<CreditDataPreloadRequested>(_onCreditDataPreload);
    on<CreditUsageCompletedInAppData>(_onCreditUsageCompleted);
    on<CreditPurchaseCompletedInAppData>(_onCreditPurchaseCompleted);
    on<CreditBalanceUpdatedInAppData>(_onCreditBalanceUpdated);
    on<CreditDataClearRequested>(_onCreditDataClear);
  }

  /// Chargement initial des données de crédits
  Future<void> _onCreditDataPreload(
    CreditDataPreloadRequested event,
    Emitter<AppDataState> emit,
  ) async {
    if (_isCreditSyncInProgress) {
      print('⚠️ Sync crédits déjà en cours, abandon');
      return;
    }

    _isCreditSyncInProgress = true;
    print('🚀 Pré-chargement des données de crédits...');

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

      print('✅ Données de crédits pré-chargées: ${userCredits.availableCredits} crédits, ${creditPlans.length} plans, ${transactions.length} transactions');

    } catch (e) {
      print('❌ Erreur pré-chargement crédits: $e');
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
    print('💳 Synchronisation après utilisation de ${event.amount} crédits');
    
    try {
      // Rafraîchir les données sans loading pour une UX fluide
      await _refreshCreditData(emit, showLoading: false);
      
      print('✅ Synchronisation post-utilisation réussie');
    } catch (e) {
      print('❌ Erreur synchronisation post-utilisation: $e');
      // Ne pas émettre d'erreur pour ne pas perturber l'UX
    }
  }

  /// Synchronisation après achat de crédits
  Future<void> _onCreditPurchaseCompleted(
    CreditPurchaseCompletedInAppData event,
    Emitter<AppDataState> emit,
  ) async {
    print('💰 Synchronisation après achat de ${event.creditsAdded} crédits');
    
    try {
      // Rafraîchir les données sans loading
      await _refreshCreditData(emit, showLoading: false);
      
      print('✅ Synchronisation post-achat réussie');
    } catch (e) {
      print('❌ Erreur synchronisation post-achat: $e');
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
      print('⚡ Mise à jour optimiste du solde: ${event.newBalance} crédits');
    } else {
      print('✅ Confirmation du solde: ${event.newBalance} crédits');
    }
  }

  /// Nettoyage des données de crédits
  Future<void> _onCreditDataClear(
    CreditDataClearRequested event,
    Emitter<AppDataState> emit,
  ) async {
    print('🗑️ Nettoyage des données de crédits');
    
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
      print('⏱️ Sync crédits trop récente, abandon');
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
      print('💳 Chargement des données de crédits...');
      
      final futures = await Future.wait([
        _creditsRepository.getUserCredits(),
        _creditsRepository.getCreditPlans(),
        _creditsRepository.getCreditTransactions(limit: 50),
      ]);

      final userCredits = futures[0] as UserCredits;
      final creditPlans = futures[1] as List<CreditPlan>;
      final transactions = futures[2] as List<CreditTransaction>;

      // 🆕 Pré-charger les produits IAP pour les achats
      try {
        await IAPService.preloadProducts(creditPlans);
        print('✅ Produits IAP pré-chargés pour ${creditPlans.length} plans');
      } catch (e) {
        print('⚠️ Erreur pré-chargement IAP: $e');
        // Ne pas faire échouer le chargement pour autant
      }

      return CreditDataResult(
        userCredits: userCredits,
        creditPlans: creditPlans,
        transactions: transactions,
      );
    } catch (e) {
      print('❌ Erreur chargement données crédits: $e');
      return null;
    }
  }

  Future<void> _onRouteAdded(
    SavedRouteAddedToAppData event,
    Emitter<AppDataState> emit,
  ) async {
    print('🚗 Sauvegarde de parcours via AppDataBloc: ${event.name}');

    // 0️⃣ → signale le début
    emit(state.copyWith(isSavingRoute: true));
    
    try {
      // 1. 📸 Capturer le screenshot de la carte
      String? screenshotUrl;
      try {
        print('📸 Capture du screenshot...');
        screenshotUrl = await ScreenshotService.captureAndUploadMapSnapshot(
          liveMap: event.map,
          routeCoords: event.coordinates,
          routeId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'temp_user',
          mapStateService: _mapStateService,
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
      
      print('✅ Parcours sauvegardé avec succès: ${savedRoute.name}');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du parcours: $e');
      emit(state.copyWith(
        lastError: 'Erreur lors de la sauvegarde du parcours: $e',
      ));
    }
  }

  Future<void> _onRouteDeleted(
    SavedRouteDeletedFromAppData event,
    Emitter<AppDataState> emit,
  ) async {
    print('🗑️ Suppression de parcours via AppDataBloc: ${event.routeId}');
    
    try {
      // Supprimer le parcours
      await _routesRepository.deleteRoute(event.routeId);
      
      // Recharger les données d'historique
      await _refreshHistoricData(emit, showLoading: false);
      
      print('✅ Parcours supprimé avec succès');
    } catch (e) {
      print('❌ Erreur lors de la suppression du parcours: $e');
      emit(state.copyWith(
        lastError: 'Erreur lors de la suppression du parcours: $e',
      ));
    }
  }

  Future<void> _onRouteUsageUpdated(
    SavedRouteUsageUpdatedInAppData event,
    Emitter<AppDataState> emit,
  ) async {
    print('📊 Mise à jour statistiques d\'utilisation: ${event.routeId}');
    
    try {
      // Mettre à jour les statistiques d'utilisation
      await _routesRepository.updateRouteUsage(event.routeId);
      
      // Recharger les données d'historique (sans loading)
      await _refreshHistoricData(emit, showLoading: false);
      
      print('✅ Statistiques d\'utilisation mises à jour');
    } catch (e) {
      print('❌ Erreur lors de la mise à jour des statistiques: $e');
      emit(state.copyWith(
        lastError: 'Erreur lors de la mise à jour des statistiques: $e',
      ));
    }
  }

  Future<void> _onRouteRenamed(
    SavedRouteRenamedInAppData event,
    Emitter<AppDataState> emit,
  ) async {
    print('✏️ Renommage de parcours via AppDataBloc: ${event.routeId} -> ${event.newName}');
    
    try {
      // Renommer le parcours via le repository
      await _routesRepository.renameRoute(event.routeId, event.newName);
      
      // Recharger les données d'historique pour mettre à jour l'interface
      await _refreshHistoricData(emit, showLoading: false);
      
      print('✅ Parcours renommé avec succès');
    } catch (e) {
      print('❌ Erreur lors du renommage du parcours: $e');
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
          isLoading: false,
          lastError: null,
        ));
        
        // Aussi rafraîchir les stats d'activité car elles dépendent des parcours
        await _refreshActivityData(emit, showLoading: false);
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
    if (_isFullSyncInProgress) {
      print('⚠️ Sync complète déjà en cours, abandon');
      return;
    }

    _isFullSyncInProgress = true;
    
    // Vérifie si le cache est encore valide pour éviter un rechargement
    if (_isCacheValid() && _hasCompleteData()) {
      print('📦 Cache valide, pas de rechargement nécessaire');
      _isFullSyncInProgress = false;
      return;
    }

    print('🚀 Pré-chargement complet des données...');
    emit(state.copyWith(isLoading: true));

    try {
      // Charger les données en parallèle
      final futures = await Future.wait([
        _loadActivityData(),
        _loadHistoricData(),
        _loadCreditData(), // 🆕 Ajout des crédits
      ]);
      
      final activityData = futures[0] as ActivityDataResult?;
      final historicData = futures[1] as List<SavedRoute>?;
      final creditData = futures[2] as CreditDataResult?; // 🆕

      // Mettre à jour le cache
      final now = DateTime.now();
      _lastCacheUpdate = now;
      _lastActivityUpdate = now;
      _lastHistoricUpdate = now;
      _lastCreditUpdate = now;
      _lastFullSync = now;

      emit(state.copyWith(
        // Activité
        activityStats: activityData?.generalStats,
        activityTypeStats: activityData?.typeStats ?? [],
        periodStats: activityData?.periodStats ?? [],
        personalGoals: activityData?.goals ?? [],
        personalRecords: activityData?.records ?? [],
        
        // Historique
        savedRoutes: historicData ?? [],
        
        // 🆕 Crédits
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

      print('✅ Pré-chargement complet terminé');
      print('📊 Activité: ${activityData != null ? "✅" : "❌"}');
      print('📚 Historique: ${historicData?.length ?? 0} parcours');
      print('💳 Crédits: ${creditData?.userCredits.availableCredits ?? 0} disponibles');
      
    } catch (e) {
      print('❌ Erreur lors du pré-chargement: $e');
      emit(state.copyWith(
        isLoading: false,
        lastError: 'Erreur lors du chargement: ${e.toString()}',
      ));
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
    print('🔄 Rafraîchissement complet...');

    emit(state.copyWith(isLoading: true));

    try {
      // Rafraîchir toutes les données
      await Future.wait([
        _refreshActivityData(emit, showLoading: false),
        _refreshHistoricData(emit, showLoading: false),
        _refreshCreditData(emit, showLoading: false), // 🆕
      ]);

      _lastCacheUpdate = DateTime.now();
      
      emit(state.copyWith(
        isLoading: false,
        lastError: null,
        lastUpdate: DateTime.now(),
      ));

      print('✅ Rafraîchissement complet terminé');

    } catch (e) {
      print('❌ Erreur rafraîchissement: $e');
      emit(state.copyWith(
        isLoading: false,
        lastError: 'Erreur lors du rafraîchissement: $e',
      ));
    } finally {
      _isFullSyncInProgress = false;
    }
  }

  /// 🆕 Rafraîchissement optimisé des données d'activité
  Future<void> _onActivityDataRefresh(
    ActivityDataRefreshRequested event,
    Emitter<AppDataState> emit,
  ) async {
    // 🛡️ Protection contre les appels multiples
    if (_isActivitySyncInProgress) {
      print('⚠️ Sync activité déjà en cours, ignorée');
      return;
    }
    
    if (_lastActivitySync != null && 
        DateTime.now().difference(_lastActivitySync!) < _minSyncInterval) {
      print('⚠️ Sync activité trop récente, ignorée');
      return;
    }

    _isActivitySyncInProgress = true;
    _lastActivitySync = DateTime.now();
    
    try {
      print('📊 Rafraîchissement données activité...');
      
      final activityData = await _loadActivityData();
      if (activityData != null) {
        _lastActivityUpdate = DateTime.now();
        emit(state.copyWith(
          activityStats: activityData.generalStats,
          activityTypeStats: activityData.typeStats,
          periodStats: activityData.periodStats,
          personalGoals: activityData.goals,
          personalRecords: activityData.records,
          lastCacheUpdate: _lastActivityUpdate,
        ));
        print('✅ Données activité mises à jour');
      }
    } catch (e) {
      print('❌ Erreur rafraîchissement activité: $e');
    } finally {
      _isActivitySyncInProgress = false;
    }
  }

  /// 🆕 Rafraîchissement optimisé des données d'historique
  Future<void> _onHistoricDataRefresh(
    HistoricDataRefreshRequested event,
    Emitter<AppDataState> emit,
  ) async {
    // 🛡️ Protection contre les appels multiples
    if (_isHistoricSyncInProgress) {
      print('⚠️ Sync historique déjà en cours, ignorée');
      return;
    }
    
    if (_lastHistoricSync != null && 
        DateTime.now().difference(_lastHistoricSync!) < _minSyncInterval) {
      print('⚠️ Sync historique trop récente, ignorée');
      return;
    }

    _isHistoricSyncInProgress = true;
    _lastHistoricSync = DateTime.now();
    
    try {
      print('📚 Rafraîchissement historique...');
      
      final historicData = await _loadHistoricData();
      if (historicData != null) {
        _lastHistoricUpdate = DateTime.now();
        emit(state.copyWith(
          savedRoutes: historicData,
          lastCacheUpdate: _lastHistoricUpdate,
        ));
        print('✅ Historique mis à jour (${historicData.length} routes)');
      }
    } catch (e) {
      print('❌ Erreur rafraîchissement historique: $e');
    } finally {
      _isHistoricSyncInProgress = false;
    }
  }

  /// 🆕 Synchronisation optimisée lors d'ajout de route
  Future<void> _onRouteAddedSync(
    RouteAddedDataSync event,
    Emitter<AppDataState> emit,
  ) async {
    print('➕ Sync optimisée - Route ajoutée: ${event.routeName}');
    
    if (!_isActivitySyncInProgress) {
      await _onActivityDataRefresh(const ActivityDataRefreshRequested(), emit);
    } else {
      print('⚠️ Sync activité déjà en cours pour ajout route');
    }
  }

  /// 🆕 Synchronisation optimisée lors de suppression de route
  Future<void> _onRouteDeletedSync(
    RouteDeletedDataSync event,
    Emitter<AppDataState> emit,
  ) async {
    print('Sync optimisée – Route supprimée : ${event.routeName}');

    // Éviter de lancer une deuxième sync si l’une est déjà en cours
    if (_isHistoricSyncInProgress || _isActivitySyncInProgress) {
      print('⚠️ Sync déjà en cours pour suppression de route');
      return;
    }

    try {
      // On attend la fin des deux tâches AVANT de sortir du handler
      await Future.wait<void>([
        _performSafeHistoricSync(emit),
        _performSafeActivitySync(emit),
      ]);
    } catch (e, st) {
      // On capture l’erreur proprement ; on peut aussi émettre un état d’erreur ici
      print('❌ Erreur sync suppression : $e\n$st');
      // emit(ErrorState(message: e.toString()));
    }
  }

  /// 🆕 Synchronisation forcée avec nettoyage complet
  Future<void> _onForceDataSync(
    ForceDataSyncRequested event,
    Emitter<AppDataState> emit,
  ) async {
    print('🔄 Synchronisation forcée des données');
    
    // Nettoyer tous les verrous et timestamps
    _isActivitySyncInProgress = false;
    _isHistoricSyncInProgress = false;
    _isFullSyncInProgress = false;
    _lastActivitySync = null;
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
          lastCacheUpdate: _lastHistoricUpdate,
        ));
        print('✅ Sync historique sécurisée terminée');
      }
    } finally {
      _isHistoricSyncInProgress = false;
    }
  }

  /// 🛡️ Sync sécurisée des activités
  Future<void> _performSafeActivitySync(Emitter<AppDataState> emit) async {
    if (_isActivitySyncInProgress) return;
    
    _isActivitySyncInProgress = true;
    try {
      final activityData = await _loadActivityData();
      if (activityData != null) {
        _lastActivityUpdate = DateTime.now();
        emit(state.copyWith(
          activityStats: activityData.generalStats,
          activityTypeStats: activityData.typeStats,
          periodStats: activityData.periodStats,
          personalGoals: activityData.goals,
          personalRecords: activityData.records,
          lastCacheUpdate: _lastActivityUpdate,
        ));
        print('✅ Sync activité sécurisée terminée');
      }
    } finally {
      _isActivitySyncInProgress = false;
    }
  }

  /// Vide le cache et remet à zéro
  Future<void> _onClearRequested(
    AppDataClearRequested event,
    Emitter<AppDataState> emit,
  ) async {
    print('🗑️ Nettoyage du cache des données');
    
    // Nettoyer tous les timestamps et verrous
    _lastCacheUpdate = null;
    _lastActivityUpdate = null;
    _lastHistoricUpdate = null;
    _lastCreditUpdate = null; // 🆕
    _lastActivitySync = null;
    _lastHistoricSync = null;
    _lastCreditSync = null; // 🆕
    _lastFullSync = null;
    _isActivitySyncInProgress = false;
    _isHistoricSyncInProgress = false;
    _isFullSyncInProgress = false;
    
    emit(const AppDataState());
  }

  /// Charge les données d'activité (inchangé)
  Future<ActivityDataResult?> _loadActivityData() async {
    try {
      print('📊 Chargement des données d\'activité...');
      
      // Charger tous les parcours pour calculer les stats
      final routes = await _routesRepository.getUserRoutes();
      
      // Calculer les statistiques en parallèle
      final statsFutures = await Future.wait([
        _activityRepository.getActivityStats(routes),
        _activityRepository.getActivityTypeStats(routes),
        _activityRepository.getPeriodStats(routes, PeriodType.monthly),
        _activityRepository.getPersonalGoals(),
        _activityRepository.getPersonalRecords(),
      ]);

      return ActivityDataResult(
        generalStats: statsFutures[0] as ActivityStats,
        typeStats: statsFutures[1] as List<ActivityTypeStats>,
        periodStats: statsFutures[2] as List<PeriodStats>,
        goals: statsFutures[3] as List<PersonalGoal>,
        records: statsFutures[4] as List<PersonalRecord>,
      );
      
    } catch (e) {
      print('❌ Erreur chargement données activité: $e');
      return null;
    }
  }

  /// Charge les données d'historique (inchangé)
  Future<List<SavedRoute>?> _loadHistoricData() async {
    try {
      print('📚 Chargement de l\'historique...');
      return await _routesRepository.getUserRoutes();
    } catch (e) {
      print('❌ Erreur chargement historique: $e');
      return null;
    }
  }

  Future<void> _onGoalAdded(
    PersonalGoalAddedToAppData event,
    Emitter<AppDataState> emit,
  ) async {
    print('🎯 Ajout d\'objectif via AppDataBloc: ${event.goal.title}');
    
    try {      
      // Recharger les données d'activité pour mettre à jour l'interface
      await _refreshActivityData(emit, showLoading: false);
      
      print('✅ Objectif ajouté avec succès');
    } catch (e) {
      print('❌ Erreur lors de l\'ajout de l\'objectif: $e');
      emit(state.copyWith(
        lastError: 'Erreur lors de l\'ajout de l\'objectif: $e',
      ));
    }
  }

  Future<void> _onGoalUpdated(
    PersonalGoalUpdatedInAppData event,
    Emitter<AppDataState> emit,
  ) async {
    print('🎯 Mise à jour d\'objectif via AppDataBloc: ${event.goal.title}');
    
    try {      
      // Recharger les données d'activité
      await _refreshActivityData(emit, showLoading: false);
      
      print('✅ Objectif mis à jour avec succès');
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de l\'objectif: $e');
      emit(state.copyWith(
        lastError: 'Erreur lors de la mise à jour de l\'objectif: $e',
      ));
    }
  }

  Future<void> _onGoalDeleted(
    PersonalGoalDeletedFromAppData event,
    Emitter<AppDataState> emit,
  ) async {
    print('🎯 Suppression d\'objectif via AppDataBloc: ${event.goalId}');
    
    try {
      // Supprimer l'objectif
      await _activityRepository.deletePersonalGoal(event.goalId);
      
      // Recharger les données d'activité
      await _refreshActivityData(emit, showLoading: false);
      
      print('✅ Objectif supprimé avec succès');
    } catch (e) {
      print('❌ Erreur lors de la suppression de l\'objectif: $e');
      emit(state.copyWith(
        lastError: 'Erreur lors de la suppression de l\'objectif: $e',
      ));
    }
  }

  Future<void> _onGoalsReset(
    PersonalGoalsResetInAppData event,
    Emitter<AppDataState> emit,
  ) async {
    print('🎯 Réinitialisation de tous les objectifs via AppDataBloc');
    
    try {
      // Récupérer tous les objectifs existants
      final existingGoals = await _activityRepository.getPersonalGoals();
      
      // Supprimer chaque objectif
      for (final goal in existingGoals) {
        await _activityRepository.deletePersonalGoal(goal.id);
      }
      
      // Recharger les données d'activité
      await _refreshActivityData(emit, showLoading: false);
      
      print('✅ Tous les objectifs réinitialisés avec succès');
    } catch (e) {
      print('❌ Erreur lors de la réinitialisation des objectifs: $e');
      emit(state.copyWith(
        lastError: 'Erreur lors de la réinitialisation des objectifs: $e',
      ));
    }
  }

  Future<void> _refreshActivityData(Emitter<AppDataState> emit, {bool showLoading = true}) async {
    if (showLoading) {
      emit(state.copyWith(isLoading: true));
    }

    try {
      final activityData = await _loadActivityData();
      
      if (activityData != null) {
        _lastActivityUpdate = DateTime.now();
        emit(state.copyWith(
          activityStats: activityData.generalStats,
          activityTypeStats: activityData.typeStats,
          periodStats: activityData.periodStats,
          personalGoals: activityData.goals,
          personalRecords: activityData.records,
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

  /// Vérifie si le cache est encore valide
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiration;
  }

  /// Vérifie si l'état contient des données complètes
  bool _hasCompleteData() {
    return state.hasHistoricData && 
           state.activityStats != null && 
           state.isCreditDataLoaded; // 🆕
  }

  /// Accesseur pour vérifier si les données sont prêtes
  bool get isDataReady => state.isDataLoaded && !state.isLoading;
}

/// 🆕 Classe helper pour les résultats de crédits
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

/// Classe helper pour les résultats d'activité (inchangée)
class ActivityDataResult {
  final ActivityStats generalStats;
  final List<ActivityTypeStats> typeStats;
  final List<PeriodStats> periodStats;
  final List<PersonalGoal> goals;
  final List<PersonalRecord> records;

  ActivityDataResult({
    required this.generalStats,
    required this.typeStats,
    required this.periodStats,
    required this.goals,
    required this.records,
  });
}

enum SyncType {
  activityOnly,
  historicOnly,
  full,
}