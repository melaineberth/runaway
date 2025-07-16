import 'package:equatable/equatable.dart';
import 'package:runaway/features/route_generator/data/validation/route_parameters_validator.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';

abstract class RouteParametersEvent extends Equatable {
  const RouteParametersEvent();

  @override
  List<Object?> get props => [];
}

class ActivityTypeChanged extends RouteParametersEvent {
  final ActivityType activityType;

  const ActivityTypeChanged(this.activityType);

  @override
  List<Object?> get props => [activityType];
}

class TerrainTypeChanged extends RouteParametersEvent {
  final TerrainType terrainType;

  const TerrainTypeChanged(this.terrainType);

  @override
  List<Object?> get props => [terrainType];
}

class UrbanDensityChanged extends RouteParametersEvent {
  final UrbanDensity urbanDensity;

  const UrbanDensityChanged(this.urbanDensity);

  @override
  List<Object?> get props => [urbanDensity];
}

class DistanceChanged extends RouteParametersEvent {
  final double distanceKm;

  const DistanceChanged(this.distanceKm);

  @override
  List<Object?> get props => [distanceKm];
}

class SearchRadiusChanged extends RouteParametersEvent {
  final double radiusInMeters;

  const SearchRadiusChanged(this.radiusInMeters);

  @override
  List<Object?> get props => [radiusInMeters];
}

class ElevationRangeChanged extends RouteParametersEvent {
  final ElevationRange elevationRange;

  const ElevationRangeChanged(this.elevationRange);

  @override
  List<Object> get props => [elevationRange];
}

class DifficultyChanged extends RouteParametersEvent {
  final DifficultyLevel difficulty;

  const DifficultyChanged(this.difficulty);

  @override
  List<Object> get props => [difficulty];
}

class MaxInclineChanged extends RouteParametersEvent {
  final double maxInclinePercent;

  const MaxInclineChanged(this.maxInclinePercent);

  @override
  List<Object> get props => [maxInclinePercent];
}

class PreferredWaypointsChanged extends RouteParametersEvent {
  final int waypoints;

  const PreferredWaypointsChanged(this.waypoints);

  @override
  List<Object> get props => [waypoints];
}

class AvoidHighwaysToggled extends RouteParametersEvent {
  final bool avoidHighways;

  const AvoidHighwaysToggled(this.avoidHighways);

  @override
  List<Object> get props => [avoidHighways];
}

class PrioritizeParksToggled extends RouteParametersEvent {
  final bool prioritizeParks;

  const PrioritizeParksToggled(this.prioritizeParks);

  @override
  List<Object> get props => [prioritizeParks];
}

class SurfacePreferenceChanged extends RouteParametersEvent {
  final double surfacePreference;

  const SurfacePreferenceChanged(this.surfacePreference);

  @override
  List<Object> get props => [surfacePreference];
}

// 🆕 Événement pour appliquer un preset de difficulté
class DifficultyPresetApplied extends RouteParametersEvent {
  final DifficultyLevel difficulty;
  final double startLongitude;
  final double startLatitude;

  const DifficultyPresetApplied({
    required this.difficulty,
    required this.startLongitude,
    required this.startLatitude,
  });

  @override
  List<Object> get props => [difficulty, startLongitude, startLatitude];
}

class StartLocationUpdated extends RouteParametersEvent {
  final double longitude;
  final double latitude;

  const StartLocationUpdated({
    required this.longitude,
    required this.latitude,
  });

  @override
  List<Object?> get props => [longitude, latitude];
}

class PresetApplied extends RouteParametersEvent {
  final String presetType;

  const PresetApplied(this.presetType);

  @override
  List<Object?> get props => [presetType];
}

class FavoriteAdded extends RouteParametersEvent {
  final String name;

  const FavoriteAdded(this.name);

  @override
  List<Object?> get props => [name];
}

class FavoriteRemoved extends RouteParametersEvent {
  final int index;

  const FavoriteRemoved(this.index);

  @override
  List<Object?> get props => [index];
}

class FavoriteApplied extends RouteParametersEvent {
  final int index;

  const FavoriteApplied(this.index);

  @override
  List<Object?> get props => [index];
}

class RouteParametersUndoRequested extends RouteParametersEvent {}

class RouteParametersRedoRequested extends RouteParametersEvent {}

class LoopToggled extends RouteParametersEvent {
  final bool isLoop;

  const LoopToggled(this.isLoop);

  @override
  List<Object?> get props => [isLoop];
}

class AvoidTrafficToggled extends RouteParametersEvent {
  final bool avoidTraffic;

  const AvoidTrafficToggled(this.avoidTraffic);

  @override
  List<Object?> get props => [avoidTraffic];
}

class PreferScenicToggled extends RouteParametersEvent {
  final bool preferScenic;

  const PreferScenicToggled(this.preferScenic);

  @override
  List<Object?> get props => [preferScenic];
}

/// Demande une validation complète avec détails des erreurs et avertissements
class ValidationRequested extends RouteParametersEvent {
  const ValidationRequested();
}

/// Demande une validation rapide (juste les erreurs critiques)
class QuickValidationRequested extends RouteParametersEvent {
  const QuickValidationRequested();
}

/// Événement interne : paramètres validés avec résultat
class ParametersValidated extends RouteParametersEvent {
  final RouteParameters parameters;
  final ValidationResult validationResult;

  const ParametersValidated({
    required this.parameters,
    required this.validationResult,
  });

  @override
  List<Object?> get props => [parameters, validationResult];
}

/// Demande d'aide contextuelle pour un champ
class ValidationHelpRequested extends RouteParametersEvent {
  final String field;

  const ValidationHelpRequested(this.field);

  @override
  List<Object?> get props => [field];
}

/// Validation en temps réel activée/désactivée
class RealTimeValidationToggled extends RouteParametersEvent {
  final bool enabled;

  const RealTimeValidationToggled(this.enabled);

  @override
  List<Object?> get props => [enabled];
}
