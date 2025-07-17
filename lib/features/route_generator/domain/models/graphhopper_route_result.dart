import 'package:runaway/core/helper/config/log_config.dart';

class GraphHopperRouteResult {
  final List<List<double>> coordinates;
  final double distanceKm;
  final int durationMinutes;
  final double elevationGain;
  final List<RouteInstruction> instructions;
  final Map<String, dynamic> metadata;
  final List<double> bbox;

  GraphHopperRouteResult({
    required this.coordinates,
    required this.distanceKm,
    required this.durationMinutes,
    required this.elevationGain,
    required this.instructions,
    required this.metadata,
    required this.bbox,
  });

  factory GraphHopperRouteResult.fromApiResponse(Map<String, dynamic> data) {
    try {
      LogConfig.logInfo('🔍 Parsing API response: ${data.keys}');
      
      // FIX: Vérifier la structure de la réponse
      if (data['success'] != true) {
        throw Exception('API response indicates failure: ${data['error'] ?? 'Unknown error'}');
      }

      final route = data['route'] as Map<String, dynamic>?;
      if (route == null) {
        throw Exception('Route data is missing from API response');
      }

      final instructions = data['instructions'] as List<dynamic>? ?? [];
      
      // FIX: Traitement sécurisé des coordonnées avec vérification
      final rawCoordinates = route['coordinates'] as List<dynamic>?;
      if (rawCoordinates == null || rawCoordinates.isEmpty) {
        throw Exception('Coordinates are missing or empty');
      }

      final coordinates = rawCoordinates.map<List<double>>((coord) {
        if (coord is! List || coord.length < 2) {
          throw Exception('Invalid coordinate format: $coord');
        }
        return <double>[
          (coord[0] as num).toDouble(), // longitude
          (coord[1] as num).toDouble(), // latitude
          coord.length > 2 ? (coord[2] as num).toDouble() : 0.0, // elevation
        ];
      }).toList();
      
      // FIX: Validation des données essentielles
      final distance = route['distance'] as num?;
      final duration = route['duration'] as num?;
      final elevationGain = route['elevationGain'] as num? ?? 0;
      
      if (distance == null) {
        throw Exception('Distance is missing from route data');
      }

      LogConfig.logInfo('Successfully parsed ${coordinates.length} coordinates, ${(distance / 1000).toStringAsFixed(1)}km');
      
      return GraphHopperRouteResult(
        coordinates: coordinates,
        distanceKm: distance.toDouble() / 1000, // Convert meters to km
        durationMinutes: duration != null ? (duration.toDouble() / 60000).round() : 0, // Convert ms to minutes
        elevationGain: elevationGain.toDouble(),
        instructions: instructions.map((inst) {
          final instMap = inst as Map<String, dynamic>? ?? {};
          return RouteInstruction.fromJson(instMap);
        }).toList(),
        metadata: Map<String, dynamic>.from(route['metadata'] as Map? ?? {}),
        bbox: (data['bbox'] as List<dynamic>?)?.map<double>((e) => (e as num).toDouble()).toList() ?? [],
      );
      
    } catch (e) {
      LogConfig.logError('❌ Erreur parsing GraphHopper response: $e');
      print('📄 Response data: $data');
      rethrow; // Re-lancer l'exception pour qu'elle soit gérée par le caller
    }
  }

  /// Conversion vers le format attendu par l'UI existante
  List<List<double>> get coordinatesForUI {
    // Retourner seulement [lon, lat] pour la compatibilité
    return coordinates.map((coord) => [coord[0], coord[1]]).toList();
  }
}

class RouteInstruction {
  final double distance;
  final int sign;
  final String text;
  final int time;
  final String streetName;

  RouteInstruction({
    required this.distance,
    required this.sign,
    required this.text,
    required this.time,
    required this.streetName,
  });

  factory RouteInstruction.fromJson(Map<String, dynamic> json) {
    return RouteInstruction(
      distance: ((json['distance'] as num?) ?? 0).toDouble(),
      sign: (json['sign'] as int?) ?? 0,
      text: (json['text'] as String?) ?? '',
      time: (json['time'] as int?) ?? 0,
      streetName: (json['street_name'] as String?) ?? '',
    );
  }
}

class GraphHopperApiException implements Exception {
  final String message;
  GraphHopperApiException(this.message);
  
  @override
  String toString() => 'GraphHopperApiException: $message';
}