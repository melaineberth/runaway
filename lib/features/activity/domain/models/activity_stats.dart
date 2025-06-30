import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import '../../../route_generator/domain/models/activity_type.dart';

/// Statistiques générales de l'utilisateur
class ActivityStats extends Equatable {
  final double totalDistanceKm;
  final int totalDurationMinutes;
  final int totalRoutes;
  final double averageSpeedKmh;
  final DateTime firstRouteDate;
  final DateTime lastRouteDate;

  const ActivityStats({
    required this.totalDistanceKm,
    required this.totalDurationMinutes,
    required this.totalRoutes,
    required this.averageSpeedKmh,
    required this.firstRouteDate,
    required this.lastRouteDate,
  });

  @override
  List<Object?> get props => [
    totalDistanceKm,
    totalDurationMinutes,
    totalRoutes,
    averageSpeedKmh,
    firstRouteDate,
    lastRouteDate,
  ];
}

/// Statistiques par type d'activité
class ActivityTypeStats extends Equatable {
  final ActivityType activityType;
  final double totalDistanceKm;
  final int totalDurationMinutes;
  final int totalRoutes;
  final double averageSpeedKmh;
  final double bestSpeedKmh;
  final double longestDistanceKm;
  final double totalElevationGain;
  final double maxElevationGain;

  const ActivityTypeStats({
    required this.activityType,
    required this.totalDistanceKm,
    required this.totalDurationMinutes,
    required this.totalRoutes,
    required this.averageSpeedKmh,
    required this.bestSpeedKmh,
    required this.longestDistanceKm,
    required this.totalElevationGain,
    required this.maxElevationGain,
  });

  @override
  List<Object?> get props => [
    activityType,
    totalDistanceKm,
    totalDurationMinutes,
    totalRoutes,
    averageSpeedKmh,
    bestSpeedKmh,
    longestDistanceKm,
    totalElevationGain,
    maxElevationGain,
  ];
}

/// Statistiques périodiques (hebdomadaire/mensuelle)
class PeriodStats extends Equatable {
  final DateTime period;
  final double distanceKm;
  final int durationMinutes;
  final int routeCount;
  final int elevation;

  const PeriodStats({
    required this.period,
    required this.distanceKm,
    required this.durationMinutes,
    required this.routeCount,
    required this.elevation,
  });

  factory PeriodStats.fromJson(Map<String, dynamic> json) {
    return PeriodStats(
      period: DateTime.parse(json['period']),
      distanceKm: (json['distance_km'] as num).toDouble(),
      durationMinutes: json['duration_minutes'] as int,
      routeCount: json['route_count'] as int,
      elevation: json['elevation'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period.toIso8601String(),
      'distance_km': distanceKm,
      'duration_minutes': durationMinutes,
      'route_count': routeCount,
      'elevation': elevation,
    };
  }

  @override
  List<Object?> get props => [period, distanceKm, durationMinutes, routeCount, elevation];
}

/// Objectif personnel
class PersonalGoal extends Equatable {
  final String id;
  final String title;
  final String description;
  final GoalType type;
  final double targetValue;
  final double currentValue;
  final DateTime createdAt;
  final DateTime? deadline;
  final bool isCompleted;
  final ActivityType? activityType;

  const PersonalGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.currentValue,
    required this.createdAt,
    this.deadline,
    required this.isCompleted,
    this.activityType,
  });

  double get progressPercentage => 
    targetValue > 0 ? (currentValue / targetValue * 100).clamp(0, 100) : 0;

  factory PersonalGoal.fromJson(Map<String, dynamic> json) {
    return PersonalGoal(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: GoalType.values.firstWhere((e) => e.name == json['type']),
      targetValue: (json['target_value'] as num).toDouble(),
      currentValue: (json['current_value'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      isCompleted: json['is_completed'] as bool,
      activityType: json['activity_type'] != null 
        ? ActivityType.values.firstWhere((e) => e.id == json['activity_type'])
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'target_value': targetValue,
      'current_value': currentValue,
      'created_at': createdAt.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'is_completed': isCompleted,
      'activity_type': activityType?.id,
    };
  }

  PersonalGoal copyWith({
    String? id,
    String? title,
    String? description,
    GoalType? type,
    double? targetValue,
    double? currentValue,
    DateTime? createdAt,
    DateTime? deadline,
    bool? isCompleted,
    ActivityType? activityType,
  }) {
    return PersonalGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
      activityType: activityType ?? this.activityType,
    );
  }

  @override
  List<Object?> get props => [
    id, title, description, type, targetValue, currentValue,
    createdAt, deadline, isCompleted, activityType,
  ];
}

/// Types d'objectifs
enum GoalType {
  distance('Distance mensuelle'),
  routes('Nombre de parcours'),
  speed('Vitesse moyenne'),
  elevation('Dénivelé total');

  const GoalType(this.label);
  final String label;
}

extension GoalL10n on GoalType {
  /// Renvoie la chaîne localisée pour *cette* valeur de enum.
  String goalLabel(BuildContext context) {
    final l10n = context.l10n;     // ou `content.l10n` dans ton widget
    switch (this) {
      case GoalType.distance:
        return l10n.goalTypeDistance;
      case GoalType.routes:
        return l10n.goalTypeRoutes;
      case GoalType.speed:
        return l10n.goalTypeSpeed;
      case GoalType.elevation:
        return l10n.goalTypeElevation;
    }
  }
}

/// Records personnels
class PersonalRecord extends Equatable {
  final String id;
  final RecordType type;
  final double value;
  final String unit;
  final DateTime achievedAt;
  final String routeId;
  final String routeName;
  final ActivityType activityType;

  const PersonalRecord({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.achievedAt,
    required this.routeId,
    required this.routeName,
    required this.activityType,
  });

  factory PersonalRecord.fromJson(Map<String, dynamic> json) {
    return PersonalRecord(
      id: json['id'],
      type: RecordType.values.firstWhere((e) => e.name == json['type']),
      value: (json['value'] as num).toDouble(),
      unit: json['unit'],
      achievedAt: DateTime.parse(json['achieved_at']),
      routeId: json['route_id'],
      routeName: json['route_name'],
      activityType: ActivityType.values.firstWhere((e) => e.id == json['activity_type']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'value': value,
      'unit': unit,
      'achieved_at': achievedAt.toIso8601String(),
      'route_id': routeId,
      'route_name': routeName,
      'activity_type': activityType.id,
    };
  }

  @override
  List<Object?> get props => [
    id, type, value, unit, achievedAt, routeId, routeName, activityType,
  ];
}

/// Types de records
enum RecordType {
  longestDistance('Plus longue distance'),
  fastestSpeed('Vitesse maximale'),
  highestElevation('Plus haut dénivelé'),
  longestDuration('Plus longue durée');

  const RecordType(this.label);
  final String label;
}