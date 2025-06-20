import 'package:equatable/equatable.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
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

class ElevationGainChanged extends RouteParametersEvent {
  final double elevationGain;

  const ElevationGainChanged(this.elevationGain);

  @override
  List<Object?> get props => [elevationGain];
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