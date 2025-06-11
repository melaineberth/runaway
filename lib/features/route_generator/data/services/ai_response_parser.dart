import 'dart:convert';
import 'dart:math';
import 'ai_route_generation_service.dart';

/// Parser pour analyser et valider les réponses de l'IA
class AIResponseParser {
  
  /// Parse la réponse complète de l'API Groq
  static AIRouteResult parseRouteResponse(Map<String, dynamic> apiResponse) {
    try {
      // Extraire le contenu de la réponse
      final choices = apiResponse['choices'] as List;
      if (choices.isEmpty) {
        throw AIParseException('Aucune réponse disponible');
      }

      final message = choices.first['message'];
      final content = message['content'] as String;

      // Parser le JSON de la route
      final routeData = _extractAndParseRouteJson(content);
      
      // Valider la structure
      _validateRouteStructure(routeData);
      
      // Extraire les coordonnées
      final coordinates = _extractCoordinates(routeData);
      
      // Extraire les métadonnées
      final metadata = _extractMetadata(routeData);
      
      // Extraire le raisonnement
      final reasoning = _extractReasoning(routeData);

      return AIRouteResult(
        coordinates: coordinates,
        metadata: metadata,
        reasoning: reasoning,
      );

    } catch (e) {
      throw AIParseException('Erreur parsing réponse IA: $e');
    }
  }

  /// Extrait et parse le JSON de la route depuis le contenu
  static Map<String, dynamic> _extractAndParseRouteJson(String content) {
    try {
      // L'IA peut répondre avec du texte autour du JSON, on extrait le JSON
      String jsonContent = content.trim();
      
      // Chercher le début et la fin du JSON
      int startIndex = jsonContent.indexOf('{');
      int endIndex = jsonContent.lastIndexOf('}');
      
      if (startIndex == -1 || endIndex == -1) {
        throw AIParseException('JSON non trouvé dans la réponse');
      }
      
      jsonContent = jsonContent.substring(startIndex, endIndex + 1);
      
      // Parser le JSON
      final parsed = jsonDecode(jsonContent);
      
      if (parsed is! Map<String, dynamic>) {
        throw AIParseException('Format JSON invalide');
      }
      
      return parsed;
      
    } catch (e) {
      // Si le parsing direct échoue, essayer de nettoyer le contenu
      return _attemptJsonCleanupAndParse(content);
    }
  }

  /// Tente de nettoyer et parser un JSON mal formaté
  static Map<String, dynamic> _attemptJsonCleanupAndParse(String content) {
    try {
      // Nettoyer les caractères de formatage markdown
      String cleaned = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .replaceAll('`', '')
          .trim();

      // Chercher les patterns de JSON
      final patterns = [
        RegExp(r'\{.*"route".*\}', dotAll: true),
        RegExp(r'\{.*"coordinates".*\}', dotAll: true),
        RegExp(r'\{[^}]*\{[^}]*\}[^}]*\}', dotAll: true),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(cleaned);
        if (match != null) {
          try {
            return jsonDecode(match.group(0)!);
          } catch (_) {
            continue;
          }
        }
      }

      throw AIParseException('Impossible d\'extraire un JSON valide');
      
    } catch (e) {
      throw AIParseException('Échec du nettoyage JSON: $e');
    }
  }

  /// Valide la structure de base de la réponse
  static void _validateRouteStructure(Map<String, dynamic> data) {
    // Vérifier la présence du nœud route
    if (!data.containsKey('route')) {
      throw AIParseException('Nœud "route" manquant');
    }

    final route = data['route'] as Map<String, dynamic>;

    // Vérifier les coordonnées
    if (!route.containsKey('coordinates')) {
      throw AIParseException('Coordonnées manquantes');
    }

    final coordinates = route['coordinates'];
    if (coordinates is! List || coordinates.isEmpty) {
      throw AIParseException('Coordonnées invalides ou vides');
    }

    // Vérifier les métadonnées de base
    if (!route.containsKey('metadata')) {
      throw AIParseException('Métadonnées manquantes');
    }

    final metadata = route['metadata'] as Map<String, dynamic>;
    if (!metadata.containsKey('distance_km')) {
      throw AIParseException('Distance manquante dans les métadonnées');
    }
  }

  /// Extrait et valide les coordonnées
  static List<List<double>> _extractCoordinates(Map<String, dynamic> data) {
    final route = data['route'] as Map<String, dynamic>;
    final rawCoordinates = route['coordinates'] as List;

    final coordinates = <List<double>>[];

    for (int i = 0; i < rawCoordinates.length; i++) {
      final coord = rawCoordinates[i];
      
      if (coord is! List || coord.length != 2) {
        throw AIParseException('Coordonnée invalide à l\'index $i: $coord');
      }

      try {
        final lon = _parseDouble(coord[0]);
        final lat = _parseDouble(coord[1]);

        // Validation des coordonnées géographiques
        if (lon < -180 || lon > 180) {
          throw AIParseException('Longitude invalide: $lon');
        }
        if (lat < -90 || lat > 90) {
          throw AIParseException('Latitude invalide: $lat');
        }

        coordinates.add([lon, lat]);
        
      } catch (e) {
        throw AIParseException('Erreur parsing coordonnée $i: $e');
      }
    }

    // Valider le nombre minimum de points
    if (coordinates.length < 2) {
      throw AIParseException('Pas assez de coordonnées (minimum 2)');
    }

    return coordinates;
  }

  /// Extrait les métadonnées
  static Map<String, dynamic> _extractMetadata(Map<String, dynamic> data) {
    final route = data['route'] as Map<String, dynamic>;
    final metadata = Map<String, dynamic>.from(route['metadata'] as Map<String, dynamic>);

    // Valider et normaliser les champs critiques
    try {
      // Distance
      if (metadata.containsKey('distance_km')) {
        metadata['distance_km'] = _parseDouble(metadata['distance_km']).toStringAsFixed(2);
      }

      // Durée estimée
      if (metadata.containsKey('estimated_duration_minutes')) {
        metadata['estimated_duration_minutes'] = _parseInt(metadata['estimated_duration_minutes']);
      }

      // Dénivelé
      if (metadata.containsKey('elevation_gain_m')) {
        metadata['elevation_gain_m'] = _parseInt(metadata['elevation_gain_m']);
      }

      // Score de qualité
      if (metadata.containsKey('quality_score')) {
        metadata['quality_score'] = _parseDouble(metadata['quality_score']);
      }

      // Nombre de segments
      if (metadata.containsKey('segments_used')) {
        metadata['segments_used'] = _parseInt(metadata['segments_used']);
      }

      // POIs inclus
      if (metadata.containsKey('pois_included')) {
        metadata['pois_included'] = _parseInt(metadata['pois_included']);
      }

    } catch (e) {
      throw AIParseException('Erreur validation métadonnées: $e');
    }

    // Ajouter des métadonnées de parsing
    metadata['ai_generated'] = true;
    metadata['parsed_at'] = DateTime.now().toIso8601String();

    return metadata;
  }

  /// Extrait le raisonnement de l'IA
  static String? _extractReasoning(Map<String, dynamic> data) {
    final route = data['route'] as Map<String, dynamic>?;
    if (route == null) return null;

    final reasoning = route['reasoning'];
    if (reasoning is String && reasoning.isNotEmpty) {
      return reasoning;
    }

    return null;
  }

  /// Parse une valeur en double avec tolérance
  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw AIParseException('Impossible de parser en double: $value');
  }

  /// Parse une valeur en entier avec tolérance
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      // Essayer de parser en double puis convertir
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) return doubleValue.round();
    }
    throw AIParseException('Impossible de parser en entier: $value');
  }

  /// Valide la cohérence géographique du parcours
  static ValidationResult validateRouteCoherence(
    List<List<double>> coordinates,
    Map<String, dynamic> metadata,
  ) {
    final issues = <String>[];
    final warnings = <String>[];

    // 1. Vérifier la continuité géographique
    double maxGap = 0;
    
    try {
      for (int i = 0; i < coordinates.length - 1; i++) {
        final distance = _calculateDistance(
          coordinates[i][1], coordinates[i][0],
          coordinates[i + 1][1], coordinates[i + 1][0],
        );
        
        if (distance > maxGap) maxGap = distance;
        
        if (distance > 1000) { // Plus de 1km entre deux points
          issues.add('Gap important détecté: ${distance.toStringAsFixed(0)}m entre points $i et ${i + 1}');
        } else if (distance > 500) {
          warnings.add('Gap modéré: ${distance.toStringAsFixed(0)}m entre points $i et ${i + 1}');
        }
      }

      // 2. Vérifier la distance totale
      final calculatedDistance = _calculateTotalDistance(coordinates);
      final reportedDistance = _parseDouble(metadata['distance_km'] ?? 0);
      final distanceError = (calculatedDistance - reportedDistance).abs();
      
      if (distanceError > 0.5) { // Plus de 500m d'erreur
        issues.add('Écart de distance important: calculé ${calculatedDistance.toStringAsFixed(2)}km vs rapporté ${reportedDistance.toStringAsFixed(2)}km');
      } else if (distanceError > 0.2) {
        warnings.add('Écart de distance modéré: ${distanceError.toStringAsFixed(2)}km');
      }

      // 3. Vérifier les coordonnées aberrantes
      final bounds = _calculateBounds(coordinates);
      if (bounds.width > 0.5 || bounds.height > 0.5) { // Plus de 50km dans une direction
        warnings.add('Parcours très étendu: ${bounds.width.toStringAsFixed(1)}° × ${bounds.height.toStringAsFixed(1)}°');
      }

      // 4. Détection de boucles étranges
      if (coordinates.length > 10) {
        final loops = _detectStrangeLoops(coordinates);
        if (loops.isNotEmpty) {
          warnings.addAll(loops.map((l) => 'Boucle détectée: $l'));
        }
      }

    } catch (e) {
      issues.add('Erreur de validation: $e');
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      warnings: warnings,
      maxGap: maxGap,
    );
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Rayon de la Terre en mètres
    final double toRad = pi / 180;

    // conversion en radians
    final double dLat = (lat2 - lat1) * toRad;
    final double dLon = (lon2 - lon1) * toRad;

    final double sinDlat2 = sin(dLat / 2);
    final double sinDlon2 = sin(dLon / 2);

    // formule de Haversine
    final double a = sinDlat2 * sinDlat2 +
        cos(lat1 * toRad) * cos(lat2 * toRad) * sinDlon2 * sinDlon2;

    // sqrt() et atan2() viennent de dart:math
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  /// Calcule la distance totale du parcours
  static double _calculateTotalDistance(List<List<double>> coordinates) {
    double total = 0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      total += _calculateDistance(
        coordinates[i][1], coordinates[i][0],
        coordinates[i + 1][1], coordinates[i + 1][0],
      );
    }
    return total / 1000; // Convertir en km
  }

  /// Calcule les bounds du parcours
  static RouteBounds _calculateBounds(List<List<double>> coordinates) {
    double minLon = coordinates.first[0];
    double maxLon = coordinates.first[0];
    double minLat = coordinates.first[1];
    double maxLat = coordinates.first[1];

    for (final coord in coordinates) {
      if (coord[0] < minLon) minLon = coord[0];
      if (coord[0] > maxLon) maxLon = coord[0];
      if (coord[1] < minLat) minLat = coord[1];
      if (coord[1] > maxLat) maxLat = coord[1];
    }

    return RouteBounds(
      minLon: minLon,
      maxLon: maxLon,
      minLat: minLat,
      maxLat: maxLat,
      width: maxLon - minLon,
      height: maxLat - minLat,
    );
  }

  /// Détecte les boucles étranges dans le parcours
  static List<String> _detectStrangeLoops(List<List<double>> coordinates) {
    final loops = <String>[];
    
    // Rechercher des points proches qui suggèrent des boucles
    for (int i = 0; i < coordinates.length - 10; i++) {
      for (int j = i + 5; j < coordinates.length; j++) {
        final distance = _calculateDistance(
          coordinates[i][1], coordinates[i][0],
          coordinates[j][1], coordinates[j][0],
        );
        
        if (distance < 50) { // Points très proches
          loops.add('Points ${i} et ${j} très proches (${distance.toStringAsFixed(0)}m)');
          break; // Éviter trop de détections
        }
      }
    }
    
    return loops;
  }
}

/// Exception de parsing IA
class AIParseException implements Exception {
  final String message;
  
  const AIParseException(this.message);
  
  @override
  String toString() => 'AIParseException: $message';
}

/// Résultat de validation
class ValidationResult {
  final bool isValid;
  final List<String> issues;
  final List<String> warnings;
  final double maxGap;

  const ValidationResult({
    required this.isValid,
    required this.issues,
    required this.warnings,
    required this.maxGap,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasCriticalIssues => issues.isNotEmpty;
}

/// Bounds d'un parcours
class RouteBounds {
  final double minLon;
  final double maxLon;
  final double minLat;
  final double maxLat;
  final double width;
  final double height;

  const RouteBounds({
    required this.minLon,
    required this.maxLon,
    required this.minLat,
    required this.maxLat,
    required this.width,
    required this.height,
  });
}