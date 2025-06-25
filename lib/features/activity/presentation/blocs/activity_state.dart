import 'package:equatable/equatable.dart';
import 'package:runaway/features/activity/data/repositories/activity_repository.dart';
import '../../domain/models/activity_stats.dart';
import '../../../route_generator/domain/models/activity_type.dart';

abstract class ActivityState extends Equatable {
  const ActivityState();

  @override
  List<Object?> get props => [];
}

class ActivityInitial extends ActivityState {}

class ActivityLoading extends ActivityState {}

class ActivityLoaded extends ActivityState {
  final ActivityStats generalStats;
  final List<ActivityTypeStats> typeStats;
  final List<PeriodStats> periodStats;
  final List<PersonalGoal> goals;
  final List<PersonalRecord> records;
  final PeriodType currentPeriod;
  final ActivityType? selectedActivityFilter;

  const ActivityLoaded({
    required this.generalStats,
    required this.typeStats,
    required this.periodStats,
    required this.goals,
    required this.records,
    required this.currentPeriod,
    this.selectedActivityFilter,
  });

  ActivityLoaded copyWith({
    ActivityStats? generalStats,
    List<ActivityTypeStats>? typeStats,
    List<PeriodStats>? periodStats,
    List<PersonalGoal>? goals,
    List<PersonalRecord>? records,
    PeriodType? currentPeriod,
    ActivityType? selectedActivityFilter,
  }) {
    return ActivityLoaded(
      generalStats: generalStats ?? this.generalStats,
      typeStats: typeStats ?? this.typeStats,
      periodStats: periodStats ?? this.periodStats,
      goals: goals ?? this.goals,
      records: records ?? this.records,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      selectedActivityFilter: selectedActivityFilter ?? this.selectedActivityFilter,
    );
  }

  @override
  List<Object?> get props => [
    generalStats,
    typeStats,
    periodStats,
    goals,
    records,
    currentPeriod,
    selectedActivityFilter,
  ];
}

class ActivityError extends ActivityState {
  final String message;

  const ActivityError(this.message);

  @override
  List<Object?> get props => [message];
}
