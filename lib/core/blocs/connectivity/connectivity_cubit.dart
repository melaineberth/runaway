// lib/core/blocs/connectivity/connectivity_cubit.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import '../../helper/services/connectivity_service.dart';

class ConnectivityCubit extends Cubit<ConnectionStatus> {
  ConnectivityCubit(this._service) : super(_service.current) {
    _initialize();
  }

  final ConnectivityService _service;
  StreamSubscription? _sub;
  Timer? _forceEmitTimer;

  // Contrôle de verbosité et cooldown
  ConnectionStatus? _lastEmittedState;
  DateTime? _lastEmitTime;
  static const _emitCooldown = Duration(seconds: 15); // Réduire les émissions

  void _initialize() {
    // Écouter les changements du service
    _sub = _service.stream.listen((status) {
      // Log seulement les vrais changements
      if (status != state) {
        if (!SecureConfig.kIsProduction) {
          print('📡 ConnectivityCubit: $state → $status');
        }
        emit(status);
        _lastEmittedState = status;
        _lastEmitTime = DateTime.now();
        
        if (!SecureConfig.kIsProduction) {
          print('✅ ConnectivityCubit émis: $status');
        }
      }
    });

    // 🆕 Force un emit périodique pour être sûr que les widgets se mettent à jour
    _startForceEmitTimer();

    // Émettre l'état initial
    final currentStatus = _service.current;
    if (!SecureConfig.kIsProduction) {
      print('🔄 ConnectivityCubit état initial: $currentStatus');
    }
    emit(currentStatus);
    _lastEmittedState = currentStatus;
    _lastEmitTime = DateTime.now();
  }

  /// 🆕 Timer qui force l'émission périodique
  void _startForceEmitTimer() {
    _forceEmitTimer?.cancel();
    // Force emit beaucoup moins fréquent (30s au lieu de 5s)
    _forceEmitTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final currentStatus = _service.current;
      final now = DateTime.now();
      
      // Force emit seulement si nécessaire et avec cooldown
      bool shouldForceEmit = false;
      
      // Forcer si l'état a changé mais pas été émis
      if (currentStatus != _lastEmittedState) {
        shouldForceEmit = true;
      }
      // Ou si ça fait longtemps qu'on n'a pas émis (pour les widgets qui pourraient avoir manqué)
      else if (_lastEmitTime != null && now.difference(_lastEmitTime!) > const Duration(minutes: 2)) {
        shouldForceEmit = true;
      }
      
      if (shouldForceEmit) {
        emit(currentStatus);
        _lastEmittedState = currentStatus;
        _lastEmitTime = now;
        
        // Log force emit seulement en debug et si vraiment nécessaire
        if (!SecureConfig.kIsProduction) {
          print('🔄 ConnectivityCubit force emit: $currentStatus');
        }
      }
    });
  }

  /// 🆕 Force une vérification de connectivité
  Future<void> forceCheck() async {
    try {
      await _service.forceCheck();
      
      final newStatus = _service.current;
      
      // Émettre seulement si l'état a changé
      if (newStatus != state) {
        emit(newStatus);
        _lastEmittedState = newStatus;
        _lastEmitTime = DateTime.now();
        
        if (!SecureConfig.kIsProduction) {
          print('🔄 ConnectivityCubit après force check: $newStatus');
        }
      }
    } catch (e) {
      // Log d'erreur seulement en debug
      if (!SecureConfig.kIsProduction) {
        print('❌ Erreur force check: $e');
      }
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _forceEmitTimer?.cancel();
    return super.close();
  }
}