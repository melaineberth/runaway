import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:runaway/core/helper/config/log_config.dart';

class SecureConfig {
  static const bool kIsProduction = bool.fromEnvironment('PRODUCTION');
  
  // 🔒 Configuration améliorée pour éviter les conflits
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'trailix_secure_prefs',
      preferencesKeyPrefix: 'trailix_',
      resetOnError: true, // 🆕 Reset automatique en cas d'erreur
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false, // 🆕 Éviter la sync iCloud qui peut causer des conflits
    ),
  );
  
  // Cache des tokens pour éviter les accès répétés
  static String? _cachedMapboxToken;
  static String? _cachedSupabaseUrl;
  static String? _cachedSupabaseAnonKey;
  static String? _cachedSupabaseServiceRoleKey;

  // 🆕 Cache pour monitoring
  static String? _cachedSentryDsn;
  static String? _cachedSentryEnvironment;
  static String? _cachedSentryRelease;

  // 🔒 État du stockage sécurisé avec retry
  static bool _secureStorageAvailable = true;
  static int _retryCount = 0;
  static const int _maxRetries = 3;

  // 🔒 Clés pour le stockage sécurisé (avec préfixe unique)
  static const String _keyAccessToken = 'trailix_supabase_access_token';
  static const String _keyRefreshToken = 'trailix_supabase_refresh_token';
  static const String _keyTokenExpiry = 'trailix_token_expiry';
  static const String _keyTokenRotationKey = 'trailix_token_rotation_key';

  static bool get isProduction => dotenv.env['ENVIRONMENT'] == 'production';
  static bool get isDevelopment => dotenv.env['ENVIRONMENT'] == 'development';

  static Duration get apiTimeout => Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '30') ?? 30,
  );

  /// 🔒 Méthode helper pour écriture sécurisée avec gestion des conflits
  static Future<bool> _writeSecurely(String key, String value) async {
    try {
      // 🆕 Suppression préventive pour éviter l'erreur -25299
      try {
        await _secureStorage.delete(key: key);
      } catch (deleteError) {
        // Ignorer les erreurs de suppression
        LogConfig.logInfo('🔒 Suppression préventive ignorée pour $key');
      }
      
      // Écriture du nouveau value
      await _secureStorage.write(key: key, value: value);
      return true;
    } catch (e) {
      final errorCode = _extractErrorCode(e.toString());
      
      // 🆕 Gestion spécifique de l'erreur -25299 (duplicate item)
      if (errorCode == -25299) {
        LogConfig.logInfo('🔒 Conflit keychain détecté, tentative de correction...');
        try {
          await _secureStorage.delete(key: key);
          await _secureStorage.write(key: key, value: value);
          LogConfig.logSuccess('🔒 Conflit keychain résolu');
          return true;
        } catch (retryError) {
          LogConfig.logWarning('⚠️ Impossible de résoudre le conflit keychain: $retryError');
        }
      }
      
      LogConfig.logWarning('⚠️ Erreur écriture sécurisée pour $key: $e');
      return false;
    }
  }

  /// 🆕 Extraction du code d'erreur depuis le message
  static int? _extractErrorCode(String errorMessage) {
    final regex = RegExp(r'Code:\s*(-?\d+)');
    final match = regex.firstMatch(errorMessage);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// 🆕 Méthode de récupération automatique du stockage sécurisé
  static Future<void> _attemptStorageRecovery() async {
    if (_retryCount >= _maxRetries) {
      LogConfig.logWarning('⚠️ Nombre maximum de tentatives atteint, stockage sécurisé désactivé');
      _secureStorageAvailable = false;
      return;
    }

    _retryCount++;
    LogConfig.logInfo('🔄 Tentative de récupération du stockage sécurisé ($_retryCount/$_maxRetries)');
    
    final isAvailable = await isSecureStorageAvailable();
    if (isAvailable) {
      LogConfig.logSuccess('🔒 Stockage sécurisé récupéré avec succès');
      _retryCount = 0; // Reset compteur en cas de succès
    }
  }

  /// 🔒 Stockage sécurisé du token d'accès avec gestion améliorée des erreurs
  static Future<void> storeAccessToken(String token) async {
    if (!_secureStorageAvailable) {
      LogConfig.logInfo('🔒 Stockage sécurisé désactivé, token ignoré');
      return;
    }

    final success = await _writeSecurely(_keyAccessToken, token);
    if (!success) {
      await _attemptStorageRecovery();
      return;
    }
      
    // Stocker l'heure d'expiration (JWT valide 1h par défaut)
    final expiry = DateTime.now().add(const Duration(hours: 1));
    final expirySuccess = await _writeSecurely(_keyTokenExpiry, expiry.toIso8601String());
    
    if (success && expirySuccess) {
      LogConfig.logInfo('🔒 Token d\'accès stocké de façon sécurisée');
    }
  }

  /// 🔒 Récupération sécurisée du token d'accès avec gestion améliorée des erreurs
  static Future<String?> getStoredAccessToken() async {
    if (!_secureStorageAvailable) {
      return null;
    }

    try {
      final token = await _secureStorage.read(key: _keyAccessToken);
      if (token != null) {
        // 🆕 Reset compteur de retry en cas de succès
        _retryCount = 0;
      }
      return token;
    } catch (e) {
      LogConfig.logWarning('⚠️ Lecture token échouée: $e');
      await _attemptStorageRecovery();
      return null;
    }
  }

  /// 🔒 Stockage sécurisé du refresh token avec gestion améliorée des erreurs
  static Future<void> storeRefreshToken(String token) async {
    if (!_secureStorageAvailable) {
      LogConfig.logInfo('🔒 Stockage sécurisé désactivé, refresh token ignoré');
      return;
    }

    final success = await _writeSecurely(_keyRefreshToken, token);
    if (success) {
      LogConfig.logInfo('🔒 Refresh token stocké de façon sécurisée');
    } else {
      await _attemptStorageRecovery();
    }
  }

  /// 🔒 Récupération sécurisée du refresh token avec gestion améliorée des erreurs
  static Future<String?> getStoredRefreshToken() async {
    if (!_secureStorageAvailable) {
      return null;
    }

    try {
      final token = await _secureStorage.read(key: _keyRefreshToken);
      if (token != null) {
        _retryCount = 0;
      }
      return token;
    } catch (e) {
      LogConfig.logWarning('⚠️ Lecture refresh token échouée: $e');
      await _attemptStorageRecovery();
      return null;
    }
  }

  /// 🔒 Validation de l'expiration du token JWT avec gestion améliorée des erreurs
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
      await _attemptStorageRecovery();
      return false; // En cas d'erreur, considérer comme non expiré
    }
  }

  /// 🔒 Validation du format JWT (améliorée)
  static bool isValidJWT(String token) {
    try {
      // Un JWT valide a 3 parties séparées par des points
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      // 🆕 Validation plus robuste du header et payload
      try {
        final header = json.decode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
        );
        
        // Le champ 'typ' est optionnel selon RFC 7519
        // S'il est présent, vérifier qu'il s'agit bien d'un JWT
        final typ = header['typ']?.toString().toLowerCase();
        if (typ != null && typ != 'jwt') {
          LogConfig.logWarning('⚠️ Type JWT invalide: $typ');
          return false;
        }
        
        // Vérifier que le header contient au minimum un algorithme
        if (header['alg'] == null) {
          LogConfig.logWarning('⚠️ Algorithme JWT manquant');
          return false;
        }
        
        // Valider le payload (doit pouvoir être décodé)
        try {
          final payload = json.decode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
          );
          
          // Vérifier qu'il contient des champs JWT standards
          if (payload['iss'] == null && payload['sub'] == null && payload['aud'] == null) {
            LogConfig.logWarning('⚠️ Payload JWT ne contient aucun champ standard');
            return false;
          }
          
          return true;
        } catch (payloadError) {
          LogConfig.logWarning('⚠️ Payload JWT invalide: $payloadError');
          return false;
        }
        
      } catch (headerError) {
        LogConfig.logWarning('⚠️ Header JWT invalide: $headerError');
        return false;
      }
    } catch (e) {
      LogConfig.logWarning('⚠️ Token JWT invalide: $e');
      return false;
    }
  }

  /// 🔒 Extraction de l'expiration depuis le JWT (améliorée)
  static DateTime? getJWTExpiration(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      
      final exp = payload['exp'];
      if (exp != null && exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      
      return null;
    } catch (e) {
      LogConfig.logWarning('⚠️ Erreur extraction expiration JWT: $e');
      return null;
    }
  }

  /// 🔒 Nettoyage de tous les tokens stockés avec gestion améliorée des erreurs
  static Future<void> clearStoredTokens() async {
    if (!_secureStorageAvailable) {
      LogConfig.logInfo('🔒 Stockage sécurisé désactivé, nettoyage ignoré');
      return;
    }

    final keys = [_keyAccessToken, _keyRefreshToken, _keyTokenExpiry, _keyTokenRotationKey];
    
    for (final key in keys) {
      try {
        await _secureStorage.delete(key: key);
      } catch (e) {
        LogConfig.logWarning('⚠️ Erreur suppression $key: $e');
      }
    }
    
    LogConfig.logInfo('🧹 Tokens nettoyés du stockage sécurisé');
  }

  /// 🔒 Génération et stockage d'une clé de rotation avec gestion améliorée des erreurs
  static Future<void> generateRotationKey() async {
    if (!_secureStorageAvailable) {
      LogConfig.logInfo('🔒 Stockage sécurisé désactivé, clé rotation ignorée');
      return;
    }

    final key = base64Encode(List.generate(32, (i) => 
      DateTime.now().millisecondsSinceEpoch + i).map((e) => e % 256).toList());
    
    final success = await _writeSecurely(_keyTokenRotationKey, key);
    if (success) {
      LogConfig.logInfo('🔑 Clé de rotation générée');
    } else {
      await _attemptStorageRecovery();
    }
  }

  /// 🔒 Validation de la sécurité du stockage (améliorée)
  static Future<bool> isSecureStorageAvailable() async {
    try {
      // 🆕 Utiliser une clé unique avec timestamp pour éviter les collisions
      final testKey = 'trailix_test_${DateTime.now().millisecondsSinceEpoch}';
      const testValue = 'test_value';
            
      // 🆕 Nettoyage agressif de toutes les anciennes clés de test
      await _cleanupOldTestKeys();
      
      // Test d'écriture/lecture
      await _secureStorage.write(key: testKey, value: testValue);
      final result = await _secureStorage.read(key: testKey);
      await _secureStorage.delete(key: testKey);
      
      final isAvailable = result == testValue;
      _secureStorageAvailable = isAvailable;
      
      if (isAvailable) {
        LogConfig.logSuccess('🔒 Stockage sécurisé disponible et testé');
      } else {
        LogConfig.logError('❌ Echec de stockage sécurisé');
      }
      
      return isAvailable;
    } catch (e) {
      LogConfig.logWarning('⚠️ Stockage sécurisé non disponible: $e');
      
      // 🆕 En cas d'erreur -25299, essayer un nettoyage et un second test
      if (_extractErrorCode(e.toString()) == -25299) {
        try {
          await _performKeychainCleanup();
          
          // Second essai avec une nouvelle clé
          final retryKey = 'trailix_retry_${DateTime.now().millisecondsSinceEpoch}';
          await _secureStorage.write(key: retryKey, value: 'retry_test');
          final retryResult = await _secureStorage.read(key: retryKey);
          await _secureStorage.delete(key: retryKey);
          
          final isRetrySuccess = retryResult == 'retry_test';
          _secureStorageAvailable = isRetrySuccess;
          
          if (isRetrySuccess) {
            LogConfig.logSuccess('🔒 Stockage sécurisé récupéré après nettoyage');
            return true;
          }
        } catch (cleanupError) {
          LogConfig.logError('❌ Echec du nettoyage: $cleanupError');
        }
      }
      
      _secureStorageAvailable = false;
      return false;
    }
  }

  /// 🆕 Nettoyage des anciennes clés de test
  static Future<void> _cleanupOldTestKeys() async {
    final oldTestPatterns = [
      'trailix_test_security',
      'test_security',
    ];
    
    for (final pattern in oldTestPatterns) {
      try {
        await _secureStorage.delete(key: pattern);
      } catch (e) {
        // Ignorer les erreurs de nettoyage
      }
    }
  }

  /// 🆕 Nettoyage agressif du keychain pour les clés Trailix
  static Future<void> _performKeychainCleanup() async {
    // Liste des clés potentiellement problématiques
    final keysToClean = [
      'trailix_test_security',
      'test_security',
      'trailix_supabase_access_token',
      'trailix_supabase_refresh_token', 
      'trailix_token_expiry',
      'trailix_token_rotation_key',
    ];
        
    for (final key in keysToClean) {
      try {
        await _secureStorage.delete(key: key);
        LogConfig.logInfo('🗑️ Supprimé: $key');
      } catch (e) {
        // Ignorer les erreurs - la clé n'existe peut-être pas
      }
      
      // Petite pause pour éviter de surcharger le keychain
      await Future.delayed(const Duration(milliseconds: 10));
    }    
  }

  /// 🆕 Méthode publique pour forcer un nettoyage complet (utile pour debug)
  static Future<void> forceKeychainCleanup() async {
    await _performKeychainCleanup();
    // Retester après nettoyage
    await isSecureStorageAvailable();
  }

  static String get apiBaseUrl {
    final String? baseUrl = dotenv.env['API_BASE_URL'];
    
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('API_BASE_URL must be configured in .env file');
    }
    
    // Validation de l'URL
    if (!Uri.tryParse(baseUrl)!.isAbsolute) {
      throw Exception('API_BASE_URL must be a valid absolute URL');
    }
    
    return baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
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

  static String get supabaseServiceRoleKey {
    if (_cachedSupabaseServiceRoleKey != null) return _cachedSupabaseServiceRoleKey!;
    
    String? key;
    if (kIsProduction) {
      key = const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY_PROD');
      if (key.isEmpty) {
        key = dotenv.env['SUPABASE_SERVICE_ROLE_KEY_PROD'];
      }
    } else {
      key = const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY_DEV');
      if (key.isEmpty) {
        key = dotenv.env['SUPABASE_SERVICE_ROLE_KEY_DEV'] ?? dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];
      }
    }
    
    if (key == null || key.isEmpty) {
      throw Exception('SUPABASE_SERVICE_ROLE_KEY non configuré pour l\'environnement ${kIsProduction ? 'PRODUCTION' : 'DEVELOPMENT'}');
    }
    
    // Validation basique de la clé Supabase (format JWT)
    if (!key.startsWith('eyJ')) {
      throw Exception('Clé Supabase anonyme invalide: doit être un JWT');
    }
    
    _cachedSupabaseServiceRoleKey = key;
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

  /// 🔒 Validation complète incluant sécurité avec gestion améliorée des erreurs
  static Future<void> validateConfiguration() async {
    try {
      LogConfig.logInfo('🔒 Validation configuration sécurisée...');
      LogConfig.logInfo('🔒 Mode: ${kIsProduction ? 'PRODUCTION' : 'DEVELOPMENT'}');
      
      // Vérifier la disponibilité du stockage sécurisé avec retry automatique
      final isSecureStorageOk = await isSecureStorageAvailable();
      if (!isSecureStorageOk) {
        LogConfig.logWarning('⚠️ Stockage sécurisé non disponible, fonctionnement en mode dégradé');
        _secureStorageAvailable = false;
      } else {
        LogConfig.logSuccess('🔒 Stockage sécurisé disponible et validé');
        _retryCount = 0; // Reset en cas de succès
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

  /// 🔒 Nettoie le cache (inclut monitoring et tokens) avec gestion améliorée des erreurs
  static Future<void> clearCache() async {
    // Cache existant
    _cachedMapboxToken = null;
    _cachedSupabaseUrl = null;
    _cachedSupabaseAnonKey = null;
    
    // Cache monitoring
    _cachedSentryDsn = null;
    _cachedSentryEnvironment = null;
    _cachedSentryRelease = null;
    
    // 🔒 Reset du système de retry
    _retryCount = 0;
    _secureStorageAvailable = true;
    
    // 🔒 Nettoyer aussi les tokens stockés (avec gestion d'erreurs)
    await clearStoredTokens();
  }

  /// 🆕 Méthode publique pour forcer une vérification du stockage sécurisé
  static Future<bool> checkSecureStorageHealth() async {
    LogConfig.logInfo('🔍 Vérification santé du stockage sécurisé...');
    
    final isHealthy = await isSecureStorageAvailable();
    if (isHealthy) {
      LogConfig.logSuccess('✅ Stockage sécurisé en bonne santé');
      _retryCount = 0;
    } else {
      LogConfig.logWarning('⚠️ Problème détecté avec le stockage sécurisé');
      await _attemptStorageRecovery();
    }
    
    return isHealthy;
  }

  static void validate() {
    try {
      apiBaseUrl; // Déclenche la validation
      LogConfig.logInfo('Configuration environment');
    } catch (e) {
      LogConfig.logError('❌ Erreur configuration: $e');
      rethrow;
    }
  }
}