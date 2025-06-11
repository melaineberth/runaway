// features/route_generator/data/services/intelligent_network_filter.dart
import 'dart:math' as math;
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

import '../../domain/models/activity_type.dart';

/// Service de filtrage intelligent pour réduire la taille des données envoyées à l'IA
class IntelligentNetworkFilter {
  
  /// Filtre et optimise le réseau pour l'IA (objectif: < 100 segments, < 3000 tokens)
  static Map<String, dynamic> filterNetworkForAI({
    required Map<String, dynamic> networkData,
    required RouteParameters parameters,
    required List<Map<String, dynamic>> pois,
    int maxSegments = 80, // Limite stricte pour rester sous 3000 tokens
  }) {
    print('🔍 Filtrage intelligent du réseau...');
    print('📊 Réseau original: ${(networkData['network'] as List).length} segments');
    
    final originalNetwork = networkData['network'] as List<Map<String, dynamic>>;
    
    // 1. Filtrage initial par qualité et pertinence
    var filteredSegments = _applyInitialFiltering(originalNetwork, parameters);
    print('📊 Après filtrage initial: ${filteredSegments.length} segments');
    
    // 2. Clustering géographique pour réduire la densité
    final clusters = _createGeographicClusters(
      filteredSegments, 
      parameters, 
      8, // targetClusters
    );
    print('📊 Clusters créés: ${clusters.length}');
    
    // 3. Sélection intelligente des meilleurs segments par cluster
    final selectedSegments = _selectBestSegmentsFromClusters(
      clusters, 
      parameters, 
      pois,
      maxSegments,
    );
    print('📊 Segments sélectionnés: ${selectedSegments.length}');
    
    // 4. Simplification des données pour l'IA
    final simplifiedSegments = _simplifySegmentsForAI(selectedSegments);
    
    // 5. Création des statistiques optimisées
    final optimizedStats = _createOptimizedStats(selectedSegments, originalNetwork);
    
    final result = {
      'network': simplifiedSegments,
      'statistics': optimizedStats,
      'clusters_info': _createClustersInfo(clusters),
      'filtering_summary': {
        'original_count': originalNetwork.length,
        'filtered_count': selectedSegments.length,
        'reduction_ratio': '${(100 * (1 - selectedSegments.length / originalNetwork.length)).toStringAsFixed(1)}%',
        'estimated_tokens': _estimateTokenCount(simplifiedSegments),
      },
    };
        
    return result;
  }

  /// Filtrage initial par qualité et pertinence
  static List<Map<String, dynamic>> _applyInitialFiltering(
    List<Map<String, dynamic>> segments,
    RouteParameters parameters,
  ) {
    final centerLat = parameters.startLatitude;
    final centerLon = parameters.startLongitude;
    final maxDistance = parameters.searchRadius * 0.8; // Utiliser 80% du rayon
    
    return segments.where((segment) {
      // 1. Vérifier la qualité minimum
      final quality = segment['quality_score'] as int? ?? 0;
      if (quality < 8) return false; // Seulement haute qualité
      
      // 2. Vérifier la compatibilité avec l'activité
      final suitable = _isSegmentSuitableForActivity(segment, parameters.activityType);
      if (!suitable) return false;
      
      // 3. Vérifier la distance du centre
      final segmentCenter = _getSegmentCenter(segment);
      final distance = _calculateDistance(
        centerLat, centerLon,
        segmentCenter[1], segmentCenter[0],
      );
      if (distance > maxDistance) return false;
      
      // 4. Vérifier la longueur du segment
      final length = segment['length_m'] as int? ?? 0;
      if (length < 50 || length > 2000) return false; // Longueurs raisonnables
      
      // 5. Filtrer selon les préférences d'environnement
      if (!_matchesEnvironmentPreferences(segment, parameters)) return false;
      
      return true;
    }).toList();
  }

  /// Crée des clusters géographiques pour organiser les segments
  static List<GeographicCluster> _createGeographicClusters(
    List<Map<String, dynamic>> segments,
    RouteParameters parameters,
    int targetClusters,
  ) {
    if (segments.isEmpty) return [];
    
    // Utiliser k-means simplifié pour créer des clusters géographiques
    final clusters = <GeographicCluster>[];
    final clusterRadius = parameters.searchRadius / math.sqrt(targetClusters); // Rayon par cluster
    
    // Initialiser avec des centres répartis autour du point de départ
    final centerLat = parameters.startLatitude;
    final centerLon = parameters.startLongitude;
    
    for (int i = 0; i < targetClusters; i++) {
      final angle = (i * 2 * math.pi) / targetClusters;
      final offsetDistance = clusterRadius * 0.6; // 60% du rayon pour éviter les chevauchements
      
      final clusterLat = centerLat + (offsetDistance / 111320) * math.cos(angle);
      final clusterLon = centerLon + (offsetDistance / (111320 * math.cos(centerLat * math.pi / 180))) * math.sin(angle);
      
      clusters.add(GeographicCluster(
        id: 'cluster_$i',
        centerLat: clusterLat,
        centerLon: clusterLon,
        segments: [],
      ));
    }
    
    // Assigner chaque segment au cluster le plus proche
    for (final segment in segments) {
      final segmentCenter = _getSegmentCenter(segment);
      
      GeographicCluster? nearestCluster;
      double minDistance = double.infinity;
      
      for (final cluster in clusters) {
        final distance = _calculateDistance(
          cluster.centerLat, cluster.centerLon,
          segmentCenter[1], segmentCenter[0],
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestCluster = cluster;
        }
      }
      
      nearestCluster?.segments.add(segment);
    }
    
    // Supprimer les clusters vides et ajuster les centres
    final nonEmptyClusters = clusters.where((c) => c.segments.isNotEmpty).toList();
    for (final cluster in nonEmptyClusters) {
      cluster._adjustCenter(); // Recalculer le centre basé sur les segments
    }
    
    return nonEmptyClusters;
  }

  /// Sélectionne les meilleurs segments de chaque cluster
  static List<Map<String, dynamic>> _selectBestSegmentsFromClusters(
    List<GeographicCluster> clusters,
    RouteParameters parameters,
    List<Map<String, dynamic>> pois,
    int maxSegments,
  ) {
    final selectedSegments = <Map<String, dynamic>>[];
    final segmentsPerCluster = (maxSegments / clusters.length).ceil();
    
    for (final cluster in clusters) {
      // Trier les segments du cluster par score de pertinence
      final sortedSegments = List<Map<String, dynamic>>.from(cluster.segments);
      sortedSegments.sort((a, b) {
        final scoreA = _calculateSegmentRelevanceScore(a, parameters, pois);
        final scoreB = _calculateSegmentRelevanceScore(b, parameters, pois);
        return scoreB.compareTo(scoreA); // Ordre décroissant
      });
      
      // Prendre les meilleurs segments du cluster
      final clusterBest = sortedSegments.take(segmentsPerCluster).toList();
      selectedSegments.addAll(clusterBest);
      
      // Ajouter des métadonnées de cluster
      for (final segment in clusterBest) {
        segment['cluster_id'] = cluster.id;
        segment['cluster_center'] = [cluster.centerLon, cluster.centerLat];
      }
    }
    
    // Si on dépasse encore la limite, prendre les meilleurs globalement
    if (selectedSegments.length > maxSegments) {
      selectedSegments.sort((a, b) {
        final scoreA = _calculateSegmentRelevanceScore(a, parameters, pois);
        final scoreB = _calculateSegmentRelevanceScore(b, parameters, pois);
        return scoreB.compareTo(scoreA);
      });
      return selectedSegments.take(maxSegments).toList();
    }
    
    return selectedSegments;
  }

  /// Calcule un score de pertinence pour un segment
  static double _calculateSegmentRelevanceScore(
    Map<String, dynamic> segment,
    RouteParameters parameters,
    List<Map<String, dynamic>> pois,
  ) {
    double score = 0.0;
    
    // 1. Score de qualité de base
    final quality = segment['quality_score'] as int? ?? 0;
    score += quality * 2; // Poids fort sur la qualité
    
    // 2. Distance du point de départ (plus proche = mieux)
    final segmentCenter = _getSegmentCenter(segment);
    final distanceFromStart = _calculateDistance(
      parameters.startLatitude, parameters.startLongitude,
      segmentCenter[1], segmentCenter[0],
    );
    final maxDistance = parameters.searchRadius;
    final distanceScore = (1 - (distanceFromStart / maxDistance)) * 20;
    score += distanceScore;
    
    // 3. Compatibilité avec les préférences d'environnement
    if (parameters.urbanDensity.id == 'nature') {
      if (segment['is_in_park'] == true) score += 15;
      if (segment['is_in_nature'] == true) score += 12;
    } else if (parameters.urbanDensity.id == 'urban') {
      final highway = segment['type'] as String? ?? '';
      if (['residential', 'pedestrian', 'cycleway'].contains(highway)) {
        score += 10;
      }
    }
    
    // 4. Bonus pour les segments près des POIs
    final nearbyPois = _countNearbyPois(segment, pois);
    score += nearbyPois * 8;
    
    // 5. Bonus pour la surface appropriée
    final surface = segment['surface'] as String? ?? '';
    if (['asphalt', 'paved', 'concrete'].contains(surface)) {
      score += 8;
    } else if (['gravel', 'compacted'].contains(surface)) {
      score += 5;
    }
    
    // 6. Longueur optimale (ni trop court, ni trop long)
    final length = segment['length_m'] as int? ?? 0;
    if (length >= 100 && length <= 800) {
      score += 10;
    } else if (length >= 50 && length <= 1500) {
      score += 5;
    }
    
    return score;
  }

  /// Simplifie les segments pour l'IA (réduction de tokens)
  static List<Map<String, dynamic>> _simplifySegmentsForAI(
    List<Map<String, dynamic>> segments,
  ) {
    return segments.map((segment) {
      // Garder seulement les données essentielles
      final coords = segment['coordinates'] as List? ?? [];
      
      return {
        'id': segment['id'],
        'type': segment['type'],
        'surface': segment['surface'],
        'length_m': segment['length_m'],
        'quality': segment['quality_score'],
        'start': segment['start'],
        'end': segment['end'],
        'suitable_running': segment['suitable_running'],
        'suitable_cycling': segment['suitable_cycling'],
        'in_park': segment['is_in_park'],
        'in_nature': segment['is_in_nature'],
        'cluster_id': segment['cluster_id'],
        // Simplifier les coordonnées (prendre seulement début, milieu, fin)
        'simplified_coords': _simplifyCoordinates(coords),
      };
    }).toList();
  }

  /// Simplifie les coordonnées d'un segment
  static List<List<double>> _simplifyCoordinates(List<dynamic> coords) {
    if (coords.length <= 3) {
      return coords.map((c) => [
        double.parse(c[0].toStringAsFixed(5)), // 5 décimales suffisent
        double.parse(c[1].toStringAsFixed(5)),
      ]).toList();
    }
    
    // Prendre début, milieu et fin seulement
    final simplified = <List<double>>[];
    simplified.add([
      double.parse(coords.first[0].toStringAsFixed(5)),
      double.parse(coords.first[1].toStringAsFixed(5)),
    ]);
    
    final middleIndex = coords.length ~/ 2;
    simplified.add([
      double.parse(coords[middleIndex][0].toStringAsFixed(5)),
      double.parse(coords[middleIndex][1].toStringAsFixed(5)),
    ]);
    
    simplified.add([
      double.parse(coords.last[0].toStringAsFixed(5)),
      double.parse(coords.last[1].toStringAsFixed(5)),
    ]);
    
    return simplified;
  }

  /// Estime le nombre de tokens pour les segments
  static int _estimateTokenCount(List<Map<String, dynamic>> segments) {
    // Estimation approximative : ~15-20 tokens par segment simplifié
    const tokensPerSegment = 18;
    const basePromptTokens = 1500; // Tokens pour le reste du prompt
    
    return basePromptTokens + (segments.length * tokensPerSegment);
  }

  /// Méthodes utilitaires
  
  static bool _isSegmentSuitableForActivity(
    Map<String, dynamic> segment,
    ActivityType activityType,
  ) {
    switch (activityType.id) {
      case 'running':
        return segment['suitable_running'] == true;
      case 'cycling':
        return segment['suitable_cycling'] == true;
      default:
        return true;
    }
  }

  static bool _matchesEnvironmentPreferences(
    Map<String, dynamic> segment,
    RouteParameters parameters,
  ) {
    switch (parameters.urbanDensity.id) {
      case 'urban':
        // En urbain, éviter les chemins de nature pure
        if (segment['is_in_nature'] == true && segment['is_in_park'] == false) {
          return false;
        }
        break;
      case 'nature':
        // En nature, privilégier les espaces verts
        final highway = segment['type'] as String? ?? '';
        if (['primary', 'secondary', 'trunk'].contains(highway)) {
          return false;
        }
        break;
    }
    return true;
  }

  static List<double> _getSegmentCenter(Map<String, dynamic> segment) {
    final start = segment['start'] as List? ?? [0.0, 0.0];
    final end = segment['end'] as List? ?? [0.0, 0.0];
    
    return [
      (start[0] + end[0]) / 2,
      (start[1] + end[1]) / 2,
    ];
  }

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

  static int _countNearbyPois(
    Map<String, dynamic> segment,
    List<Map<String, dynamic>> pois,
  ) {
    final segmentCenter = _getSegmentCenter(segment);
    int count = 0;
    
    for (final poi in pois) {
      final poiCoords = poi['coordinates'] as List? ?? [0.0, 0.0];
      final distance = _calculateDistance(
        segmentCenter[1], segmentCenter[0],
        poiCoords[1], poiCoords[0],
      );
      
      if (distance <= 200) { // 200m de rayon
        count++;
      }
    }
    
    return count;
  }

  static Map<String, dynamic> _createOptimizedStats(
    List<Map<String, dynamic>> selectedSegments,
    List<Map<String, dynamic>> originalSegments,
  ) {
    final totalLength = selectedSegments.fold(0, (sum, s) => sum + (s['length_m'] as int));
    final avgQuality = selectedSegments.fold(0.0, (sum, s) => sum + (s['quality_score'] as int)) / selectedSegments.length;
    
    return {
      'total_segments': selectedSegments.length,
      'original_segments': originalSegments.length,
      'total_length_km': (totalLength / 1000).toStringAsFixed(2),
      'avg_quality': avgQuality.toStringAsFixed(1),
      'park_segments': selectedSegments.where((s) => s['is_in_park'] == true).length,
      'nature_segments': selectedSegments.where((s) => s['is_in_nature'] == true).length,
      'optimization_applied': true,
    };
  }

  static List<Map<String, dynamic>> _createClustersInfo(List<GeographicCluster> clusters) {
    return clusters.map((cluster) => {
      'id': cluster.id,
      'center': [cluster.centerLon, cluster.centerLat],
      'segment_count': cluster.segments.length,
      'avg_quality': cluster.segments.fold(0.0, (sum, s) => sum + (s['quality_score'] as int)) / cluster.segments.length,
    }).toList();
  }
}

/// Classe pour représenter un cluster géographique
class GeographicCluster {
  final String id;
  double centerLat;
  double centerLon;
  final List<Map<String, dynamic>> segments;

  GeographicCluster({
    required this.id,
    required this.centerLat,
    required this.centerLon,
    required this.segments,
  });

  /// Ajuste le centre du cluster basé sur les segments qu'il contient
  void _adjustCenter() {
    if (segments.isEmpty) return;
    
    double sumLat = 0;
    double sumLon = 0;
    
    for (final segment in segments) {
      final center = [
        (segment['start'][0] + segment['end'][0]) / 2,
        (segment['start'][1] + segment['end'][1]) / 2,
      ];
      sumLon += center[0];
      sumLat += center[1];
    }
    
    centerLon = sumLon / segments.length;
    centerLat = sumLat / segments.length;
  }
}