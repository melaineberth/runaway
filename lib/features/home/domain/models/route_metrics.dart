import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';

/// Modèle pour les caractéristiques enrichies du parcours
class RouteMetrics {
  final double distanceKm;
  final Duration estimatedDuration;
  final double elevationGain;
  final double elevationLoss;
  final double maxElevation;
  final double minElevation;
  final double averageIncline;
  final double maxIncline;
  final int waypointCount;
  final double calories; // Estimation des calories brûlées
  final List<String> surfaceTypes; // Types de surfaces traversées
  final List<String> highlights; // Points d'intérêt
  final String difficulty; // Niveau de difficulté calculé
  final double scenicScore; // Score de beauté du paysage (0-10)

  const RouteMetrics({
    required this.distanceKm,
    required this.estimatedDuration,
    required this.elevationGain,
    required this.elevationLoss,
    required this.maxElevation,
    required this.minElevation,
    required this.averageIncline,
    required this.maxIncline,
    required this.waypointCount,
    required this.calories,
    required this.surfaceTypes,
    required this.highlights,
    required this.difficulty,
    required this.scenicScore,
  });

  factory RouteMetrics.fromRouteData({
    required Map<String, dynamic> routeMetadata,
    required List<List<double>> coordinates,
    required RouteParameters parameters,
  }) {
    // Extraction des métriques avancées depuis les métadonnées
    final distance = routeMetadata['distance_km'] as double? ?? 0.0;
    final elevationGain = routeMetadata['elevation_gain'] as double? ?? 0.0;
    final elevationLoss = routeMetadata['elevation_loss'] as double? ?? 0.0;
    final maxElevation = routeMetadata['max_elevation'] as double? ?? 0.0;
    final minElevation = routeMetadata['min_elevation'] as double? ?? 0.0;
    final avgIncline = routeMetadata['average_incline'] as double? ?? 0.0;
    final maxIncline = routeMetadata['max_incline'] as double? ?? 0.0;
    final waypointCount = routeMetadata['waypoint_count'] as int? ?? 0;
    final scenicScore = routeMetadata['scenic_score'] as double? ?? 5.0;
    
    // Calcul de la durée estimée
    final duration = _calculateDuration(distance, elevationGain, parameters);
    
    // Calcul des calories
    final calories = _calculateCalories(distance, elevationGain, duration, parameters);
    
    // Extraction des types de surface
    final surfaceTypes = (routeMetadata['surface_types'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? ['Mixte'];
    
    // Extraction des points d'intérêt
    final highlights = (routeMetadata['highlights'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [];
    
    // Calcul de la difficulté
    final difficulty = _calculateDifficulty(distance, elevationGain, avgIncline, parameters);

    return RouteMetrics(
      distanceKm: distance,
      estimatedDuration: duration,
      elevationGain: elevationGain,
      elevationLoss: elevationLoss,
      maxElevation: maxElevation,
      minElevation: minElevation,
      averageIncline: avgIncline,
      maxIncline: maxIncline,
      waypointCount: waypointCount,
      calories: calories,
      surfaceTypes: surfaceTypes,
      highlights: highlights,
      difficulty: difficulty,
      scenicScore: scenicScore,
    );
  }

  static Duration _calculateDuration(double distance, double elevation, RouteParameters params) {
    final baseSpeed = params.activityType.defaultSpeed;
    final terrainFactor = switch (params.terrainType) {
      TerrainType.flat => 1.0,
      TerrainType.mixed => 0.85,
      TerrainType.hilly => 0.7,
    };
    
    final difficultyFactor = switch (params.difficulty) {
      DifficultyLevel.easy => 0.8,
      DifficultyLevel.moderate => 1.0,
      DifficultyLevel.hard => 1.2,
      DifficultyLevel.expert => 1.4,
    };
    
    final adjustedSpeed = baseSpeed * terrainFactor * difficultyFactor;
    final baseTime = (distance / adjustedSpeed) * 60; // minutes
    final elevationPenalty = (elevation / 100) * 2; // 2 min par 100m
    
    return Duration(minutes: (baseTime + elevationPenalty).round());
  }

  static double _calculateCalories(double distance, double elevation, Duration duration, RouteParameters params) {
    // Formules approximatives selon l'activité
    switch (params.activityType) {
      case ActivityType.running:
        return (distance * 65) + (elevation * 0.5); // ~65 cal/km + bonus élévation
      case ActivityType.cycling:
        return (distance * 35) + (elevation * 0.3); // ~35 cal/km + bonus élévation
      case ActivityType.walking:
        return (distance * 45) + (elevation * 0.4); // ~45 cal/km + bonus élévation
    }
  }

  static String _calculateDifficulty(double distance, double elevation, double avgIncline, RouteParameters params) {
    var score = 0;
    
    // Score basé sur la distance
    if (distance > params.activityType.maxDistance * 0.8) {
      score += 2;
    } else if (distance > params.activityType.maxDistance * 0.5) {score += 1;}
    
    // Score basé sur l'élévation
    if (elevation > 300) {score += 2;}
    else if (elevation > 150) {score += 1;}
    
    // Score basé sur la pente moyenne
    if (avgIncline > 8) {score += 2;}
    else if (avgIncline > 5) {score += 1;}
    
    return switch (score) {
      0 => 'Facile',
      1 => 'Facile',
      2 => 'Modéré',
      3 => 'Difficile',
      _ => 'Expert',
    };
  }
}
