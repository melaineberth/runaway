import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/graphhopper_route_result.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';
import '../../domain/models/route_parameters.dart';

class GraphHopperApiService {
  // Configuration de l'API locale (à adapter selon votre déploiement)
  static String get _baseUrl {
    // En développement, utiliser localhost
    if (dotenv.env['ENVIRONMENT'] == 'development') {
      return 'http://localhost:3000/api';
    }
    // En production, utiliser l'URL de votre serveur déployé
    return dotenv.env['GRAPHHOPPER_API_URL'] ?? 'http://localhost:3000/api';
  }

  /// Génère un parcours via l'API GraphHopper
  static Future<GraphHopperRouteResult> generateRoute({
    required RouteParameters parameters,
  }) async {
    print('🛣️ Génération de parcours via API GraphHopper...');
    print('📍 ${parameters.distanceKm}km, ${parameters.activityType.name}, ${parameters.terrainType.name}');

    try {
      final requestBody = {
        'startLatitude': parameters.startLatitude,
        'startLongitude': parameters.startLongitude,
        'activityType': _mapActivityType(parameters.activityType),
        'distanceKm': parameters.distanceKm,
        'terrainType': _mapTerrainType(parameters.terrainType),
        'urbanDensity': _mapUrbanDensity(parameters.urbanDensity),
        'elevationGain': parameters.elevationGain.round(),
        'isLoop': parameters.isLoop,
        'avoidTraffic': parameters.avoidTraffic,
        'preferScenic': parameters.preferScenic,
      };

      print('📤 Envoi requête: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/routes/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 30));

      print('📥 Réponse API: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          return GraphHopperRouteResult.fromApiResponse(data);
        } else {
          throw GraphHopperApiException('API returned success=false: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw GraphHopperApiException('API Error ${response.statusCode}: ${errorData['error'] ?? response.body}');
      }

    } catch (e) {
      print('❌ Erreur API GraphHopper: $e');
      if (e is GraphHopperApiException) rethrow;
      throw GraphHopperApiException('Erreur de connexion: $e');
    }
  }

  /// Analyse une route existante (optionnel)
  static Future<Map<String, dynamic>> analyzeRoute({
    required List<List<double>> coordinates,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/routes/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'coordinates': coordinates}),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Analyse route failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur analyse route: $e');
      return {};
    }
  }

  /// Mapping ActivityType vers string API
  static String _mapActivityType(ActivityType type) {
    switch (type) {
      case ActivityType.running:
        return 'running';
      case ActivityType.walking:
        return 'walking';
      case ActivityType.cycling:
        return 'cycling';
      }
  }

  /// Mapping TerrainType vers string API
  static String _mapTerrainType(TerrainType type) {
    switch (type) {
      case TerrainType.flat:
        return 'flat';
      case TerrainType.hilly:
        return 'hilly';
      case TerrainType.mixed:
        return 'mixed';
      }
  }

  /// Mapping UrbanDensity vers string API
  static String _mapUrbanDensity(UrbanDensity type) {
    switch (type) {
      case UrbanDensity.urban:
        return 'urban';
      case UrbanDensity.nature:
        return 'nature';
      case UrbanDensity.mixed:
        return 'mixed';
      }
  }
}
