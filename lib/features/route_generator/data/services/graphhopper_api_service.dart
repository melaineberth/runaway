import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:runaway/core/errors/api_exceptions.dart';
import 'package:runaway/core/errors/error_handler.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/graphhopper_route_result.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';
import '../../domain/models/route_parameters.dart';
import 'package:runaway/core/helper/config/log_config.dart';

class GraphHopperApiService {

  // ===== 🆕 CONSTANTES POUR TIMEOUT ADAPTATIF =====
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _slowConnectionTimeout = Duration(seconds: 45);

  /// Génère un parcours via l'API GraphHopper
  static Future<GraphHopperRouteResult> generateRoute({
  required RouteParameters parameters,
}) async {
  LogConfig.logInfo('🛣️ Génération de parcours via API GraphHopper...');
  LogConfig.logInfo('📍 ${parameters.distanceKm}km, ${parameters.activityType.name}, ${parameters.terrainType.name}');

  try {
    final requestBody = {
      'activityType': _mapActivityType(parameters.activityType),
      'terrainType': _mapTerrainType(parameters.terrainType),
      'urbanDensity': _mapUrbanDensity(parameters.urbanDensity),
      'distanceKm': parameters.distanceKm,
      'elevationRange': parameters.elevationRange.toJson(),
      'difficulty': parameters.difficulty.id,
      'maxInclinePercent': parameters.maxInclinePercent,
      'preferredWaypoints': parameters.preferredWaypoints,
      'avoidHighways': parameters.avoidHighways,
      'prioritizeParks': parameters.prioritizeParks,
      'surfacePreference': parameters.surfacePreference,
      'startLatitude': parameters.startLatitude,
      'startLongitude': parameters.startLongitude,
      'preferredStartTime': parameters.preferredStartTime?.toIso8601String(),
      'isLoop': parameters.isLoop,
      'avoidTraffic': parameters.avoidTraffic,
      'preferScenic': parameters.preferScenic,
    };

    LogConfig.logInfo('📤 Envoi requête: ${jsonEncode(requestBody)}');

    // 🆕 Timeout adaptatif basé sur la connectivité
    final timeout = _getAdaptiveTimeout();
    LogConfig.logInfo('⏱️ Timeout configuré: ${timeout.inSeconds}s');

    final response = await http.post(
      Uri.parse('${SecureConfig.apiBaseUrl}/routes/generate'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // 🆕 Header pour indiquer qu'on supporte les retry
        'X-Retry-Capable': 'true',
      },
      body: jsonEncode(requestBody),
    ).timeout(timeout); // Timeout adaptatif

    LogConfig.logInfo('📥 Réponse reçue: status=${response.statusCode}, body_length=${response.body.length}');

    if (response.statusCode == 200) {
      // Validation et parsing sécurisé
      late Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw RouteGenerationException('Réponse serveur invalide: impossible de parser le JSON');
      }

      // Vérification du succès
      if (data['success'] == true) {
        LogConfig.logInfo('Parsing des données de route...');
        return GraphHopperRouteResult.fromApiResponse(data);
      } else {
        final errorMsg = data['error'] as String? ?? 'Erreur inconnue du serveur';
        throw RouteGenerationException('Génération échouée: $errorMsg');
      }
    } else {
      // Gestion des erreurs HTTP
      LogConfig.logError('❌ Erreur HTTP ${response.statusCode}: ${response.body}');
      throw ErrorHandler.handleHttpError(response);
    }
    
  } on AppException {
    rethrow; // Re-lancer les exceptions déjà typées
  } on FormatException catch (e) {
    LogConfig.logError('❌ Erreur format JSON: $e');
    throw RouteGenerationException('Réponse serveur mal formatée');
  } on TimeoutException catch (e) {
    LogConfig.logError('❌ Timeout: $e');
    // 🆕 Message plus spécifique pour les timeouts
    throw NetworkException(
      'Délai d\'attente dépassé (${_getAdaptiveTimeout().inSeconds}s). Votre connexion semble lente.',
      code: 'TIMEOUT'
    );
  } catch (e) {
    LogConfig.logError('❌ Erreur inattendue: $e');
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
    LogConfig.logInfo('🛣️ Génération itinéraire simple via backend...');
    LogConfig.logInfo('📍 De: $startLat, $startLon vers: $endLat, $endLon');

    try {
      final requestBody = {
        'points': [
          [startLon, startLat],  // Point de départ [lon, lat]
          [endLon, endLat]       // Point d'arrivée [lon, lat]
        ],
        'profile': profile,
      };

      LogConfig.logInfo('📤 Envoi requête itinéraire: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('${SecureConfig.apiBaseUrl}/routes/simple'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 15));

      LogConfig.logInfo('📥 Réponse itinéraire: status=${response.statusCode}');

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
          
          LogConfig.logInfo('Itinéraire généré: ${routeCoordinates.length} points');
          LogConfig.logInfo('📊 Distance: ${(route['distance'] / 1000).toStringAsFixed(1)}km');
          LogConfig.logInfo('⏱️ Durée: ${(route['duration'] / 60000).round()}min');
          
          return routeCoordinates;
        } else {
          throw Exception('Échec génération itinéraire: ${data['error'] ?? 'Erreur inconnue'}');
        }
      } else {
        throw ErrorHandler.handleHttpError(response);
      }
      
    } catch (e) {
      LogConfig.logError('❌ Erreur génération itinéraire simple: $e');
      
      // Fallback : retourner une ligne droite si l'API échoue
      LogConfig.logInfo('📍 Fallback: ligne droite');
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
        Uri.parse('${SecureConfig.apiBaseUrl}/routes/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'coordinates': coordinates}),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Analyse route failed: ${response.statusCode}');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur analyse route: $e');
      return {};
    }
  }

  // ===== 🆕 MÉTHODES UTILITAIRES POUR TIMEOUT ADAPTATIF =====

  /// Détermine le timeout adaptatif basé sur la connectivité
  static Duration _getAdaptiveTimeout() {
    try {
      final connectivity = ConnectivityService.instance;
      
      // Si on est sur mobile, on donne plus de temps
      if (connectivity.current == ConnectionStatus.onlineMobile) {
        return _slowConnectionTimeout;
      }
      
      return _defaultTimeout;
    } catch (e) {
      // En cas d'erreur, utiliser le timeout par défaut
      return _defaultTimeout;
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

  // ===== 🆕 MÉTHODE POUR TESTER LA CONNECTIVITÉ API =====
  
  /// Test rapide de connectivité vers l'API
  static Future<bool> testApiConnectivity() async {
    try {
      final response = await http.get(
        Uri.parse('${SecureConfig.apiBaseUrl}/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      LogConfig.logError('❌ Test connectivité API échoué: $e');
      return false;
    }
  }
}
