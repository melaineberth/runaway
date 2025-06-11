import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class GeoJsonService {
  /// Récupère uniquement les chemins de haute qualité pour les parcours sportifs
  Future<List<dynamic>> fetchHighQualityOsmWays(
      double lat, double lon, double radius) async {
    
    // Ajuster le rayon selon la densité
    final adjustedRadius = math.min(radius, 10000); // Max 10km
    
    // Requête Overpass améliorée pour un meilleur réseau connecté
    final query = '''
[out:json][timeout:30];
(
  // 1. Pistes cyclables et voies vertes (excellentes pour course et vélo)
  way["highway"="cycleway"](around:${adjustedRadius.toInt()},$lat,$lon);
  way["highway"="path"]["bicycle"="designated"](around:${adjustedRadius.toInt()},$lat,$lon);
  way["route"="bicycle"](around:${adjustedRadius.toInt()},$lat,$lon);
  
  // 2. Chemins piétons de qualité
  way["highway"="footway"]["surface"~"^(asphalt|paved|concrete|gravel)\$"](around:${adjustedRadius.toInt()},$lat,$lon);
  way["highway"="footway"]["footway"~"^(sidewalk|crossing)\$"](around:${adjustedRadius.toInt()},$lat,$lon);
  
  // 3. Chemins dans les parcs et espaces verts
  way["highway"~"^(footway|path|track)\$"]["leisure"="park"](around:${adjustedRadius.toInt()},$lat,$lon);
  way["highway"~"^(footway|path)\$"]["landuse"~"^(recreation_ground|grass)\$"](around:${adjustedRadius.toInt()},$lat,$lon);
  
  // 4. Sentiers et chemins naturels
  way["highway"="path"]["surface"!="sand"]["surface"!="mud"](around:${adjustedRadius.toInt()},$lat,$lon);
  way["highway"="track"]["tracktype"~"^(grade1|grade2)\$"](around:${adjustedRadius.toInt()},$lat,$lon);
  
  // 5. Routes résidentielles calmes et zones piétonnes
  way["highway"="pedestrian"](around:${adjustedRadius.toInt()},$lat,$lon);
  way["highway"="living_street"](around:${adjustedRadius.toInt()},$lat,$lon);
  way["highway"="residential"]["maxspeed"~"^(10|20|30)\$"](around:${adjustedRadius.toInt()},$lat,$lon);
  way["highway"="residential"]["traffic_calming"](around:${adjustedRadius.toInt()},$lat,$lon);
  
  // 6. Voies partagées et zones 30
  way["highway"="service"]["service"!="parking_aisle"]["access"!="private"](around:${adjustedRadius.toInt()},$lat,$lon);
  way["highway"="unclassified"]["maxspeed"="30"](around:${adjustedRadius.toInt()},$lat,$lon);
  
  // 7. Chemins le long de l'eau
  way["highway"~"^(footway|path|track)\$"]["waterway"](around:${adjustedRadius.toInt()},$lat,$lon);
  way["highway"~"^(footway|path)\$"]["natural"="coastline"](around:${adjustedRadius.toInt()},$lat,$lon);
);
out body geom;
''';

    print('🔍 Requête Overpass optimisée (rayon: ${(adjustedRadius/1000).toStringAsFixed(1)}km)');

    final response = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'data': query},
    ).timeout(Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Erreur Overpass: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>;
    
    print('✅ ${elements.length} segments récupérés');
    return elements;
  }

  /// Construit et filtre intelligemment les features GeoJSON
  List<Map<String, dynamic>> buildFilteredGeoJsonFeatures(List<dynamic> ways) {
    print('🔧 Filtrage et construction des features...');
    
    final features = <Map<String, dynamic>>[];
    final processedCoords = <String>{};

    for (final way in ways) {
      final tags = way['tags'] as Map<String, dynamic>? ?? {};
      final coords = (way['geometry'] as List)
          .map((pt) => [pt['lon'], pt['lat']])
          .toList();

      // Filtres de base
      if (!_isSegmentWorthKeeping(tags, coords)) continue;

      // Éviter les doublons géographiques
      final coordKey = _generateCoordKey(coords);
      if (processedCoords.contains(coordKey)) continue;
      processedCoords.add(coordKey);

      // Calculer les propriétés
      final length = _calculateSegmentLength(coords);
      final suitability = _calculateSuitability(tags);
      final quality = _calculateQualityScore(tags, length);

      final feature = {
        'type': 'Feature',
        'properties': {
          // Propriétés essentielles
          'highway': tags['highway'],
          'surface': tags['surface'] ?? 'unknown',
          'access': tags['access'] ?? 'yes',
          'name': tags['name'],
          'length_m': length.round(),
          
          // Adaptabilité
          'suitable_running': suitability['running'],
          'suitable_cycling': suitability['cycling'],
          'quality_score': quality,
          
          // Environnement
          'leisure': tags['leisure'],
          'landuse': tags['landuse'],
          'natural': tags['natural'],
          'is_in_park': tags['leisure'] == 'park',
          'is_in_nature': tags['landuse'] == 'forest' || tags['natural'] != null,
          
          // Métadonnées OSM
          'osm_id': way['id'],
          'osm_type': way['type'],
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': coords,
        }
      };

      features.add(feature);
    }

    // Trier par score de qualité et garder les meilleurs
    features.sort((a, b) => (b['properties']['quality_score'] as int)
        .compareTo(a['properties']['quality_score'] as int));

    // Limiter le nombre total (garder les 5000 meilleurs max pour un réseau plus dense)
    final limitedFeatures = features.take(5000).toList();
    
    print('📊 ${limitedFeatures.length} segments conservés après filtrage');
    return limitedFeatures;
  }

  /// Vérifie si un segment vaut la peine d'être gardé
  bool _isSegmentWorthKeeping(Map<String, dynamic> tags, List<dynamic> coords) {
    // Longueur minimum
    if (coords.length < 2) return false;
    
    final length = _calculateSegmentLength(coords);
    if (length < 10) return false; // Au moins 10m (réduit de 20m)
    if (length > 10000) return false; // Max 10km

    final highway = tags['highway'] as String?;
    final access = tags['access'] as String?;
    final surface = tags['surface'] as String?;

    // Exclure les accès strictement interdits
    if (access == 'no') return false;

    // Exclure les routes dangereuses
    if (highway == 'motorway' || highway == 'trunk' || highway == 'motorway_link' || highway == 'trunk_link') return false;

    // Exclure les surfaces vraiment impraticables
    if (surface == 'mud') return false;

    // Accepter plus largement les segments
    // - Tous les chemins piétons et cyclables
    // - Les routes résidentielles calmes
    // - Les chemins dans les parcs et espaces verts
    // - Les chemins même sans nom s'ils sont dans des zones intéressantes
    
    return true; // Accepter par défaut
  }

  /// Génère une clé unique pour détecter les doublons géographiques
  String _generateCoordKey(List<dynamic> coords) {
    if (coords.length < 2) return '';
    final start = coords.first;
    final end = coords.last;
    return '${start[1].toStringAsFixed(5)}_${start[0].toStringAsFixed(5)}_'
           '${end[1].toStringAsFixed(5)}_${end[0].toStringAsFixed(5)}';
  }

  /// Calcule un score de qualité pour prioriser les segments
  int _calculateQualityScore(Map<String, dynamic> tags, double length) {
    int score = 0;

    // Points pour le type de voie
    final highway = tags['highway'] as String?;
    switch (highway) {
      case 'cycleway': score += 12; break;
      case 'footway': score += 10; break;
      case 'path': score += 8; break;
      case 'pedestrian': score += 9; break;
      case 'living_street': score += 7; break;
      case 'residential': score += 5; break;
      case 'track': score += 4; break;
      case 'service': score += 3; break;
      case 'unclassified': score += 2; break;
    }

    // Points pour la surface
    final surface = tags['surface'] as String?;
    switch (surface) {
      case 'asphalt': case 'paved': case 'concrete': score += 6; break;
      case 'gravel': case 'fine_gravel': case 'compacted': score += 4; break;
      case 'ground': case 'earth': score += 2; break;
      case 'grass': score += 1; break;
    }

    // Points pour l'environnement
    if (tags['leisure'] == 'park') score += 10;
    if (tags['landuse'] == 'forest') score += 8;
    if (tags['landuse'] == 'recreation_ground') score += 7;
    if (tags['natural'] != null) score += 6;
    if (tags['waterway'] != null) score += 5;

    // Points pour avoir un nom
    if (tags['name'] != null && (tags['name'] as String).isNotEmpty) score += 4;

    // Points pour la longueur optimale (100-1000m)
    if (length >= 100 && length <= 1000) score += 4;
    else if (length >= 50 && length <= 2000) score += 2;

    // Points pour les aménagements
    if (tags['lit'] == 'yes') score += 2; // Éclairage
    if (tags['bicycle'] == 'designated' || tags['bicycle'] == 'yes') score += 3;
    if (tags['foot'] == 'designated' || tags['foot'] == 'yes') score += 2;
    if (tags['segregated'] == 'yes') score += 2; // Séparation piétons/vélos

    // Malus pour accès restreint
    if (tags['access'] == 'destination') score -= 2;
    if (tags['access'] == 'private') score -= 5;
    if (tags['foot'] == 'no') score -= 10;

    return math.max(0, score);
  }

  /// Ajoute l'élévation par batches optimisés
  Future<List<Map<String, dynamic>>> addOptimizedElevation(
      List<Map<String, dynamic>> features) async {
    final _apiKey = dotenv.get('ORS_TOKEN');
    
    if (_apiKey.isEmpty) {
      print('⚠️ ORS_TOKEN manquant, élévations non ajoutées');
      return features;
    }

    print('🏔️ Ajout optimisé des données d\'élévation...');
    
    // Traiter seulement les segments les plus importants pour l'élévation
    final priorityFeatures = features.where((f) => 
        f['properties']['quality_score'] >= 10 || // Scores élevés
        f['properties']['is_in_park'] == true ||   // Dans les parcs
        f['properties']['length_m'] >= 300         // Segments longs
    ).toList();

    // Limiter à 500 segments max pour les élévations
    final elevationFeatures = priorityFeatures.take(500).toList();
    
    print('📊 Traitement élévation pour ${elevationFeatures.length} segments prioritaires');

    int processed = 0;
    const batchSize = 5; // Traiter par groupes de 5

    for (int i = 0; i < elevationFeatures.length; i += batchSize) {
      final batch = elevationFeatures.skip(i).take(batchSize);
      
      await Future.wait(batch.map((feature) async {
        try {
          final coords = feature['geometry']['coordinates'] as List;
          final startCoord = coords.first;
          final endCoord = coords.last;

          // Points de début et fin seulement
          final elevations = await Future.wait([
            _getElevationForPoint(startCoord[0], startCoord[1], _apiKey),
            _getElevationForPoint(endCoord[0], endCoord[1], _apiKey),
          ]);

          if (elevations[0] != null && elevations[1] != null) {
            feature['properties']['ele_start'] = elevations[0];
            feature['properties']['ele_end'] = elevations[1];
            
            final elevationGain = elevations[1]! - elevations[0]!;
            feature['properties']['elevation_gain'] = elevationGain.round();
            
            final length = feature['properties']['length_m'] as int;
            feature['properties']['grade_percent'] = 
                length > 0 ? ((elevationGain / length) * 100).round() : 0;
          }
        } catch (e) {
          // Ignorer les erreurs individuelles
        }
      }));

      processed += batch.length;
      if (processed % 20 == 0) {
        print('📍 ${processed}/${elevationFeatures.length} segments traités');
      }

      // Délai entre les batches
      await Future.delayed(Duration(milliseconds: 200));
    }
    
    print('✅ Élévations ajoutées pour $processed segments');
    return features;
  }

  /// Récupère l'élévation pour un point
  Future<double?> _getElevationForPoint(double lon, double lat, String apiKey) async {
    try {
      final body = json.encode({
        'format_in': 'point',
        'geometry': [lon, lat],
      });

      final response = await http.post(
        Uri.parse('https://api.openrouteservice.org/elevation/point'),
        headers: {
          'Authorization': apiKey,
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonResp = json.decode(response.body);
        final coords = jsonResp['geometry']['coordinates'];
        if (coords != null && coords.length >= 3) {
          return coords[2].toDouble();
        }
      }
    } catch (e) {
      // Ignorer les erreurs
    }
    return null;
  }

  /// Sauvegarde avec statistiques améliorées
  Future<File> saveOptimizedGeoJson(
      List<Map<String, dynamic>> features,
      double centerLat,
      double centerLon,
      double radius) async {
    
    // Calculer les statistiques
    final stats = _calculateNetworkStats(features);
    
    final collection = {
      'type': 'FeatureCollection',
      'metadata': {
        'generated_at': DateTime.now().toIso8601String(),
        'generator': 'RunAway App - Optimized Network',
        'center_coordinates': [centerLon, centerLat],
        'search_radius_m': radius,
        'optimization': 'high_quality_only',
        'statistics': stats,
      },
      'features': features,
    };

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/optimized_network_$timestamp.geojson');
    
    final jsonString = JsonEncoder.withIndent('  ').convert(collection);
    await file.writeAsString(jsonString);
    
    print('💾 Réseau optimisé sauvegardé: ${file.path}');
    print('📊 ${features.length} segments, ${stats['total_length_km']}km total');
    
    return file;
  }

  /// Calcule les statistiques du réseau
  Map<String, dynamic> _calculateNetworkStats(List<Map<String, dynamic>> features) {
    final totalLength = features.fold(0.0, (sum, f) => 
        sum + ((f['properties']['length_m'] as int) / 1000.0));
    
    final runningSegments = features.where((f) => 
        f['properties']['suitable_running'] == true).length;
    
    final cyclingSegments = features.where((f) => 
        f['properties']['suitable_cycling'] == true).length;
    
    final parkSegments = features.where((f) => 
        f['properties']['is_in_park'] == true).length;
    
    final namedSegments = features.where((f) => 
        f['properties']['name'] != null).length;

    final avgQuality = features.fold(0.0, (sum, f) => 
        sum + (f['properties']['quality_score'] as int)) / features.length;

    return {
      'total_features': features.length,
      'total_length_km': totalLength.toStringAsFixed(2),
      'running_segments': runningSegments,
      'cycling_segments': cyclingSegments,
      'park_segments': parkSegments,
      'named_segments': namedSegments,
      'average_quality_score': avgQuality.toStringAsFixed(1),
      'coverage_ratio': '${((runningSegments / features.length) * 100).round()}%',
    };
  }

  /// Génération complète optimisée
  Future<File> generateOptimizedNetworkGeoJson(
      double lat, double lon, double radius) async {
    
    print('🚀 Génération optimisée du réseau...');
    print('📍 Centre: $lat, $lon');
    print('🔍 Rayon: ${(radius/1000).toStringAsFixed(1)}km');
    
    try {
      // 1. Récupérer seulement les ways de qualité
      final ways = await fetchHighQualityOsmWays(lat, lon, radius);
      
      // 2. Filtrer et construire intelligemment
      var features = buildFilteredGeoJsonFeatures(ways);
      
      // 3. Ajouter les élévations de manière optimisée
      features = await addOptimizedElevation(features);
      
      // 4. Sauvegarder
      return await saveOptimizedGeoJson(features, lat, lon, radius);
      
    } catch (e) {
      print('❌ Erreur génération optimisée: $e');
      rethrow;
    }
  }

  // Méthodes utilitaires existantes...
  double _calculateSegmentLength(List<dynamic> coords) {
    if (coords.length < 2) return 0.0;
    
    double totalLength = 0.0;
    for (int i = 0; i < coords.length - 1; i++) {
      final lat1 = coords[i][1] as double;
      final lon1 = coords[i][0] as double;
      final lat2 = coords[i + 1][1] as double;
      final lon2 = coords[i + 1][0] as double;
      
      totalLength += _haversineDistance(lat1, lon1, lat2, lon2);
    }
    
    return totalLength;
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000;
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLon = (lon2 - lon1) * (math.pi / 180);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  Map<String, bool> _calculateSuitability(Map<String, dynamic> tags) {
    final highway = tags['highway'] as String?;
    final access = tags['access'] as String?;
    final foot = tags['foot'] as String?;
    final bicycle = tags['bicycle'] as String?;
    final surface = tags['surface'] as String?;
    
    bool runningOk = true;
    bool cyclingOk = true;
    
    // Vérifier l'accès général
    if (access == 'no') {
      runningOk = false;
      cyclingOk = false;
    }
    
    // Vérifier les interdictions spécifiques
    if (foot == 'no') runningOk = false;
    if (bicycle == 'no') cyclingOk = false;
    
    // Vérifier le type de voie
    if (highway == 'motorway' || highway == 'trunk' || highway == 'motorway_link' || highway == 'trunk_link') {
      runningOk = false;
      cyclingOk = false;
    }
    
    // Routes principales : ok pour le vélo seulement si aménagé
    if (highway == 'primary' || highway == 'secondary') {
      runningOk = false;
      if (bicycle != 'designated' && bicycle != 'yes') {
        cyclingOk = false;
      }
    }
    
    // Autorisations explicites
    if (foot == 'designated' || foot == 'yes') runningOk = true;
    if (bicycle == 'designated' || bicycle == 'yes') cyclingOk = true;
    
    // Surfaces impraticables
    if (surface == 'mud') {
      runningOk = false;
      cyclingOk = false;
    } else if (surface == 'sand' || surface == 'grass') {
      cyclingOk = false; // Difficile en vélo mais possible en course
    }
    
    // Cas spéciaux par type de voie
    switch (highway) {
      case 'cycleway':
        cyclingOk = true;
        runningOk = foot != 'no'; // Autorisé sauf interdiction explicite
        break;
      case 'footway':
      case 'pedestrian':
        runningOk = true;
        cyclingOk = bicycle == 'yes' || bicycle == 'designated';
        break;
      case 'path':
      case 'track':
        // Dépend des tags spécifiques et de la surface
        if (surface == 'paved' || surface == 'asphalt') {
          runningOk = foot != 'no';
          cyclingOk = bicycle != 'no';
        }
        break;
    }
    
    return {
      'running': runningOk,
      'cycling': cyclingOk,
    };
  }
}