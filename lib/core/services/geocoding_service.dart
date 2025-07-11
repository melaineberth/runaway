import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeocodingService {
  static final String _baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static final String _accessToken = dotenv.get('MAPBOX_TOKEN');
  
  // Recherche d'adresses avec autocomplétion
  static Future<List<AddressSuggestion>> searchAddress(
    String query, {
    double? longitude, 
    double? latitude,
    int limit = 30,
  }) async {
    if (query.isEmpty) return [];
    
    try {
      // 🆕 Version alternative sans restriction de types
      String url = '$_baseUrl/${Uri.encodeComponent(query)}.json?access_token=$_accessToken&limit=$limit&language=fr&autocomplete=true';
      
      if (longitude != null && latitude != null) {
        url += '&proximity=$longitude,$latitude';
      }
      
      print('🔍 URL de recherche: $url');
      print('🔍 Limite demandée: $limit');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        print('🔍 Nombre de résultats reçus de Mapbox: ${features.length}');
        print('🔍 Query: "$query"');
        
        // 🐛 DEBUG: Afficher la réponse complète pour analyse
        print('🔍 Réponse complète: ${json.encode(data)}');
        
        final suggestions = features.map((feature) => AddressSuggestion(
          id: feature['id'],
          placeName: feature['place_name'],
          center: [feature['center'][0], feature['center'][1]],
          relevance: feature['relevance'].toDouble(),
        )).toList();
        
        print('🔍 Nombre final de suggestions: ${suggestions.length}');
        
        return suggestions;
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
      }
      
      return [];
    } catch (e) {
      print('❌ Erreur lors de la recherche d\'adresse: $e');
      return [];
    }
  }
}

class AddressSuggestion {
  final String id;
  final String placeName;
  final List<double> center; // [longitude, latitude]
  final double relevance;
  
  AddressSuggestion({
    required this.id,
    required this.placeName,
    required this.center,
    required this.relevance,
  });
}