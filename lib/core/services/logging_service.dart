import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/secure_config.dart';
import 'crash_reporting_service.dart';

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
      'timestamp': timestamp.toIso8601String(),
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
      timestamp: DateTime.parse(json['timestamp']),
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
      print('⚠️ LoggingService déjà initialisé');
      return;
    }

    try {
      print('📝 Initialisation Logging Service...');

      // Configuration du niveau minimum selon l'environnement
      _minimumLevel = _getMinimumLogLevel();

      // Configuration du logger
      _logger = Logger(
        level: _getLoggerLevel(),
        printer: PrettyPrinter(
          methodCount: SecureConfig.kIsProduction ? 0 : 2,
          errorMethodCount: 5,
          lineLength: 120,
          colors: !SecureConfig.kIsProduction,
          printEmojis: !SecureConfig.kIsProduction,
          printTime: true,
        ),
        output: _LogOutput(),
      );

      // Démarrer le timer de flush périodique si Supabase logging activé
      if (SecureConfig.isSupabaseLoggingEnabled) {
        _startPeriodicFlush();
      }

      _isInitialized = true;
      print('✅ Logging Service initialisé');
      
      // Log de test
      info('LoggingService', 'Service de logging initialisé avec succès');
      
    } catch (e, stackTrace) {
      print('❌ Erreur initialisation Logging Service: $e');
      print('Stack trace: $stackTrace');
    }
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
      final logEntry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: message,
        context: context,
        data: data,
        userId: _currentUserId,
        stackTrace: stackTrace,
      );

      // Log local via Logger
      _logToConsole(logEntry, exception);

      // Envoyer vers Sentry si erreur/critique
      if (level == LogLevel.error || level == LogLevel.critical) {
        _logToSentry(logEntry, exception, stackTrace);
      }

      // Ajouter au buffer pour Supabase si activé
      if (SecureConfig.isSupabaseLoggingEnabled) {
        _addToPendingLogs(logEntry);
      }

    } catch (e) {
      print('❌ Erreur lors du logging: $e');
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
      print('❌ Erreur envoi log vers Sentry: $e');
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
      print('❌ Erreur ajout log au buffer: $e');
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

      final logData = logsToSend.map((log) => {
        ...log.toJson(),
        'app_version': '1.0.0', // À récupérer depuis PackageInfo
        'platform': defaultTargetPlatform.name,
        'environment': SecureConfig.sentryEnvironment,
      }).toList();

      await Supabase.instance.client
        .from('app_logs')
        .insert(logData);

      if (!SecureConfig.kIsProduction) {
        print('📤 ${logsToSend.length} log(s) envoyé(s) vers Supabase');
      }
    } catch (e) {
      print('❌ Erreur envoi logs vers Supabase: $e');
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
        return SecureConfig.kIsProduction ? LogLevel.error : LogLevel.debug;
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
      
      print('✅ LoggingService fermé');
    } catch (e) {
      print('❌ Erreur fermeture LoggingService: $e');
    }
  }
}

/// Output personnalisé pour Logger
class _LogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // En production, réduire la sortie console
    if (SecureConfig.kIsProduction) {
      // Afficher seulement les erreurs en production
      if (event.level.index >= Level.error.index) {
        for (final line in event.lines) {
          print(line);
        }
      }
    } else {
      // En développement, afficher tous les logs
      for (final line in event.lines) {
        print(line);
      }
    }
  }
}