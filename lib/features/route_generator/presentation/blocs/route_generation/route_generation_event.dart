import 'package:equatable/equatable.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

abstract class RouteGenerationEvent extends Equatable {
  const RouteGenerationEvent();

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

  const RouteGenerationRequested(this.parameters);

  @override
  List<Object?> get props => [parameters];
}

/// Événement pour sauvegarder le parcours généré
class GeneratedRouteSaved extends RouteGenerationEvent {
  final String name;

  const GeneratedRouteSaved(this.name);

  @override
  List<Object?> get props => [name];
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
