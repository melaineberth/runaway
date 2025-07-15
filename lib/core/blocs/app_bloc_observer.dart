import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/config/secure_config.dart';
import 'package:runaway/core/services/crash_reporting_service.dart';
import 'package:runaway/core/services/logging_Service.dart';
import 'package:runaway/core/services/performance_monitoring_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppBlocObserver extends BlocObserver {
  final Map<String, DateTime> _blocStartTimes = {};
  final Map<String, String> _blocOperations = {};

  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    
    try {
      final blocName = bloc.runtimeType.toString();
      
      // Log de création
      LoggingService.instance.info(
        'BlocLifecycle',
        'Bloc créé: $blocName',
        data: {'bloc_type': blocName, 'action': 'create'},
      );

      // Breadcrumb pour Sentry
      CrashReportingService.instance.addBreadcrumb(
        'bloc_lifecycle',
        'Création du bloc: $blocName',
        data: {'bloc_type': blocName},
      );

      if (!SecureConfig.kIsProduction) {
        print('🔧 Bloc créé: $blocName');
      }
    } catch (e) {
      print('❌ Erreur onCreate BlocObserver: $e');
    }
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    
    try {
      final blocName = bloc.runtimeType.toString();
      final eventName = event.runtimeType.toString();
      final eventKey = '${blocName}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Enregistrer le début de l'événement
      _blocStartTimes[eventKey] = DateTime.now();
      
      // Démarrer le monitoring de performance
      final operationId = PerformanceMonitoringService.instance.startOperation(
        'bloc_event',
        description: '$blocName -> $eventName',
        data: {
          'bloc_type': blocName,
          'event_type': eventName,
          'type': 'bloc_event',
        },
      );
      
      if (operationId.isNotEmpty) {
        _blocOperations[eventKey] = operationId;
      }

      // Log selon la criticité
      final isImportantEvent = _isImportantEvent(eventName);
      
      if (isImportantEvent || !SecureConfig.kIsProduction) {
        LoggingService.instance.info(
          'BlocEvent',
          '$blocName reçoit événement: $eventName',
          data: {
            'bloc_type': blocName,
            'event_type': eventName,
            'event_key': eventKey,
            'is_important': isImportantEvent,
          },
        );
      }

      // Breadcrumb pour les événements importants
      if (isImportantEvent) {
        CrashReportingService.instance.addBreadcrumb(
          'bloc_event',
          '$blocName -> $eventName',
          data: {
            'bloc_type': blocName,
            'event_type': eventName,
          },
        );
      }

      if (!SecureConfig.kIsProduction) {
        print('📥 ${bloc.runtimeType} Event: $event');
      }
    } catch (e) {
      print('❌ Erreur onEvent BlocObserver: $e');
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    
    try {
      final blocName = bloc.runtimeType.toString();
      final currentState = change.currentState.runtimeType.toString();
      final nextState = change.nextState.runtimeType.toString();
      
      // Log des changements d'état importants
      final isImportantState = _isImportantState(nextState);
      
      if (isImportantState || !SecureConfig.kIsProduction) {
        LoggingService.instance.debug(
          'BlocState',
          '$blocName: $currentState -> $nextState',
          data: {
            'bloc_type': blocName,
            'current_state': currentState,
            'next_state': nextState,
            'is_important': isImportantState,
          },
        );
      }

      // Breadcrumb pour les états importants
      if (isImportantState) {
        CrashReportingService.instance.addBreadcrumb(
          'bloc_state',
          '$blocName: $currentState -> $nextState',
          data: {
            'bloc_type': blocName,
            'current_state': currentState,
            'next_state': nextState,
          },
        );
      }

      // Détecter les états d'erreur
      if (_isErrorState(nextState)) {
        LoggingService.instance.warning(
          'BlocState',
          '$blocName est entré dans un état d\'erreur: $nextState',
          data: {
            'bloc_type': blocName,
            'error_state': nextState,
            'previous_state': currentState,
          },
        );
      }

      if (!SecureConfig.kIsProduction) {
        print('🔄 ${bloc.runtimeType} Change: $change');
      }
    } catch (e) {
      print('❌ Erreur onChange BlocObserver: $e');
    }
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    
    try {
      final blocName = bloc.runtimeType.toString();
      final eventName = transition.event.runtimeType.toString();
      final currentState = transition.currentState.runtimeType.toString();
      final nextState = transition.nextState.runtimeType.toString();
      
      // Calculer la durée de traitement
      final eventKey = _findEventKey(blocName, eventName);
      if (eventKey != null) {
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
                'current_state': currentState,
                'next_state': nextState,
              },
            );
          }

          // Log si la transition est lente
          if (duration.inMilliseconds > 1000) {
            LoggingService.instance.warning(
              'BlocPerformance',
              'Transition lente détectée: $blocName ($eventName)',
              data: {
                'bloc_type': blocName,
                'event_type': eventName,
                'duration_ms': duration.inMilliseconds,
                'current_state': currentState,
                'next_state': nextState,
              },
            );
          }
        }
      }

      // Log des transitions importantes
      final isImportantTransition = _isImportantEvent(eventName) || _isImportantState(nextState);
      
      if (isImportantTransition || !SecureConfig.kIsProduction) {
        LoggingService.instance.debug(
          'BlocTransition',
          '$blocName: $eventName -> ($currentState -> $nextState)',
          data: {
            'bloc_type': blocName,
            'event_type': eventName,
            'current_state': currentState,
            'next_state': nextState,
            'is_important': isImportantTransition,
          },
        );
      }

      if (!SecureConfig.kIsProduction) {
        print('🔀 ${bloc.runtimeType} Transition: $transition');
      }
    } catch (e) {
      print('❌ Erreur onTransition BlocObserver: $e');
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    
    try {
      final blocName = bloc.runtimeType.toString();
      final errorMessage = error.toString();
      
      // Log critique de l'erreur
      LoggingService.instance.critical(
        'BlocError',
        'Erreur dans $blocName: $errorMessage',
        data: {
          'bloc_type': blocName,
          'error_type': error.runtimeType.toString(),
          'error_message': errorMessage,
        },
        exception: error,
        stackTrace: stackTrace,
      );

      // Capturer l'erreur dans Sentry avec contexte
      CrashReportingService.instance.captureException(
        error,
        stackTrace,
        context: 'BlocError',
        extra: {
          'bloc_type': blocName,
          'error_occurred_in': 'bloc_observer',
        },
        level: SentryLevel.error,
      );

      // Terminer toutes les opérations en cours pour ce bloc
      _finishBlocOperations(blocName, false, errorMessage);

      print('❌ ${bloc.runtimeType} Error: $error');
      print('Stack trace: $stackTrace');
    } catch (e) {
      print('❌ Erreur onError BlocObserver: $e');
    }
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    
    try {
      final blocName = bloc.runtimeType.toString();
      
      // Terminer toutes les opérations en cours pour ce bloc
      _finishBlocOperations(blocName, true, 'Bloc fermé');
      
      // Log de fermeture
      LoggingService.instance.info(
        'BlocLifecycle',
        'Bloc fermé: $blocName',
        data: {'bloc_type': blocName, 'action': 'close'},
      );

      // Breadcrumb pour Sentry
      CrashReportingService.instance.addBreadcrumb(
        'bloc_lifecycle',
        'Fermeture du bloc: $blocName',
        data: {'bloc_type': blocName},
      );

      if (!SecureConfig.kIsProduction) {
        print('🔒 Bloc fermé: $blocName');
      }
    } catch (e) {
      print('❌ Erreur onClose BlocObserver: $e');
    }
  }

  /// Détermine si un événement est important à tracker
  bool _isImportantEvent(String eventName) {
    final importantEvents = [
      'AuthLoginRequested',
      'AuthLogoutRequested', 
      'RouteGenerationRequested',
      'CreditsReloadRequested',
      'ErrorOccurred',
      'LoadingStarted',
      'LoadingCompleted',
    ];
    
    return importantEvents.any((important) => eventName.contains(important));
  }

  /// Détermine si un état est important à tracker
  bool _isImportantState(String stateName) {
    final importantStates = [
      'Error',
      'Loading',
      'Success',
      'Authenticated',
      'Unauthenticated',
      'Generated',
      'Failed',
    ];
    
    return importantStates.any((important) => stateName.contains(important));
  }

  /// Détermine si un état représente une erreur
  bool _isErrorState(String stateName) {
    return stateName.toLowerCase().contains('error') || 
           stateName.toLowerCase().contains('failed') ||
           stateName.toLowerCase().contains('failure');
  }

  /// Trouve la clé d'événement correspondante
  String? _findEventKey(String blocName, String eventName) {
    return _blocStartTimes.keys
        .where((key) => key.startsWith(blocName))
        .lastOrNull;
  }

  /// Termine toutes les opérations en cours pour un bloc
  void _finishBlocOperations(String blocName, bool success, String reason) {
    try {
      final keysToRemove = <String>[];
      
      for (final entry in _blocOperations.entries) {
        if (entry.key.startsWith(blocName)) {
          PerformanceMonitoringService.instance.finishOperation(
            entry.value,
            success: success,
            errorMessage: success ? null : reason,
          );
          keysToRemove.add(entry.key);
        }
      }
      
      // Nettoyer les maps
      for (final key in keysToRemove) {
        _blocOperations.remove(key);
        _blocStartTimes.remove(key);
      }
    } catch (e) {
      print('❌ Erreur nettoyage opérations bloc: $e');
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