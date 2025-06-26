import 'package:equatable/equatable.dart';
import 'package:runaway/features/activity/domain/models/activity_stats.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';

class AppDataState extends Equatable {
  final bool isLoading;
  final bool isDataLoaded;
  final String? lastError;
  final DateTime? lastCacheUpdate;

  // Données d'activité
  final ActivityStats? activityStats;
  final List<ActivityTypeStats>? activityTypeStats;
  final List<PeriodStats>? periodStats; 
  final List<PersonalGoal>? personalGoals;
  final List<PersonalRecord>? personalRecords;

  // Données d'historique
  final List<SavedRoute> savedRoutes;

  const AppDataState({
    this.isLoading = false,
    this.isDataLoaded = false,
    this.lastError,
    this.lastCacheUpdate,
    this.activityStats,
    this.activityTypeStats,
    this.periodStats,
    this.personalGoals,
    this.personalRecords,
    this.savedRoutes = const [],
  });

  AppDataState copyWith({
    bool? isLoading,
    bool? isDataLoaded,
    String? lastError,
    DateTime? lastCacheUpdate,
    ActivityStats? activityStats,
    List<ActivityTypeStats>? activityTypeStats,
    List<PeriodStats>? periodStats, 
    List<PersonalGoal>? personalGoals,
    List<PersonalRecord>? personalRecords,
    List<SavedRoute>? savedRoutes,
  }) {
    return AppDataState(
      isLoading: isLoading ?? this.isLoading,
      isDataLoaded: isDataLoaded ?? this.isDataLoaded,
      lastError: lastError,
      lastCacheUpdate: lastCacheUpdate ?? this.lastCacheUpdate,
      activityStats: activityStats ?? this.activityStats,
      activityTypeStats: activityTypeStats ?? this.activityTypeStats,
      periodStats: periodStats ?? this.periodStats,
      personalGoals: personalGoals ?? this.personalGoals,
      personalRecords: personalRecords ?? this.personalRecords,
      savedRoutes: savedRoutes ?? this.savedRoutes,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isDataLoaded,
    lastError,
    lastCacheUpdate,
    activityStats,
    activityTypeStats,
    periodStats,
    personalGoals,
    personalRecords,
    savedRoutes,
  ];

  /// Helpers pour vérifier l'état des données
  bool get hasActivityData => activityStats != null;
  bool get hasHistoricData => savedRoutes.isNotEmpty;
  bool get hasCompleteData => hasActivityData || hasHistoricData;

  /// Vérifie si le cache est encore valide (30 minutes)
  bool get isCacheValid {
    if (lastCacheUpdate == null) return false;
    return DateTime.now().difference(lastCacheUpdate!) <
        const Duration(minutes: 30);
  }

  /// Vérifie si les données sont prêtes à être utilisées
  bool get isDataReady => isDataLoaded && isCacheValid;
}
