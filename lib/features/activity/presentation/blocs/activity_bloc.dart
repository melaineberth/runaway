import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/activity_repository.dart';
import '../../../route_generator/data/repositories/routes_repository.dart';
import '../../../route_generator/domain/models/saved_route.dart';
import 'activity_event.dart';
import 'activity_state.dart';

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  final ActivityRepository _activityRepository;
  final RoutesRepository _routesRepository;

  ActivityBloc({
    required ActivityRepository activityRepository,
    required RoutesRepository routesRepository,
  })  : _activityRepository = activityRepository,
        _routesRepository = routesRepository,
        super(ActivityInitial()) {
    on<ActivityStatsRequested>(_onStatsRequested);
    on<ActivityPeriodChanged>(_onPeriodChanged);
    on<ActivityFilterChanged>(_onFilterChanged);
    on<PersonalGoalAdded>(_onGoalAdded);
    on<PersonalGoalUpdated>(_onGoalUpdated);
    on<PersonalGoalDeleted>(_onGoalDeleted);
  }

  Future<void> _onStatsRequested(
    ActivityStatsRequested event,
    Emitter<ActivityState> emit,
  ) async {
    emit(ActivityLoading());

    try {
      // Charger tous les parcours de l'utilisateur
      final routes = await _routesRepository.getUserRoutes();
      
      // Calculer les statistiques
      final generalStats = await _activityRepository.getActivityStats(routes);
      final typeStats = await _activityRepository.getActivityTypeStats(routes);
      
      // Charger les objectifs et records
      final goals = await _activityRepository.getPersonalGoals();
      final records = await _activityRepository.getPersonalRecords();
      
      // Mettre à jour les objectifs avec les parcours actuels
      await _activityRepository.updateGoalsProgress(routes);
      final updatedGoals = await _activityRepository.getPersonalGoals();
      
      // Calculer les stats périodiques (par défaut mensuel)
      final periodStats = await _activityRepository.getPeriodStats(
        routes, 
        PeriodType.monthly
      );

      emit(ActivityLoaded(
        generalStats: generalStats,
        typeStats: typeStats,
        periodStats: periodStats,
        goals: updatedGoals,
        records: records,
        currentPeriod: PeriodType.monthly,
      ));
    } catch (e) {
      emit(ActivityError('Erreur lors du chargement des statistiques: $e'));
    }
  }

  Future<void> _onPeriodChanged(
    ActivityPeriodChanged event,
    Emitter<ActivityState> emit,
  ) async {
    if (state is ActivityLoaded) {
      final currentState = state as ActivityLoaded;
      
      try {
        final routes = await _routesRepository.getUserRoutes();
        final periodStats = await _activityRepository.getPeriodStats(
          routes, 
          event.period
        );

        emit(currentState.copyWith(
          periodStats: periodStats,
          currentPeriod: event.period,
        ));
      } catch (e) {
        emit(ActivityError('Erreur lors du changement de période: $e'));
      }
    }
  }

  Future<void> _onFilterChanged(
    ActivityFilterChanged event,
    Emitter<ActivityState> emit,
  ) async {
    if (state is ActivityLoaded) {
      final currentState = state as ActivityLoaded;
      emit(currentState.copyWith(selectedActivityFilter: event.activityType));
    }
  }

  Future<void> _onGoalAdded(
    PersonalGoalAdded event,
    Emitter<ActivityState> emit,
  ) async {
    if (state is ActivityLoaded) {
      final currentState = state as ActivityLoaded;
      
      try {
        await _activityRepository.savePersonalGoal(event.goal);
        final goals = await _activityRepository.getPersonalGoals();

        emit(currentState.copyWith(goals: goals));
      } catch (e) {
        emit(ActivityError('Erreur lors de l\'ajout de l\'objectif: $e'));
      }
    }
  }

  Future<void> _onGoalUpdated(
    PersonalGoalUpdated event,
    Emitter<ActivityState> emit,
  ) async {
    if (state is ActivityLoaded) {
      final currentState = state as ActivityLoaded;
      
      try {
        await _activityRepository.savePersonalGoal(event.goal);
        final goals = await _activityRepository.getPersonalGoals();

        emit(currentState.copyWith(goals: goals));
      } catch (e) {
        emit(ActivityError('Erreur lors de la mise à jour de l\'objectif: $e'));
      }
    }
  }

  Future<void> _onGoalDeleted(
    PersonalGoalDeleted event,
    Emitter<ActivityState> emit,
  ) async {
    if (state is ActivityLoaded) {
      final currentState = state as ActivityLoaded;
      
      try {
        await _activityRepository.deletePersonalGoal(event.goalId);
        final goals = await _activityRepository.getPersonalGoals();

        emit(currentState.copyWith(goals: goals));
      } catch (e) {
        emit(ActivityError('Erreur lors de la suppression de l\'objectif: $e'));
      }
    }
  }
}