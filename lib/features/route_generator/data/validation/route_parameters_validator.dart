import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';

/// Résultat de validation avec détails des erreurs
class ValidationResult {
  final bool isValid;
  final List<ValidationError> errors;
  final List<ValidationWarning> warnings;

  ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  
  String get firstErrorMessage => errors.isNotEmpty ? errors.first.message : '';
  String get firstWarningMessage => warnings.isNotEmpty ? warnings.first.message : '';
}

class ValidationError {
  final String field;
  final String message;
  final String code;

  ValidationError({
    required this.field,
    required this.message,
    required this.code,
  });
}

class ValidationWarning {
  final String field;
  final String message;
  final String suggestion;

  ValidationWarning({
    required this.field,
    required this.message,
    required this.suggestion,
  });
}

/// Validateur complet pour les paramètres de route
class RouteParametersValidator {
  
 /// Validation complète des paramètres améliorés
  static ValidationResult validate(RouteParameters parameters) {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    // Validations existantes
    _validateDistance(parameters, errors, warnings);
    _validatePosition(parameters, errors);
    
    // 🆕 Nouvelles validations
    _validateElevationRange(parameters, errors, warnings);
    _validateInclineParameters(parameters, errors, warnings);
    _validateWaypoints(parameters, errors, warnings);
    _validateSurfacePreference(parameters, errors);
    _validateActivityCombinations(parameters, warnings);
    _validateAdvancedCombinations(parameters, warnings);

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// 🆕 Validation de la plage d'élévation
  static void _validateElevationRange(
    RouteParameters parameters, 
    List<ValidationError> errors, 
    List<ValidationWarning> warnings
  ) {
    final elevationRange = parameters.elevationRange;
    final distance = parameters.distanceKm;
    final activity = parameters.activityType;

    // Erreurs critiques
    if (elevationRange.min < 0) {
      errors.add(ValidationError(
        field: 'elevationRange.min',
        message: 'Le dénivelé minimum ne peut pas être négatif',
        code: 'ELEVATION_MIN_NEGATIVE',
      ));
    }

    if (elevationRange.max < elevationRange.min) {
      errors.add(ValidationError(
        field: 'elevationRange.max',
        message: 'Le dénivelé maximum doit être supérieur au minimum',
        code: 'ELEVATION_RANGE_INVALID',
      ));
    }

    // Validation par activité
    final maxReasonableElevation = _getMaxReasonableElevation(activity, distance);
    if (elevationRange.max > maxReasonableElevation) {
      warnings.add(ValidationWarning(
        field: 'elevationRange.max',
        message: 'Dénivelé très élevé pour cette activité (${elevationRange.max.toInt()}m)',
        suggestion: 'Considérez réduire à ${maxReasonableElevation.toInt()}m maximum',
      ));
    }

    // Cohérence avec le terrain
    if (parameters.terrainType == TerrainType.flat && elevationRange.max > 150) {
      warnings.add(ValidationWarning(
        field: 'elevationRange',
        message: 'Dénivelé élevé avec terrain plat sélectionné',
        suggestion: 'Changez le terrain vers "Vallonné" ou réduisez le dénivelé',
      ));
    }

    // Plage trop étroite
    if (elevationRange.max - elevationRange.min < 20 && elevationRange.max > 50) {
      warnings.add(ValidationWarning(
        field: 'elevationRange',
        message: 'Plage de dénivelé très étroite',
        suggestion: 'Élargissez la plage pour plus de variété dans le parcours',
      ));
    }
  }

  /// 🆕 Validation des paramètres d'inclinaison
  static void _validateInclineParameters(
    RouteParameters parameters, 
    List<ValidationError> errors, 
    List<ValidationWarning> warnings
  ) {
    final maxIncline = parameters.maxInclinePercent;
    final activity = parameters.activityType;

    if (maxIncline <= 0) {
      errors.add(ValidationError(
        field: 'maxInclinePercent',
        message: 'La pente maximale doit être positive',
        code: 'INCLINE_INVALID',
      ));
    }

    if (maxIncline > 25) {
      errors.add(ValidationError(
        field: 'maxInclinePercent',
        message: 'Pente maximale trop élevée (>25%)',
        code: 'INCLINE_TOO_HIGH',
      ));
    }

    // Recommandations par activité
    final recommendedMaxIncline = _getRecommendedMaxIncline(activity);
    if (maxIncline > recommendedMaxIncline) {
      warnings.add(ValidationWarning(
        field: 'maxInclinePercent',
        message: 'Pente élevée pour ${activity.title} (${maxIncline.toStringAsFixed(1)}%)',
        suggestion: 'Recommandé: ${recommendedMaxIncline.toStringAsFixed(1)}% maximum',
      ));
    }

    // Cohérence avec la difficulté
    if (parameters.difficulty == DifficultyLevel.easy && maxIncline > 8) {
      warnings.add(ValidationWarning(
        field: 'maxInclinePercent',
        message: 'Pente élevée pour un niveau facile',
        suggestion: 'Réduisez à 8% ou changez la difficulté',
      ));
    }
  }

  /// 🆕 Validation des points d'intérêt
  static void _validateWaypoints(
    RouteParameters parameters, 
    List<ValidationError> errors, 
    List<ValidationWarning> warnings
  ) {
    final waypoints = parameters.preferredWaypoints;
    final distance = parameters.distanceKm;

    if (waypoints < 0) {
      errors.add(ValidationError(
        field: 'preferredWaypoints',
        message: 'Le nombre de points d\'intérêt ne peut pas être négatif',
        code: 'WAYPOINTS_NEGATIVE',
      ));
    }

    if (waypoints > 10) {
      errors.add(ValidationError(
        field: 'preferredWaypoints',
        message: 'Trop de points d\'intérêt demandés (maximum: 10)',
        code: 'WAYPOINTS_TOO_MANY',
      ));
    }

    // Recommandations selon la distance
    final recommendedWaypoints = (distance / 3).round().clamp(1, 6);
    if (waypoints > recommendedWaypoints + 2) {
      warnings.add(ValidationWarning(
        field: 'preferredWaypoints',
        message: 'Beaucoup de points d\'intérêt pour cette distance',
        suggestion: 'Recommandé: $recommendedWaypoints points pour ${distance.toStringAsFixed(1)}km',
      ));
    }
  }

  /// 🆕 Validation de la préférence de surface
  static void _validateSurfacePreference(
    RouteParameters parameters, 
    List<ValidationError> errors
  ) {
    final surfacePreference = parameters.surfacePreference;

    if (surfacePreference < 0 || surfacePreference > 1) {
      errors.add(ValidationError(
        field: 'surfacePreference',
        message: 'La préférence de surface doit être entre 0 et 1',
        code: 'SURFACE_PREFERENCE_INVALID',
      ));
    }
  }

  /// 🆕 Validation des combinaisons d'activité améliorées
  static void _validateActivityCombinations(
    RouteParameters parameters, 
    List<ValidationWarning> warnings
  ) {
    final activity = parameters.activityType;
    final terrain = parameters.terrainType;
    final urbanDensity = parameters.urbanDensity;
    final surfacePreference = parameters.surfacePreference;

    // Vélo + terrain accidenté + préférence chemins naturels
    if (activity == ActivityType.cycling && 
        terrain == TerrainType.hilly && 
        surfacePreference < 0.4) {
      warnings.add(ValidationWarning(
        field: 'combination',
        message: 'Vélo sur terrain accidenté avec chemins naturels',
        suggestion: 'Privilégiez les routes goudronnées pour le vélo',
      ));
    }

    // Course + éviter autoroutes + urbain dense
    if (activity == ActivityType.running && 
        parameters.avoidHighways && 
        urbanDensity == UrbanDensity.urban) {
      warnings.add(ValidationWarning(
        field: 'combination',
        message: 'Peu d\'options en évitant les routes principales en ville',
        suggestion: 'Autorisez les routes principales ou changez de zone',
      ));
    }

    // Marche + priorité parcs + nature
    if (activity == ActivityType.walking && 
        parameters.prioritizeParks && 
        urbanDensity == UrbanDensity.nature) {
      warnings.add(ValidationWarning(
        field: 'combination',
        message: 'Peu de parcs en zone naturelle',
        suggestion: 'Les espaces verts sont déjà privilégiés en nature',
      ));
    }
  }

  /// 🆕 Validation des combinaisons avancées
  static void _validateAdvancedCombinations(
    RouteParameters parameters, 
    List<ValidationWarning> warnings
  ) {
    // Difficulté expert + paramètres faciles
    if (parameters.difficulty == DifficultyLevel.expert) {
      if (parameters.maxInclinePercent < 10 && 
          parameters.elevationRange.max < 300) {
        warnings.add(ValidationWarning(
          field: 'difficulty',
          message: 'Niveau expert mais paramètres modérés',
          suggestion: 'Augmentez la pente max et le dénivelé pour un défi expert',
        ));
      }
    }

    // Difficulté facile + paramètres difficiles
    if (parameters.difficulty == DifficultyLevel.easy) {
      if (parameters.maxInclinePercent > 10 || 
          parameters.elevationRange.max > 200) {
        warnings.add(ValidationWarning(
          field: 'difficulty',
          message: 'Niveau facile mais paramètres élevés',
          suggestion: 'Réduisez la difficulté ou changez le niveau',
        ));
      }
    }

    // Distance longue + beaucoup de points d'intérêt + éviter routes
    if (parameters.distanceKm > 15 && 
        parameters.preferredWaypoints > 6 && 
        parameters.avoidHighways) {
      warnings.add(ValidationWarning(
        field: 'combination',
        message: 'Contraintes élevées pour un long parcours',
        suggestion: 'Réduisez les points d\'intérêt ou autorisez plus de routes',
      ));
    }
  }

  // Méthodes utilitaires

  static double _getMaxReasonableElevation(ActivityType activity, double distance) {
    final baseRatio = switch (activity) {
      ActivityType.cycling => 60, // 60m/km max pour vélo
      ActivityType.running => 80, // 80m/km max pour course
      ActivityType.walking => 100, // 100m/km max pour marche
    };
    return distance * baseRatio;
  }

  static double _getRecommendedMaxIncline(ActivityType activity) {
    return switch (activity) {
      ActivityType.cycling => 10.0, // 10% max recommandé pour vélo
      ActivityType.running => 12.0, // 12% max recommandé pour course
      ActivityType.walking => 15.0, // 15% max recommandé pour marche
    };
  }

  /// Validation existante améliorée
  static void _validateDistance(
    RouteParameters parameters, 
    List<ValidationError> errors, 
    List<ValidationWarning> warnings
  ) {
    final activity = parameters.activityType;
    final distance = parameters.distanceKm;
    final difficulty = parameters.difficulty;

    // Erreurs critiques (inchangées)
    if (distance <= 0) {
      errors.add(ValidationError(
        field: 'distanceKm',
        message: 'La distance doit être supérieure à 0 km',
        code: 'DISTANCE_TOO_LOW',
      ));
      return;
    }

    if (distance < activity.minDistance) {
      errors.add(ValidationError(
        field: 'distanceKm',
        message: 'Distance minimale pour ${activity.title}: ${activity.minDistance} km',
        code: 'DISTANCE_BELOW_MIN',
      ));
    }

    if (distance > activity.maxDistance) {
      errors.add(ValidationError(
        field: 'distanceKm',
        message: 'Distance maximale pour ${activity.title}: ${activity.maxDistance} km',
        code: 'DISTANCE_ABOVE_MAX',
      ));
    }

    // 🆕 Avertissements selon la difficulté
    final recommendedRange = _getDistanceRangeForDifficulty(activity, difficulty);
    if (distance < recommendedRange.min) {
      warnings.add(ValidationWarning(
        field: 'distanceKm',
        message: 'Distance courte pour le niveau ${difficulty.title}',
        suggestion: 'Recommandé: ${recommendedRange.min}-${recommendedRange.max}km',
      ));
    } else if (distance > recommendedRange.max) {
      warnings.add(ValidationWarning(
        field: 'distanceKm',
        message: 'Distance longue pour le niveau ${difficulty.title}',
        suggestion: 'Considérez augmenter la difficulté ou réduire la distance',
      ));
    }
  }

  static ({double min, double max}) _getDistanceRangeForDifficulty(
    ActivityType activity, 
    DifficultyLevel difficulty
  ) {
    final activityRange = (min: activity.minDistance, max: activity.maxDistance);
    final totalRange = activityRange.max - activityRange.min;
    
    return switch (difficulty) {
      DifficultyLevel.easy => (
        min: activityRange.min,
        max: activityRange.min + totalRange * 0.4,
      ),
      DifficultyLevel.moderate => (
        min: activityRange.min + totalRange * 0.3,
        max: activityRange.min + totalRange * 0.7,
      ),
      DifficultyLevel.hard => (
        min: activityRange.min + totalRange * 0.6,
        max: activityRange.max,
      ),
      DifficultyLevel.expert => (
        min: activityRange.min + totalRange * 0.8,
        max: activityRange.max,
      ),
    };
  }

  /// Validation de position (inchangée)
  static void _validatePosition(
    RouteParameters parameters, 
    List<ValidationError> errors
  ) {
    final lat = parameters.startLatitude;
    final lng = parameters.startLongitude;

    if (lat < -90 || lat > 90) {
      errors.add(ValidationError(
        field: 'startLatitude',
        message: 'Latitude invalide: doit être entre -90 et 90',
        code: 'INVALID_LATITUDE',
      ));
    }

    if (lng < -180 || lng > 180) {
      errors.add(ValidationError(
        field: 'startLongitude',
        message: 'Longitude invalide: doit être entre -180 et 180',
        code: 'INVALID_LONGITUDE',
      ));
    }
  }

  /// Validation rapide pour l'UI (juste les erreurs critiques)
  static bool isQuickValid(RouteParameters parameters) {
    return parameters.distanceKm > 0 &&
           parameters.distanceKm >= parameters.activityType.minDistance &&
           parameters.distanceKm <= parameters.activityType.maxDistance &&
           parameters.elevationGain >= 0 &&
           parameters.startLatitude != 0 &&
           parameters.startLongitude != 0 &&
           parameters.startLatitude.abs() <= 90 &&
           parameters.startLongitude.abs() <= 180;
  }

  /// Messages d'aide contextuelle
  static String getHelpMessage(String field, RouteParameters parameters) {
    switch (field) {
      case 'distanceKm':
        final activity = parameters.activityType;
        return 'Distance recommandée pour ${activity.title}: ${activity.minDistance}-${activity.maxDistance} km';
      
      case 'elevationGain':
        return 'Dénivelé moyen: 0-50m (facile), 50-200m (modéré), +200m (difficile)';
      
      case 'terrainType':
        return 'Choisissez selon vos préférences et votre niveau';
      
      case 'urbanDensity':
        return 'Influence la fréquentation et les types de chemins';
      
      default:
        return '';
    }
  }
}