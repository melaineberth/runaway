import 'package:equatable/equatable.dart';
import 'package:runaway/features/route_generator/data/validation/route_parameters_validator.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

import '../../../route_generator/domain/models/activity_type.dart';
import '../../../route_generator/domain/models/terrain_type.dart';
import '../../../route_generator/domain/models/urban_density.dart';

class RouteParametersState extends Equatable {
  final RouteParameters parameters;
  final List<RouteParameters> history;
  final int historyIndex;
  final List<RouteParameters> favorites;
  final String? errorMessage;
  final ValidationResult? validationResult;

  const RouteParametersState({
    required this.parameters,
    this.history = const [],
    this.historyIndex = -1,
    this.favorites = const [],
    this.errorMessage,
    this.validationResult,
  });

  bool get canUndo => historyIndex > 0;
  bool get canRedo => historyIndex < history.length - 1;
  bool get isValid => validationResult?.isValid ?? RouteParametersValidator.isQuickValid(parameters);

  RouteParametersState copyWith({
    RouteParameters? parameters,
    List<RouteParameters>? history,
    int? historyIndex,
    List<RouteParameters>? favorites,
    String? errorMessage,
    ValidationResult? validationResult,
  }) {
    return RouteParametersState(
      parameters: parameters ?? this.parameters,
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
      favorites: favorites ?? this.favorites,
      errorMessage: errorMessage,
      validationResult: validationResult ?? this.validationResult,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parameters': parameters.toJson(),
      'favorites': favorites.map((f) => f.toJson()).toList(),
    };
  }

  factory RouteParametersState.fromJson(Map<String, dynamic> json) {
    // Reconstruction des paramètres et favoris depuis JSON
    // Note: startLongitude et startLatitude seront mis à jour au démarrage
    final parameters = _parametersFromJson(json['parameters']);
    final favorites = (json['favorites'] as List?)
        ?.map((f) => _parametersFromJson(f))
        .toList() ?? [];

    return RouteParametersState(
      parameters: parameters,
      favorites: favorites,
      history: [parameters],
      historyIndex: 0,
    );
  }

  static RouteParameters _parametersFromJson(Map<String, dynamic> json) {
    // 🆕 Support pour les nouveaux paramètres avec fallback sur les anciens
    ElevationRange? elevationRange;
    
    if (json['elevation_range'] != null) {
      elevationRange = ElevationRange.fromJson(json['elevation_range'] as Map<String, dynamic>);
    } 

    return RouteParameters(
      activityType: ActivityType.values.firstWhere(
        (a) => a.id == json['activity_type'],
        orElse: () => ActivityType.running,
      ),
      terrainType: TerrainType.values.firstWhere(
        (t) => t.id == json['terrain_type'],
        orElse: () => TerrainType.mixed,
      ),
      urbanDensity: UrbanDensity.values.firstWhere(
        (u) => u.id == json['urban_density'],
        orElse: () => UrbanDensity.mixed,
      ),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 5.0,
      elevationRange: elevationRange!,
      // 🆕 Nouveaux paramètres avec valeurs par défaut
      difficulty: DifficultyLevel.values.firstWhere(
        (d) => d.id == json['difficulty'],
        orElse: () => DifficultyLevel.moderate,
      ),
      maxInclinePercent: (json['max_incline_percent'] as num?)?.toDouble() ?? 12.0,
      preferredWaypoints: json['preferred_waypoints'] as int? ?? 3,
      avoidHighways: json['avoid_highways'] as bool? ?? true,
      prioritizeParks: json['prioritize_parks'] as bool? ?? false,
      surfacePreference: (json['surface_preference'] as num?)?.toDouble() ?? 0.5,
      startLongitude: (json['start_longitude'] as num?)?.toDouble() ?? 0.0,
      startLatitude: (json['start_latitude'] as num?)?.toDouble() ?? 0.0,
      isLoop: json['is_loop'] as bool? ?? true,
      avoidTraffic: json['avoid_traffic'] as bool? ?? true,
      preferScenic: json['prefer_scenic'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
    parameters,
    history,
    historyIndex,
    favorites,
    errorMessage,
    validationResult,
  ];
}