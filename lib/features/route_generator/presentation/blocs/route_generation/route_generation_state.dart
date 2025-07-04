import 'package:equatable/equatable.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';

import '../../../domain/models/graphhopper_route_result.dart';

class RouteGenerationState extends Equatable {
  /// POIs récupérés lors de l'analyse de zone
  final List<Map<String, dynamic>> pois;

  final Map<String, dynamic>? routeMetadata;
  final List<RouteInstruction>? routeInstructions;
  
  /// Indique si une analyse est en cours
  final bool isAnalyzingZone;
  
  /// Indique si une génération est en cours
  final bool isGeneratingRoute;
  
  /// 🆕 Indique si une sauvegarde est en cours
  final bool isSavingRoute;
  
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

  // Indique si le parcours affiché provient de l'historique
  final bool isLoadedFromHistory;

  // ID unique pour tracker les changements d'état
  final String stateId;

  const RouteGenerationState({
    this.pois = const [],
    this.isAnalyzingZone = false,
    this.isGeneratingRoute = false,
    this.isSavingRoute = false, // 🆕 Ajout du nouvel état
    this.generatedRoute,
    this.usedParameters,
    this.errorMessage,
    this.zoneStats,
    this.savedRoutes = const [],
    this.routeMetadata,
    this.routeInstructions,
    this.isLoadedFromHistory = false, 
    this.stateId = 'empty',
  });

  /// Vérifie si la zone a été analysée
  bool get isZoneAnalyzed => pois.isNotEmpty;
  
  /// Vérifie si un parcours a été généré
  bool get hasGeneratedRoute => generatedRoute != null && generatedRoute!.isNotEmpty;

  // Indique si c'est un nouveau parcours généré (pas chargé depuis l'historique)
  bool get isNewlyGenerated => hasGeneratedRoute && !isLoadedFromHistory;

  // Indique si l'état est vide/reseté
  bool get isEmpty => generatedRoute == null && 
                     routeMetadata == null && 
                     usedParameters == null &&
                     !isLoadedFromHistory;

  RouteGenerationState copyWith({
    List<Map<String, dynamic>>? pois,
    bool? isAnalyzingZone,
    bool? isGeneratingRoute,
    bool? isSavingRoute, // 🆕 Ajout dans copyWith
    List<List<double>>? generatedRoute,
    RouteParameters? usedParameters,
    String? errorMessage,
    ZoneStatistics? zoneStats,
    List<SavedRoute>? savedRoutes,
    Map<String, dynamic>? routeMetadata,
    List<RouteInstruction>? routeInstructions,
    bool? isLoadedFromHistory,
    String? stateId,
  }) {
    return RouteGenerationState(
      pois: pois ?? this.pois,
      isAnalyzingZone: isAnalyzingZone ?? this.isAnalyzingZone,
      isGeneratingRoute: isGeneratingRoute ?? this.isGeneratingRoute,
      isSavingRoute: isSavingRoute ?? this.isSavingRoute, // 🆕 Ajout dans copyWith
      generatedRoute: generatedRoute ?? this.generatedRoute,
      usedParameters: usedParameters ?? this.usedParameters,
      errorMessage: errorMessage ?? this.errorMessage,
      zoneStats: zoneStats ?? this.zoneStats,
      savedRoutes: savedRoutes ?? this.savedRoutes,
      routeMetadata: routeMetadata ?? this.routeMetadata,
      routeInstructions: routeInstructions ?? this.routeInstructions,
      isLoadedFromHistory: isLoadedFromHistory ?? this.isLoadedFromHistory,
      stateId: stateId ?? this.stateId,
    );
  }

  @override
  List<Object?> get props => [
    pois,
    isAnalyzingZone,
    isGeneratingRoute,
    isSavingRoute, // 🆕 Ajout dans props
    generatedRoute,
    usedParameters,
    errorMessage,
    zoneStats,
    savedRoutes,
    routeMetadata,
    routeInstructions,
    isLoadedFromHistory,
    stateId,
  ];

  // 🆕 Sérialisation pour HydratedBloc (si utilisé) - simplifiée
  Map<String, dynamic> toJson() {
    return {
      'pois': pois,
      'isAnalyzingZone': isAnalyzingZone,
      'isGeneratingRoute': isGeneratingRoute,
      'isSavingRoute': isSavingRoute, 
      'generatedRoute': generatedRoute,
      'usedParameters': usedParameters?.toJson(),
      'errorMessage': errorMessage,
      // 🔧 Sérialisation manuelle pour ZoneStatistics
      'zoneStats': zoneStats != null ? {
        'parksCount': zoneStats!.parksCount,
        'waterPointsCount': zoneStats!.waterPointsCount,
        'viewPointsCount': zoneStats!.viewPointsCount,
        'drinkingWaterCount': zoneStats!.drinkingWaterCount,
        'toiletsCount': zoneStats!.toiletsCount,
        'greenSpaceRatio': zoneStats!.greenSpaceRatio,
        'suitabilityLevel': zoneStats!.suitabilityLevel,
      } : null,
      'savedRoutes': savedRoutes.map((route) => route.toJson()).toList(),
      'routeMetadata': routeMetadata,
      // 🔧 Sérialisation manuelle pour RouteInstruction (n'a pas de toJson)
      'routeInstructions': routeInstructions?.map((instruction) => {
        'distance': instruction.distance,
        'sign': instruction.sign,
        'text': instruction.text,
        'time': instruction.time,
        'street_name': instruction.streetName,
      }).toList(),
      'isLoadedFromHistory': isLoadedFromHistory,
      'stateId': stateId,
    };
  }

  // 🆕 Désérialisation pour HydratedBloc (si utilisé) - simplifiée
  static RouteGenerationState fromJson(Map<String, dynamic> json) {
    return RouteGenerationState(
      pois: List<Map<String, dynamic>>.from(json['pois'] ?? []),
      isAnalyzingZone: json['isAnalyzingZone'] ?? false,
      isGeneratingRoute: json['isGeneratingRoute'] ?? false,
      isSavingRoute: json['isSavingRoute'] ?? false,
      generatedRoute: json['generatedRoute'] != null 
          ? List<List<double>>.from(json['generatedRoute'].map((x) => List<double>.from(x)))
          : null,
      usedParameters: json['usedParameters'] != null
          ? RouteParameters.fromJson(json['usedParameters'])
          : null,
      errorMessage: json['errorMessage'],
      // 🔧 Désérialisation manuelle pour ZoneStatistics
      zoneStats: json['zoneStats'] != null ? ZoneStatistics(
        parksCount: json['zoneStats']['parksCount'] ?? 0,
        waterPointsCount: json['zoneStats']['waterPointsCount'] ?? 0,
        viewPointsCount: json['zoneStats']['viewPointsCount'] ?? 0,
        drinkingWaterCount: json['zoneStats']['drinkingWaterCount'] ?? 0,
        toiletsCount: json['zoneStats']['toiletsCount'] ?? 0,
        greenSpaceRatio: (json['zoneStats']['greenSpaceRatio'] ?? 0.0).toDouble(),
        suitabilityLevel: json['zoneStats']['suitabilityLevel'] ?? 'good',
      ) : null,
      savedRoutes: json['savedRoutes'] != null
          ? List<SavedRoute>.from(json['savedRoutes'].map((x) => SavedRoute.fromJson(x)))
          : [],
      routeMetadata: json['routeMetadata'],
      // 🔧 Désérialisation manuelle pour RouteInstruction
      routeInstructions: json['routeInstructions'] != null
          ? List<RouteInstruction>.from(json['routeInstructions'].map((x) => RouteInstruction.fromJson(x)))
          : null,
      isLoadedFromHistory: json['isLoadedFromHistory'] ?? false,
      stateId: json['stateId'] ?? 'empty',
    );
  }
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