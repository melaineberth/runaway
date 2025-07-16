import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'crash_reporting_service.dart';

/// Service de monitoring des performances
class PerformanceMonitoringService {
  static PerformanceMonitoringService? _instance;
  static PerformanceMonitoringService get instance => _instance ??= PerformanceMonitoringService._();
  
  PerformanceMonitoringService._();

  bool _isInitialized = false;
  final Map<String, ISentrySpan> _activeTransactions = {};
  final Map<String, DateTime> _operationStartTimes = {};

  /// Initialise le service de performance monitoring
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ PerformanceMonitoringService déjà initialisé');
      return;
    }

    if (!SecureConfig.isPerformanceMonitoringEnabled) {
      print('ℹ️ Performance monitoring désactivé via configuration');
      return;
    }

    try {
      print('📊 Initialisation Performance Monitoring...');

      // Le monitoring est configuré via Sentry dans CrashReportingService
      _isInitialized = true;
      
      // Démarrer le monitoring des métriques système
      _startSystemMetricsMonitoring();
      
      print('✅ Performance Monitoring initialisé');
    } catch (e) {
      print('❌ Erreur initialisation Performance Monitoring: $e');
    }
  }

  /// Démarre le tracking d'une opération
  String startOperation(String operationName, {
    String? description,
    Map<String, dynamic>? data,
  }) {
    if (!_isInitialized) return '';

    try {
      final operationId = '${operationName}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Démarrer la transaction Sentry
      final transaction = CrashReportingService.instance.startTransaction(
        operationName,
        'operation',
        data: data,
      );

      if (transaction != null) {
        _activeTransactions[operationId] = transaction;
        transaction.setData('description', description ?? operationName);
        transaction.setData('start_time', DateTime.now().toIso8601String());
        
        if (data != null) {
          for (final entry in data.entries) {
            transaction.setData(entry.key, entry.value);
          }
        }
      }

      _operationStartTimes[operationId] = DateTime.now();

      // Breadcrumb pour tracer l'opération
      CrashReportingService.instance.addBreadcrumb(
        'performance',
        'Démarrage opération: $operationName',
        data: {'operation_id': operationId, 'description': description},
      );

      if (!SecureConfig.kIsProduction) {
        print('⏱️ Opération démarrée: $operationName (ID: $operationId)');
      }

      return operationId;
    } catch (e) {
      print('❌ Erreur démarrage opération: $e');
      return '';
    }
  }

  /// Termine une opération et enregistre les métriques
  void finishOperation(
    String operationId, {
    bool success = true,
    String? errorMessage,
    Map<String, dynamic>? additionalData,
  }) {
    if (!_isInitialized || operationId.isEmpty) return;

    try {
      final transaction = _activeTransactions.remove(operationId);
      final startTime = _operationStartTimes.remove(operationId);

      if (transaction != null) {
        // Ajouter les données finales
        transaction.setData('success', success);
        transaction.setData('end_time', DateTime.now().toIso8601String());
        
        if (errorMessage != null) {
          transaction.setData('error_message', errorMessage);
        }
        
        if (additionalData != null) {
          for (final entry in additionalData.entries) {
            transaction.setData(entry.key, entry.value);
          }
        }

        // Définir le statut
        transaction.status = success 
          ? const SpanStatus.ok() 
          : const SpanStatus.internalError();

        // Terminer la transaction
        transaction.finish();
      }

      // Calculer la durée
      if (startTime != null) {
        final duration = DateTime.now().difference(startTime);
        
        // Log et breadcrumb
        CrashReportingService.instance.addBreadcrumb(
          'performance',
          'Opération terminée: $operationId',
          data: {
            'duration_ms': duration.inMilliseconds,
            'success': success,
            if (errorMessage != null) 'error': errorMessage,
          },
        );

        if (!SecureConfig.kIsProduction) {
          print('⏱️ Opération terminée: $operationId - ${duration.inMilliseconds}ms (${success ? 'succès' : 'échec'})');
        }

        // Alerter si l'opération est lente
        if (duration.inSeconds > 5) {
          CrashReportingService.instance.captureMessage(
            'Opération lente détectée: $operationId',
            level: SentryLevel.warning,
            extra: {
              'operation_id': operationId,
              'duration_ms': duration.inMilliseconds,
              'duration_readable': _formatDuration(duration),
            },
          );
        }
      }
    } catch (e) {
      print('❌ Erreur fin opération: $e');
    }
  }

  /// Démarre le tracking d'une requête réseau
  String startNetworkRequest(
    String url,
    String method, {
    Map<String, dynamic>? headers,
    Map<String, dynamic>? body,
  }) {
    return startOperation(
      'network_request',
      description: '$method $url',
      data: {
        'url': url,
        'method': method,
        'type': 'network',
        if (headers != null) 'headers_count': headers.length,
        if (body != null) 'has_body': true,
      },
    );
  }

  /// Termine une requête réseau
  void finishNetworkRequest(
    String operationId, {
    required int statusCode,
    int? responseSize,
    String? errorMessage,
  }) {
    finishOperation(
      operationId,
      success: statusCode >= 200 && statusCode < 400,
      errorMessage: errorMessage,
      additionalData: {
        'status_code': statusCode,
        if (responseSize != null) 'response_size_bytes': responseSize,
        'response_size_readable': responseSize != null ? _formatBytes(responseSize) : null,
      },
    );
  }

  /// Démarre le tracking d'un chargement d'écran
  String startScreenLoad(String screenName) {
    return startOperation(
      'screen_load',
      description: 'Chargement écran: $screenName',
      data: {
        'screen_name': screenName,
        'type': 'ui',
      },
    );
  }

  /// Termine le chargement d'écran
  void finishScreenLoad(
    String operationId, {
    bool success = true,
    String? errorMessage,
    int? widgetCount,
  }) {
    finishOperation(
      operationId,
      success: success,
      errorMessage: errorMessage,
      additionalData: {
        if (widgetCount != null) 'widget_count': widgetCount,
      },
    );
  }

  /// Track une opération Supabase
  String startSupabaseOperation(
    String operation,
    String table, {
    Map<String, dynamic>? filters,
  }) {
    return startOperation(
      'supabase_operation',
      description: '$operation sur $table',
      data: {
        'operation': operation,
        'table': table,
        'type': 'database',
        if (filters != null) 'filters_count': filters.length,
      },
    );
  }

  /// Termine une opération Supabase
  void finishSupabaseOperation(
    String operationId, {
    required bool success,
    int? recordCount,
    String? errorMessage,
  }) {
    finishOperation(
      operationId,
      success: success,
      errorMessage: errorMessage,
      additionalData: {
        if (recordCount != null) 'record_count': recordCount,
      },
    );
  }

  /// Enregistre une métrique personnalisée
  void recordMetric(
    String metricName,
    num value, {
    String? unit,
    Map<String, dynamic>? tags,
  }) {
    if (!_isInitialized) return;

    try {
      CrashReportingService.instance.addBreadcrumb(
        'metric',
        'Métrique: $metricName = $value${unit ?? ''}',
        data: {
          'metric_name': metricName,
          'value': value,
          if (unit != null) 'unit': unit,
          ...?tags,
        },
      );

      // Log local si développement
      if (!SecureConfig.kIsProduction) {
        print('📊 Métrique: $metricName = $value${unit ?? ''}');
      }
    } catch (e) {
      print('❌ Erreur enregistrement métrique: $e');
    }
  }

  /// Démarre le monitoring des métriques système
  void _startSystemMetricsMonitoring() {
    if (!_isInitialized) return;

    try {
      // Timer pour collecter les métriques périodiquement
      Timer.periodic(const Duration(minutes: 5), (timer) {
        _collectSystemMetrics();
      });

      print('🔄 Monitoring métriques système démarré');
    } catch (e) {
      print('❌ Erreur démarrage monitoring système: $e');
    }
  }

  /// Collecte les métriques système
  void _collectSystemMetrics() {
    if (!_isInitialized) return;

    try {
      // Métrique du nombre de transactions actives
      recordMetric(
        'active_transactions',
        _activeTransactions.length,
        unit: 'count',
        tags: {'type': 'performance'},
      );

      // Métrique de mémoire (approximative)
      if (!kIsWeb) {
        final processInfo = ProcessInfo.currentRss;
        recordMetric(
          'memory_usage',
          processInfo,
          unit: 'bytes',
          tags: {'type': 'system'},
        );
      }

    } catch (e) {
      print('❌ Erreur collecte métriques système: $e');
    }
  }

  /// Formate une durée en format lisible
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else if (duration.inSeconds > 0) {
      return '${duration.inSeconds}s ${duration.inMilliseconds.remainder(1000)}ms';
    } else {
      return '${duration.inMilliseconds}ms';
    }
  }

  /// Formate une taille en bytes
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Obtient un rapport des performances en cours
  Map<String, dynamic> getPerformanceReport() {
    return {
      'is_initialized': _isInitialized,
      'active_transactions': _activeTransactions.length,
      'active_operations': _operationStartTimes.length,
      'monitoring_enabled': SecureConfig.isPerformanceMonitoringEnabled,
      'transaction_keys': _activeTransactions.keys.toList(),
      'oldest_operation_age_minutes': _operationStartTimes.values.isNotEmpty 
        ? DateTime.now().difference(_operationStartTimes.values.first).inMinutes
        : 0,
    };
  }

  /// Nettoie les opérations orphelines (plus de 10 minutes)
  void cleanupStaleOperations() {
    if (!_isInitialized) return;

    try {
      final now = DateTime.now();
      final staleThreshold = const Duration(minutes: 10);
      
      final staleOperations = _operationStartTimes.entries
        .where((entry) => now.difference(entry.value) > staleThreshold)
        .map((entry) => entry.key)
        .toList();

      for (final operationId in staleOperations) {
        print('⚠️ Nettoyage opération périmée: $operationId');
        finishOperation(
          operationId,
          success: false,
          errorMessage: 'Opération périmée (timeout)',
        );
      }

      if (staleOperations.isNotEmpty) {
        print('🧹 ${staleOperations.length} opération(s) périmée(s) nettoyée(s)');
      }
    } catch (e) {
      print('❌ Erreur nettoyage opérations: $e');
    }
  }

  /// Dispose le service
  void dispose() {
    if (!_isInitialized) return;

    try {
      // Terminer toutes les transactions actives
      for (final entry in _activeTransactions.entries) {
        entry.value.finish();
      }
      
      _activeTransactions.clear();
      _operationStartTimes.clear();
      _isInitialized = false;
      
      print('✅ PerformanceMonitoringService fermé');
    } catch (e) {
      print('❌ Erreur fermeture PerformanceMonitoringService: $e');
    }
  }
}