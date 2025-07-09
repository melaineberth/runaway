import 'package:equatable/equatable.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

abstract class RouteGenerationEvent extends Equatable {
  const RouteGenerationEvent();

  @override
  List<Object?> get props => [];
}

/// 🆕 Événement pour nettoyer complètement l'état et préparer une nouvelle génération
class RouteStateReset extends RouteGenerationEvent {
  const RouteStateReset();

  @override
  List<Object?> get props => [];
}

/// Événement pour analyser la zone et récupérer les POIs
class ZoneAnalysisRequested extends RouteGenerationEvent {
  final double latitude;
  final double longitude;
  final double radiusInMeters;

  const ZoneAnalysisRequested({
    required this.latitude,
    required this.longitude,
    required this.radiusInMeters,
  });

  @override
  List<Object?> get props => [latitude, longitude, radiusInMeters];
}

/// Événement pour générer un parcours avec les paramètres
class RouteGenerationRequested extends RouteGenerationEvent {
  final RouteParameters parameters;
  final MapboxMap? mapboxMap;
  final bool bypassCreditCheck; // 🆕 NOUVEAU PARAMÈTRE

  const RouteGenerationRequested(
    this.parameters, {
    this.mapboxMap,
    this.bypassCreditCheck = false, // 🆕 Par défaut false pour la compatibilité
  });

  @override
  List<Object?> get props => [parameters, mapboxMap, bypassCreditCheck]; // 🆕 Ajouter dans props
}

/// 🆕 Sauvegarde de parcours avec capture de screenshot optionnelle
class GeneratedRouteSaved extends RouteGenerationEvent {
  final String name;
  final MapboxMap map;

  const GeneratedRouteSaved(
    this.name, {
    required this.map, // 🆕 Paramètre optionnel
  });

  @override
  List<Object?> get props => [name, map];
}

/// Événement pour charger un parcours sauvegardé
class SavedRouteLoaded extends RouteGenerationEvent {
  final String routeId;

  const SavedRouteLoaded(this.routeId);

  @override
  List<Object?> get props => [routeId];
}

/// Événement pour effacer l'analyse de zone
class ZoneAnalysisCleared extends RouteGenerationEvent {}

/// Événement pour supprimer un parcours sauvegardé
class SavedRouteDeleted extends RouteGenerationEvent {
  final String routeId;

  const SavedRouteDeleted(this.routeId);

  @override
  List<Object?> get props => [routeId];
}

/// Événement pour demander la liste des parcours sauvegardés
class SavedRoutesRequested extends RouteGenerationEvent {
  const SavedRoutesRequested();
}

/// Événement pour mettre à jour les statistiques d'utilisation d'un parcours
class RouteUsageUpdated extends RouteGenerationEvent {
  final String routeId;

  const RouteUsageUpdated(this.routeId);

  @override
  List<Object?> get props => [routeId];
}

/// Événement pour synchroniser les parcours en attente
class SyncPendingRoutesRequested extends RouteGenerationEvent {
  const SyncPendingRoutesRequested();
}

/// Événement pour filtrer les parcours par critères
class RoutesFilterRequested extends RouteGenerationEvent {
  final String? activityType;
  final double? minDistance;
  final double? maxDistance;
  final String? searchQuery;

  const RoutesFilterRequested({
    this.activityType,
    this.minDistance,
    this.maxDistance,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [activityType, minDistance, maxDistance, searchQuery];
}
