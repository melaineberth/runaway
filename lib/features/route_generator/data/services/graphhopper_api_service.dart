import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:runaway/core/errors/api_exceptions.dart';
import 'package:runaway/core/errors/error_handler.dart';
import 'package:runaway/core/helper/config/environment_config.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/graphhopper_route_result.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';
import '../../domain/models/route_parameters.dart';

class GraphHopperApiService {
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
      Uri.parse('${EnvironmentConfig.apiBaseUrl}/routes/generate'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestBody),
    ).timeout(EnvironmentConfig.apiTimeout);

    print('📥 Réponse reçue: status=${response.statusCode}, body_length=${response.body.length}');

    if (response.statusCode == 200) {
      // FIX: Validation et parsing sécurisé
      late Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw RouteGenerationException('Réponse serveur invalide: impossible de parser le JSON');
      }

      // FIX: Vérification du succès
      if (data['success'] == true) {
        print('✅ Parsing des données de route...');
        return GraphHopperRouteResult.fromApiResponse(data);
      } else {
        final errorMsg = data['error'] as String? ?? 'Erreur inconnue du serveur';
        throw RouteGenerationException('Génération échouée: $errorMsg');
      }
    } else {
      // FIX: Gestion des erreurs HTTP
      print('❌ Erreur HTTP ${response.statusCode}: ${response.body}');
      throw ErrorHandler.handleHttpError(response);
    }
    
  } on AppException {
    rethrow; // Re-lancer les exceptions déjà typées
  } on FormatException catch (e) {
    print('❌ Erreur format JSON: $e');
    throw RouteGenerationException('Réponse serveur mal formatée');
  } on TimeoutException catch (e) {
    print('❌ Timeout: $e');
    throw NetworkException('Délai d\'attente dépassé', code: 'TIMEOUT');
  } catch (e) {
    print('❌ Erreur inattendue: $e');
    throw ErrorHandler.handleNetworkError(e);
  }
}

  static Future<List<List<double>>> generateSimpleRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    String profile = 'foot', // foot, driving, cycling
  }) async {
    print('🛣️ Génération itinéraire simple via backend...');
    print('📍 De: $startLat, $startLon vers: $endLat, $endLon');

    try {
      final requestBody = {
        'points': [
          [startLon, startLat],  // Point de départ [lon, lat]
          [endLon, endLat]       // Point d'arrivée [lon, lat]
        ],
        'profile': profile,
      };

      print('📤 Envoi requête itinéraire: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('${EnvironmentConfig.apiBaseUrl}/routes/simple'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 15));

      print('📥 Réponse itinéraire: status=${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true && data['route'] != null) {
          final route = data['route'] as Map<String, dynamic>;
          final coordinates = route['coordinates'] as List<dynamic>;
          
          final routeCoordinates = coordinates.map<List<double>>((coord) {
            return <double>[
              (coord[0] as num).toDouble(), // longitude
              (coord[1] as num).toDouble(), // latitude
            ];
          }).toList();
          
          print('✅ Itinéraire généré: ${routeCoordinates.length} points');
          print('📊 Distance: ${(route['distance'] / 1000).toStringAsFixed(1)}km');
          print('⏱️ Durée: ${(route['duration'] / 60000).round()}min');
          
          return routeCoordinates;
        } else {
          throw Exception('Échec génération itinéraire: ${data['error'] ?? 'Erreur inconnue'}');
        }
      } else {
        throw ErrorHandler.handleHttpError(response);
      }
      
    } catch (e) {
      print('❌ Erreur génération itinéraire simple: $e');
      
      // Fallback : retourner une ligne droite si l'API échoue
      print('📍 Fallback: ligne droite');
      return [
        [startLon, startLat],
        [endLon, endLat],
      ];
    }
  }
  
  /// Analyse une route existante (optionnel)
  static Future<Map<String, dynamic>> analyzeRoute({
    required List<List<double>> coordinates,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${EnvironmentConfig.apiBaseUrl}/routes/analyze'),
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
