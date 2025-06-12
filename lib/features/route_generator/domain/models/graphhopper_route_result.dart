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
      final route = data['route'] as Map<String, dynamic>? ?? {};
      final instructions = data['instructions'] as List<dynamic>? ?? [];
      
      // Traitement sécurisé des coordonnées
      final rawCoordinates = route['coordinates'] as List<dynamic>? ?? [];
      final coordinates = rawCoordinates.map<List<double>>((coord) {
        final coordList = coord as List<dynamic>? ?? [];
        return <double>[
          coordList.isNotEmpty ? (coordList[0] as num).toDouble() : 0.0, // longitude
          coordList.length > 1 ? (coordList[1] as num).toDouble() : 0.0, // latitude
          coordList.length > 2 ? (coordList[2] as num).toDouble() : 0.0, // elevation
        ];
      }).toList();
      
      return GraphHopperRouteResult(
        coordinates: coordinates,
        distanceKm: ((route['distance'] as num?) ?? 0) / 1000,
        durationMinutes: (((route['duration'] as num?) ?? 0) / 60000).round(),
        elevationGain: ((route['elevationGain'] as num?) ?? 0).toDouble(),
        instructions: instructions.map((inst) {
          final instMap = inst as Map<String, dynamic>? ?? {};
          return RouteInstruction.fromJson(instMap);
        }).toList(),
        metadata: Map<String, dynamic>.from(route['metadata'] as Map? ?? {}),
        bbox: (data['bbox'] as List<dynamic>?)?.map<double>((e) => (e as num).toDouble()).toList() ?? [],
      );
    } catch (e) {
      print('❌ Erreur parsing GraphHopper response: $e');
      // Retourner un résultat vide en cas d'erreur
      return GraphHopperRouteResult(
        coordinates: [],
        distanceKm: 0.0,
        durationMinutes: 0,
        elevationGain: 0.0,
        instructions: [],
        metadata: {},
        bbox: [],
      );
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