import 'dart:async';

import 'package:runaway/core/blocs/app_bloc_observer.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'crash_reporting_service.dart';
import 'logging_service.dart';
import 'performance_monitoring_service.dart';

/// Service principal de monitoring qui orchestre tous les autres services
class MonitoringService {
  static MonitoringService? _instance;
  static MonitoringService get instance => _instance ??= MonitoringService._();
  
  MonitoringService._();

  bool _isInitialized = false;
  late AppBlocObserver _blocObserver;
  Timer? _cleanupTimer;
  Timer? _healthCheckTimer;

  /// Initialise tous les services de monitoring
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ MonitoringService déjà initialisé');
      return;
    }

    try {
      print('🔍 Initialisation complète du monitoring...');

      // 1. Initialiser les services de base en parallèle
      await Future.wait([
        CrashReportingService.instance.initialize(),
        PerformanceMonitoringService.instance.initialize(),
        LoggingService.instance.initialize(),
      ]);

      // 2. Configurer le BlocObserver amélioré
      _blocObserver = AppBlocObserver();

      // 3. Démarrer les tâches de maintenance
      _startMaintenanceTasks();

      // 4. Log de succès
      _isInitialized = true;
      print('✅ MonitoringService initialisé avec succès');
      
      LoggingService.instance.info(
        'MonitoringService',
        'Système de monitoring initialisé',
        data: {
          'crash_reporting': SecureConfig.isCrashReportingEnabled,
          'performance_monitoring': SecureConfig.isPerformanceMonitoringEnabled,
          'supabase_logging': SecureConfig.isSupabaseLoggingEnabled,
          'environment': SecureConfig.sentryEnvironment,
        },
      );

      // 5. Créer la table de logs si nécessaire
      print('ℹ️ Vérification tables Supabase reportée après initialisation Supabase');

    } catch (e, stackTrace) {
      print('❌ Erreur initialisation MonitoringService: $e');
      print('Stack trace: $stackTrace');
      
      // Ne pas faire échouer l'app si le monitoring échoue
      try {
        await CrashReportingService.instance.captureException(
          e,
          stackTrace,
          context: 'MonitoringService.initialize',
          level: SentryLevel.error,
        );
      } catch (sentryError) {
        print('❌ Impossible d\'envoyer l\'erreur vers Sentry: $sentryError');
      }
    }
  }

  /// 🆕 Vérifie les tables Supabase après initialisation
  Future<void> checkSupabaseTablesLater() async {
    if (!_isInitialized || !SecureConfig.isSupabaseLoggingEnabled) return;

    try {
      await _ensureSupabaseTablesExist();
    } catch (e) {
      print('❌ Erreur vérification tables Supabase: $e');
    }
  }

  /// Configure un utilisateur dans tous les services
  Future<void> setUser({
    required String userId,
    String? email,
    String? username,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isInitialized) return;

    try {
      await Future.wait([
        CrashReportingService.instance.setUser(
          userId: userId,
          email: email,
          username: username,
          additionalData: additionalData,
        ),
      ]);

      LoggingService.instance.setUser(userId);

      LoggingService.instance.info(
        'MonitoringService',
        'Utilisateur configuré dans tous les services de monitoring',
        data: {
          'user_id': userId,
          'username': username,
          'has_email': email != null,
        },
      );
    } catch (e) {
      print('❌ Erreur configuration utilisateur monitoring: $e');
    }
  }

  /// Supprime l'utilisateur de tous les services
  Future<void> clearUser() async {
    if (!_isInitialized) return;

    try {
      await CrashReportingService.instance.clearUser();
      LoggingService.instance.setUser(null);

      LoggingService.instance.info(
        'MonitoringService',
        'Utilisateur supprimé de tous les services de monitoring',
      );
    } catch (e) {
      print('❌ Erreur suppression utilisateur monitoring: $e');
    }
  }

  /// Capture une erreur applicative avec contexte
  Future<void> captureError(
    dynamic error,
    StackTrace? stackTrace, {
    required String context,
    Map<String, dynamic>? extra,
    bool isCritical = false,
  }) async {
    if (!_isInitialized) return;

    try {
      // Log selon la gravité
      if (isCritical) {
        LoggingService.instance.critical(
          context,
          'Erreur critique: ${error.toString()}',
          data: extra,
          exception: error,
          stackTrace: stackTrace,
        );
      } else {
        LoggingService.instance.error(
          context,
          'Erreur: ${error.toString()}',
          data: extra,
          exception: error,
          stackTrace: stackTrace,
        );
      }

      // Capture Sentry
      await CrashReportingService.instance.captureException(
        error,
        stackTrace,
        context: context,
        extra: extra,
        level: isCritical ? SentryLevel.fatal : SentryLevel.error,
      );
    } catch (e) {
      print('❌ Erreur capture erreur: $e');
    }
  }

  /// Track une opération métier importante
  String trackOperation(
    String operationName, {
    String? description,
    Map<String, dynamic>? data,
  }) {
    if (!_isInitialized) return '';

    try {
      final operationId = PerformanceMonitoringService.instance.startOperation(
        operationName,
        description: description,
        data: data,
      );

      LoggingService.instance.info(
        'OperationTracking',
        'Démarrage opération: $operationName',
        data: {
          'operation_id': operationId,
          'description': description,
          ...?data,
        },
      );

      return operationId;
    } catch (e) {
      print('❌ Erreur track opération: $e');
      return '';
    }
  }

  /// Termine le tracking d'une opération
  void finishOperation(
    String operationId, {
    required bool success,
    String? errorMessage,
    Map<String, dynamic>? data,
  }) {
    if (!_isInitialized || operationId.isEmpty) return;

    try {
      PerformanceMonitoringService.instance.finishOperation(
        operationId,
        success: success,
        errorMessage: errorMessage,
        additionalData: data,
      );

      LoggingService.instance.info(
        'OperationTracking',
        'Fin opération: $operationId',
        data: {
          'success': success,
          'error_message': errorMessage,
          ...?data,
        },
      );
    } catch (e) {
      print('❌ Erreur fin opération: $e');
    }
  }

  /// Track une requête API/Supabase
  String trackApiRequest(
    String endpoint,
    String method, {
    Map<String, dynamic>? headers,
    Map<String, dynamic>? body,
  }) {
    if (!_isInitialized) return '';

    return PerformanceMonitoringService.instance.startNetworkRequest(
      endpoint,
      method,
      headers: headers,
      body: body,
    );
  }

  /// Termine le tracking d'une requête API
  void finishApiRequest(
    String operationId, {
    required int statusCode,
    int? responseSize,
    String? errorMessage,
  }) {
    if (!_isInitialized || operationId.isEmpty) return;

    PerformanceMonitoringService.instance.finishNetworkRequest(
      operationId,
      statusCode: statusCode,
      responseSize: responseSize,
      errorMessage: errorMessage,
    );
  }

  /// Track le chargement d'un écran
  String trackScreenLoad(String screenName) {
    if (!_isInitialized) return '';

    return PerformanceMonitoringService.instance.startScreenLoad(screenName);
  }

  /// Termine le tracking de chargement d'écran
  void finishScreenLoad(
    String operationId, {
    bool success = true,
    String? errorMessage,
  }) {
    if (!_isInitialized || operationId.isEmpty) return;

    PerformanceMonitoringService.instance.finishScreenLoad(
      operationId,
      success: success,
      errorMessage: errorMessage,
    );
  }

  /// Enregistre une métrique métier
  void recordMetric(
    String metricName,
    num value, {
    String? unit,
    Map<String, dynamic>? tags,
  }) {
    if (!_isInitialized) return;

    try {
      PerformanceMonitoringService.instance.recordMetric(
        metricName,
        value,
        unit: unit,
        tags: tags,
      );

      LoggingService.instance.debug(
        'Metrics',
        'Métrique enregistrée: $metricName = $value${unit ?? ''}',
        data: {
          'metric_name': metricName,
          'value': value,
          'unit': unit,
          ...?tags,
        },
      );
    } catch (e) {
      print('❌ Erreur enregistrement métrique: $e');
    }
  }

  /// Force le flush de tous les logs en attente
  Future<void> flushLogs() async {
    if (!_isInitialized) return;

    try {
      await LoggingService.instance.forceFlush();
      print('📤 Flush des logs terminé');
    } catch (e) {
      print('❌ Erreur flush logs: $e');
    }
  }

  /// Obtient un rapport de santé complet du monitoring
  Map<String, dynamic> getHealthReport() {
    if (!_isInitialized) {
      return {'status': 'not_initialized'};
    }

    try {
      return {
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
        'environment': SecureConfig.sentryEnvironment,
        'services': {
          'crash_reporting': {
            'enabled': SecureConfig.isCrashReportingEnabled,
            'status': 'active',
          },
          'performance_monitoring': {
            'enabled': SecureConfig.isPerformanceMonitoringEnabled,
            'status': 'active',
            ...PerformanceMonitoringService.instance.getPerformanceReport(),
          },
          'logging': {
            'enabled': true,
            'supabase_logging': SecureConfig.isSupabaseLoggingEnabled,
            'status': 'active',
            ...LoggingService.instance.getLoggingStats(),
          },
          'bloc_observer': {
            'enabled': true,
            'status': 'active',
            ..._blocObserver.getStats(),
          },
        },
      };
    } catch (e) {
      print('❌ Erreur génération rapport santé: $e');
      return {
        'status': 'error',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Démarre les tâches de maintenance périodiques
  void _startMaintenanceTasks() {
    try {
      // Nettoyage toutes les 10 minutes
      _cleanupTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
        _performCleanup();
      });

      // Health check toutes les 5 minutes
      _healthCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        _performHealthCheck();
      });

      print('🔄 Tâches de maintenance démarrées');
    } catch (e) {
      print('❌ Erreur démarrage tâches maintenance: $e');
    }
  }

  /// Effectue le nettoyage périodique
  void _performCleanup() {
    try {
      // Nettoyer les opérations périmées
      PerformanceMonitoringService.instance.cleanupStaleOperations();
      _blocObserver.cleanupStaleOperations();

      if (!SecureConfig.kIsProduction) {
        print('🧹 Nettoyage périodique effectué');
      }
    } catch (e) {
      print('❌ Erreur nettoyage périodique: $e');
    }
  }

  /// Effectue un health check périodique
  void _performHealthCheck() {
    try {
      final report = getHealthReport();
      
      // Log du health check seulement si problème détecté
      if (report['status'] != 'healthy') {
        LoggingService.instance.warning(
          'MonitoringService',
          'Health check détecte des problèmes',
          data: report,
        );
      }

      if (!SecureConfig.kIsProduction) {
        print('💊 Health check effectué: ${report['status']}');
      }
    } catch (e) {
      print('❌ Erreur health check: $e');
    }
  }

  /// S'assure que les tables Supabase existent
  Future<void> _ensureSupabaseTablesExist() async {
    if (!SecureConfig.isSupabaseLoggingEnabled) return;

    try {
      // Vérifier si la table app_logs existe en essayant de faire une requête
      await Supabase.instance.client
          .from('app_logs')
          .select('id')
          .limit(1);
      
      print('✅ Table app_logs existe');
    } catch (e) {
      print('⚠️ Table app_logs n\'existe pas ou erreur d\'accès: $e');
      print('📝 Veuillez créer la table app_logs dans Supabase (voir documentation)');
    }
  }

  /// Obtient le BlocObserver amélioré (pour l'utiliser dans main.dart)
  AppBlocObserver get blocObserver {
    if (!_isInitialized) {
      throw StateError('MonitoringService non initialisé');
    }
    return _blocObserver;
  }

  /// Dispose tous les services de monitoring
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      print('🔍 Fermeture du système de monitoring...');

      // Arrêter les timers
      _cleanupTimer?.cancel();
      _healthCheckTimer?.cancel();

      // Flush final des logs
      await flushLogs();

      // Fermer tous les services
      await Future.wait<void>([
        CrashReportingService.instance.dispose(),
        LoggingService.instance.dispose(),
      ]);

      PerformanceMonitoringService.instance.dispose();

      _isInitialized = false;
      print('✅ MonitoringService fermé');
    } catch (e) {
      print('❌ Erreur fermeture MonitoringService: $e');
    }
  }
}