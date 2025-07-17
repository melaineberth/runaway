import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/config/secure_config.dart';

class GeocodingService {
  static final String _baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  // 🆕 SÉCURISATION: Utiliser le token sécurisé avec lazy loading
  static String get _accessToken => SecureConfig.mapboxToken;
  
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
      
      LogConfig.logInfo('🔍 URL de recherche: $url');
      LogConfig.logInfo('🔍 Limite demandée: $limit');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        LogConfig.logInfo('🔍 Nombre de résultats reçus de Mapbox: ${features.length}');
        LogConfig.logInfo('🔍 Query: "$query"');
        
        // 🐛 DEBUG: Afficher la réponse complète pour analyse
        LogConfig.logInfo('🔍 Réponse complète: ${json.encode(data)}');
        
        final suggestions = features.map((feature) => AddressSuggestion(
          id: feature['id'],
          placeName: feature['place_name'],
          center: [feature['center'][0], feature['center'][1]],
          relevance: feature['relevance'].toDouble(),
        )).toList();
        
        LogConfig.logInfo('🔍 Nombre final de suggestions: ${suggestions.length}');
        
        return suggestions;
      } else {
        LogConfig.logError('❌ Erreur HTTP: ${response.statusCode}');
        LogConfig.logError('❌ Response body: ${response.body}');
      }
      
      return [];
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de la recherche d\'adresse: $e');
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