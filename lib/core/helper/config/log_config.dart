import 'package:runaway/core/helper/config/secure_config.dart';

/// Configuration centralisée pour le logging simplifié
class LogConfig {
  LogConfig._();
  
  // 🔧 CONTRÔLE PRINCIPAL: Active/désactive la verbosité
  static bool get isVerboseLoggingEnabled {
    // En production: jamais de logs verbeux
    if (SecureConfig.kIsProduction) return false;
    
    // En debug: configurable via environnement
    return _getBoolFromEnv('VERBOSE_LOGS', defaultValue: true);
  }
  
  // 🔧 LOGGING PAR CATÉGORIE
  static bool get enableBlocLogs {
    if (SecureConfig.kIsProduction) return false;
    return _getBoolFromEnv('ENABLE_BLOC_LOGS', defaultValue: false);
  }
  
  static bool get enableConnectivityLogs {
    if (SecureConfig.kIsProduction) return false;
    return _getBoolFromEnv('ENABLE_CONNECTIVITY_LOGS', defaultValue: false);
  }
  
  static bool get enablePerformanceLogs {
    if (SecureConfig.kIsProduction) return false;
    return _getBoolFromEnv('ENABLE_PERFORMANCE_LOGS', defaultValue: true);
  }
  
  static bool get enableDebugLogs {
    if (SecureConfig.kIsProduction) return false;
    return _getBoolFromEnv('ENABLE_DEBUG_LOGS', defaultValue: false);
  }
  
  // 🔧 NIVEAUX DE LOG SIMPLIFIÉS
  static LogLevel get minimumLogLevel {
    if (SecureConfig.kIsProduction) {
      return LogLevel.error; // Production: seulement erreurs
    }
    
    // Debug: configurable
    final level = _getStringFromEnv('LOG_LEVEL', defaultValue: 'warning');
    switch (level.toLowerCase()) {
      case 'debug': return LogLevel.debug;
      case 'info': return LogLevel.info;
      case 'warning': return LogLevel.warning;
      case 'error': return LogLevel.error;
      default: return LogLevel.warning;
    }
  }
  
  // 🔧 HELPERS pour les logs conditionnels - CORRIGÉ: plus de récursion
  static void logDebug(String message) {
    if (enableDebugLogs) {
      print('🐛 $message'); // ✅ Utilise print directement
    }
  }
  
  static void logInfo(String message) {
    if (isVerboseLoggingEnabled) {
      print('ℹ️ $message'); // ✅ Utilise print directement
    }
  }
  
  static void logWarning(String message) {
    print('⚠️ $message'); // ✅ Utilise print directement
  }
  
  static void logError(String message) {
    print('❌ $message'); // ✅ Utilise print directement
  }
  
  static void logSuccess(String message) {
    if (isVerboseLoggingEnabled) {
      print('✅ $message'); // ✅ Utilise print directement
    }
  }
  
  // 🔧 HELPERS PRIVÉS
  static bool _getBoolFromEnv(String key, {required bool defaultValue}) {
    try {
      final value = String.fromEnvironment(key);
      if (value.isEmpty) return defaultValue;
      return value.toLowerCase() == 'true';
    } catch (e) {
      return defaultValue;
    }
  }
  
  static String _getStringFromEnv(String key, {required String defaultValue}) {
    try {
      final value = String.fromEnvironment(key);
      return value.isEmpty ? defaultValue : value;
    } catch (e) {
      return defaultValue;
    }
  }
}

/// Énumération simplifiée des niveaux de log
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

extension LogLevelExtension on LogLevel {
  int get index {
    switch (this) {
      case LogLevel.debug: return 0;
      case LogLevel.info: return 1;
      case LogLevel.warning: return 2;
      case LogLevel.error: return 3;
    }
  }
  
  String get name {
    switch (this) {
      case LogLevel.debug: return 'DEBUG';
      case LogLevel.info: return 'INFO';
      case LogLevel.warning: return 'WARNING';
      case LogLevel.error: return 'ERROR';
    }
  }
}

/// Mixin pour simplifier l'usage dans les classes
mixin SimpleLogging {
  void logDebug(String message) => LogConfig.logDebug('[$runtimeType] $message');
  void logInfo(String message) => LogConfig.logInfo('[$runtimeType] $message');
  void logWarning(String message) => LogConfig.logWarning('[$runtimeType] $message');
  void logError(String message) => LogConfig.logError('[$runtimeType] $message');
  void logSuccess(String message) => LogConfig.logSuccess('[$runtimeType] $message');
}