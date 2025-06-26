// lib/core/blocs/app_data/app_data_bloc.dart

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
  
  // Cache avec expiration (30 minutes par défaut)
  static const Duration _cacheExpiration = Duration(minutes: 30);
  DateTime? _lastCacheUpdate;

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
  }

  /// Pré-charge toutes les données nécessaires
  Future<void> _onPreloadRequested(
    AppDataPreloadRequested event,
    Emitter<AppDataState> emit,
  ) async {
    print('🚀 Début pré-chargement des données...');
    
    // Vérifier si les données sont encore valides dans le cache
    if (_isCacheValid() && _hasCompleteData()) {
      print('✅ Données en cache valides, pas de rechargement nécessaire');
      return;
    }

    emit(state.copyWith(
      isLoading: true,
      lastError: null,
    ));

    try {
      // Charger les données en parallèle pour optimiser les performances
      final futures = <Future>[
        _loadActivityData(),
        _loadHistoricData(),
      ];

      final results = await Future.wait(futures, eagerError: false);
      
      final activityData = results[0] as ActivityDataResult?;
      final historicData = results[1] as List<SavedRoute>?;

      // Mettre à jour le cache
      _lastCacheUpdate = DateTime.now();

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
    }
  }

  /// Charge les données d'activité
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

  /// Charge les données d'historique
  Future<List<SavedRoute>?> _loadHistoricData() async {
    try {
      print('📚 Chargement de l\'historique...');
      return await _routesRepository.getUserRoutes();
    } catch (e) {
      print('❌ Erreur chargement historique: $e');
      return null;
    }
  }

  /// Rafraîchit toutes les données
  Future<void> _onRefreshRequested(
    AppDataRefreshRequested event,
    Emitter<AppDataState> emit,
  ) async {
    print('🔄 Rafraîchissement des données demandé');
    _lastCacheUpdate = null; // Forcer le rechargement
    add(const AppDataPreloadRequested());
  }

  /// Rafraîchit uniquement les données d'activité
  Future<void> _onActivityDataRefresh(
    ActivityDataRefreshRequested event,
    Emitter<AppDataState> emit,
  ) async {
    try {
      print('📊 Rafraîchissement données activité...');
      
      final activityData = await _loadActivityData();
      if (activityData != null) {
        emit(state.copyWith(
          activityStats: activityData.generalStats,
          activityTypeStats: activityData.typeStats,
          periodStats: activityData.periodStats,
          personalGoals: activityData.goals,
          personalRecords: activityData.records,
          lastCacheUpdate: DateTime.now(),
        ));
      }
    } catch (e) {
      print('❌ Erreur rafraîchissement activité: $e');
    }
  }

  /// Rafraîchit uniquement les données d'historique
  Future<void> _onHistoricDataRefresh(
    HistoricDataRefreshRequested event,
    Emitter<AppDataState> emit,
  ) async {
    try {
      print('📚 Rafraîchissement historique...');
      
      final historicData = await _loadHistoricData();
      if (historicData != null) {
        print('✅ ${historicData.length} parcours chargés, émission du nouvel état');
        
        emit(state.copyWith(
          savedRoutes: historicData,
          lastCacheUpdate: DateTime.now(),
        ));
        
        print('✅ AppDataState mis à jour avec ${historicData.length} parcours');
      } else {
        print('❌ Aucune donnée historique reçue');
      }
    } catch (e) {
      print('❌ Erreur rafraîchissement historique: $e');
    }
  }

  /// Vide le cache et remet à zéro
  Future<void> _onClearRequested(
    AppDataClearRequested event,
    Emitter<AppDataState> emit,
  ) async {
    print('🗑️ Nettoyage du cache des données');
    _lastCacheUpdate = null;
    emit(const AppDataState());
  }

  /// Vérifie si le cache est encore valide
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiration;
  }

  /// Vérifie si on a des données complètes en cache
  bool _hasCompleteData() {
    return state.activityStats != null && 
           state.savedRoutes.isNotEmpty;
  }

  /// Getters pour accéder facilement aux données
  bool get isDataReady => state.isDataLoaded && _isCacheValid();
  bool get hasActivityData => state.activityStats != null;
  bool get hasHistoricData => state.savedRoutes.isNotEmpty;
}

/// Structure pour retourner les données d'activité
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