import 'package:equatable/equatable.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

import '../../../../route_generator/domain/models/activity_type.dart';
import '../../../../route_generator/domain/models/terrain_type.dart';
import '../../../../route_generator/domain/models/urban_density.dart';

class RouteParametersState extends Equatable {
  final RouteParameters parameters;
  final List<RouteParameters> history;
  final int historyIndex;
  final List<RouteParameters> favorites;
  final String? errorMessage;

  const RouteParametersState({
    required this.parameters,
    this.history = const [],
    this.historyIndex = -1,
    this.favorites = const [],
    this.errorMessage,
  });

  bool get canUndo => historyIndex > 0;
  bool get canRedo => historyIndex < history.length - 1;

  RouteParametersState copyWith({
    RouteParameters? parameters,
    List<RouteParameters>? history,
    int? historyIndex,
    List<RouteParameters>? favorites,
    String? errorMessage,
  }) {
    return RouteParametersState(
      parameters: parameters ?? this.parameters,
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
      favorites: favorites ?? this.favorites,
      errorMessage: errorMessage,
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
      distanceKm: json['distance_km'] ?? 5.0,
      searchRadius: json['search_radius'] ?? 5000.0,
      elevationGain: json['elevation_gain'] ?? 0.0,
      startLongitude: json['start_longitude'] ?? 0.0,
      startLatitude: json['start_latitude'] ?? 0.0,
      isLoop: json['is_loop'] ?? true,
      avoidTraffic: json['avoid_traffic'] ?? true,
      preferScenic: json['prefer_scenic'] ?? true,
    );
  }

  @override
  List<Object?> get props => [
        parameters,
        history,
        historyIndex,
        favorites,
        errorMessage,
      ];
}