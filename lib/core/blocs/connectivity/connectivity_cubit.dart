// lib/core/blocs/connectivity/connectivity_cubit.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../helper/services/connectivity_service.dart';

class ConnectivityCubit extends Cubit<ConnectionStatus> {
  ConnectivityCubit(this._service) : super(_service.current) {
    _initialize();
  }

  final ConnectivityService _service;
  StreamSubscription? _sub;
  Timer? _forceEmitTimer;

  void _initialize() {
    // Écouter les changements du service
    _sub = _service.stream.listen((status) {
      print('📡 ConnectivityCubit reçoit: $status (état actuel: $state)');
      
      // TOUJOURS émettre, même si c'est le même état
      emit(status);
      
      print('✅ ConnectivityCubit émis: $status');
    });

    // 🆕 Force un emit périodique pour être sûr que les widgets se mettent à jour
    _startForceEmitTimer();

    // Émettre l'état initial
    final currentStatus = _service.current;
    print('🔄 ConnectivityCubit état initial: $currentStatus');
    emit(currentStatus);
  }

  /// 🆕 Timer qui force l'émission périodique
  void _startForceEmitTimer() {
    _forceEmitTimer?.cancel();
    _forceEmitTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final currentStatus = _service.current;
      
      // Force l'émission même si c'est le même état
      // Cela garantit que les widgets se rebuilent
      emit(currentStatus);
      print('🔄 ConnectivityCubit force emit: $currentStatus');
    });
  }

  /// 🆕 Force une vérification de connectivité
  Future<void> forceCheck() async {
    try {
      await _service.forceCheck();
      
      // Émettre le nouveau statut
      final newStatus = _service.current;
      emit(newStatus);
      print('🔄 ConnectivityCubit après force check: $newStatus');
    } catch (e) {
      print('❌ Erreur force check dans cubit: $e');
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _forceEmitTimer?.cancel();
    return super.close();
  }
}