import 'package:equatable/equatable.dart';

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
