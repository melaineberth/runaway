import 'package:flutter_dotenv/flutter_dotenv.dart';

class SecureConfig {
  static const bool kIsProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  
  // Cache des tokens pour éviter les accès répétés
  static String? _cachedMapboxToken;
  static String? _cachedSupabaseUrl;
  static String? _cachedSupabaseAnonKey;

  /// Token Mapbox avec fallback production/développement
  static String get mapboxToken {
    if (_cachedMapboxToken != null) return _cachedMapboxToken!;
    
    String? token;
    if (kIsProduction) {
      token = const String.fromEnvironment('MAPBOX_TOKEN_PROD');
      if (token.isEmpty) {
        token = dotenv.env['MAPBOX_TOKEN_PROD'];
      }
    } else {
      token = const String.fromEnvironment('MAPBOX_TOKEN_DEV');
      if (token.isEmpty) {
        token = dotenv.env['MAPBOX_TOKEN_DEV'] ?? dotenv.env['MAPBOX_TOKEN'];
      }
    }
    
    if (token == null || token.isEmpty) {
      throw Exception('MAPBOX_TOKEN non configuré pour l\'environnement ${kIsProduction ? 'PRODUCTION' : 'DEVELOPMENT'}');
    }
    
    // Validation basique du format Mapbox (commence par pk.)
    if (!token.startsWith('pk.')) {
      throw Exception('Token Mapbox invalide: doit commencer par "pk."');
    }
    
    _cachedMapboxToken = token;
    return token;
  }

  /// URL Supabase sécurisée
  static String get supabaseUrl {
    if (_cachedSupabaseUrl != null) return _cachedSupabaseUrl!;
    
    String? url;
    if (kIsProduction) {
      url = const String.fromEnvironment('SUPABASE_URL_PROD');
      if (url.isEmpty) {
        url = dotenv.env['SUPABASE_URL_PROD'];
      }
    } else {
      url = const String.fromEnvironment('SUPABASE_URL_DEV');
      if (url.isEmpty) {
        url = dotenv.env['SUPABASE_URL_DEV'] ?? dotenv.env['SUPABASE_URL'];
      }
    }
    
    if (url == null || url.isEmpty) {
      throw Exception('SUPABASE_URL non configuré pour l\'environnement ${kIsProduction ? 'PRODUCTION' : 'DEVELOPMENT'}');
    }
    
    // Validation de l'URL Supabase
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute || !url.contains('supabase')) {
      throw Exception('URL Supabase invalide: $url');
    }
    
    _cachedSupabaseUrl = url;
    return url;
  }

  /// Clé anonyme Supabase sécurisée
  static String get supabaseAnonKey {
    if (_cachedSupabaseAnonKey != null) return _cachedSupabaseAnonKey!;
    
    String? key;
    if (kIsProduction) {
      key = const String.fromEnvironment('SUPABASE_ANON_KEY_PROD');
      if (key.isEmpty) {
        key = dotenv.env['SUPABASE_ANON_KEY_PROD'];
      }
    } else {
      key = const String.fromEnvironment('SUPABASE_ANON_KEY_DEV');
      if (key.isEmpty) {
        key = dotenv.env['SUPABASE_ANON_KEY_DEV'] ?? dotenv.env['SUPABASE_ANON_KEY'];
      }
    }
    
    if (key == null || key.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY non configuré pour l\'environnement ${kIsProduction ? 'PRODUCTION' : 'DEVELOPMENT'}');
    }
    
    // Validation basique de la clé Supabase (format JWT)
    if (!key.startsWith('eyJ')) {
      throw Exception('Clé Supabase anonyme invalide: doit être un JWT');
    }
    
    _cachedSupabaseAnonKey = key;
    return key;
  }

  /// Identifiants Google avec validation
  static String get googleWebClientId {
    String? clientId;
    if (kIsProduction) {
      clientId = const String.fromEnvironment('WEB_CLIENT_ID_PROD');
      if (clientId.isEmpty) {
        clientId = dotenv.env['WEB_CLIENT_ID_PROD'];
      }
    } else {
      clientId = const String.fromEnvironment('WEB_CLIENT_ID_DEV');
      if (clientId.isEmpty) {
        clientId = dotenv.env['WEB_CLIENT_ID_DEV'] ?? dotenv.env['WEB_CLIENT_ID'];
      }
    }
    
    if (clientId == null || clientId.isEmpty) {
      throw Exception('WEB_CLIENT_ID non configuré');
    }
    
    if (!clientId.endsWith('.googleusercontent.com')) {
      throw Exception('WEB_CLIENT_ID invalide: doit se terminer par .googleusercontent.com');
    }
    
    return clientId;
  }

  static String get googleIosClientId {
    String? clientId;
    if (kIsProduction) {
      clientId = const String.fromEnvironment('IOS_CLIENT_ID_PROD');
      if (clientId.isEmpty) {
        clientId = dotenv.env['IOS_CLIENT_ID_PROD'];
      }
    } else {
      clientId = const String.fromEnvironment('IOS_CLIENT_ID_DEV');
      if (clientId.isEmpty) {
        clientId = dotenv.env['IOS_CLIENT_ID_DEV'] ?? dotenv.env['IOS_CLIENT_ID'];
      }
    }
    
    if (clientId == null || clientId.isEmpty) {
      throw Exception('IOS_CLIENT_ID non configuré');
    }
    
    if (!clientId.endsWith('.googleusercontent.com')) {
      throw Exception('IOS_CLIENT_ID invalide: doit se terminer par .googleusercontent.com');
    }
    
    return clientId;
  }

  /// Validation complète de la configuration
  static void validateConfiguration() {
    try {
      print('🔒 Validation configuration sécurisée...');
      print('🔒 Mode: ${kIsProduction ? 'PRODUCTION' : 'DEVELOPMENT'}');
      
      // Valider toutes les clés critiques
      final _ = mapboxToken;
      final __ = supabaseUrl;
      final ___ = supabaseAnonKey;
      final ____ = googleWebClientId;
      final _____ = googleIosClientId;
      
      print('✅ Configuration sécurisée validée');
    } catch (e) {
      print('❌ Erreur configuration sécurisée: $e');
      rethrow;
    }
  }

  /// Nettoie le cache (utile pour les tests)
  static void clearCache() {
    _cachedMapboxToken = null;
    _cachedSupabaseUrl = null;
    _cachedSupabaseAnonKey = null;
  }
}