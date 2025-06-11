import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'ai_route_generation_service.dart';
import 'ai_configuration_service.dart';
import 'ai_response_parser.dart';
import '../../../route_generator/data/services/route_builder_service.dart';
import '../../../../core/services/geojson_service.dart';
import '../../../route_generator/data/services/overpass_poi_service.dart';

/// Service principal intégrant IA et algorithme classique avec fallback intelligent
class IntegratedRouteGenerationService {
  
  /// Génère un parcours en utilisant l'IA avec fallback automatique
  static Future<IntegratedRouteResult> generateOptimalRoute({
    required RouteParameters parameters,
    required double latitude,
    required double longitude,
    bool forceClassicAlgorithm = false,
    AIGenerationConfig? customConfig,
  }) async {
    print('🚀 Génération de parcours intégrée');
    print('📍 Position: $latitude, $longitude');
    print('🎯 Paramètres: ${parameters.distanceKm}km, ${parameters.terrainType.title}');
    
    final startTime = DateTime.now();
    
    // 1. Vérifier la disponibilité de l'IA
    final aiStatus = AIConfigurationService.checkAIAvailability();
    final useAI = !forceClassicAlgorithm && aiStatus.isAvailable;
    
    if (!useAI) {
      print('⚠️ IA non disponible: ${aiStatus.reason}');
      print('🔄 Utilisation de l\'algorithme classique');
    }

    try {
      // 2. Préparer les données communes
      final dataPreparation = await _prepareCommonData(
        parameters: parameters,
        latitude: latitude,
        longitude: longitude,
      );

      IntegratedRouteResult result;

      if (useAI) {
        // 3a. Tentative de génération IA
        result = await _generateWithAI(
          parameters: parameters,
          dataPreparation: dataPreparation,
          customConfig: customConfig,
        );
      } else {
        // 3b. Génération classique directe
        result = await _generateWithClassicAlgorithm(
          parameters: parameters,
          dataPreparation: dataPreparation,
        );
      }

      // 4. Finaliser le résultat
      final duration = DateTime.now().difference(startTime);
      result = result.copyWith(
        generationDuration: duration,
        totalGenerationTime: duration.inMilliseconds,
      );

      print('✅ Parcours généré en ${duration.inMilliseconds}ms');
      print('📊 Méthode: ${result.generationMethod}');
      print('📏 Distance: ${result.actualDistanceKm.toStringAsFixed(2)}km');
      
      return result;

    } catch (e) {
      print('❌ Erreur génération: $e');
      
      // Fallback final vers l'algorithme classique si pas déjà essayé
      if (useAI) {
        print('🔄 Fallback vers algorithme classique...');
        return _generateWithClassicAlgorithm(
          parameters: parameters,
          dataPreparation: await _prepareCommonData(
            parameters: parameters,
            latitude: latitude,
            longitude: longitude,
          ),
        );
      }
      
      rethrow;
    }
  }

  /// Prépare les données communes nécessaires aux deux approches
  static Future<RouteDataPreparation> _prepareCommonData({
    required RouteParameters parameters,
    required double latitude,
    required double longitude,
  }) async {
    print('📦 Préparation des données...');
    
    // 1. Générer le réseau optimisé
    final geoJsonService = GeoJsonService();
    final networkFile = await geoJsonService.generateOptimizedNetworkGeoJson(
      latitude,
      longitude,
      parameters.searchRadius,
    );

    // 2. Récupérer les POIs
    final pois = await OverpassPoiService.fetchPoisInRadius(
      latitude: latitude,
      longitude: longitude,
      radiusInMeters: parameters.searchRadius,
    );

    // 3. Analyser les données pour configuration
    final networkStats = await _analyzeNetworkFile(networkFile);
    
    print('📊 Réseau: ${networkStats['total_features']} segments');
    print('📍 POIs: ${pois.length} points d\'intérêt');

    return RouteDataPreparation(
      networkFile: networkFile,
      pois: pois,
      networkStats: networkStats,
      parameters: parameters,
    );
  }

  /// Génère un parcours avec l'IA
  static Future<IntegratedRouteResult> _generateWithAI({
    required RouteParameters parameters,
    required RouteDataPreparation dataPreparation,
    AIGenerationConfig? customConfig,
  }) async {
    print('🤖 Génération IA...');
    
    try {
      // 1. Configuration IA
      final config = customConfig ?? AIConfigurationService.getDefaultConfig(
        distanceKm: parameters.distanceKm,
        terrainType: parameters.terrainType.id,
        networkSize: dataPreparation.networkStats['total_features'] ?? 0,
      );

      // 2. Estimation du coût
      final costEstimate = AIConfigurationService.estimateGenerationCost(
        model: config.model,
        networkSize: dataPreparation.networkStats['total_features'] ?? 0,
        poisCount: dataPreparation.pois.length,
      );
      
      print('💰 ${costEstimate.description}');

      // 3. Génération IA
      final aiResult = await AIRouteGenerationService.generateIntelligentRoute(
        parameters: parameters,
        networkFile: dataPreparation.networkFile,
        pois: dataPreparation.pois,
      );

      // 4. Validation approfondie
      final validation = AIResponseParser.validateRouteCoherence(
        aiResult.coordinates,
        aiResult.metadata,
      );

      if (!validation.isValid && config.enableValidation) {
        print('⚠️ Validation IA échouée: ${validation.issues.join(', ')}');
        
        if (config.enableFallback) {
          print('🔄 Fallback vers algorithme classique...');
          return _generateWithClassicAlgorithm(
            parameters: parameters,
            dataPreparation: dataPreparation,
          );
        } else {
          throw Exception('Validation IA échouée: ${validation.issues.first}');
        }
      }

      // 5. Succès IA
      return IntegratedRouteResult(
        coordinates: aiResult.coordinates,
        metadata: aiResult.metadata,
        generationMethod: RouteGenerationMethod.ai,
        aiModel: config.model,
        actualDistanceKm: double.parse(aiResult.metadata['distance_km'] ?? '0'),
        validationResult: validation,
        costEstimate: costEstimate,
        aiReasoning: aiResult.reasoning,
        fallbackUsed: false,
      );

    } catch (e) {
      print('❌ Erreur IA: $e');
      throw AIGenerationException('Génération IA échouée: $e');
    }
  }

  /// Génère un parcours avec l'algorithme classique
  static Future<IntegratedRouteResult> _generateWithClassicAlgorithm({
    required RouteParameters parameters,
    required RouteDataPreparation dataPreparation,
  }) async {
    print('🔧 Génération algorithme classique...');
    
    try {
      // 1. Utiliser le RouteBuilderService existant
      final routeBuilder = RouteBuilderService();
      await routeBuilder.loadNetwork(
        dataPreparation.networkFile,
        dataPreparation.pois,
      );
      
      // 2. Générer la route
      final coordinates = await routeBuilder.generateRoute(parameters);
      
      if (coordinates.isEmpty) {
        throw Exception('Algorithme classique: aucune route générée');
      }

      // 3. Calculer les métadonnées
      final metadata = _buildClassicMetadata(coordinates, parameters);
      
      // 4. Validation simple
      final validation = AIResponseParser.validateRouteCoherence(
        coordinates,
        metadata,
      );

      return IntegratedRouteResult(
        coordinates: coordinates,
        metadata: metadata,
        generationMethod: RouteGenerationMethod.classic,
        actualDistanceKm: _calculateRouteDistance(coordinates),
        validationResult: validation,
        fallbackUsed: false,
      );

    } catch (e) {
      print('❌ Erreur algorithme classique: $e');
      throw ClassicAlgorithmException('Algorithme classique échoué: $e');
    }
  }

  /// Construit les métadonnées pour l'algorithme classique
  static Map<String, dynamic> _buildClassicMetadata(
    List<List<double>> coordinates,
    RouteParameters parameters,
  ) {
    final distance = _calculateRouteDistance(coordinates);
    final estimatedDuration = (distance / parameters.activityType.defaultSpeed * 60).round();
    
    return {
      'distance_km': distance.toStringAsFixed(2),
      'estimated_duration_minutes': estimatedDuration,
      'elevation_gain_m': parameters.elevationGain.round(),
      'route_type': parameters.isLoop ? 'loop' : 'one_way',
      'segments_used': coordinates.length - 1,
      'quality_score': 7.5, // Score par défaut pour l'algorithme classique
      'generation_method': 'classic_algorithm',
      'classic_generated': true,
    };
  }

  /// Analyse le fichier réseau
  static Future<Map<String, dynamic>> _analyzeNetworkFile(File networkFile) async {
    try {
      final jsonString = await networkFile.readAsString();
      final data = jsonDecode(jsonString);
      return data['metadata']?['statistics'] ?? {'total_features': 0};
    } catch (e) {
      return {'total_features': 0};
    }
  }

  /// Calcule la distance d'une route
  static double _calculateRouteDistance(List<List<double>> coordinates) {
    if (coordinates.length < 2) return 0;
    
    double total = 0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      final dist = _haversineDistance(
        coordinates[i][1], coordinates[i][0],
        coordinates[i + 1][1], coordinates[i + 1][0],
      );
      total += dist;
    }
    
    return total / 1000; // Convertir en km
  }

  /// Distance de Haversine
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // rayon de la Terre en mètres

    // conversion degrés -> radians
    final double toRad = pi / 180;
    final double dLat = (lat2 - lat1) * toRad;
    final double dLon = (lon2 - lon1) * toRad;

    final double sinDlat2 = sin(dLat / 2);
    final double sinDlon2 = sin(dLon / 2);

    final double a = sinDlat2 * sinDlat2 +
        cos(lat1 * toRad) * cos(lat2 * toRad) * sinDlon2 * sinDlon2;

    // ici on utilise sqrt() et atan2() fournis par dart:math
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }
}

/// Préparation des données pour la génération
class RouteDataPreparation {
  final File networkFile;
  final List<Map<String, dynamic>> pois;
  final Map<String, dynamic> networkStats;
  final RouteParameters parameters;

  const RouteDataPreparation({
    required this.networkFile,
    required this.pois,
    required this.networkStats,
    required this.parameters,
  });
}

/// Résultat intégré de génération
class IntegratedRouteResult {
  final List<List<double>> coordinates;
  final Map<String, dynamic> metadata;
  final RouteGenerationMethod generationMethod;
  final String? aiModel;
  final double actualDistanceKm;
  final ValidationResult? validationResult;
  final AICostEstimate? costEstimate;
  final String? aiReasoning;
  final bool fallbackUsed;
  final Duration? generationDuration;
  final int? totalGenerationTime;

  const IntegratedRouteResult({
    required this.coordinates,
    required this.metadata,
    required this.generationMethod,
    this.aiModel,
    required this.actualDistanceKm,
    this.validationResult,
    this.costEstimate,
    this.aiReasoning,
    required this.fallbackUsed,
    this.generationDuration,
    this.totalGenerationTime,
  });

  IntegratedRouteResult copyWith({
    List<List<double>>? coordinates,
    Map<String, dynamic>? metadata,
    RouteGenerationMethod? generationMethod,
    String? aiModel,
    double? actualDistanceKm,
    ValidationResult? validationResult,
    AICostEstimate? costEstimate,
    String? aiReasoning,
    bool? fallbackUsed,
    Duration? generationDuration,
    int? totalGenerationTime,
  }) {
    return IntegratedRouteResult(
      coordinates: coordinates ?? this.coordinates,
      metadata: metadata ?? this.metadata,
      generationMethod: generationMethod ?? this.generationMethod,
      aiModel: aiModel ?? this.aiModel,
      actualDistanceKm: actualDistanceKm ?? this.actualDistanceKm,
      validationResult: validationResult ?? this.validationResult,
      costEstimate: costEstimate ?? this.costEstimate,
      aiReasoning: aiReasoning ?? this.aiReasoning,
      fallbackUsed: fallbackUsed ?? this.fallbackUsed,
      generationDuration: generationDuration ?? this.generationDuration,
      totalGenerationTime: totalGenerationTime ?? this.totalGenerationTime,
    );
  }

  /// Vérifie si la génération a réussi selon les critères de qualité
  bool get isSuccessful {
    return coordinates.isNotEmpty && 
           actualDistanceKm > 0 &&
           (validationResult?.isValid ?? true);
  }

  /// Obtient un score de qualité global
  double get qualityScore {
    if (!isSuccessful) return 0;
    
    double score = 5.0; // Base
    
    // Bonus pour IA vs classique
    if (generationMethod == RouteGenerationMethod.ai) {
      score += 2.0;
    }
    
    // Bonus pour validation réussie
    if (validationResult?.isValid == true) {
      score += 2.0;
    }
    
    // Bonus pour absence d'avertissements
    if (validationResult?.hasWarnings == false) {
      score += 1.0;
    }
    
    return score.clamp(0, 10);
  }
}

/// Méthodes de génération
enum RouteGenerationMethod {
  ai,
  classic,
  hybrid,
}

/// Exception de génération IA
class AIGenerationException implements Exception {
  final String message;
  AIGenerationException(this.message);
  @override
  String toString() => 'AIGenerationException: $message';
}

/// Exception algorithme classique
class ClassicAlgorithmException implements Exception {
  final String message;
  ClassicAlgorithmException(this.message);
  @override
  String toString() => 'ClassicAlgorithmException: $message';
}