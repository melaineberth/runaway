import 'package:equatable/equatable.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

import '../../../domain/models/graphhopper_route_result.dart';

/// État de la génération de parcours
class RouteGenerationState extends Equatable {
  /// POIs récupérés lors de l'analyse de zone
  final List<Map<String, dynamic>> pois;

  final Map<String, dynamic>? routeMetadata;
  final List<RouteInstruction>? routeInstructions;
  
  /// Indique si une analyse est en cours
  final bool isAnalyzingZone;
  
  /// Indique si une génération est en cours
  final bool isGeneratingRoute;
  
  /// Parcours généré (liste de coordonnées)
  final List<List<double>>? generatedRoute;
  
  /// Paramètres utilisés pour la génération
  final RouteParameters? usedParameters;
  
  /// Message d'erreur éventuel
  final String? errorMessage;
  
  /// Statistiques de la zone analysée
  final ZoneStatistics? zoneStats;
  
  /// Parcours sauvegardés
  final List<SavedRoute> savedRoutes;

  const RouteGenerationState({
    this.pois = const [],
    this.isAnalyzingZone = false,
    this.isGeneratingRoute = false,
    this.generatedRoute,
    this.usedParameters,
    this.errorMessage,
    this.zoneStats,
    this.savedRoutes = const [],
    this.routeMetadata,
    this.routeInstructions,
  });

  /// Vérifie si la zone a été analysée
  bool get isZoneAnalyzed => pois.isNotEmpty;
  
  /// Vérifie si un parcours a été généré
  bool get hasGeneratedRoute => generatedRoute != null && generatedRoute!.isNotEmpty;

  RouteGenerationState copyWith({
    List<Map<String, dynamic>>? pois,
    bool? isAnalyzingZone,
    bool? isGeneratingRoute,
    List<List<double>>? generatedRoute,
    RouteParameters? usedParameters,
    String? errorMessage,
    ZoneStatistics? zoneStats,
    List<SavedRoute>? savedRoutes,
    Map<String, dynamic>? routeMetadata,
    List<RouteInstruction>? routeInstructions,
  }) {
    return RouteGenerationState(
      pois: pois ?? this.pois,
      isAnalyzingZone: isAnalyzingZone ?? this.isAnalyzingZone,
      isGeneratingRoute: isGeneratingRoute ?? this.isGeneratingRoute,
      generatedRoute: generatedRoute ?? this.generatedRoute,
      usedParameters: usedParameters ?? this.usedParameters,
      errorMessage: errorMessage,
      zoneStats: zoneStats ?? this.zoneStats,
      savedRoutes: savedRoutes ?? this.savedRoutes,
      routeMetadata: routeMetadata ?? this.routeMetadata,
      routeInstructions: routeInstructions ?? this.routeInstructions,
    );
  }

  @override
  List<Object?> get props => [
    pois,
    isAnalyzingZone,
    isGeneratingRoute,
    generatedRoute,
    usedParameters,
    errorMessage,
    zoneStats,
    savedRoutes,
    routeMetadata,
    routeInstructions,
  ];
}

/// Statistiques de la zone analysée
class ZoneStatistics extends Equatable {
  final int parksCount;
  final int waterPointsCount;
  final int viewPointsCount;
  final int drinkingWaterCount;
  final int toiletsCount;
  final double greenSpaceRatio;
  final String suitabilityLevel; // 'excellent', 'good', 'fair', 'poor'

  const ZoneStatistics({
    required this.parksCount,
    required this.waterPointsCount,
    required this.viewPointsCount,
    required this.drinkingWaterCount,
    required this.toiletsCount,
    required this.greenSpaceRatio,
    required this.suitabilityLevel,
  });

  factory ZoneStatistics.fromPois(List<Map<String, dynamic>> pois) {
    final parksCount = pois.where((p) => p['type'] == 'Parc').length;
    final waterPointsCount = pois.where((p) => p['type'] == 'Point d\'eau').length;
    final viewPointsCount = pois.where((p) => p['type'] == 'Point de vue').length;
    final drinkingWaterCount = pois.where((p) => p['type'] == 'Eau potable').length;
    final toiletsCount = pois.where((p) => p['type'] == 'Toilettes').length;
    
    // Calculer le ratio d'espaces verts (simplifié)
    final totalPois = pois.length;
    final greenPois = parksCount + waterPointsCount;
    final greenSpaceRatio = totalPois > 0 ? greenPois / totalPois : 0.0;
    
    // Déterminer le niveau de pertinence
    String suitabilityLevel;
    if (parksCount >= 3 && (drinkingWaterCount > 0 || toiletsCount > 0)) {
      suitabilityLevel = 'excellent';
    } else if (parksCount >= 2 || (parksCount >= 1 && waterPointsCount >= 1)) {
      suitabilityLevel = 'good';
    } else if (parksCount >= 1 || waterPointsCount >= 1) {
      suitabilityLevel = 'fair';
    } else {
      suitabilityLevel = 'poor';
    }
    
    return ZoneStatistics(
      parksCount: parksCount,
      waterPointsCount: waterPointsCount,
      viewPointsCount: viewPointsCount,
      drinkingWaterCount: drinkingWaterCount,
      toiletsCount: toiletsCount,
      greenSpaceRatio: greenSpaceRatio,
      suitabilityLevel: suitabilityLevel,
    );
  }

  @override
  List<Object?> get props => [
        parksCount,
        waterPointsCount,
        viewPointsCount,
        drinkingWaterCount,
        toiletsCount,
        greenSpaceRatio,
        suitabilityLevel,
      ];
}

/// Parcours sauvegardé
class SavedRoute extends Equatable {
  final String id;
  final String name;
  final RouteParameters parameters;
  final List<List<double>> coordinates;
  final DateTime createdAt;
  final double? actualDistance;
  final int? actualDuration;

  const SavedRoute({
    required this.id,
    required this.name,
    required this.parameters,
    required this.coordinates,
    required this.createdAt,
    this.actualDistance,
    this.actualDuration,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        parameters,
        coordinates,
        createdAt,
        actualDistance,
        actualDuration,
      ];
}
