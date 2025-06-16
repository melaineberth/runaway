import 'activity_type.dart';
import 'terrain_type.dart';
import 'urban_density.dart';

class RouteParameters {
  final ActivityType activityType;
  final TerrainType terrainType;
  final UrbanDensity urbanDensity;
  final double distanceKm;
  final double elevationGain;
  final double startLongitude;
  final double startLatitude;
  final DateTime? preferredStartTime;
  final bool isLoop; // Parcours en boucle ou aller simple
  final bool avoidTraffic;
  final bool preferScenic;

  const RouteParameters({
    required this.activityType,
    required this.terrainType,
    required this.urbanDensity,
    required this.distanceKm,
    required this.elevationGain,
    required this.startLongitude,
    required this.startLatitude,
    this.preferredStartTime,
    this.isLoop = true,
    this.avoidTraffic = true,
    this.preferScenic = true,
  });

  RouteParameters copyWith({
    ActivityType? activityType,
    TerrainType? terrainType,
    UrbanDensity? urbanDensity,
    double? distanceKm,
    double? elevationGain,
    double? startLongitude,
    double? startLatitude,
    DateTime? preferredStartTime,
    bool? isLoop,
    bool? avoidTraffic,
    bool? preferScenic,
  }) {
    return RouteParameters(
      activityType: activityType ?? this.activityType,
      terrainType: terrainType ?? this.terrainType,
      urbanDensity: urbanDensity ?? this.urbanDensity,
      distanceKm: distanceKm ?? this.distanceKm,
      elevationGain: elevationGain ?? this.elevationGain,
      startLongitude: startLongitude ?? this.startLongitude,
      startLatitude: startLatitude ?? this.startLatitude,
      preferredStartTime: preferredStartTime ?? this.preferredStartTime,
      isLoop: isLoop ?? this.isLoop,
      avoidTraffic: avoidTraffic ?? this.avoidTraffic,
      preferScenic: preferScenic ?? this.preferScenic,
    );
  }

  Map<String, dynamic> toJson() => {
    'activity_type': activityType.id,
    'terrain_type': terrainType.id,
    'urban_density': urbanDensity.id,
    'distance_km': distanceKm,
    'elevation_gain': elevationGain,
    'start_longitude': startLongitude,
    'start_latitude': startLatitude,
    'preferred_start_time': preferredStartTime?.toIso8601String(),
    'is_loop': isLoop,
    'avoid_traffic': avoidTraffic,
    'prefer_scenic': preferScenic,
  };

  // Calculer la durée estimée
  Duration get estimatedDuration {
    final baseTime = (distanceKm / activityType.defaultSpeed) * 60; // en minutes
    final elevationPenalty = (elevationGain / 100) * 5; // 5 min par 100m de dénivelé
    return Duration(minutes: (baseTime + elevationPenalty).round());
  }

  // Vérifier si les paramètres sont valides
  bool get isValid {
    return distanceKm >= activityType.minDistance &&
           distanceKm <= activityType.maxDistance &&
           elevationGain >= 0;
  }

  // Obtenir des suggestions basées sur le niveau
  static RouteParameters beginnerPreset({
    required double startLongitude,
    required double startLatitude,
  }) {
    return RouteParameters(
      activityType: ActivityType.running,
      terrainType: TerrainType.flat,
      urbanDensity: UrbanDensity.urban,
      distanceKm: 5.0,
      elevationGain: 0.0,
      startLongitude: startLongitude,
      startLatitude: startLatitude,
    );
  }

  static RouteParameters intermediatePreset({
    required double startLongitude,
    required double startLatitude,
  }) {
    return RouteParameters(
      activityType: ActivityType.running,
      terrainType: TerrainType.mixed,
      urbanDensity: UrbanDensity.mixed,
      distanceKm: 10.0,
      elevationGain: 100.0,
      startLongitude: startLongitude,
      startLatitude: startLatitude,
    );
  }

  static RouteParameters advancedPreset({
    required double startLongitude,
    required double startLatitude,
  }) {
    return RouteParameters(
      activityType: ActivityType.running,
      terrainType: TerrainType.hilly,
      urbanDensity: UrbanDensity.nature,
      distanceKm: 21.0,
      elevationGain: 300.0,
      startLongitude: startLongitude,
      startLatitude: startLatitude,
    );
  }
}