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
  
  /// Validation complète des paramètres
  static ValidationResult validate(RouteParameters parameters) {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    // Validation de la distance
    _validateDistance(parameters, errors, warnings);
    
    // Validation du dénivelé
    _validateElevationGain(parameters, errors, warnings);
    
    // Validation de la position
    _validatePosition(parameters, errors);
    
    // Validation de la cohérence activité/terrain
    _validateActivityTerrainCoherence(parameters, warnings);
    
    // Validation de la cohérence densité urbaine/terrain
    _validateUrbanDensityCoherence(parameters, warnings);
    
    // Validation des combinaisons avancées
    _validateAdvancedCombinations(parameters, warnings);

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validation spécifique de la distance
  static void _validateDistance(
    RouteParameters parameters, 
    List<ValidationError> errors, 
    List<ValidationWarning> warnings
  ) {
    final activity = parameters.activityType;
    final distance = parameters.distanceKm;

    // Erreurs critiques
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

    // Avertissements pour optimiser l'expérience
    if (activity == ActivityType.running && distance > 20) {
      warnings.add(ValidationWarning(
        field: 'distanceKm',
        message: 'Course de plus de 20 km détectée',
        suggestion: 'Considérez réduire ou changer pour du vélo',
      ));
    }

    if (activity == ActivityType.walking && distance > 15) {
      warnings.add(ValidationWarning(
        field: 'distanceKm',
        message: 'Marche longue détectée',
        suggestion: 'Assurez-vous d\'avoir le temps nécessaire',
      ));
    }
  }

  /// Validation du dénivelé
  static void _validateElevationGain(
    RouteParameters parameters, 
    List<ValidationError> errors, 
    List<ValidationWarning> warnings
  ) {
    final elevation = parameters.elevationGain;
    final distance = parameters.distanceKm;
    final activity = parameters.activityType;

    if (elevation < 0) {
      errors.add(ValidationError(
        field: 'elevationGain',
        message: 'Le dénivelé ne peut pas être négatif',
        code: 'ELEVATION_NEGATIVE',
      ));
      return;
    }

    // Calcul du ratio dénivelé/distance
    final elevationRatio = distance > 0 ? elevation / distance : 0;

    // Seuils par activité
    double maxReasonableRatio;
    switch (activity) {
      case ActivityType.cycling:
        maxReasonableRatio = 80; // 80m/km max pour vélo
        break;
      case ActivityType.running:
        maxReasonableRatio = 100; // 100m/km max pour course
        break;
      case ActivityType.walking:
        maxReasonableRatio = 120; // 120m/km max pour marche
        break;
    }

    if (elevationRatio > maxReasonableRatio) {
      warnings.add(ValidationWarning(
        field: 'elevationGain',
        message: 'Dénivelé très important (${elevationRatio.toInt()}m/km)',
        suggestion: 'Parcours très difficile, réduisez si nécessaire',
      ));
    }

    // Avertissement terrain plat vs dénivelé élevé
    if (parameters.terrainType == TerrainType.flat && elevation > 200) {
      warnings.add(ValidationWarning(
        field: 'elevationGain',
        message: 'Dénivelé élevé avec terrain plat sélectionné',
        suggestion: 'Changez le terrain ou réduisez le dénivelé',
      ));
    }
  }

  /// Validation de la position
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

    if (lat == 0 && lng == 0) {
      errors.add(ValidationError(
        field: 'startPosition',
        message: 'Position de départ non définie',
        code: 'POSITION_NOT_SET',
      ));
    }
  }

  /// Validation cohérence activité/terrain
  static void _validateActivityTerrainCoherence(
    RouteParameters parameters, 
    List<ValidationWarning> warnings
  ) {
    final activity = parameters.activityType;
    final terrain = parameters.terrainType;

    // Vélo + tout-terrain urbain = moins optimal
    if (activity == ActivityType.cycling && terrain == TerrainType.mixed) {
      warnings.add(ValidationWarning(
        field: 'terrainType',
        message: 'Vélo en zone urbaine dense',
        suggestion: 'Préférez les parcs ou routes moins fréquentées',
      ));
    }

    // Course + montagne = très difficile
    if (activity == ActivityType.running && terrain == TerrainType.hilly) {
      warnings.add(ValidationWarning(
        field: 'terrainType',
        message: 'Course en montagne détectée',
        suggestion: 'Parcours très exigeant, adaptez la distance',
      ));
    }
  }

  /// Validation cohérence densité urbaine/terrain
  static void _validateUrbanDensityCoherence(
    RouteParameters parameters, 
    List<ValidationWarning> warnings
  ) {
    final terrain = parameters.terrainType;
    final urbanDensity = parameters.urbanDensity;

    // Terrain naturel + haute densité urbaine
    if ((terrain == TerrainType.hilly || terrain == TerrainType.mixed) && 
        urbanDensity == UrbanDensity.nature) {
      warnings.add(ValidationWarning(
        field: 'urbanDensity',
        message: 'Terrain naturel avec haute densité urbaine',
        suggestion: 'Réduisez la densité urbaine pour plus de nature',
      ));
    }

    // Terrain urbain + faible densité
    if (terrain == TerrainType.flat && urbanDensity == UrbanDensity.urban) {
      warnings.add(ValidationWarning(
        field: 'urbanDensity',
        message: 'Terrain urbain avec faible densité',
        suggestion: 'Augmentez la densité ou changez le terrain',
      ));
    }
  }

  /// Validation des combinaisons avancées
  static void _validateAdvancedCombinations(
    RouteParameters parameters, 
    List<ValidationWarning> warnings
  ) {
    // Parcours en boucle + très longue distance
    if (parameters.isLoop && parameters.distanceKm > 30) {
      warnings.add(ValidationWarning(
        field: 'isLoop',
        message: 'Boucle très longue détectée',
        suggestion: 'Les boucles longues peuvent être monotones',
      ));
    }

    // Éviter trafic + terrain nature
    if (parameters.avoidTraffic && 
        (parameters.terrainType == TerrainType.mixed || 
         parameters.terrainType == TerrainType.hilly)) {
      warnings.add(ValidationWarning(
        field: 'avoidTraffic',
        message: 'Éviter le trafic en terrain naturel',
        suggestion: 'Option peu utile hors zones urbaines',
      ));
    }

    // Préférer panorama + distance très courte
    if (parameters.preferScenic && parameters.distanceKm < 2) {
      warnings.add(ValidationWarning(
        field: 'preferScenic',
        message: 'Parcours panoramique très court',
        suggestion: 'Augmentez la distance pour plus de paysages',
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