import 'activity_type.dart';
import 'terrain_type.dart';
import 'urban_density.dart';

enum SurfaceType {
  asphalt('asphalt', 'Asphalte', 0.9),
  mixed('mixed', 'Mixte', 0.5),
  natural('natural', 'Chemins', 0.1);

  const SurfaceType(this.id, this.title, this.value);
  final String id;
  final String title;
  final double value;

  static SurfaceType fromValue(double value) {
    if (value >= 0.7) return SurfaceType.asphalt;
    if (value >= 0.3) return SurfaceType.mixed;
    return SurfaceType.natural;
  }
}

/// Plage de dénivelé pour un contrôle plus précis
class ElevationRange {
  final double min;
  final double max;

  const ElevationRange({
    required this.min,
    required this.max,
  });

  ElevationRange copyWith({
    double? min,
    double? max,
  }) {
    return ElevationRange(
      min: min ?? this.min,
      max: max ?? this.max,
    );
  }

  Map<String, dynamic> toJson() => {
    'min': min,
    'max': max,
  };

  factory ElevationRange.fromJson(Map<String, dynamic> json) {
    return ElevationRange(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
    );
  }

  @override
  String toString() => '${min.toInt()}-${max.toInt()}m';
}

/// Niveau de difficulté pour l'algorithme de génération
enum DifficultyLevel {
  easy('easy', 'Facile', 1),
  moderate('moderate', 'Modéré', 2),
  hard('hard', 'Difficile', 3),
  expert('expert', 'Expert', 4);

  const DifficultyLevel(this.id, this.title, this.level);

  final String id;
  final String title;
  final int level;
}

class RouteParameters {
  final ActivityType activityType;
  final TerrainType terrainType;
  final UrbanDensity urbanDensity;
  final double distanceKm;
  
  // 🆕 Plage de dénivelé au lieu d'une valeur fixe
  final ElevationRange elevationRange;
  
  // 🆕 Nouveaux paramètres pour une génération plus précise
  final DifficultyLevel difficulty;
  final double maxInclinePercent; // Pente maximale acceptée (en %)
  final int preferredWaypoints; // Nombre de points d'intérêt souhaités
  final bool avoidHighways; // Éviter les routes principales
  final bool prioritizeParks; // Privilégier les parcs et espaces verts
  final double surfacePreference; // 0-1: asphalte vs chemins naturels
  
  final double startLongitude;
  final double startLatitude;
  final DateTime? preferredStartTime;
  final bool isLoop;
  final bool avoidTraffic;
  final bool preferScenic;

  const RouteParameters({
    required this.activityType,
    required this.terrainType,
    required this.urbanDensity,
    required this.distanceKm,
    required this.elevationRange,
    this.difficulty = DifficultyLevel.moderate,
    this.maxInclinePercent = 12.0,
    this.preferredWaypoints = 3,
    this.avoidHighways = true,
    this.prioritizeParks = false,
    this.surfacePreference = 0.5,
    required this.startLongitude,
    required this.startLatitude,
    this.preferredStartTime,
    this.isLoop = true,
    this.avoidTraffic = true,
    this.preferScenic = true,
  });

  // Getter de compatibilité pour l'ancien elevationGain
  double get elevationGain => elevationRange.max;

  RouteParameters copyWith({
    ActivityType? activityType,
    TerrainType? terrainType,
    UrbanDensity? urbanDensity,
    double? distanceKm,
    ElevationRange? elevationRange,
    DifficultyLevel? difficulty,
    double? maxInclinePercent,
    int? preferredWaypoints,
    bool? avoidHighways,
    bool? prioritizeParks,
    double? surfacePreference,
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
      elevationRange: elevationRange ?? this.elevationRange,
      difficulty: difficulty ?? this.difficulty,
      maxInclinePercent: maxInclinePercent ?? this.maxInclinePercent,
      preferredWaypoints: preferredWaypoints ?? this.preferredWaypoints,
      avoidHighways: avoidHighways ?? this.avoidHighways,
      prioritizeParks: prioritizeParks ?? this.prioritizeParks,
      surfacePreference: surfacePreference ?? this.surfacePreference,
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
    'elevation_range': elevationRange.toJson(),
    'difficulty': difficulty.id,
    'max_incline_percent': maxInclinePercent,
    'preferred_waypoints': preferredWaypoints,
    'avoid_highways': avoidHighways,
    'prioritize_parks': prioritizeParks,
    'surface_preference': surfacePreference,
    'start_longitude': startLongitude,
    'start_latitude': startLatitude,
    'preferred_start_time': preferredStartTime?.toIso8601String(),
    'is_loop': isLoop,
    'avoid_traffic': avoidTraffic,
    'prefer_scenic': preferScenic,
  };

  factory RouteParameters.fromJson(Map<String, dynamic> json) {
    return RouteParameters(
      activityType: _parseActivityType(json['activity_type'] as String),
      terrainType: _parseTerrainType(json['terrain_type'] as String),
      urbanDensity: _parseUrbanDensity(json['urban_density'] as String),
      distanceKm: (json['distance_km'] as num).toDouble(),
      elevationRange: json['elevation_range'] != null 
          ? ElevationRange.fromJson(json['elevation_range'] as Map<String, dynamic>)
          : ElevationRange(min: 0, max: (json['elevation_gain'] as num?)?.toDouble() ?? 0), // Migration
      difficulty: _parseDifficulty(json['difficulty'] as String?),
      maxInclinePercent: (json['max_incline_percent'] as num?)?.toDouble() ?? 12.0,
      preferredWaypoints: json['preferred_waypoints'] as int? ?? 3,
      avoidHighways: json['avoid_highways'] as bool? ?? true,
      prioritizeParks: json['prioritize_parks'] as bool? ?? false,
      surfacePreference: (json['surface_preference'] as num?)?.toDouble() ?? 0.5,
      startLongitude: (json['start_longitude'] as num).toDouble(),
      startLatitude: (json['start_latitude'] as num).toDouble(),
      preferredStartTime: json['preferred_start_time'] != null 
          ? DateTime.parse(json['preferred_start_time'] as String)
          : null,
      isLoop: json['is_loop'] as bool? ?? true,
      avoidTraffic: json['avoid_traffic'] as bool? ?? true,
      preferScenic: json['prefer_scenic'] as bool? ?? true,
    );
  }

  // Parsing helpers
  static ActivityType _parseActivityType(String type) {
    return ActivityType.values.firstWhere(
      (e) => e.id == type,
      orElse: () => ActivityType.running,
    );
  }

  static TerrainType _parseTerrainType(String type) {
    return TerrainType.values.firstWhere(
      (e) => e.id == type,
      orElse: () => TerrainType.mixed,
    );
  }

  static UrbanDensity _parseUrbanDensity(String density) {
    return UrbanDensity.values.firstWhere(
      (e) => e.id == density,
      orElse: () => UrbanDensity.mixed,
    );
  }

  static DifficultyLevel _parseDifficulty(String? difficulty) {
    if (difficulty == null) return DifficultyLevel.moderate;
    return DifficultyLevel.values.firstWhere(
      (e) => e.id == difficulty,
      orElse: () => DifficultyLevel.moderate,
    );
  }

  // Calculer la durée estimée avec plus de précision
  Duration get estimatedDuration {
    final baseSpeed = activityType.defaultSpeed;
    
    // Ajustement selon la difficulté
    final difficultyFactor = switch (difficulty) {
      DifficultyLevel.easy => 1.2,
      DifficultyLevel.moderate => 1.0,
      DifficultyLevel.hard => 0.8,
      DifficultyLevel.expert => 0.6,
    };
    
    final adjustedSpeed = baseSpeed * difficultyFactor;
    final baseTime = (distanceKm / adjustedSpeed) * 60; // en minutes
    
    // Pénalité pour le dénivelé (plus sophistiquée)
    final avgElevation = (elevationRange.min + elevationRange.max) / 2;
    final elevationPenalty = (avgElevation / 100) * 3; // 3 min par 100m moyen
    
    // Pénalité terrain
    final terrainPenalty = switch (terrainType) {
      TerrainType.flat => 0,
      TerrainType.mixed => baseTime * 0.1,
      TerrainType.hilly => baseTime * 0.2,
    };
    
    return Duration(minutes: (baseTime + elevationPenalty + terrainPenalty).round());
  }

  // Validation améliorée
  bool get isValid {
    return distanceKm >= activityType.minDistance &&
           distanceKm <= activityType.maxDistance &&
           elevationRange.min >= 0 &&
           elevationRange.max >= elevationRange.min &&
           maxInclinePercent > 0 &&
           maxInclinePercent <= 25 &&
           preferredWaypoints >= 0 &&
           preferredWaypoints <= 10 &&
           surfacePreference >= 0 &&
           surfacePreference <= 1;
  }

  // Presets améliorés
  static RouteParameters beginnerPreset({
    required double startLongitude,
    required double startLatitude,
  }) {
    return RouteParameters(
      activityType: ActivityType.running,
      terrainType: TerrainType.flat,
      urbanDensity: UrbanDensity.urban,
      distanceKm: 3.0,
      elevationRange: const ElevationRange(min: 0, max: 50),
      difficulty: DifficultyLevel.easy,
      maxInclinePercent: 5.0,
      preferredWaypoints: 2,
      avoidHighways: true,
      prioritizeParks: true,
      surfacePreference: 0.8, // Préférence asphalte
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
      distanceKm: 8.0,
      elevationRange: const ElevationRange(min: 50, max: 200),
      difficulty: DifficultyLevel.moderate,
      maxInclinePercent: 10.0,
      preferredWaypoints: 4,
      avoidHighways: true,
      prioritizeParks: false,
      surfacePreference: 0.6,
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
      distanceKm: 15.0,
      elevationRange: const ElevationRange(min: 200, max: 500),
      difficulty: DifficultyLevel.hard,
      maxInclinePercent: 15.0,
      preferredWaypoints: 6,
      avoidHighways: true,
      prioritizeParks: false,
      surfacePreference: 0.3, // Préférence chemins naturels
      startLongitude: startLongitude,
      startLatitude: startLatitude,
    );
  }
}