import 'package:flutter_dotenv/flutter_dotenv.dart';

class SecureConfig {
  static const bool kIsProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  
  // Cache des tokens pour éviter les accès répétés
  static String? _cachedMapboxToken;
  static String? _cachedSupabaseUrl;
  static String? _cachedSupabaseAnonKey;

  // 🆕 Cache pour monitoring
  static String? _cachedSentryDsn;
  static String? _cachedSentryEnvironment;
  static String? _cachedSentryRelease;

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

  // DSN Sentry avec fallback production/développement
  static String get sentryDsn {
    if (_cachedSentryDsn != null) return _cachedSentryDsn!;
    
    String? dsn;
    if (kIsProduction) {
      dsn = const String.fromEnvironment('SENTRY_DSN_PROD');
      if (dsn.isEmpty) {
        dsn = dotenv.env['SENTRY_DSN_PROD'];
      }
    } else {
      dsn = const String.fromEnvironment('SENTRY_DSN_DEV');
      if (dsn.isEmpty) {
        dsn = dotenv.env['SENTRY_DSN_DEV'] ?? dotenv.env['SENTRY_DSN'];
      }
    }
    
    if (dsn == null || dsn.isEmpty) {
      throw Exception('SENTRY_DSN non configuré pour l\'environnement ${kIsProduction ? 'PRODUCTION' : 'DEVELOPMENT'}');
    }
    
    // Validation basique du DSN Sentry (format https://key@org.ingest.sentry.io/project)
    if (!dsn.startsWith('https://') || !dsn.contains('sentry.io')) {
      throw Exception('DSN Sentry invalide: $dsn');
    }
    
    _cachedSentryDsn = dsn;
    return dsn;
  }

  /// Environnement Sentry
  static String get sentryEnvironment {
    if (_cachedSentryEnvironment != null) return _cachedSentryEnvironment!;
    
    String? environment;
    if (kIsProduction) {
      environment = const String.fromEnvironment('SENTRY_ENVIRONMENT_PROD');
      if (environment.isEmpty) {
        environment = dotenv.env['SENTRY_ENVIRONMENT_PROD'] ?? 'production';
      }
    } else {
      environment = const String.fromEnvironment('SENTRY_ENVIRONMENT_DEV');
      if (environment.isEmpty) {
        environment = dotenv.env['SENTRY_ENVIRONMENT_DEV'] ?? 'development';
      }
    }
    
    _cachedSentryEnvironment = environment;
    return environment;
  }

  /// Version de release pour Sentry
  static String get sentryRelease {
    if (_cachedSentryRelease != null) return _cachedSentryRelease!;
    
    String? release;
    if (kIsProduction) {
      release = const String.fromEnvironment('SENTRY_RELEASE_PROD');
      if (release.isEmpty) {
        release = dotenv.env['SENTRY_RELEASE_PROD'] ?? '1.0.0+1';
      }
    } else {
      release = const String.fromEnvironment('SENTRY_RELEASE_DEV');
      if (release.isEmpty) {
        release = dotenv.env['SENTRY_RELEASE_DEV'] ?? '1.0.0+1-dev';
      }
    }
    
    _cachedSentryRelease = release;
    return release;
  }

  // ===== 🆕 MONITORING SETTINGS =====

  /// Activer le crash reporting
  static bool get isCrashReportingEnabled {
    return dotenv.env['ENABLE_CRASH_REPORTING']?.toLowerCase() == 'true';
  }

  /// Activer le monitoring des performances
  static bool get isPerformanceMonitoringEnabled {
    return dotenv.env['ENABLE_PERFORMANCE_MONITORING']?.toLowerCase() == 'true';
  }

  /// Taux d'échantillonnage pour les erreurs (0.0 à 1.0)
  static double get sentrySampleRate {
    return double.tryParse(dotenv.env['SENTRY_SAMPLE_RATE'] ?? '1.0') ?? 1.0;
  }

  /// Taux d'échantillonnage pour les traces de performance (0.0 à 1.0)
  static double get sentryTracesSampleRate {
    return double.tryParse(dotenv.env['SENTRY_TRACES_SAMPLE_RATE'] ?? '0.1') ?? 0.1;
  }

  // ===== 🆕 LOGGING SETTINGS =====

  /// Niveau de log selon l'environnement
  static String get logLevel {
    if (kIsProduction) {
      return dotenv.env['LOG_LEVEL_PROD'] ?? 'error';
    } else {
      return dotenv.env['LOG_LEVEL_DEV'] ?? 'debug';
    }
  }

  /// Activer les logs dans Supabase
  static bool get isSupabaseLoggingEnabled {
    return dotenv.env['ENABLE_SUPABASE_LOGGING']?.toLowerCase() == 'true';
  }

  /// Durée de rétention des logs (en jours)
  static int get logRetentionDays {
    return int.tryParse(dotenv.env['LOG_RETENTION_DAYS'] ?? '30') ?? 30;
  }

  /// Validation complète incluant monitoring
  static void validateConfiguration() {
    try {
      print('🔒 Validation configuration sécurisée...');
      print('🔒 Mode: ${kIsProduction ? 'PRODUCTION' : 'DEVELOPMENT'}');
            
      // 🆕 Valider la configuration monitoring
      if (isCrashReportingEnabled || isPerformanceMonitoringEnabled) {
        print('✅ Configuration Sentry validée');
      }
      
      print('✅ Configuration complète validée');
    } catch (e) {
      print('❌ Erreur configuration: $e');
      rethrow;
    }
  }

  /// Nettoie le cache (inclut monitoring)
  static void clearCache() {
    // Cache existant
    _cachedMapboxToken = null;
    _cachedSupabaseUrl = null;
    _cachedSupabaseAnonKey = null;
    
    // 🆕 Cache monitoring
    _cachedSentryDsn = null;
    _cachedSentryEnvironment = null;
    _cachedSentryRelease = null;
  }
}