import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:runaway/core/helper/services/crash_reporting_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runaway/core/helper/config/log_config.dart';

/// Énumération des niveaux de log
enum LogLevel {
  debug,
  info, 
  warning,
  error,
  critical,
}

/// Modèle pour un log structuré
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? context;
  final Map<String, dynamic>? data;
  final String? userId;
  final StackTrace? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.context,
    this.data,
    this.userId,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'log_timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      if (context != null) 'context': context,
      if (data != null) 'data': data,
      if (userId != null) 'user_id': userId,
      if (stackTrace != null) 'stack_trace': stackTrace.toString(),
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['log_timestamp']),
      level: LogLevel.values.firstWhere((e) => e.name == json['level']),
      message: json['message'],
      context: json['context'],
      data: json['data'],
      userId: json['user_id'],
      stackTrace: json['stack_trace'] != null 
        ? StackTrace.fromString(json['stack_trace'])
        : null,
    );
  }
}

/// Service de logging centralisé
class LoggingService {
  static LoggingService? _instance;
  static LoggingService get instance => _instance ??= LoggingService._();
  
  LoggingService._();

  bool _isInitialized = false;
  late Logger _logger;
  String? _currentUserId;
  LogLevel _minimumLevel = LogLevel.debug;
  
  // Buffer pour les logs en attente d'envoi
  final List<LogEntry> _pendingLogs = [];
  Timer? _flushTimer;

  /// Initialise le service de logging
  Future<void> initialize() async {
    if (_isInitialized) {
      LogConfig.logInfo('LoggingService déjà initialisé');
      return;
    }

    try {
      LogConfig.logInfo('📝 Initialisation Logging Service...');

      // Configuration du niveau minimum selon l'environnement
      _minimumLevel = _getMinimumLogLevel();

      // Configuration du logger
      _logger = Logger(
        level: _getLoggerLevel(),
        printer: PrettyPrinter(
          // Réduire les stack traces en production
          methodCount: SecureConfig.kIsProduction ? 0 : 2,
          errorMethodCount: SecureConfig.kIsProduction ? 3 : 8,
          lineLength: 80,
          colors: true,
          printEmojis: !SecureConfig.kIsProduction,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
        output: _LogOutput(),
      );

      // Démarrer le timer de flush périodique si Supabase logging activé
      if (SecureConfig.isSupabaseLoggingEnabled) {
        _startPeriodicFlush();
      }

      _isInitialized = true;
      LogConfig.logInfo('Logging Service initialisé');
      
      // Log de test
      info('LoggingService', 'Service de logging initialisé avec succès');
      
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur initialisation Logging Service: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Map<String, dynamic>? _makeSerializable(Map<String, dynamic>? data) {
    if (data == null) return null;
    
    final serialized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Convertir les enums en String
      if (value is Enum) {
        serialized[key] = '${value.runtimeType}.${value.name}';
      }
      // Convertir les objets complexes avec toJson si disponible
      else if (value != null && value.runtimeType.toString() != 'String' && 
              value.runtimeType.toString() != 'int' && 
              value.runtimeType.toString() != 'double' && 
              value.runtimeType.toString() != 'bool' &&
              value is! List && value is! Map) {
        try {
          // Essayer d'appeler toJson() si disponible
          final dynamic toJsonMethod = value.toJson;
          if (toJsonMethod is Function) {
            serialized[key] = toJsonMethod();
          } else {
            serialized[key] = value.toString();
          }
        } catch (e) {
          serialized[key] = value.toString();
        }
      }
      // Gérer les listes
      else if (value is List) {
        serialized[key] = value.map((item) {
          if (item is Enum) {
            return '${item.runtimeType}.${item.name}';
          } else if (item != null) {
            try {
              final dynamic toJsonMethod = item.toJson;
              if (toJsonMethod is Function) {
                return toJsonMethod();
              }
            } catch (e) {
              // Ignorer les erreurs
            }
          }
          return item?.toString() ?? 'null';
        }).toList();
      }
      // Gérer les maps
      else if (value is Map) {
        serialized[key] = _makeSerializableMap(value as Map<String, dynamic>);
      }
      // Valeurs primitives
      else {
        serialized[key] = value;
      }
    }
    
    return serialized;
  }

  /// Convertit récursivement une Map en format sérialisable
  Map<String, dynamic> _makeSerializableMap(Map<String, dynamic> map) {
    final serialized = <String, dynamic>{};
    
    for (final entry in map.entries) {
      final value = entry.value;
      
      if (value is Enum) {
        serialized[entry.key] = '${value.runtimeType}.${value.name}';
      } else if (value is Map) {
        serialized[entry.key] = _makeSerializableMap(value as Map<String, dynamic>);
      } else if (value is List) {
        serialized[entry.key] = value.map((item) {
          if (item is Enum) {
            return '${item.runtimeType}.${item.name}';
          }
          return item?.toString() ?? 'null';
        }).toList();
      } else {
        serialized[entry.key] = value;
      }
    }
    
    return serialized;
  }

  /// Configure l'utilisateur courant
  void setUser(String? userId) {
    _currentUserId = userId;
    if (userId != null) {
      info('LoggingService', 'Utilisateur configuré pour les logs', data: {'user_id': userId});
    } else {
      info('LoggingService', 'Utilisateur supprimé des logs');
    }
  }

  /// Log de debug
  void debug(String context, String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.debug, context, message, data: data);
  }

  /// Log d'information
  void info(String context, String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.info, context, message, data: data);
  }

  /// Log d'avertissement
  void warning(String context, String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.warning, context, message, data: data);
  }

  /// Log d'erreur
  void error(
    String context, 
    String message, {
    Map<String, dynamic>? data,
    dynamic exception,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error, 
      context, 
      message, 
      data: data, 
      exception: exception,
      stackTrace: stackTrace,
    );
  }

  /// Log critique (erreurs graves)
  void critical(
    String context, 
    String message, {
    Map<String, dynamic>? data,
    dynamic exception,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.critical, 
      context, 
      message, 
      data: data, 
      exception: exception,
      stackTrace: stackTrace,
    );
  }

  /// Méthode de log principale
  void _log(
    LogLevel level,
    String context,
    String message, {
    Map<String, dynamic>? data,
    dynamic exception,
    StackTrace? stackTrace,
  }) {
    if (!_isInitialized || !_shouldLog(level)) return;

    try {
      // Log simplifié sans stack trace détaillée
      final logEntry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: message,
        context: context,
        data: _makeSerializable(data),
        userId: _currentUserId,
        stackTrace: level.index >= LogLevel.error.index ? stackTrace : null,
      );

      // Log local via Logger (déjà filtré par _LogOutput)
      _logToConsole(logEntry, exception);

      // Sentry seulement pour erreurs critiques
      if (level == LogLevel.error || level == LogLevel.critical) {
        _logToSentry(logEntry, exception, stackTrace);
      }

      // Supabase seulement pour warnings et plus
      if (SecureConfig.isSupabaseLoggingEnabled && level.index >= LogLevel.warning.index) {
        _addToPendingLogs(logEntry);
      }

    } catch (e) {
      // Erreur de log simplifiée
      LogConfig.logError('❌ Logging error: $e');
    }
  }

  /// Vérifie si on doit logger ce niveau
  bool _shouldLog(LogLevel level) {
    return level.index >= _minimumLevel.index;
  }

  /// Log vers la console via Logger
  void _logToConsole(LogEntry entry, dynamic exception) {
    final message = '[${entry.context}] ${entry.message}';
    final data = entry.data;

    switch (entry.level) {
      case LogLevel.debug:
        _logger.d(message, error: data);
        break;
      case LogLevel.info:
        _logger.i(message, error: data);
        break;
      case LogLevel.warning:
        _logger.w(message, error: data);
        break;
      case LogLevel.error:
        _logger.e(message, error: data, stackTrace: entry.stackTrace);
        break;
      case LogLevel.critical:
        _logger.f(message, error: data, stackTrace: entry.stackTrace);
        break;
    }
  }

  /// Log vers Sentry
  void _logToSentry(LogEntry entry, dynamic exception, StackTrace? stackTrace) {
    try {
      if (exception != null) {
        // Si c'est une exception, utiliser captureException
        CrashReportingService.instance.captureException(
          exception,
          stackTrace,
          context: entry.context,
          extra: entry.data,
          level: _mapToSentryLevel(entry.level),
        );
      } else {
        // Sinon, utiliser captureMessage
        CrashReportingService.instance.captureMessage(
          '[${entry.context}] ${entry.message}',
          level: _mapToSentryLevel(entry.level),
          context: entry.context,
          extra: entry.data,
        );
      }

      // Ajouter un breadcrumb
      CrashReportingService.instance.addBreadcrumb(
        entry.context ?? 'app',
        entry.message,
        data: entry.data,
        level: _mapToSentryLevel(entry.level),
      );
    } catch (e) {
      LogConfig.logError('❌ Erreur envoi log vers Sentry: $e');
    }
  }

  /// Ajoute un log au buffer pour Supabase
  void _addToPendingLogs(LogEntry entry) {
    try {
      _pendingLogs.add(entry);
      
      // Flush immédiat si erreur critique ou buffer plein
      if (entry.level == LogLevel.critical || _pendingLogs.length >= 10) {
        _flushToSupabase();
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur ajout log au buffer: $e');
    }
  }

  /// Démarre le flush périodique vers Supabase
  void _startPeriodicFlush() {
    _flushTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _flushToSupabase();
    });
  }

  /// Flush les logs vers Supabase
  Future<void> _flushToSupabase() async {
    if (_pendingLogs.isEmpty) return;

    try {
      final logsToSend = List<LogEntry>.from(_pendingLogs);
      _pendingLogs.clear();

      final logData = logsToSend.map((log) {
        try {
          // ✅ FIX: Sérialisation supplémentaire pour Supabase
          final baseData = log.toJson();
          final additionalData = {
            'app_version': '1.0.0',
            'platform': defaultTargetPlatform.name,
            'environment': SecureConfig.sentryEnvironment,
          };
          
          // Fusionner et re-sérialiser
          final mergedData = {...baseData, ...additionalData};
          return _makeSerializable(mergedData) ?? mergedData;
        } catch (e) {
          LogConfig.logError('❌ Erreur sérialisation log individual: $e');
          // Retourner un log minimal en cas d'erreur
          return {
            'timestamp': log.timestamp.toIso8601String(),
            'level': log.level.name,
            'message': log.message,
            'context': log.context,
            'serialization_error': e.toString(),
            'app_version': '1.0.0',
            'platform': defaultTargetPlatform.name,
            'environment': SecureConfig.sentryEnvironment,
          };
        }
      }).toList();

      await Supabase.instance.client
        .from('app_logs')
        .insert(logData);

      if (!SecureConfig.kIsProduction) {
        LogConfig.logInfo('📤 ${logsToSend.length} log(s) envoyé(s) vers Supabase');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur envoi logs vers Supabase: $e');
      // Remettre les logs dans le buffer si l'envoi échoue
      // (mais limiter pour éviter la consommation mémoire)
      if (_pendingLogs.length < 50) {
        // Ne pas remettre les logs pour éviter les boucles infinies
      }
    }
  }

  /// Convertit LogLevel vers SentryLevel
  SentryLevel _mapToSentryLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return SentryLevel.debug;
      case LogLevel.info:
        return SentryLevel.info;
      case LogLevel.warning:
        return SentryLevel.warning;
      case LogLevel.error:
        return SentryLevel.error;
      case LogLevel.critical:
        return SentryLevel.fatal;
    }
  }

  /// Détermine le niveau minimum selon la configuration
  LogLevel _getMinimumLogLevel() {
    final configLevel = SecureConfig.logLevel.toLowerCase();
    switch (configLevel) {
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warning':
        return LogLevel.warning;
      case 'error':
        return LogLevel.error;
      default:
        // Plus restrictif par défaut
        return SecureConfig.kIsProduction ? LogLevel.error : LogLevel.warning;
    }
  }

  /// Convertit vers le niveau Logger
  Level _getLoggerLevel() {
    switch (_minimumLevel) {
      case LogLevel.debug:
        return Level.debug;
      case LogLevel.info:
        return Level.info;
      case LogLevel.warning:
        return Level.warning;
      case LogLevel.error:
        return Level.error;
      case LogLevel.critical:
        return Level.fatal;
    }
  }

  /// Force le flush immédiat de tous les logs en attente
  Future<void> forceFlush() async {
    if (SecureConfig.isSupabaseLoggingEnabled) {
      await _flushToSupabase();
    }
  }

  /// Obtient les statistiques de logging
  Map<String, dynamic> getLoggingStats() {
    return {
      'is_initialized': _isInitialized,
      'minimum_level': _minimumLevel.name,
      'current_user': _currentUserId,
      'pending_logs_count': _pendingLogs.length,
      'supabase_logging_enabled': SecureConfig.isSupabaseLoggingEnabled,
      'environment': SecureConfig.sentryEnvironment,
    };
  }

  /// Dispose le service
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      // Flush final des logs
      if (SecureConfig.isSupabaseLoggingEnabled && _pendingLogs.isNotEmpty) {
        _flushToSupabase();
      }

      _flushTimer?.cancel();
      _flushTimer = null;
      _pendingLogs.clear();
      _isInitialized = false;
      
      LogConfig.logInfo('LoggingService fermé');
    } catch (e) {
      LogConfig.logError('❌ Erreur fermeture LoggingService: $e');
    }
  }
}

/// Output personnalisé pour Logger
class _LogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Seulement erreurs et warnings, plus de debug/info verbeux
    if (SecureConfig.kIsProduction) {
      // Production: seulement erreurs
      if (event.level.index >= Level.error.index) {
        for (final line in event.lines) {
          print(line);
        }
      }
    } else {
      // Debug: warnings et erreurs seulement
      if (event.level.index >= Level.warning.index) {
        for (final line in event.lines) {
          print(line);
        }
      }
    }
  }
}