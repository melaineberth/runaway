import 'package:equatable/equatable.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

abstract class AppDataEvent extends Equatable {
  const AppDataEvent();

  @override
  List<Object?> get props => [];
}

// ===== ÉVÉNEMENTS GÉNÉRAUX =====

/// Demande le pré-chargement de toutes les données
class AppDataPreloadRequested extends AppDataEvent {
  const AppDataPreloadRequested();
}

/// Demande le rafraîchissement de toutes les données
class AppDataRefreshRequested extends AppDataEvent {
  const AppDataRefreshRequested();
}

/// Demande la suppression du cache
class AppDataClearRequested extends AppDataEvent {
  const AppDataClearRequested();
}

/// 🆕 Synchronisation forcée avec bypass du cache
class ForceDataSyncRequested extends AppDataEvent {
  const ForceDataSyncRequested();
}

// ===== ÉVÉNEMENTS HISTORIQUE =====

/// Demande le rafraîchissement des données d'historique uniquement
class HistoricDataRefreshRequested extends AppDataEvent {
  const HistoricDataRefreshRequested();
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

/// Renommage d'un parcours sauvegardé
class SavedRouteRenamedInAppData extends AppDataEvent {
  final String routeId;
  final String newName;

  const SavedRouteRenamedInAppData({
    required this.routeId,
    required this.newName,
  });

  @override
  List<Object?> get props => [routeId, newName];
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

// ===== 🆕 ÉVÉNEMENTS CRÉDITS =====

/// Demande le rafraîchissement des données de crédits uniquement
class CreditDataRefreshRequested extends AppDataEvent {
  const CreditDataRefreshRequested();
}

/// Demande le chargement initial des crédits (plans + solde + transactions)
class CreditDataPreloadRequested extends AppDataEvent {
  const CreditDataPreloadRequested();
}

/// Synchronisation après utilisation de crédits
class CreditUsageCompletedInAppData extends AppDataEvent {
  final int amount;
  final String reason;
  final String? routeGenerationId;
  final String transactionId;

  const CreditUsageCompletedInAppData({
    required this.amount,
    required this.reason,
    this.routeGenerationId,
    required this.transactionId,
  });

  @override
  List<Object?> get props => [amount, reason, routeGenerationId, transactionId];
}

/// Synchronisation après achat de crédits
class CreditPurchaseCompletedInAppData extends AppDataEvent {
  final String planId;
  final String paymentIntentId;
  final int creditsAdded;

  const CreditPurchaseCompletedInAppData({
    required this.planId,
    required this.paymentIntentId,
    required this.creditsAdded,
  });

  @override
  List<Object?> get props => [planId, paymentIntentId, creditsAdded];
}

/// Mise à jour locale immédiate du solde de crédits (optimistic update)
class CreditBalanceUpdatedInAppData extends AppDataEvent {
  final int newBalance;
  final bool isOptimistic; // true = mise à jour optimiste, false = confirmée

  const CreditBalanceUpdatedInAppData({
    required this.newBalance,
    this.isOptimistic = false,
  });

  @override
  List<Object?> get props => [newBalance, isOptimistic];
}

/// Reset des données de crédits lors de la déconnexion
class CreditDataClearRequested extends AppDataEvent {
  const CreditDataClearRequested();
}