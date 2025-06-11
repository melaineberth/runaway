import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/route_parameters.dart';

class OverpassPoiService {
  static const String OVERPASS_API_URL = 'https://overpass-api.de/api/interpreter';

  static Future<List<Map<String, dynamic>>> fetchPoisInRadius({
    required double latitude,
    required double longitude,
    required double radiusInMeters,
  }) async {
    final double effectiveRadius = radiusInMeters > 15000 ? 15000 : radiusInMeters;

    final String query = '''
      [out:json][timeout:25];
      (
        way["leisure"="park"]["name"](around:$effectiveRadius,$latitude,$longitude);
        way["natural"="water"]["name"](around:$effectiveRadius,$latitude,$longitude);
        node["tourism"="viewpoint"](around:$effectiveRadius,$latitude,$longitude);
        node["amenity"="drinking_water"](around:$effectiveRadius,$latitude,$longitude);
        node["amenity"="toilets"]["access"!="private"](around:$effectiveRadius,$latitude,$longitude);
      );
      out center;
    ''';

    try {
      final response = await http.post(
        Uri.parse(OVERPASS_API_URL),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List<dynamic>;

        final List<Map<String, dynamic>> pois = [];
        final Set<String> processedIds = {};

        for (final element in elements) {
          final tags = element['tags'] as Map<String, dynamic>?;
          if (tags == null) continue;

          final id = '${element['type']}_${element['id']}';
          if (processedIds.contains(id)) continue;
          processedIds.add(id);

          double? lat, lon;
          if (element['type'] == 'node') {
            lat = element['lat']?.toDouble();
            lon = element['lon']?.toDouble();
          } else if (element['type'] == 'way' && element['center'] != null) {
            lat = element['center']['lat']?.toDouble();
            lon = element['center']['lon']?.toDouble();
          }

          if (lat == null || lon == null) continue;

          final distance = _calculateDistance(latitude, longitude, lat, lon);
          if (distance > radiusInMeters) continue;

          final name = tags['name'] ?? _getDefaultName(tags);
          final type = _categorizePoiType(tags);

          pois.add({
            'id': id,
            'name': name,
            'type': type,
            'coordinates': [lon, lat],
            'tags': tags,
            'distance': distance,
          });
        }

        pois.sort((a, b) => a['distance'].compareTo(b['distance']));

        print('✅ ${pois.length} POIs retenus pour la génération');

        return pois;
      } else {
        throw Exception('Overpass API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur Overpass: $e');
      return [];
    }
  }

  static String _categorizePoiType(Map<String, dynamic> tags) {
    if (tags['leisure'] == 'park') return 'Parc';
    if (tags['natural'] == 'water') return 'Point d\'eau';
    if (tags['tourism'] == 'viewpoint') return 'Point de vue';
    if (tags['amenity'] == 'drinking_water') return 'Eau potable';
    if (tags['amenity'] == 'toilets') return 'Toilettes';
    return 'Autre';
  }

  static String _getDefaultName(Map<String, dynamic> tags) {
    if (tags['leisure'] == 'park') return 'Parc';
    if (tags['natural'] == 'water') return 'Plan d\'eau';
    if (tags['tourism'] == 'viewpoint') return 'Point de vue';
    if (tags['amenity'] == 'drinking_water') return 'Fontaine';
    if (tags['amenity'] == 'toilets') return 'Toilettes publiques';
    return 'Lieu';
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
              sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static Future<List<List<double>>> generateRoute({
    required RouteParameters parameters,
    required List<Map<String, dynamic>> pois,
  }) async {
    if (pois.isEmpty) return [];

    final List<List<double>> selectedPoints = [];

    final start = pois.firstWhere((p) => p['coordinates'] != null, orElse: () => pois[0]);
    selectedPoints.add(start['coordinates']);

    double targetDistance = parameters.distanceKm * 1000;
    double currentDistance = 0.0;
    final used = <String>{start['id']};

    while (currentDistance < targetDistance * 0.9) {
      final current = selectedPoints.last;

      final candidates = pois.where((p) {
        final coord = p['coordinates'];
        final id = p['id'];
        final dist = _calculateDistance(current[1], current[0], coord[1], coord[0]);
        return !used.contains(id) && dist > 50 && dist < 1500;
      }).toList();

      if (candidates.isEmpty) break;

      candidates.sort((a, b) {
        final d1 = _calculateDistance(current[1], current[0], a['coordinates'][1], a['coordinates'][0]);
        final d2 = _calculateDistance(current[1], current[0], b['coordinates'][1], b['coordinates'][0]);
        return d1.compareTo(d2);
      });

      final next = candidates.first;
      selectedPoints.add(next['coordinates']);
      used.add(next['id']);

      currentDistance = _computeTotalDistance(selectedPoints);
    }

    if (selectedPoints.length >= 2) {
      selectedPoints.add(selectedPoints.first);
    }

    final routedCoords = await OpenRouteService.generateFullRoute(selectedPoints);
    return routedCoords;
  }

  static double _computeTotalDistance(List<List<double>> coords) {
    double dist = 0.0;
    for (int i = 0; i < coords.length - 1; i++) {
      dist += _calculateDistance(
        coords[i][1], coords[i][0],
        coords[i + 1][1], coords[i + 1][0],
      );
    }
    return dist;
  }
}

class OpenRouteService {
  static const String _baseUrl = 'https://api.openrouteservice.org/v2/directions/foot-walking';
  static final String _apiKey = dotenv.env['ORS_TOKEN'] ?? '';

  static Future<List<List<double>>> generateFullRoute(List<List<double>> waypoints) async {
    if (_apiKey.isEmpty) {
      print('❌ Clé ORS_TOKEN absente');
      throw Exception('ORS_TOKEN manquant');
    }

    if (waypoints.length < 2) return [];

    final body = {
      'coordinates': waypoints,
    };

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': _apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final coords = json['features'][0]['geometry']['coordinates'];
      return List<List<double>>.from(coords.map((c) => [c[0].toDouble(), c[1].toDouble()]));
    } else {
      print('❌ Erreur ORS: ${response.statusCode} - ${response.body}');
      return [];
    }
  }
}
