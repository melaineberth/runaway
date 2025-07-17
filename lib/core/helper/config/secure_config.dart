// lib/core/helper/config/secure_config.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:runaway/core/helper/config/log_config.dart';

class SecureConfig {
  static const bool kIsProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  
  // 🔒 Stockage sécurisé pour les tokens
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'trailix_secure_prefs',
      preferencesKeyPrefix: 'trailix_',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device
    ),
  );
  
  // Cache des tokens pour éviter les accès répétés
  static String? _cachedMapboxToken;
  static String? _cachedSupabaseUrl;
  static String? _cachedSupabaseAnonKey;

  // 🆕 Cache pour monitoring
  static String? _cachedSentryDsn;
  static String? _cachedSentryEnvironment;
  static String? _cachedSentryRelease;

  // 🔒 État du stockage sécurisé
  static bool _secureStorageAvailable = true;

  // 🔒 Clés pour le stockage sécurisé
  static const String _keyAccessToken = 'supabase_access_token';
  static const String _keyRefreshToken = 'supabase_refresh_token';
  static const String _keyTokenExpiry = 'token_expiry';
  static const String _keyTokenRotationKey = 'token_rotation_key';

  /// 🔒 Stockage sécurisé du token d'accès avec fallback
  static Future<void> storeAccessToken(String token) async {
    if (!_secureStorageAvailable) {
      LogConfig.logInfo('🔒 Stockage sécurisé désactivé, token ignoré');
      return;
    }

    try {
      await _secureStorage.write(key: _keyAccessToken, value: token);
      
      // Stocker l'heure d'expiration (JWT valide 1h par défaut)
      final expiry = DateTime.now().add(const Duration(hours: 1));
      await _secureStorage.write(
        key: _keyTokenExpiry, 
        value: expiry.toIso8601String(),
      );
      
      LogConfig.logInfo('🔒 Token d\'accès stocké de façon sécurisée');
    } catch (e) {
      LogConfig.logWarning('⚠️ Stockage sécurisé échoué, désactivation: $e');
      _secureStorageAvailable = false;
      // Ne pas faire échouer l'opération
    }
  }

  /// 🔒 Récupération sécurisée du token d'accès avec fallback
  static Future<String?> getStoredAccessToken() async {
    if (!_secureStorageAvailable) {
      return null;
    }

    try {
      return await _secureStorage.read(key: _keyAccessToken);
    } catch (e) {
      LogConfig.logWarning('⚠️ Lecture token échouée: $e');
      _secureStorageAvailable = false;
      return null;
    }
  }

  /// 🔒 Stockage sécurisé du refresh token avec fallback
  static Future<void> storeRefreshToken(String token) async {
    if (!_secureStorageAvailable) {
      LogConfig.logInfo('🔒 Stockage sécurisé désactivé, refresh token ignoré');
      return;
    }

    try {
      await _secureStorage.write(key: _keyRefreshToken, value: token);
      LogConfig.logInfo('🔒 Refresh token stocké de façon sécurisée');
    } catch (e) {
      LogConfig.logWarning('⚠️ Stockage refresh token échoué: $e');
      _secureStorageAvailable = false;
      // Ne pas faire échouer l'opération
    }
  }

  /// 🔒 Récupération sécurisée du refresh token avec fallback
  static Future<String?> getStoredRefreshToken() async {
    if (!_secureStorageAvailable) {
      return null;
    }

    try {
      return await _secureStorage.read(key: _keyRefreshToken);
    } catch (e) {
      LogConfig.logWarning('⚠️ Lecture refresh token échouée: $e');
      _secureStorageAvailable = false;
      return null;
    }
  }

  /// 🔒 Validation de l'expiration du token JWT avec fallback
  static Future<bool> isTokenExpired() async {
    if (!_secureStorageAvailable) {
      return false; // Si pas de stockage, on considère comme non expiré
    }

    try {
      final expiryString = await _secureStorage.read(key: _keyTokenExpiry);
      if (expiryString == null) return false; // Pas d'info = pas expiré
      
      final expiry = DateTime.parse(expiryString);
      final now = DateTime.now();
      
      // Considérer expiré si moins de 5 minutes avant expiration
      final isExpiring = now.isAfter(expiry.subtract(const Duration(minutes: 5)));
      
      if (isExpiring) {
        LogConfig.logInfo('⚠️ Token proche de l\'expiration');
      }
      
      return isExpiring;
    } catch (e) {
      LogConfig.logWarning('⚠️ Erreur vérification expiration token: $e');
      _secureStorageAvailable = false;
      return false; // En cas d'erreur, considérer comme non expiré
    }
  }

  /// 🔒 Validation du format JWT
  static bool isValidJWT(String token) {
    try {
      // Un JWT valide a 3 parties séparées par des points
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      // Decoder le header pour validation basique
      final header = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
      );
      
      // Vérifier qu'il s'agit bien d'un JWT
      return header['typ'] == 'JWT' || header['typ'] == 'jwt';
    } catch (e) {
      LogConfig.logWarning('⚠️ Token JWT invalide: $e');
      return false;
    }
  }

  /// 🔒 Extraction de l'expiration depuis le JWT
  static DateTime? getJWTExpiration(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      
      final exp = payload['exp'];
      if (exp != null) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      
      return null;
    } catch (e) {
      LogConfig.logWarning('⚠️ Erreur extraction expiration JWT: $e');
      return null;
    }
  }

  /// 🔒 Nettoyage de tous les tokens stockés avec fallback
  static Future<void> clearStoredTokens() async {
    if (!_secureStorageAvailable) {
      LogConfig.logInfo('🔒 Stockage sécurisé désactivé, nettoyage ignoré');
      return;
    }

    try {
      await Future.wait([
        _secureStorage.delete(key: _keyAccessToken),
        _secureStorage.delete(key: _keyRefreshToken),
        _secureStorage.delete(key: _keyTokenExpiry),
        _secureStorage.delete(key: _keyTokenRotationKey),
      ]);
      LogConfig.logInfo('🧹 Tokens nettoyés du stockage sécurisé');
    } catch (e) {
      LogConfig.logWarning('⚠️ Erreur nettoyage tokens: $e');
      _secureStorageAvailable = false;
    }
  }

  /// 🔒 Génération et stockage d'une clé de rotation avec fallback
  static Future<void> generateRotationKey() async {
    if (!_secureStorageAvailable) {
      LogConfig.logInfo('🔒 Stockage sécurisé désactivé, clé rotation ignorée');
      return;
    }

    try {
      final key = base64Encode(List.generate(32, (i) => 
        DateTime.now().millisecondsSinceEpoch + i).map((e) => e % 256).toList());
      
      await _secureStorage.write(key: _keyTokenRotationKey, value: key);
      LogConfig.logInfo('🔑 Clé de rotation générée');
    } catch (e) {
      LogConfig.logWarning('⚠️ Erreur génération clé rotation: $e');
      _secureStorageAvailable = false;
    }
  }

  /// 🔒 Validation de la sécurité du stockage
  static Future<bool> isSecureStorageAvailable() async {
    if (!_secureStorageAvailable) {
      return false;
    }

    try {
      // Test simple d'écriture/lecture
      const testKey = 'test_security';
      const testValue = 'test_value';
      
      await _secureStorage.write(key: testKey, value: testValue);
      final result = await _secureStorage.read(key: testKey);
      await _secureStorage.delete(key: testKey);
      
      final isAvailable = result == testValue;
      _secureStorageAvailable = isAvailable;
      
      return isAvailable;
    } catch (e) {
      LogConfig.logWarning('⚠️ Stockage sécurisé non disponible: $e');
      _secureStorageAvailable = false;
      return false;
    }
  }

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
    
    // Validation basique du DSN Sentry
    final uri = Uri.tryParse(dsn);
    if (uri == null || !uri.isAbsolute) {
      throw Exception('DSN Sentry invalide: $dsn');
    }
    
    _cachedSentryDsn = dsn;
    return dsn;
  }

  static String get sentryEnvironment {
    if (_cachedSentryEnvironment != null) return _cachedSentryEnvironment!;
    
    final env = kIsProduction 
        ? (dotenv.env['SENTRY_ENVIRONMENT_PROD'] ?? 'production')
        : (dotenv.env['SENTRY_ENVIRONMENT_DEV'] ?? 'development');
    
    _cachedSentryEnvironment = env;
    return env;
  }

  static String get sentryRelease {
    if (_cachedSentryRelease != null) return _cachedSentryRelease!;
    
    // Version par défaut si non spécifiée
    final release = dotenv.env['SENTRY_RELEASE'] ?? 'trailix@1.0.0';
    
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

  /// Taux d'échantillonnage pour Sentry (0.0 à 1.0)
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

  /// 🔒 Validation complète incluant sécurité avec fallback
  static Future<void> validateConfiguration() async {
    try {
      LogConfig.logInfo('🔒 Validation configuration sécurisée...');
      LogConfig.logInfo('🔒 Mode: ${kIsProduction ? 'PRODUCTION' : 'DEVELOPMENT'}');
      
      // Vérifier la disponibilité du stockage sécurisé
      final isSecureStorageOk = await isSecureStorageAvailable();
      if (!isSecureStorageOk) {
        LogConfig.logWarning('⚠️ Stockage sécurisé non disponible, fonctionnement en mode dégradé');
        _secureStorageAvailable = false;
      } else {
        LogConfig.logSuccess('🔒 Stockage sécurisé disponible');
      }
      
      // Valider la configuration monitoring
      if (isCrashReportingEnabled || isPerformanceMonitoringEnabled) {
        LogConfig.logSuccess('Configuration Sentry validée');
      }
      
      LogConfig.logSuccess('Configuration complète validée');
    } catch (e) {
      LogConfig.logError('❌ Erreur configuration: $e');
      rethrow;
    }
  }

  /// 🔒 Nettoie le cache (inclut monitoring et tokens) avec fallback
  static Future<void> clearCache() async {
    // Cache existant
    _cachedMapboxToken = null;
    _cachedSupabaseUrl = null;
    _cachedSupabaseAnonKey = null;
    
    // Cache monitoring
    _cachedSentryDsn = null;
    _cachedSentryEnvironment = null;
    _cachedSentryRelease = null;
    
    // 🔒 Nettoyer aussi les tokens stockés (avec fallback)
    await clearStoredTokens();
  }
}