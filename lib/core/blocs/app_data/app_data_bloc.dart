import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/features/activity/data/repositories/activity_repository.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/features/activity/domain/models/activity_stats.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'app_data_event.dart';
import 'app_data_state.dart';

/// BLoC principal pour orchestrer le pré-chargement et la gestion des données de l'application
class AppDataBloc extends Bloc<AppDataEvent, AppDataState> {
  final ActivityRepository _activityRepository;
  final RoutesRepository _routesRepository;
  
  // Cache avec expiration optimisé
  static const Duration _cacheExpiration = Duration(minutes: 30);
  DateTime? _lastCacheUpdate;
  DateTime? _lastActivityUpdate;
  DateTime? _lastHistoricUpdate;
  
  // 🛡️ Protection contre les synchronisations multiples
  bool _isActivitySyncInProgress = false;
  bool _isHistoricSyncInProgress = false;
  bool _isFullSyncInProgress = false;
  
  // 🕒 Timing pour éviter les appels trop fréquents
  static const Duration _minSyncInterval = Duration(seconds: 5);
  DateTime? _lastActivitySync;
  DateTime? _lastHistoricSync;
  DateTime? _lastFullSync;

  AppDataBloc({
    required ActivityRepository activityRepository,
    required RoutesRepository routesRepository,
  })  : _activityRepository = activityRepository,
        _routesRepository = routesRepository,
        super(const AppDataState()) {
    on<AppDataPreloadRequested>(_onPreloadRequested);
    on<AppDataRefreshRequested>(_onRefreshRequested);
    on<AppDataClearRequested>(_onClearRequested);
    on<ActivityDataRefreshRequested>(_onActivityDataRefresh);
    on<HistoricDataRefreshRequested>(_onHistoricDataRefresh);
    
    // 🆕 Événements de synchronisation optimisés
    on<RouteAddedDataSync>(_onRouteAddedSync);
    on<RouteDeletedDataSync>(_onRouteDeletedSync);
    on<ForceDataSyncRequested>(_onForceDataSync);
  }

  /// Pré-charge toutes les données nécessaires
  Future<void> _onPreloadRequested(
    AppDataPreloadRequested event,
    Emitter<AppDataState> emit,
  ) async {
    print('🚀 Début pré-chargement des données...');
    
    // Éviter les appels multiples pendant un preload
    if (_isFullSyncInProgress) {
      print('⏳ Preload déjà en cours, ignoré');
      return;
    }
    
    // Vérifier si les données sont encore valides dans le cache
    if (_isCacheValid() && _hasCompleteData()) {
      print('✅ Données en cache valides, pas de rechargement nécessaire');
      return;
    }

    _isFullSyncInProgress = true;
    
    emit(state.copyWith(
      isLoading: true,
      lastError: null,
    ));

    try {
      // Charger les données en parallèle
      final futures = <Future>[
        _loadActivityData(),
        _loadHistoricData(),
      ];

      final results = await Future.wait(futures, eagerError: false);
      
      final activityData = results[0] as ActivityDataResult?;
      final historicData = results[1] as List<SavedRoute>?;

      // Mettre à jour le cache
      final now = DateTime.now();
      _lastCacheUpdate = now;
      _lastActivityUpdate = now;
      _lastHistoricUpdate = now;
      _lastFullSync = now;

      emit(state.copyWith(
        isLoading: false,
        isDataLoaded: true,
        // Données d'activité
        activityStats: activityData?.generalStats,
        activityTypeStats: activityData?.typeStats,
        periodStats: activityData?.periodStats,
        personalGoals: activityData?.goals,
        personalRecords: activityData?.records,
        // Données d'historique
        savedRoutes: historicData ?? [],
        lastCacheUpdate: _lastCacheUpdate,
      ));

      print('✅ Pré-chargement terminé avec succès');
      
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
    // 🛡️ Protection contre les appels trop fréquents
    if (_isFullSyncInProgress) {
      print('⚠️ Sync complète déjà en cours, ignorée');
      return;
    }
    
    if (_lastFullSync != null && 
        DateTime.now().difference(_lastFullSync!) < _minSyncInterval) {
      print('⚠️ Sync complète trop récente, ignorée');
      return;
    }
    
    print('🔄 Rafraîchissement des données demandé');
    _lastCacheUpdate = null; // Forcer le rechargement
    add(const AppDataPreloadRequested());
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
    
    // Pour un ajout, rafraîchir SEULEMENT les statistiques d'activité
    // L'historique sera déjà à jour via RouteGenerationBloc
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
    _lastActivitySync = null;
    _lastHistoricSync = null;
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

  /// Vérifie si le cache est encore valide
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiration;
  }

  /// Vérifie si l'état contient des données complètes
  bool _hasCompleteData() {
    return state.hasHistoricData && state.activityStats != null;
  }

  /// Accesseur pour vérifier si les données sont prêtes
  bool get isDataReady => state.isDataLoaded && !state.isLoading;
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