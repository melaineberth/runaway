import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/monitoring_service.dart';

/// Extensions pour faciliter l'utilisation du monitoring
extension MonitoringContext on BuildContext {
  /// Accès rapide au service de monitoring
  MonitoringService get monitoring => MonitoringService.instance;

  /// Track le chargement d'un écran avec nom automatique
  String trackScreenLoad([String? customName]) {
    final screenName = customName ?? _getScreenName();
    return monitoring.trackScreenLoad(screenName);
  }

  /// Termine le tracking d'écran avec gestion automatique des erreurs
  void finishScreenLoad(String operationId, {Object? error}) {
    monitoring.finishScreenLoad(
      operationId,
      success: error == null,
      errorMessage: error?.toString(),
    );
  }

  /// Capture une erreur avec contexte automatique
  void captureError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? extra,
    bool isCritical = false,
  }) {
    monitoring.captureError(
      error,
      stackTrace,
      context: _getScreenName(),
      extra: {
        'widget_context': toString(),
        'route_name': _getRouteName(),
        ...?extra,
      },
      isCritical: isCritical,
    );
  }

  /// Enregistre une métrique avec contexte automatique
  void recordMetric(
    String metricName,
    num value, {
    String? unit,
  }) {
    monitoring.recordMetric(
      metricName,
      value,
      unit: unit,
      tags: {
        'screen': _getScreenName(),
        'route': _getRouteName(),
      },
    );
  }

  /// Récupère le nom de l'écran actuel
  String _getScreenName() {
    try {
      final route = ModalRoute.of(this);
      if (route?.settings.name != null) {
        return route!.settings.name!;
      }
      return runtimeType.toString();
    } catch (e) {
      return 'UnknownScreen';
    }
  }

  /// Récupère le nom de la route actuelle
  String _getRouteName() {
    try {
      final route = ModalRoute.of(this);
      return route?.settings.name ?? '/unknown';
    } catch (e) {
      return '/unknown';
    }
  }
}

/// Extensions pour les BLoCs
extension MonitoringBloc<E, S> on Bloc<E, S> {
  /// Track un événement BLoC important
  void trackEvent(E event, {Map<String, dynamic>? data}) {
    MonitoringService.instance.recordMetric(
      'bloc_event',
      1,
      tags: {
        'bloc_type': runtimeType.toString(),
        'event_type': event.runtimeType.toString(),
        ...?data,
      },
    );
  }

  /// Capture une erreur dans le BLoC
  void captureError(
    Object error,
    StackTrace stackTrace, {
    E? event,
    S? state,
    Map<String, dynamic>? extra,
  }) {
    MonitoringService.instance.captureError(
      error,
      stackTrace,
      context: 'BlocError',
      extra: {
        'bloc_type': runtimeType.toString(),
        if (event != null) 'event_type': event.runtimeType.toString(),
        if (state != null) 'state_type': state.runtimeType.toString(),
        ...?extra,
      },
      isCritical: false,
    );
  }
}

/// Extensions pour Supabase avec monitoring automatique
extension MonitoringSupabase on SupabaseQueryBuilder {
  /// Select avec monitoring automatique
  Future<T> selectWithMonitoring<T>(
    String columns, {
    String? tableName,
    String? context,
    Map<String, dynamic>? extraData,
  }) async {
    final table = tableName ?? 'unknown_table';
    final operationId = MonitoringService.instance.trackOperation(
      'supabase_select',
      description: 'SELECT $columns FROM $table',
      data: {
        'table': table,
        'columns': columns,
        'operation': 'select',
        ...?extraData,
      },
    );

    try {
      final result = await select(columns) as T;
      
      MonitoringService.instance.finishOperation(
        operationId,
        success: true,
        data: {
          'result_type': result.runtimeType.toString(),
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: e.toString(),
      );
      
      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: context ?? 'supabase_select',
        extra: {
          'table': table,
          'columns': columns,
          'operation': 'select',
          ...?extraData,
        },
      );
      
      rethrow;
    }
  }

  /// Insert avec monitoring automatique
  Future<T> insertWithMonitoring<T>(
    Map<String, dynamic> data, {
    String? tableName,
    String? context,
    Map<String, dynamic>? extraData,
  }) async {
    final table = tableName ?? 'unknown_table';
    final operationId = MonitoringService.instance.trackOperation(
      'supabase_insert',
      description: 'INSERT INTO $table',
      data: {
        'table': table,
        'operation': 'insert',
        'record_count': data is List ? data.length : 1,
        ...?extraData,
      },
    );

    try {
      final result = await insert(data) as T;
      
      MonitoringService.instance.finishOperation(
        operationId,
        success: true,
        data: {
          'record_count': data is List ? data.length : 1,
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: e.toString(),
      );
      
      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: context ?? 'supabase_insert',
        extra: {
          'table': table,
          'operation': 'insert',
          'data_keys': data.keys.toList(),
          ...?extraData,
        },
      );
      
      rethrow;
    }
  }

  /// Update avec monitoring automatique
  Future<T> updateWithMonitoring<T>(
    Map<String, dynamic> data, {
    String? tableName,
    String? context,
    Map<String, dynamic>? extraData,
  }) async {
    final table = tableName ?? 'unknown_table';
    final operationId = MonitoringService.instance.trackOperation(
      'supabase_update',
      description: 'UPDATE $table',
      data: {
        'table': table,
        'operation': 'update',
        'fields_count': data.keys.length,
        ...?extraData,
      },
    );

    try {
      final result = await update(data) as T;
      
      MonitoringService.instance.finishOperation(
        operationId,
        success: true,
        data: {
          'fields_updated': data.keys.length,
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: e.toString(),
      );
      
      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: context ?? 'supabase_update',
        extra: {
          'table': table,
          'operation': 'update',
          'data_keys': data.keys.toList(),
          ...?extraData,
        },
      );
      
      rethrow;
    }
  }

  /// Delete avec monitoring automatique
  Future<T> deleteWithMonitoring<T>({
    String? tableName,
    String? context,
    Map<String, dynamic>? extraData,
  }) async {
    final table = tableName ?? 'unknown_table';
    final operationId = MonitoringService.instance.trackOperation(
      'supabase_delete',
      description: 'DELETE FROM $table',
      data: {
        'table': table,
        'operation': 'delete',
        ...?extraData,
      },
    );

    try {
      final result = await delete() as T;
      
      MonitoringService.instance.finishOperation(
        operationId,
        success: true,
      );
      
      return result;
    } catch (e, stackTrace) {
      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: e.toString(),
      );
      
      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: context ?? 'supabase_delete',
        extra: {
          'table': table,
          'operation': 'delete',
          ...?extraData,
        },
      );
      
      rethrow;
    }
  }
}

/// Extensions pour Future avec retry et monitoring
extension MonitoringFuture<T> on Future<T> {
  /// Exécute avec retry automatique et monitoring
  Future<T> withRetryAndMonitoring({
    required String operationName,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    String? context,
    Map<String, dynamic>? extraData,
  }) async {
    final operationId = MonitoringService.instance.trackOperation(
      operationName,
      description: 'Opération avec retry automatique',
      data: {
        'max_retries': maxRetries,
        'delay_ms': delay.inMilliseconds,
        ...?extraData,
      },
    );

    int attempts = 0;
    Object? lastError;
    StackTrace? lastStackTrace;

    while (attempts <= maxRetries) {
      try {
        final result = await this;
        
        MonitoringService.instance.finishOperation(
          operationId,
          success: true,
          data: {
            'attempts_made': attempts + 1,
            'success_on_attempt': attempts + 1,
          },
        );
        
        if (attempts > 0) {
          MonitoringService.instance.recordMetric(
            'retry_success',
            1,
            tags: {
              'operation': operationName,
              'attempts': attempts + 1,
            },
          );
        }
        
        return result;
      } catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;
        attempts++;
        
        if (attempts <= maxRetries) {
          MonitoringService.instance.recordMetric(
            'retry_attempt',
            1,
            tags: {
              'operation': operationName,
              'attempt_number': attempts,
            },
          );
          
          await Future.delayed(delay * attempts); // Backoff exponentiel
        }
      }
    }

    // Toutes les tentatives ont échoué
    MonitoringService.instance.finishOperation(
      operationId,
      success: false,
      errorMessage: lastError.toString(),
      data: {
        'total_attempts': attempts,
        'max_retries_reached': true,
      },
    );

    MonitoringService.instance.captureError(
      lastError!,
      lastStackTrace,
      context: context ?? operationName,
      extra: {
        'total_attempts': attempts,
        'max_retries': maxRetries,
        'final_error': true,
        ...?extraData,
      },
    );

    throw lastError;
  }

  /// Exécute avec timeout et monitoring
  Future<T> withTimeoutAndMonitoring({
    required Duration timeout,
    required String operationName,
    String? context,
    Map<String, dynamic>? extraData,
  }) async {
    final operationId = MonitoringService.instance.trackOperation(
      operationName,
      description: 'Opération avec timeout',
      data: {
        'timeout_ms': timeout.inMilliseconds,
        ...?extraData,
      },
    );

    try {
      final result = await this.timeout(timeout);
      
      MonitoringService.instance.finishOperation(
        operationId,
        success: true,
      );
      
      return result;
    } on TimeoutException catch (e, stackTrace) {
      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: 'Timeout après ${timeout.inMilliseconds}ms',
      );

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: context ?? operationName,
        extra: {
          'timeout_ms': timeout.inMilliseconds,
          'error_type': 'timeout',
          ...?extraData,
        },
      );
      
      rethrow;
    } catch (e, stackTrace) {
      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: e.toString(),
      );

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: context ?? operationName,
        extra: extraData,
      );
      
      rethrow;
    }
  }
}

/// Widget wrapper pour monitoring automatique des écrans
class MonitoredScreen extends StatefulWidget {
  final Widget child;
  final String screenName;
  final Map<String, dynamic>? screenData;

  const MonitoredScreen({
    super.key,
    required this.child,
    required this.screenName,
    this.screenData,
  });

  @override
  State<MonitoredScreen> createState() => _MonitoredScreenState();
}

class _MonitoredScreenState extends State<MonitoredScreen> {
  late String _operationId;

  @override
  void initState() {
    super.initState();
    _operationId = MonitoringService.instance.trackScreenLoad(widget.screenName);
  }

  @override
  void dispose() {
    MonitoringService.instance.finishScreenLoad(_operationId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Décorateur de méthode pour monitoring automatique
class MonitoredOperation {
  static Future<T> run<T>(
    String operationName,
    Future<T> Function() operation, {
    String? description,
    Map<String, dynamic>? data,
    String? context,
  }) async {
    final operationId = MonitoringService.instance.trackOperation(
      operationName,
      description: description,
      data: data,
    );

    try {
      final result = await operation();
      
      MonitoringService.instance.finishOperation(
        operationId,
        success: true,
        data: {
          'result_type': result.runtimeType.toString(),
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: e.toString(),
      );

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: context ?? operationName,
        extra: data,
      );
      
      rethrow;
    }
  }
}