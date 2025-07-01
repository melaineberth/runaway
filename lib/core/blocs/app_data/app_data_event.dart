import 'package:equatable/equatable.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/features/activity/domain/models/activity_stats.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

abstract class AppDataEvent extends Equatable {
  const AppDataEvent();

  @override
  List<Object?> get props => [];
}

/// Demande le pré-chargement de toutes les données
class AppDataPreloadRequested extends AppDataEvent {
  const AppDataPreloadRequested();
}

/// Demande le rafraîchissement de toutes les données
class AppDataRefreshRequested extends AppDataEvent {
  const AppDataRefreshRequested();
}

/// Demande le rafraîchissement des données d'activité uniquement
class ActivityDataRefreshRequested extends AppDataEvent {
  const ActivityDataRefreshRequested();
}

/// Demande le rafraîchissement des données d'historique uniquement
class HistoricDataRefreshRequested extends AppDataEvent {
  const HistoricDataRefreshRequested();
}

/// 🆕 Événement déclenché automatiquement lors d'ajout de route
class RouteAddedDataSync extends AppDataEvent {
  final String routeId;
  final String routeName;

  const RouteAddedDataSync({
    required this.routeId,
    required this.routeName,
  });

  @override
  List<Object?> get props => [routeId, routeName];
}

/// 🆕 Événement déclenché automatiquement lors de suppression de route
class RouteDeletedDataSync extends AppDataEvent {
  final String routeId;
  final String routeName;

  const RouteDeletedDataSync({
    required this.routeId,
    required this.routeName,
  });

  @override
  List<Object?> get props => [routeId, routeName];
}

/// 🆕 Synchronisation forcée avec bypass du cache
class ForceDataSyncRequested extends AppDataEvent {
  const ForceDataSyncRequested();
}

/// Demande la suppression du cache
class AppDataClearRequested extends AppDataEvent {
  const AppDataClearRequested();
}

/// Ajout d'un objectif personnel
class PersonalGoalAddedToAppData extends AppDataEvent {
  final PersonalGoal goal;

  const PersonalGoalAddedToAppData(this.goal);

  @override
  List<Object?> get props => [goal];
}

/// Mise à jour d'un objectif personnel
class PersonalGoalUpdatedInAppData extends AppDataEvent {
  final PersonalGoal goal;

  const PersonalGoalUpdatedInAppData(this.goal);

  @override
  List<Object?> get props => [goal];
}

/// Suppression d'un objectif personnel
class PersonalGoalDeletedFromAppData extends AppDataEvent {
  final String goalId;

  const PersonalGoalDeletedFromAppData(this.goalId);

  @override
  List<Object?> get props => [goalId];
}

/// Réinitialisation de tous les objectifs
class PersonalGoalsResetInAppData extends AppDataEvent {
  const PersonalGoalsResetInAppData();
}

/// Sauvegarde d'un nouveau parcours
class SavedRouteAddedToAppData extends AppDataEvent {
  final String name;
  final RouteParameters parameters;
  final List<List<double>> coordinates;
  final double? actualDistance;
  final int? estimatedDuration;
  final MapboxMap map;

  const SavedRouteAddedToAppData({
    required this.name,
    required this.parameters,
    required this.coordinates,
    this.actualDistance,
    this.estimatedDuration,
    required this.map,
  });

  @override
  List<Object?> get props => [name, parameters, coordinates, actualDistance, estimatedDuration, map];
}

/// Suppression d'un parcours sauvegardé
class SavedRouteDeletedFromAppData extends AppDataEvent {
  final String routeId;

  const SavedRouteDeletedFromAppData(this.routeId);

  @override
  List<Object?> get props => [routeId];
}

/// Mise à jour des statistiques d'utilisation d'un parcours
class SavedRouteUsageUpdatedInAppData extends AppDataEvent {
  final String routeId;

  const SavedRouteUsageUpdatedInAppData(this.routeId);

  @override
  List<Object?> get props => [routeId];
}