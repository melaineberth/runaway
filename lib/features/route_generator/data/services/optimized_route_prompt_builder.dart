// // features/route_generator/data/services/optimized_route_prompt_builder.dart
// import 'dart:convert';
// import 'dart:math' as math;
// import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

// /// Builder optimisé pour des prompts IA légers et efficaces
// class OptimizedRoutePromptBuilder {
  
//   /// Construit un prompt optimisé (< 4000 tokens)
//   static String buildOptimizedPrompt({
//     required RouteParameters parameters,
//     required Map<String, dynamic> networkData,
//     required List<Map<String, dynamic>> poisData,
//   }) {
//     // 1. Analyser et filtrer les données
//     final filteredNetwork = _filterAndClusterNetwork(networkData, parameters);
//     final priorityPois = _selectPriorityPois(poisData, parameters);
    
//     // 2. Construire le prompt compact
//     final buffer = StringBuffer();
    
//     buffer.writeln(_buildCompactContext(parameters));
//     buffer.writeln(_buildNetworkSummary(filteredNetwork, networkData));
//     buffer.writeln(_buildPoisSummary(priorityPois));
//     buffer.writeln(_buildOptimizedInstructions(parameters));
//     buffer.writeln(_buildCompactOutputFormat());
    
//     return buffer.toString();
//   }

//   /// Filtre et groupe le réseau en clusters manageable
//   static Map<String, dynamic> _filterAndClusterNetwork(
//     Map<String, dynamic> networkData, 
//     RouteParameters parameters,
//   ) {
//     final network = networkData['network'] as List;
//     final stats = networkData['statistics'] as Map<String, dynamic>;
    
//     // 1. Filtrer par qualité et pertinence
//     final filtered = network.where((segment) {
//       final quality = (segment['quality_score'] as int?) ?? 0;
//       final length = (segment['length_m'] as int?) ?? 0;
//       final suitable = _isSegmentSuitable(segment, parameters);
      
//       return quality >= 8 && // Haute qualité seulement
//              length >= 100 && length <= 2000 && // Longueurs raisonnables
//              suitable;
//     }).toList();

//     // 2. Limiter drastiquement le nombre
//     final maxSegments = math.min(50, filtered.length); // MAX 50 segments !
//     final bestSegments = filtered.take(maxSegments).toList();

//     // 3. Créer des clusters géographiques
//     final clusters = _createGeographicClusters(bestSegments, 5); // 5 clusters max

//     return {
//       'clusters': clusters,
//       'total_original': network.length,
//       'total_filtered': filtered.length,
//       'total_selected': bestSegments.length,
//       'cluster_count': clusters.length,
//       'coverage_stats': _calculateCoverageStats(bestSegments, stats),
//     };
//   }

//   /// Vérifie si un segment est adapté aux paramètres
//   static bool _isSegmentSuitable(Map<String, dynamic> segment, RouteParameters parameters) {
//     final running = segment['suitable_running'] == true;
//     final cycling = segment['suitable_cycling'] == true;
//     final isInPark = segment['is_in_park'] == true;
//     final isInNature = segment['is_in_nature'] == true;
    
//     // Vérifier l'activité
//     if (parameters.activityType.id == 'running' && !running) return false;
//     if (parameters.activityType.id == 'cycling' && !cycling) return false;
    
//     // Vérifier les préférences d'environnement
//     if (parameters.urbanDensity.id == 'nature' && !isInNature && !isInPark) return false;
//     if (parameters.urbanDensity.id == 'urban' && (isInNature || isInPark)) return false;
    
//     return true;
//   }

//   /// Crée des clusters géographiques
//   static List<Map<String, dynamic>> _createGeographicClusters(
//     List<dynamic> segments,
//     int maxClusters,
//   ) {
//     if (segments.isEmpty) return [];
    
//     // Simplification: grouper par zones géographiques approximatives
//     final clusters = <Map<String, dynamic>>[];
//     final used = <bool>[];
    
//     for (int i = 0; i < segments.length && clusters.length < maxClusters; i++) {
//       if (used.length <= i) used.add(false);
//       if (used[i]) continue;
      
//       final center = segments[i];
//       final centerCoord = center['start'] as List<dynamic>;
      
//       // Trouver les segments proches (dans un rayon de ~500m)
//       final nearbySegments = <dynamic>[center];
//       used[i] = true;
      
//       for (int j = i + 1; j < segments.length && nearbySegments.length < 10; j++) {
//         if (used.length <= j) used.add(false);
//         if (used[j]) continue;
        
//         final other = segments[j];
//         final otherCoord = other['start'] as List<dynamic>;
        
//         final distance = _calculateApproxDistance(
//           centerCoord[1].toDouble(), centerCoord[0].toDouble(),
//           otherCoord[1].toDouble(), otherCoord[0].toDouble(),
//         );
        
//         if (distance < 500) { // 500m
//           nearbySegments.add(other);
//           used[j] = true;
//         }
//       }
      
//       clusters.add({
//         'id': 'cluster_${clusters.length}',
//         'center': centerCoord,
//         'segments': nearbySegments.map((s) => _simplifySegment(s)).toList(),
//         'count': nearbySegments.length,
//         'avg_quality': _calculateAvgQuality(nearbySegments),
//         'total_length_m': _calculateTotalLength(nearbySegments),
//       });
//     }
    
//     return clusters;
//   }

//   /// Simplifie un segment pour l'IA
//   static Map<String, dynamic> _simplifySegment(dynamic segment) {
//     return {
//       'type': segment['type'],
//       'surface': segment['surface'],
//       'length_m': segment['length_m'],
//       'quality': segment['quality_score'],
//       'start': segment['start'],
//       'end': segment['end'],
//       'in_park': segment['is_in_park'],
//       'in_nature': segment['is_in_nature'],
//     };
//   }

//   /// Sélectionne les POIs prioritaires
//   static List<Map<String, dynamic>> _selectPriorityPois(
//     List<Map<String, dynamic>> pois,
//     RouteParameters parameters,
//   ) {
//     // Limiter à 10 POIs max pour réduire la taille
//     final maxPois = math.min(10, pois.length);
    
//     // Trier par pertinence
//     final sorted = List<Map<String, dynamic>>.from(pois);
//     sorted.sort((a, b) {
//       final relevanceA = (a['relevance'] as double?) ?? 0;
//       final relevanceB = (b['relevance'] as double?) ?? 0;
//       return relevanceB.compareTo(relevanceA);
//     });
    
//     return sorted.take(maxPois).map((poi) => {
//       'name': poi['name'],
//       'type': poi['type'],
//       'coordinates': poi['coordinates'],
//       'distance_m': (poi['distance_from_center'] as num?)?.round() ?? 0,
//     }).toList();
//   }

//   /// Contexte compact
//   static String _buildCompactContext(RouteParameters parameters) {
//     return '''
// === GÉNÉRATION PARCOURS ${parameters.activityType.title.toUpperCase()} ===

// OBJECTIF: ${parameters.distanceKm}km en ${parameters.isLoop ? 'boucle' : 'aller simple'}
// TERRAIN: ${parameters.terrainType.title} | ZONE: ${parameters.urbanDensity.title}
// DÉPART: [${parameters.startLongitude}, ${parameters.startLatitude}]
// DÉNIVELÉ: ${parameters.elevationGain.toStringAsFixed(0)}m

// PRÉFÉRENCES:
// - Éviter trafic: ${parameters.avoidTraffic ? 'OUI' : 'NON'}
// - Parcours pittoresque: ${parameters.preferScenic ? 'OUI' : 'NON'}
// ''';
//   }

//   /// Résumé du réseau
//   static String _buildNetworkSummary(
//     Map<String, dynamic> filteredNetwork,
//     Map<String, dynamic> originalData,
//   ) {
//     final clusters = filteredNetwork['clusters'] as List;
//     final stats = filteredNetwork['coverage_stats'] as Map<String, dynamic>;
    
//     return '''
// === RÉSEAU DE CHEMINS (OPTIMISÉ) ===

// RÉSUMÉ: ${filteredNetwork['total_selected']}/${filteredNetwork['total_original']} segments sélectionnés
// QUALITÉ: ${stats['avg_quality']} | LONGUEUR: ${stats['total_length_km']}km
// ENVIRONNEMENT: ${stats['park_ratio']}% parcs, ${stats['nature_ratio']}% nature

// CLUSTERS GÉOGRAPHIQUES:
// ${clusters.map((c) => 
//   '• Zone ${c['id']}: ${c['count']} segments, ${(c['total_length_m']/1000).toStringAsFixed(1)}km, qualité ${c['avg_quality']}'
// ).join('\n')}

// SEGMENTS DÉTAILLÉS:
// ${_formatClustersForAI(clusters)}
// ''';
//   }

//   /// POIs résumé
//   static String _buildPoisSummary(List<Map<String, dynamic>> pois) {
//     if (pois.isEmpty) return '=== AUCUN POI DISPONIBLE ===';
    
//     return '''
// === POINTS D'INTÉRÊT (${pois.length}) ===

// ${pois.map((p) => 
//   '• ${p['name']} (${p['type']}) à ${p['distance_m']}m: ${p['coordinates']}'
// ).join('\n')}
// ''';
//   }

//   /// Instructions optimisées
//   static String _buildOptimizedInstructions(RouteParameters parameters) {
//     return '''
// === INSTRUCTIONS ===

// RÈGLES ABSOLUES:
// 1. Utilise UNIQUEMENT les segments des clusters fournis
// 2. Distance cible: ${parameters.distanceKm}km (±10%)
// 3. ${parameters.isLoop ? 'BOUCLE OBLIGATOIRE' : 'Aller simple'} 
// 4. Assure la CONTINUITÉ géographique

// STRATÉGIE:
// - Connecte intelligemment les clusters
// - Privilégie qualité > distance exacte
// - Intègre 2-3 POIs max si possible
// - ${parameters.preferScenic ? 'Privilégie nature/parcs' : 'Efficacité avant tout'}

// SÉLECTION:
// - Commence par le cluster le plus proche du départ
// - Enchaîne vers clusters voisins
// - ${parameters.isLoop ? 'Termine près du départ' : 'Optimise l\'arrivée'}
// ''';
//   }

//   /// Format de sortie compact
//   static String _buildCompactOutputFormat() {
//     return '''
// === FORMAT RÉPONSE (JSON UNIQUEMENT) ===

// {
//   "route": {
//     "coordinates": [[lon,lat], [lon,lat], ...],
//     "metadata": {
//       "distance_km": "X.XX",
//       "segments_used": X,
//       "clusters_connected": X,
//       "pois_included": X,
//       "quality_score": X.X
//     },
//     "reasoning": "Explication concise (max 100 mots)"
//   }
// }

// IMPORTANT: Coordonnées = vraies positions GPS des segments fournis
// ''';
//   }

//   /// Formate les clusters pour l'IA
//   static String _formatClustersForAI(List<dynamic> clusters) {
//     final buffer = StringBuffer();
    
//     for (final cluster in clusters) {
//       final segments = cluster['segments'] as List;
//       buffer.writeln('\n${cluster['id']} (centre: ${cluster['center']}):');
      
//       for (final segment in segments.take(5)) { // Max 5 segments par cluster
//         buffer.writeln(
//           '  ${segment['type']}/${segment['surface']} ${segment['length_m']}m '
//           '${segment['start']}→${segment['end']} Q:${segment['quality']}'
//         );
//       }
      
//       if (segments.length > 5) {
//         buffer.writeln('  ... +${segments.length - 5} autres segments');
//       }
//     }
    
//     return buffer.toString();
//   }

//   // Méthodes utilitaires
//   static double _calculateApproxDistance(double lat1, double lon1, double lat2, double lon2) {
//     final dLat = (lat2 - lat1) * 111320;
//     final dLon = (lon2 - lon1) * 111320 * math.cos(lat1 * math.pi / 180);
//     return math.sqrt(dLat * dLat + dLon * dLon);
//   }

//   static double _calculateAvgQuality(List<dynamic> segments) {
//     if (segments.isEmpty) return 0;
//     final sum = segments.fold(0.0, (sum, s) => sum + (s['quality_score'] as int? ?? 0));
//     return (sum / segments.length);
//   }

//   static int _calculateTotalLength(List<dynamic> segments) {
//     return segments.fold(0, (sum, s) => sum + (s['length_m'] as int? ?? 0));
//   }

//   static Map<String, dynamic> _calculateCoverageStats(List<dynamic> segments, Map<String, dynamic> originalStats) {
//     final totalLength = _calculateTotalLength(segments);
//     final avgQuality = _calculateAvgQuality(segments);
//     final parkSegments = segments.where((s) => s['is_in_park'] == true).length;
//     final natureSegments = segments.where((s) => s['is_in_nature'] == true).length;
    
//     return {
//       'total_length_km': (totalLength / 1000).toStringAsFixed(1),
//       'avg_quality': avgQuality.toStringAsFixed(1),
//       'park_ratio': ((parkSegments / segments.length) * 100).round(),
//       'nature_ratio': ((natureSegments / segments.length) * 100).round(),
//     };
//   }
// }