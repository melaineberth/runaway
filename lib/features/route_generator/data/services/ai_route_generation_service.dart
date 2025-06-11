// features/route_generator/data/services/ai_route_generation_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:runaway/features/route_generator/data/services/ai_response_parser.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

import 'route_prompt_builder.dart';

/// Service principal pour la génération de parcours basée sur l'IA
class AIRouteGenerationService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
  
  // Configuration des modèles IA disponibles
  static const String _defaultModel = 'llama3-70b-8192'; // Recommandé pour l'analyse géographique
  static const String _fallbackModel = 'llama3-8b-8192'; // Plus rapide, moins précis
  
  /// Génère un parcours intelligent basé sur l'IA
  static Future<AIRouteResult> generateIntelligentRoute({
    required RouteParameters parameters,
    required File networkFile,
    required List<Map<String, dynamic>> pois,
    bool useFallbackModel = false,
  }) async {
    if (_apiKey.isEmpty) {
      throw AIRouteException('GROQ_API_KEY manquant dans le fichier .env');
    }

    print('🤖 Génération IA du parcours...');
    print('📍 Paramètres: ${parameters.distanceKm}km, ${parameters.terrainType.title}, ${parameters.urbanDensity.title}');

    try {
      // 1. Préparer les données pour l'IA
      final networkData = await _prepareNetworkData(networkFile);
      final poisData = _preparePoisData(pois);
      
      // 2. Construire le prompt pour l'IA
      final prompt = RoutePromptBuilder.buildAdvancedPrompt(
        parameters: parameters,
        networkData: networkData,
        poisData: poisData,
      );

      // 3. Appeler l'IA
      final aiResponse = await _callGroqAPI(
        prompt: prompt,
        model: useFallbackModel ? _fallbackModel : _defaultModel,
      );

      // 4. Parser la réponse
      final result = AIResponseParser.parseRouteResponse(aiResponse);
      
      // 5. Valider et optimiser le résultat
      final validatedRoute = await _validateAndOptimizeRoute(result, parameters);
      
      print('✅ Parcours IA généré: ${validatedRoute.coordinates.length} points, ${validatedRoute.metadata['distance_km']}km');
      
      return validatedRoute;

    } catch (e) {
      print('❌ Erreur génération IA: $e');
      
      // Fallback vers l'algorithme classique si l'IA échoue
      if (!useFallbackModel && e is! AIRouteException) {
        print('🔄 Tentative avec modèle fallback...');
        return generateIntelligentRoute(
          parameters: parameters,
          networkFile: networkFile,
          pois: pois,
          useFallbackModel: true,
        );
      }
      
      throw AIRouteException('Impossible de générer le parcours: $e');
    }
  }

  /// Appelle l'API GroqCloud
  static Future<Map<String, dynamic>> _callGroqAPI({
    required String prompt,
    required String model,
  }) async {
    final body = {
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': _getSystemPrompt(),
        },
        {
          'role': 'user',
          'content': prompt,
        }
      ],
      'temperature': 0.3, // Moins de créativité, plus de précision
      'max_tokens': 4000,
      'top_p': 0.9,
    };

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    ).timeout(Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw AIRouteException(
        'Erreur API Groq: ${response.statusCode} - ${response.body}'
      );
    }

    final data = jsonDecode(response.body);
    
    if (data['choices'] == null || data['choices'].isEmpty) {
      throw AIRouteException('Réponse IA vide ou invalide');
    }

    return data;
  }

  /// Prompt système pour guider l'IA
  static String _getSystemPrompt() {
    return '''
Tu es un expert en planification de parcours sportifs. Tu analyses des données géographiques réelles pour créer des itinéraires optimisés pour la course à pied, le vélo et la marche.

EXPERTISE:
- Géographie et topographie
- Réseaux de chemins et routes
- Optimisation d'itinéraires
- Sécurité et praticabilité des parcours
- Points d'intérêt sportifs et touristiques

OBJECTIFS:
1. Créer des parcours réalistes et praticables
2. Respecter exactement les paramètres demandés
3. Optimiser pour la sécurité et l'agrément
4. Privilégier les chemins de qualité
5. Intégrer intelligemment les POIs

CONTRAINTES:
- Utiliser UNIQUEMENT les chemins fournis dans les données
- Respecter la distance demandée (±10%)
- Assurer la continuité du parcours
- Éviter les segments dangereux
- Retourner un JSON valide et structuré

FORMAT DE RÉPONSE:
Réponds UNIQUEMENT avec un JSON valide contenant les coordonnées du parcours et les métadonnées.
''';
  }

  /// Prépare les données réseau pour l'IA
  static Future<Map<String, dynamic>> _prepareNetworkData(File networkFile) async {
    final jsonString = await networkFile.readAsString();
    final geoJson = jsonDecode(jsonString);
    
    final features = geoJson['features'] as List;
    
    // Filtrer et simplifier les données pour l'IA
    final simplifiedNetwork = features.map((feature) {
      final props = feature['properties'] as Map<String, dynamic>;
      final coords = feature['geometry']['coordinates'] as List;
      
      return {
        'id': props['osm_id'],
        'type': props['highway'],
        'surface': props['surface'],
        'length_m': props['length_m'],
        'quality_score': props['quality_score'],
        'suitable_running': props['suitable_running'],
        'suitable_cycling': props['suitable_cycling'],
        'is_in_park': props['is_in_park'],
        'is_in_nature': props['is_in_nature'],
        'coordinates': coords,
        'start': [coords.first[0], coords.first[1]],
        'end': [coords.last[0], coords.last[1]],
      };
    }).toList();

    // Statistiques pour aider l'IA
    final stats = {
      'total_segments': simplifiedNetwork.length,
      'total_length_km': (simplifiedNetwork.fold(0.0, (sum, s) => 
          sum + (s['length_m'] as int)) / 1000).toStringAsFixed(2),
      'quality_segments': simplifiedNetwork.where((s) => 
          (s['quality_score'] as int) >= 15).length,
      'park_segments': simplifiedNetwork.where((s) => 
          s['is_in_park'] == true).length,
      'nature_segments': simplifiedNetwork.where((s) => 
          s['is_in_nature'] == true).length,
    };

    return {
      'network': simplifiedNetwork,
      'statistics': stats,
      'metadata': geoJson['metadata'],
    };
  }

  /// Prépare les données POIs pour l'IA
  static List<Map<String, dynamic>> _preparePoisData(List<Map<String, dynamic>> pois) {
    return pois.map((poi) {
      return {
        'id': poi['id'],
        'name': poi['name'],
        'type': poi['type'],
        'coordinates': poi['coordinates'],
        'distance_from_center': poi['distance'],
        'relevance': _calculatePoiRelevance(poi),
      };
    }).toList();
  }

  /// Calcule la pertinence d'un POI pour l'itinéraire
  static double _calculatePoiRelevance(Map<String, dynamic> poi) {
    final type = poi['type'] as String;
    final distance = (poi['distance'] as num?)?.toDouble() ?? 0;
    
    double relevance = 1.0;
    
    // Bonus selon le type
    switch (type) {
      case 'Parc': relevance += 0.8; break;
      case 'Point de vue': relevance += 0.6; break;
      case 'Eau potable': relevance += 0.4; break;
      case 'Toilettes': relevance += 0.3; break;
      case 'Point d\'eau': relevance += 0.5; break;
    }
    
    // Pénalité pour la distance
    if (distance > 1000) relevance *= 0.5;
    else if (distance > 500) relevance *= 0.8;
    
    return relevance.clamp(0.1, 2.0);
  }

  /// Valide et optimise le parcours généré par l'IA
  static Future<AIRouteResult> _validateAndOptimizeRoute(
    AIRouteResult aiResult,
    RouteParameters parameters,
  ) async {
    var coordinates = aiResult.coordinates;
    
    // 1. Vérifier la continuité
    coordinates = _ensureContinuity(coordinates);
    
    // 2. Vérifier la distance
    final distance = _calculateRouteDistance(coordinates);
    final targetDistance = parameters.distanceKm;
    final distanceError = (distance - targetDistance).abs() / targetDistance;
    
    if (distanceError > 0.15) { // Plus de 15% d'erreur
      print('⚠️ Distance IA imprécise: ${distance.toStringAsFixed(2)}km vs ${targetDistance}km');
      // On garde quand même le résultat mais on log l'avertissement
    }
    
    // 3. Optimiser le lissage
    coordinates = _smoothRoute(coordinates);
    
    // 4. Mettre à jour les métadonnées
    final updatedMetadata = Map<String, dynamic>.from(aiResult.metadata);
    updatedMetadata['actual_distance_km'] = distance.toStringAsFixed(2);
    updatedMetadata['distance_accuracy'] = ((1 - distanceError) * 100).toStringAsFixed(1);
    updatedMetadata['validation_passed'] = distanceError <= 0.15;
    
    return AIRouteResult(
      coordinates: coordinates,
      metadata: updatedMetadata,
      reasoning: aiResult.reasoning,
    );
  }

  /// Assure la continuité du parcours
  static List<List<double>> _ensureContinuity(List<List<double>> points) {
    if (points.length < 2) return points;
    
    final continuous = <List<double>>[points.first];
    
    for (int i = 1; i < points.length; i++) {
      final prev = continuous.last;
      final curr = points[i];
      
      final dist = _calculateDistance(prev[1], prev[0], curr[1], curr[0]);
      
      // Si saut > 200m, interpoler
      if (dist > 200) {
        final steps = (dist / 100).ceil();
        for (int j = 1; j < steps; j++) {
          final t = j / steps.toDouble();
          final interpLon = prev[0] + (curr[0] - prev[0]) * t;
          final interpLat = prev[1] + (curr[1] - prev[1]) * t;
          continuous.add([interpLon, interpLat]);
        }
      }
      
      continuous.add(curr);
    }
    
    return continuous;
  }

  /// Lisse le parcours
  static List<List<double>> _smoothRoute(List<List<double>> points) {
    if (points.length < 3) return points;
    
    final smoothed = <List<double>>[points.first];
    
    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];
      
      // Moyennage simple pour lisser
      final smoothLon = (prev[0] + curr[0] * 2 + next[0]) / 4;
      final smoothLat = (prev[1] + curr[1] * 2 + next[1]) / 4;
      
      smoothed.add([smoothLon, smoothLat]);
    }
    
    smoothed.add(points.last);
    return smoothed;
  }

  /// Calcule la distance totale d'un parcours
  static double _calculateRouteDistance(List<List<double>> coordinates) {
    if (coordinates.length < 2) return 0.0;
    
    double total = 0.0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      total += _calculateDistance(
        coordinates[i][1], coordinates[i][0],
        coordinates[i + 1][1], coordinates[i + 1][0],
      );
    }
    
    return total / 1000; // Convertir en km
  }

  /// Calcule la distance entre deux points
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Rayon de la Terre en mètres
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
              math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
}

/// Résultat de la génération IA
class AIRouteResult {
  final List<List<double>> coordinates;
  final Map<String, dynamic> metadata;
  final String? reasoning;

  const AIRouteResult({
    required this.coordinates,
    required this.metadata,
    this.reasoning,
  });
}

/// Exception spécifique à la génération IA
class AIRouteException implements Exception {
  final String message;
  
  const AIRouteException(this.message);
  
  @override
  String toString() => 'AIRouteException: $message';
}