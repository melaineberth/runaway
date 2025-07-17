import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runaway/core/helper/config/log_config.dart';

class ReverseGeocodingService {
  static final String _baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static const String _cachePrefix = 'reverse_geocoding_';
  static const Duration _cacheExpiration = Duration(hours: 24);

  /// Obtient le nom de la localisation à partir des coordonnées
  static Future<LocationInfo> getLocationName({
    required double latitude,
    required double longitude,
    bool useCache = true,
  }) async {
    try {
      // Générer une clé de cache basée sur les coordonnées arrondies
      final cacheKey = _generateCacheKey(latitude, longitude);
      
      // Vérifier le cache d'abord
      if (useCache) {
        final cachedResult = await _getCachedLocation(cacheKey);
        if (cachedResult != null) {
          LogConfig.logInfo('📍 Localisation depuis cache: ${cachedResult.displayName}');
          return cachedResult;
        }
      }

      // Faire l'appel API si pas en cache
      final locationInfo = await _fetchLocationFromAPI(latitude, longitude);
      
      // Mettre en cache le résultat
      if (useCache) {
        await _cacheLocation(cacheKey, locationInfo);
      }

      LogConfig.logInfo('📍 Localisation depuis API: ${locationInfo.displayName}');
      return locationInfo;

    } catch (e) {
      LogConfig.logError('❌ Erreur reverse geocoding: $e');
      return LocationInfo.fallback(latitude, longitude);
    }
  }

  /// Obtient le nom de localisation pour une route (utilise le point de départ)
  static Future<LocationInfo> getLocationNameForRoute(List<List<double>> coordinates) async {
    if (coordinates.isEmpty) {
      return LocationInfo.unknown();
    }

    // Utiliser le point de départ de la route
    final startCoord = coordinates.first;
    return getLocationName(
      latitude: startCoord[1],
      longitude: startCoord[0],
    );
  }

  /// Batch geocoding pour plusieurs routes
  static Future<Map<String, LocationInfo>> getLocationNamesForRoutes(
    Map<String, List<List<double>>> routeCoordinates,
  ) async {
    final results = <String, LocationInfo>{};
    
    // Traiter par lots pour éviter de surcharger l'API
    const batchSize = 5;
    final entries = routeCoordinates.entries.toList();
    
    for (int i = 0; i < entries.length; i += batchSize) {
      final batch = entries.skip(i).take(batchSize);
      
      final futures = batch.map((entry) async {
        final routeId = entry.key;
        final coordinates = entry.value;
        
        if (coordinates.isNotEmpty) {
          final location = await getLocationName(
            latitude: coordinates.first[1],
            longitude: coordinates.first[0],
          );
          return MapEntry(routeId, location);
        }
        
        return MapEntry(routeId, LocationInfo.unknown());
      });

      final batchResults = await Future.wait(futures);
      for (final result in batchResults) {
        results[result.key] = result.value;
      }

      // Délai entre les lots pour respecter les limites de l'API
      if (i + batchSize < entries.length) {
        await Future.delayed(Duration(milliseconds: 200));
      }
    }

    return results;
  }

  /// Fait l'appel API Mapbox pour le reverse geocoding
  static Future<LocationInfo> _fetchLocationFromAPI(
    double latitude,
    double longitude,
  ) async {
    final url = '$_baseUrl/$longitude,$latitude.json?access_token=${SecureConfig.mapboxToken}&types=place,locality,neighborhood,address&language=fr&limit=1';
    
    final response = await http.get(Uri.parse(url)).timeout(
      Duration(seconds: 10),
    );
    
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final data = json.decode(response.body);
    final features = data['features'] as List;
    
    if (features.isEmpty) {
      return LocationInfo.fallback(latitude, longitude);
    }

    final feature = features.first;
    return LocationInfo.fromMapboxFeature(feature, latitude, longitude);
  }

  /// Génère une clé de cache basée sur les coordonnées arrondies
  static String _generateCacheKey(double latitude, double longitude) {
    // Arrondir à 3 décimales (~100m de précision) pour le cache
    final lat = (latitude * 1000).round() / 1000;
    final lon = (longitude * 1000).round() / 1000;
    return '$_cachePrefix${lat}_$lon';
  }

  /// Récupère une localisation depuis le cache
  static Future<LocationInfo?> _getCachedLocation(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      
      if (cachedJson == null) return null;

      final data = json.decode(cachedJson) as Map<String, dynamic>;
      
      // Vérifier l'expiration
      final cachedAt = DateTime.parse(data['cached_at']);
      if (DateTime.now().difference(cachedAt) > _cacheExpiration) {
        // Supprimer le cache expiré
        await prefs.remove(cacheKey);
        return null;
      }

      return LocationInfo.fromJson(data['location']);

    } catch (e) {
      LogConfig.logError('❌ Erreur lecture cache geocoding: $e');
      return null;
    }
  }

  /// Met en cache une localisation
  static Future<void> _cacheLocation(String cacheKey, LocationInfo location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cacheData = {
        'location': location.toJson(),
        'cached_at': DateTime.now().toIso8601String(),
      };

      await prefs.setString(cacheKey, json.encode(cacheData));

    } catch (e) {
      LogConfig.logError('❌ Erreur mise en cache geocoding: $e');
    }
  }

  /// Nettoie le cache expiré
  static Future<void> cleanExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));
      
      for (final key in keys) {
        final cachedJson = prefs.getString(key);
        if (cachedJson != null) {
          try {
            final data = json.decode(cachedJson) as Map<String, dynamic>;
            final cachedAt = DateTime.parse(data['cached_at']);
            
            if (DateTime.now().difference(cachedAt) > _cacheExpiration) {
              await prefs.remove(key);
            }
          } catch (e) {
            // Supprimer les entrées corrompues
            await prefs.remove(key);
          }
        }
      }

      LogConfig.logInfo('Cache de géocodage nettoyé');

    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage cache: $e');
    }
  }
}

/// Modèle pour les informations de localisation
class LocationInfo {
  final String displayName;
  final String? city;
  final String? neighborhood;
  final String? address;
  final String? country;
  final double latitude;
  final double longitude;

  const LocationInfo({
    required this.displayName,
    this.city,
    this.neighborhood,
    this.address,
    this.country,
    required this.latitude,
    required this.longitude,
  });

  /// Crée une LocationInfo depuis une feature Mapbox
  factory LocationInfo.fromMapboxFeature(
    Map<String, dynamic> feature,
    double lat,
    double lon,
  ) {
    final context = feature['context'] as List<dynamic>? ?? [];
    final placeName = feature['place_name'] as String? ?? '';

    // Extraire les informations du contexte
    String? city;
    String? neighborhood;
    String? country;

    for (final item in context) {
      final id = item['id'] as String? ?? '';
      final text = item['text'] as String? ?? '';

      if (id.startsWith('place.')) {
        city = text;
      } else if (id.startsWith('neighborhood.')) {
        neighborhood = text;
      } else if (id.startsWith('country.')) {
        country = text;
      }
    }

    // Créer un nom d'affichage intelligent
    String displayName;
    if (neighborhood != null && city != null) {
      displayName = '$neighborhood, $city';
    } else if (city != null) {
      displayName = city;
    } else {
      // Extraire le premier élément significatif du place_name
      final parts = placeName.split(',').map((e) => e.trim()).toList();
      displayName = parts.isNotEmpty ? parts.first : 'Localisation';
    }

    return LocationInfo(
      displayName: displayName,
      city: city,
      neighborhood: neighborhood,
      address: placeName,
      country: country,
      latitude: lat,
      longitude: lon,
    );
  }

  /// Crée une LocationInfo de fallback
  factory LocationInfo.fallback(double lat, double lon) {
    return LocationInfo(
      displayName: 'Localisation',
      latitude: lat,
      longitude: lon,
    );
  }

  /// Crée une LocationInfo inconnue
  factory LocationInfo.unknown() {
    return const LocationInfo(
      displayName: 'Localisation inconnue',
      latitude: 0.0,
      longitude: 0.0,
    );
  }

  /// Crée une LocationInfo depuis JSON
  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      displayName: json['display_name'] as String,
      city: json['city'] as String?,
      neighborhood: json['neighborhood'] as String?,
      address: json['address'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  /// Convertit en JSON
  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'city': city,
      'neighborhood': neighborhood,
      'address': address,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Version courte pour l'affichage dans les listes
  String get shortName {
    if (neighborhood != null) {
      return neighborhood!;
    } else if (city != null) {
      return city!;
    } else {
      return displayName;
    }
  }

  /// Version complète avec le pays
  String get fullName {
    if (country != null && !displayName.contains(country!)) {
      return '$displayName, $country';
    }
    return displayName;
  }

  @override
  String toString() => displayName;
}