import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionStatus { onlineWifi, onlineMobile, offline }

class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectionStatus> _controller =
      StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _lastStatus = ConnectionStatus.offline;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;
  Timer? _pollingTimer;
  StreamSubscription? _connectivitySubscription;

  Stream<ConnectionStatus> get stream => _controller.stream;
  ConnectionStatus get current => _lastStatus;
  bool get isOffline => _lastStatus == ConnectionStatus.offline;
  bool get isInitialized => _isInitialized;

  /// À appeler une seule fois, au démarrage de l'appli.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    
    _initCompleter = Completer<void>();
    
    try {
      print('🔄 Initialisation ConnectivityService...');
      
      // 🚀 Vérification initiale rapide
      await _checkConnectivityNow();
      
      // 🆕 Double écoute : native + polling
      _startNativeListener();
      _startPolling();
      
      _isInitialized = true;
      _initCompleter!.complete();
      print('✅ ConnectivityService initialisé: $_lastStatus');
      
    } catch (e) {
      print('❌ Erreur ConnectivityService: $e - assumé offline');
      _setStatus(ConnectionStatus.offline);
      _isInitialized = true;
      _initCompleter!.complete();
    }
  }

  /// 🆕 Écoute native des changements
  void _startNativeListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (result) {
        print('📡 Changement connectivité natif détecté: $result');
        _emit(result);
      },
      onError: (e) {
        print('❌ Erreur listener natif: $e');
      },
    );
  }

  /// 🆕 Polling périodique pour forcer la détection
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        await _checkConnectivityNow();
      } catch (e) {
        print('⚠️ Erreur polling connectivité: $e');
      }
    });
  }

  /// 🆕 Vérification immédiate avec test réseau réel
  Future<void> _checkConnectivityNow() async {
    try {
      // Étape 1: Vérifier l'état système
      final result = await _connectivity.checkConnectivity()
          .timeout(const Duration(seconds: 2));
      
      print('📊 État système: $result');
      
      // Étape 2: Test réseau réel si système dit "connecté"
      if (!result.every((r) => r == ConnectivityResult.none)) {
        final hasRealConnection = await _testRealConnection();
        print('🌐 Test connexion réelle: $hasRealConnection');
        
        if (!hasRealConnection) {
          // Système dit connecté mais pas de vraie connexion
          _setStatus(ConnectionStatus.offline);
          return;
        }
      }
      
      // Étape 3: Mapper le résultat
      _emit(result);
      
    } catch (e) {
      print('❌ Erreur vérification connectivité: $e');
      _setStatus(ConnectionStatus.offline);
    }
  }

  /// 🆕 Test de connexion réseau réelle
  Future<bool> _testRealConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 🆕 Setter de statut avec émission forcée
  void _setStatus(ConnectionStatus newStatus) {
    final oldStatus = _lastStatus;
    _lastStatus = newStatus;
    
    // TOUJOURS émettre pour forcer les rebuilds
    _controller.add(newStatus);
    
    print('🔄 ConnectivityService: $oldStatus → $newStatus');
    
    if (oldStatus != newStatus) {
      if (oldStatus == ConnectionStatus.offline && newStatus != ConnectionStatus.offline) {
        print('🟢 RECONNEXION DÉTECTÉE: $oldStatus → $newStatus');
      } else if (oldStatus != ConnectionStatus.offline && newStatus == ConnectionStatus.offline) {
        print('🔴 DÉCONNEXION DÉTECTÉE: $oldStatus → $newStatus');
      }
    }
  }

  void _emit(dynamic raw) {
    // Normalise en liste
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

    _setStatus(next);
  }

  /// Force une vérification immédiate
  Future<void> forceCheck() async {
    print('🔄 Vérification forcée demandée...');
    await _checkConnectivityNow();
  }

  /// Méthodes existantes conservées
  ConnectionStatus getCurrentSync() => _lastStatus;
  
  bool canMakeNetworkCalls() => _isInitialized && !isOffline;

  Future<void> waitForInitialization({Duration timeout = const Duration(seconds: 3)}) async {
    if (_isInitialized) return;
    
    try {
      await _initCompleter?.future.timeout(timeout);
    } catch (e) {
      print('⚠️ Timeout attente initialisation ConnectivityService');
      if (!_isInitialized) {
        _lastStatus = ConnectionStatus.offline;
        _isInitialized = true;
      }
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
    _connectivitySubscription?.cancel();
    _controller.close();
  }
}