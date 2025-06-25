import 'package:equatable/equatable.dart';
import 'package:runaway/features/activity/data/repositories/activity_repository.dart';
import '../../domain/models/activity_stats.dart';
import '../../../route_generator/domain/models/activity_type.dart';

abstract class ActivityEvent extends Equatable {
  const ActivityEvent();

  @override
  List<Object?> get props => [];
}

class ActivityStatsRequested extends ActivityEvent {}

class ActivityPeriodChanged extends ActivityEvent {
  final PeriodType period;

  const ActivityPeriodChanged(this.period);

  @override
  List<Object?> get props => [period];
}

class ActivityFilterChanged extends ActivityEvent {
  final ActivityType? activityType;

  const ActivityFilterChanged(this.activityType);

  @override
  List<Object?> get props => [activityType];
}

class PersonalGoalAdded extends ActivityEvent {
  final PersonalGoal goal;

  const PersonalGoalAdded(this.goal);

  @override
  List<Object?> get props => [goal];
}

class PersonalGoalUpdated extends ActivityEvent {
  final PersonalGoal goal;

  const PersonalGoalUpdated(this.goal);

  @override
  List<Object?> get props => [goal];
}

class PersonalGoalDeleted extends ActivityEvent {
  final String goalId;

  const PersonalGoalDeleted(this.goalId);

  @override
  List<Object?> get props => [goalId];
}