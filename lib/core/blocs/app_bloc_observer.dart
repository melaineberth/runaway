import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:runaway/core/helper/services/crash_reporting_service.dart';
import 'package:runaway/core/helper/services/logging_service.dart';
import 'package:runaway/core/helper/services/performance_monitoring_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppBlocObserver extends BlocObserver {
  final Map<String, DateTime> _blocStartTimes = {};
  final Map<String, String> _blocOperations = {};

  // Liste des blocs importants à monitorer
  static const _importantBlocs = {
    'AuthBloc',
    'RouteGenerationBloc', 
    'AppDataBloc',
    'CreditsBloc',
  };

  // Événements importants à logger
  static const _importantEvents = {
    'AppStarted',
    'SignInRequested',
    'SignOutRequested', 
    'RouteGenerationRequested',
    'AppDataPreloadRequested',
    'CreditsPurchaseRequested',
    'Error',
    'Failure',
  };

  // États d'erreur à surveiller
  static const _errorStates = {
    'Error',
    'Failure', 
    'NetworkFailure',
    'AuthenticationFailure',
    'GenerationFailure',
  };

  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    
    final blocName = bloc.runtimeType.toString();
    
    // Log seulement les blocs importants
    if (_isImportantBloc(blocName) || !SecureConfig.kIsProduction) {
      LoggingService.instance.info(
        'BlocLifecycle',
        'Bloc important créé: $blocName',
        data: {'bloc_type': blocName},
      );
      
      if (!SecureConfig.kIsProduction) {
        print('🔧 Bloc créé: $blocName');
      }
    }
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    
    final blocName = bloc.runtimeType.toString();
    final eventName = event.runtimeType.toString();
    
    // 🔧 CHANGEMENT: Logger seulement les événements importants
    if (_isImportantEvent(eventName) || _isImportantBloc(blocName)) {
      final eventKey = '${blocName}_${DateTime.now().millisecondsSinceEpoch}';
      _blocStartTimes[eventKey] = DateTime.now();
      
      // Performance monitoring seulement pour les événements critiques
      if (_isImportantEvent(eventName)) {
        final operationId = PerformanceMonitoringService.instance.startOperation(
          'bloc_event',
          description: '$blocName -> $eventName',
          data: {
            'bloc_type': blocName,
            'event_type': eventName,
          },
        );
        
        if (operationId.isNotEmpty) {
          _blocOperations[eventKey] = operationId;
        }
      }

      LoggingService.instance.info(
        'BlocEvent',
        '$blocName reçoit: $eventName',
        data: {
          'bloc_type': blocName,
          'event_type': eventName,
        },
      );

      if (!SecureConfig.kIsProduction) {
        print('📥 $blocName Event: $eventName');
      }
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    
    final blocName = bloc.runtimeType.toString();
    final nextState = change.nextState.runtimeType.toString();
    
    // 🔧 CHANGEMENT: Logger seulement les changements d'état critiques
    if (_isErrorState(nextState) || (_isImportantBloc(blocName) && !SecureConfig.kIsProduction)) {
      LoggingService.instance.warning(
        'BlocState',
        '$blocName -> $nextState',
        data: {
          'bloc_type': blocName,
          'new_state': nextState,
          'is_error': _isErrorState(nextState),
        },
      );
    }

    // Détecter et logger les états d'erreur
    if (_isErrorState(nextState)) {
      LoggingService.instance.error(
        'BlocError',
        '$blocName est entré dans un état d\'erreur: $nextState',
        data: {
          'bloc_type': blocName,
          'error_state': nextState,
        },
      );
    }
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    
    final blocName = bloc.runtimeType.toString();
    final eventName = transition.event.runtimeType.toString();
    final nextState = transition.nextState.runtimeType.toString();
    
    // 🔧 CHANGEMENT: Suivre les performances seulement pour les événements importants
    final eventKey = _findEventKey(blocName, eventName);
    if (eventKey != null && _importantEvents.contains(eventName)) {
      final startTime = _blocStartTimes.remove(eventKey);
      final operationId = _blocOperations.remove(eventKey);
      
      if (startTime != null) {
        final duration = DateTime.now().difference(startTime);
        
        // Terminer le monitoring de performance
        if (operationId != null) {
          PerformanceMonitoringService.instance.finishOperation(
            operationId,
            success: !_isErrorState(nextState),
            additionalData: {
              'duration_ms': duration.inMilliseconds,
            },
          );
        }

        // 🔧 CHANGEMENT: Logger seulement les transitions lentes (>2s au lieu de 1s)
        if (duration.inMilliseconds > 2000) {
          LoggingService.instance.warning(
            'BlocPerformance',
            'Transition lente: $blocName ($eventName) - ${duration.inMilliseconds}ms',
            data: {
              'bloc_type': blocName,
              'event_type': eventName,
              'duration_ms': duration.inMilliseconds,
            },
          );
        }
      }
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    
    final blocName = bloc.runtimeType.toString();
    
    // 🔧 CHANGEMENT: Toujours logger les erreurs (critique)
    LoggingService.instance.critical(
      'BlocError',
      'Erreur critique dans $blocName: $error',
      data: {
        'bloc_type': blocName,
        'error_type': error.runtimeType.toString(),
      },
      exception: error,
      stackTrace: stackTrace,
    );

    CrashReportingService.instance.captureException(
      error,
      stackTrace,
      context: 'BlocError',
      extra: {'bloc_type': blocName},
      level: SentryLevel.error,
    );

    _finishBlocOperations(blocName, false, error.toString());
    print('❌ $blocName Error: $error');
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    
    final blocName = bloc.runtimeType.toString();
    
    // 🔧 CHANGEMENT: Logger seulement les fermetures importantes
    if (_isImportantBloc(blocName)) {
      LoggingService.instance.info(
        'BlocLifecycle',
        'Bloc important fermé: $blocName',
        data: {'bloc_type': blocName},
      );
    }

    _finishBlocOperations(blocName, true, 'Bloc fermé');
  }

  bool _isImportantBloc(String blocName) {
    return _importantBlocs.any((name) => blocName.contains(name));
  }

  bool _isImportantEvent(String eventName) {
    return _importantEvents.any((name) => eventName.contains(name));
  }

  bool _isErrorState(String stateName) {
    return _errorStates.any((name) => stateName.contains(name));
  }

  String? _findEventKey(String blocName, String eventName) {
    return _blocStartTimes.keys
        .where((key) => key.startsWith(blocName))
        .lastOrNull;
  }

  void _finishBlocOperations(String blocName, bool success, String? errorMessage) {
    // Terminer toutes les opérations en cours pour ce bloc
    final keysToRemove = <String>[];
    
    for (final entry in _blocOperations.entries) {
      if (entry.key.startsWith(blocName)) {
        PerformanceMonitoringService.instance.finishOperation(
          entry.value,
          success: success,
          additionalData: success ? null : {'error': errorMessage},
        );
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _blocOperations.remove(key);
      _blocStartTimes.remove(key);
    }
  }

  /// Nettoie les opérations périmées
  void cleanupStaleOperations() {
    try {
      final now = DateTime.now();
      final staleThreshold = const Duration(minutes: 5);
      
      final staleKeys = _blocStartTimes.entries
          .where((entry) => now.difference(entry.value) > staleThreshold)
          .map((entry) => entry.key)
          .toList();
      
      for (final key in staleKeys) {
        final operationId = _blocOperations.remove(key);
        _blocStartTimes.remove(key);
        
        if (operationId != null) {
          PerformanceMonitoringService.instance.finishOperation(
            operationId,
            success: false,
            errorMessage: 'Opération bloc périmée',
          );
        }
      }
      
      if (staleKeys.isNotEmpty && !SecureConfig.kIsProduction) {
        print('🧹 ${staleKeys.length} opération(s) bloc périmée(s) nettoyée(s)');
      }
    } catch (e) {
      print('❌ Erreur nettoyage opérations périmées: $e');
    }
  }

  /// Obtient les statistiques du BlocObserver
  Map<String, dynamic> getStats() {
    return {
      'active_operations': _blocOperations.length,
      'pending_start_times': _blocStartTimes.length,
      'oldest_operation_age_minutes': _blocStartTimes.values.isNotEmpty
          ? DateTime.now().difference(_blocStartTimes.values.first).inMinutes
          : 0,
    };
  }
}