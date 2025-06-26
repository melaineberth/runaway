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

/// Demande la suppression du cache
class AppDataClearRequested extends AppDataEvent {
  const AppDataClearRequested();
}
