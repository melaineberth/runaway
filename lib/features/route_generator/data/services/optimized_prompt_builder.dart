import 'dart:math' as math;
import '../../domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

/// Builder de prompts optimisé pour minimiser les tokens tout en gardant l'efficacité
class OptimizedPromptBuilder {
  
  /// Construit un prompt ultra-optimisé (objectif: < 3000 tokens)
  static String buildCompactPrompt({
    required RouteParameters parameters,
    required Map<String, dynamic> filteredNetworkData,
    required List<Map<String, dynamic>> priorityPois,
  }) {
    final buffer = StringBuffer();
    
    // 1. Contexte concis
    buffer.writeln(_buildCompactContext(parameters));
    
    // 2. Réseau filtré ultra-compact
    buffer.writeln(_buildCompactNetwork(filteredNetworkData));
    
    // 3. POIs essentiels seulement
    buffer.writeln(_buildCompactPois(priorityPois));
    
    // 4. Instructions concentrées
    buffer.writeln(_buildCompactInstructions(parameters));
    
    // 5. Format de sortie minimal
    buffer.writeln(_buildCompactOutputFormat());
    
    return buffer.toString();
  }

  /// Contexte ultra-compact
  static String _buildCompactContext(RouteParameters parameters) {
    return '''
=== GÉNÉRATION PARCOURS ===
Distance: ${parameters.distanceKm}km | Activité: ${parameters.activityType.title}
Terrain: ${parameters.terrainType.title} | Zone: ${parameters.urbanDensity.title}
Départ: [${parameters.startLongitude.toStringAsFixed(5)}, ${parameters.startLatitude.toStringAsFixed(5)}]
Type: ${parameters.isLoop ? 'BOUCLE' : 'ALLER'} | Dénivelé: ${parameters.elevationGain.toStringAsFixed(0)}m
Préférences: ${parameters.avoidTraffic ? 'Éviter trafic' : ''} ${parameters.preferScenic ? 'Pittoresque' : ''}
''';
  }

  /// Réseau ultra-compact avec clusters
  static String _buildCompactNetwork(Map<String, dynamic> networkData) {
    final segments = networkData['network'] as List<Map<String, dynamic>>;
    final stats = networkData['statistics'] as Map<String, dynamic>;
    final filtering = networkData['filtering_summary'] as Map<String, dynamic>;
    final clusters = networkData['clusters_info'] as List<Map<String, dynamic>>;
    
    final buffer = StringBuffer();
    
    buffer.writeln('=== RÉSEAU (${segments.length} segments optimisés) ===');
    buffer.writeln('Sélection: ${filtering['reduction_ratio']} réduction, qualité moy: ${stats['avg_quality']}');
    buffer.writeln('Clusters: ${clusters.length} zones géographiques');
    
    // Afficher info clusters compacte
    for (final cluster in clusters) {
      buffer.writeln('${cluster['id']}: ${cluster['segment_count']} seg, Q:${(cluster['avg_quality'] as double).toStringAsFixed(1)}');
    }
    
    buffer.writeln('\nSEGMENTS:');
    
    // Format ultra-compact pour chaque segment
    for (int i = 0; i < segments.length; i++) {
      final s = segments[i];
      final coords = s['simplified_coords'] as List<List<double>>;
      
      buffer.write('${s['id']}|${s['type']}|${s['surface']}|${s['length_m']}m|Q${s['quality']}');
      buffer.write('|${coords[0][0].toStringAsFixed(4)},${coords[0][1].toStringAsFixed(4)}');
      buffer.write('>>${coords.last[0].toStringAsFixed(4)},${coords.last[1].toStringAsFixed(4)}');
      buffer.write('|R:${s['suitable_running']}|C:${s['suitable_cycling']}');
      if (s['in_park'] == true) buffer.write('|PARK');
      if (s['in_nature'] == true) buffer.write('|NAT');
      buffer.writeln('|${s['cluster_id']}');
    }
    
    return buffer.toString();
  }

  /// POIs ultra-compacts
  static String _buildCompactPois(List<Map<String, dynamic>> pois) {
    if (pois.isEmpty) return '=== AUCUN POI ===';
    
    final limitedPois = pois.take(12).toList(); // Max 12 POIs
    final buffer = StringBuffer();
    
    buffer.writeln('=== POIs (${limitedPois.length}) ===');
    
    for (final poi in limitedPois) {
      final coords = poi['coordinates'] as List;
      buffer.writeln('${poi['name']}|${poi['type']}|${coords[0].toStringAsFixed(4)},${coords[1].toStringAsFixed(4)}');
    }
    
    return buffer.toString();
  }

  /// Instructions ultra-concentrées
  static String _buildCompactInstructions(RouteParameters parameters) {
    return '''
=== RÈGLES ===
1. Distance exacte: ${parameters.distanceKm}km (±8%)
2. ${parameters.isLoop ? 'BOUCLE obligatoire (retour départ)' : 'Aller simple'}
3. Segments: utilise UNIQUEMENT ceux listés ci-dessus
4. Continuité: chaque point connecté au suivant
5. Activité: segments suitable_${parameters.activityType.id == 'running' ? 'running' : 'cycling'}=true
6. Qualité: priorité aux scores Q élevés
7. ${_getSpecificConstraints(parameters)}

STRATÉGIE:
- Commence près du départ
- Connecte segments voisins (même cluster prioritaire)
- Intègre 1-2 POIs si possible (détour max 100m)
- ${parameters.preferScenic ? 'Privilégie PARK/NAT' : 'Efficacité prioritaire'}
''';
  }

  /// Format de sortie minimal
  static String _buildCompactOutputFormat() {
    return '''
=== RÉPONSE REQUISE ===
JSON pur uniquement:
{
  "route": {
    "coordinates": [[lon,lat],[lon,lat],...],
    "metadata": {
      "distance_km": "X.XX",
      "duration_min": X,
      "segments_used": X,
      "quality_score": X.X
    }
  }
}
''';
  }

  /// Contraintes spécifiques selon les paramètres
  static String _getSpecificConstraints(RouteParameters parameters) {
    final constraints = <String>[];
    
    if (parameters.avoidTraffic) {
      constraints.add('Évite primary/secondary/trunk');
    }
    
    switch (parameters.terrainType.id) {
      case 'flat':
        constraints.add('Privilégie terrain plat');
        break;
      case 'hilly':
        constraints.add('Recherche dénivelé');
        break;
    }
    
    switch (parameters.urbanDensity.id) {
      case 'urban':
        constraints.add('Focus residential/pedestrian');
        break;
      case 'nature':
        constraints.add('Focus PARK/NAT segments');
        break;
    }
    
    return constraints.join(', ');
  }

  /// Filtre et prépare les POIs pour l'IA (réduction drastique)
  static List<Map<String, dynamic>> filterPoisForAI(
    List<Map<String, dynamic>> pois,
    RouteParameters parameters,
  ) {
    // Filtrer par pertinence et distance
    final relevantPois = pois.where((poi) {
      final distance = poi['distance'] as num? ?? 0;
      final type = poi['type'] as String? ?? '';
      
      // Distance max 1km du centre
      if (distance > 1000) return false;
      
      // Types pertinents selon l'activité
      final relevantTypes = _getRelevantPoiTypes(parameters.activityType);
      if (!relevantTypes.contains(type)) return false;
      
      return true;
    }).toList();
    
    // Trier par pertinence et prendre les meilleurs
    relevantPois.sort((a, b) {
      final scoreA = _calculatePoiRelevance(a, parameters);
      final scoreB = _calculatePoiRelevance(b, parameters);
      return scoreB.compareTo(scoreA);
    });
    
    // Limiter à 12 POIs max
    return relevantPois.take(12).map((poi) => {
      'name': (poi['name'] as String? ?? '').substring(0, math.min(30, (poi['name'] as String? ?? '').length)),
      'type': poi['type'],
      'coordinates': poi['coordinates'],
      'distance': (poi['distance'] as num?)?.round() ?? 0,
    }).toList();
  }

  static List<String> _getRelevantPoiTypes(ActivityType activityType) {
    switch (activityType.id) {
      case 'running':
        return ['Parc', 'Eau potable', 'Toilettes', 'Point de vue'];
      case 'cycling':
        return ['Parc', 'Point de vue', 'Eau potable'];
      default:
        return ['Parc', 'Point de vue'];
    }
  }

  static double _calculatePoiRelevance(
    Map<String, dynamic> poi,
    RouteParameters parameters,
  ) {
    double relevance = 1.0;
    
    final type = poi['type'] as String? ?? '';
    final distance = poi['distance'] as num? ?? 0;
    
    // Bonus par type
    switch (type) {
      case 'Parc':
        relevance += parameters.preferScenic ? 2.0 : 1.0;
        break;
      case 'Point de vue':
        relevance += parameters.preferScenic ? 1.5 : 0.5;
        break;
      case 'Eau potable':
        relevance += 1.0;
        break;
      case 'Toilettes':
        relevance += 0.8;
        break;
    }
    
    // Malus distance
    if (distance > 500) relevance *= 0.5;
    
    return relevance;
  }

  /// Estime les tokens du prompt final
  static int estimatePromptTokens(
    RouteParameters parameters,
    Map<String, dynamic> filteredNetworkData,
    List<Map<String, dynamic>> pois,
  ) {
    final segments = filteredNetworkData['network'] as List;
    const baseTokens = 800; // Contexte + instructions + format
    const tokensPerSegment = 12; // Format ultra-compact
    const tokensPerPoi = 8;
    
    return baseTokens + (segments.length * tokensPerSegment) + (pois.length * tokensPerPoi);
  }
}