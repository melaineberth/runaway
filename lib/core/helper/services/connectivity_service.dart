import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionStatus { onlineWifi, onlineMobile, offline }

class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectionStatus> _controller =
      StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _lastStatus = ConnectionStatus.offline;

  Stream<ConnectionStatus> get stream => _controller.stream;
  ConnectionStatus get current => _lastStatus;
  bool get isOffline => _lastStatus == ConnectionStatus.offline;

  /// À appeler une seule fois, au démarrage de l’appli.
  Future<void> initialize() async {
    _emit(await _connectivity.checkConnectivity());            // v6 ➜ List, v3 ➜ Enum
    _connectivity.onConnectivityChanged.listen(_emit);         // v6 ➜ List, v3 ➜ Enum
  }

  void _emit(dynamic raw) {
    // Normalise en liste.
    final List<ConnectivityResult> results = switch (raw) {
      ConnectivityResult r => [r],
      List<ConnectivityResult> l => l,
      _ => const [ConnectivityResult.none],
    };

    final next = results.every((r) => r == ConnectivityResult.none)
        ? ConnectionStatus.offline
        : results.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet)
            ? ConnectionStatus.onlineWifi
            : ConnectionStatus.onlineMobile;

    if (next != _lastStatus) {
      _lastStatus = next;
      _controller.add(next);
    }
  }

  void dispose() => _controller.close();
}
