import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class GeoJsonService {
  /// Récupère les ways OSM de type chemin dans le rayon
  Future<List<dynamic>> fetchOsmWays(
      double lat, double lon, double radius) async {
    final query = '''
[out:json][timeout:25];
(
  way["highway"~"footway|path|residential|cycleway"](around:${radius.toInt()},$lat,$lon);
);
out body geom;
''';
    final response = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'data': query},
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur Overpass: ${response.statusCode}');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['elements'] as List<dynamic>;
  }

  /// Construit les features GeoJSON à partir des ways
  List<Map<String, dynamic>> buildGeoJsonFeatures(List<dynamic> ways) {
    return ways.map((way) {
      final tags = way['tags'] as Map<String, dynamic>? ?? {};
      final coords = (way['geometry'] as List)
          .map((pt) => [pt['lon'], pt['lat']])
          .toList();
      return {
        'type': 'Feature',
        'properties': {
          'highway': tags['highway'],
          'surface': tags['surface'],
          'access': tags['access'],
          'name': tags['name'],
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': coords,
        }
      };
    }).toList();
  }

  /// Ajoute élévation via OpenTopography (/globaldem) en Dart
  Future<List<Map<String, dynamic>>> addElevationORS(List<Map<String, dynamic>> features) async {
    final _apiKey = dotenv.get('ORS_TOKEN');
    for (var feat in features) {
      final coords = feat['geometry']['coordinates'] as List;
      // start & end points
      final points = [coords.first, coords.last];

      for (var point in points) {
        final lon = point[0] as double;
        final lat = point[1] as double;

        // Construction du body selon la doc ORS
        final body = json.encode({
          'format_in': 'point',
          'geometry': [lon, lat],
        });

        final response = await http.post(
          Uri.parse('https://api.openrouteservice.org/elevation/point'),
          headers: {
            'Authorization': _apiKey,
            'Content-Type': 'application/json',
          },
          body: body,
        );

        if (response.statusCode != 200) {
          throw Exception('ORS Elevation error: ${response.statusCode}');
        }

        final jsonResp = json.decode(response.body) as Map<String, dynamic>;
        // La réponse GeoJSON contient geometry.coordinates = [lon, lat, ele]
        final geometry = jsonResp['geometry'] as Map<String, dynamic>?;
        if (geometry != null && geometry['coordinates'] is List) {
          final coords3d = (geometry['coordinates'] as List).cast<num>();
          if (coords3d.length >= 3) {
            final ele = coords3d[2];
            // Assigner ele_start sur le premier point, ele_end sur le deuxième
            if (point == coords.first) {
              feat['properties']['ele_start'] = ele;
            } else {
              feat['properties']['ele_end'] = ele;
            }
          }
        }
      }
    }
    return features;
  }

  /// Sauvegarde le GeoJSON sur le stockage local
  Future<File> saveGeoJson(List<Map<String, dynamic>> features) async {
    final collection = {
      'type': 'FeatureCollection',
      'features': features,
    };
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/network.geojson');
    return file.writeAsString(JsonEncoder.withIndent('  ').convert(collection));
  }

  /// Génération complète
  Future<File> generateNetworkGeoJson(
      double lat, double lon, double radius) async {
    final ways = await fetchOsmWays(lat, lon, radius);
    var features = buildGeoJsonFeatures(ways);
    features = await addElevationORS(features);
    return await saveGeoJson(features);
  }
}