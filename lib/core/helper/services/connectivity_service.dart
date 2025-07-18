import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:runaway/core/helper/config/log_config.dart';

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

  // Contrôle de verbosité
  DateTime? _lastLogTime;
  ConnectionStatus? _lastLoggedStatus;
  static const _logCooldown = Duration(seconds: 30); // Réduire les logs répétitifs

  Stream<ConnectionStatus> get stream => _controller.stream;
  ConnectionStatus get current => _lastStatus;
  bool get isOffline => _lastStatus == ConnectionStatus.offline;
  bool get isInitialized => _isInitialized;
  bool get isOnline => _lastStatus == ConnectionStatus.onlineMobile;

  /// À appeler une seule fois, au démarrage de l'appli.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    
    _initCompleter = Completer<void>();
    
    try {
      if (!SecureConfig.kIsProduction) {
        LogConfig.logInfo('🔄 Initialisation ConnectivityService...');
      }
      
      // 🚀 Vérification initiale rapide
      await _checkConnectivityNow();
      
      // 🆕 Double écoute : native + polling
      _startNativeListener();
      _startPolling();
      
      _isInitialized = true;
      _initCompleter!.complete();

      // Log d'initialisation simplifié
      _logWithCooldown('✅ ConnectivityService initialisé: $_lastStatus');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur ConnectivityService: $e - assumé offline');
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
        // Log seulement si changement significatif
        if (!SecureConfig.kIsProduction) {
          _logWithCooldown('📡 Changement natif détecté: $result');
        }
        _emit(result);
      },
      onError: (e) {
        LogConfig.logError('❌ Erreur listener natif: $e');
      },
    );
  }

  /// 🆕 Polling périodique pour forcer la détection
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        await _checkConnectivityNow();
      } catch (e) {
        // Ne pas logger chaque erreur de polling
        if (!SecureConfig.kIsProduction) {
          _logWithCooldown('⚠️ Erreur polling: $e');
        }
      }
    });
  }

  /// 🆕 Vérification immédiate avec test réseau réel
  Future<void> _checkConnectivityNow() async {
    try {
      // Étape 1: Vérifier l'état système
      final result = await _connectivity.checkConnectivity()
          .timeout(const Duration(seconds: 2));
      
      // Log système seulement en debug et avec cooldown
      if (!SecureConfig.kIsProduction) {
        _logWithCooldown('📊 État système: $result', isDebug: true);
      }
      
      // Étape 2: Test réseau réel si système dit "connecté"
      if (!result.every((r) => r == ConnectivityResult.none)) {
        final hasRealConnection = await _testRealConnection();
        
        if (!SecureConfig.kIsProduction) {
          _logWithCooldown('🌐 Test connexion: $hasRealConnection', isDebug: true);
        }
        
        if (!hasRealConnection) {
          // Système dit connecté mais pas de vraie connexion
          _setStatus(ConnectionStatus.offline);
          return;
        }
      }
      
      // Étape 3: Mapper le résultat
      _emit(result);
      
    } catch (e) {
      // Erreur silencieuse sauf en debug
      if (!SecureConfig.kIsProduction) {
        _logWithCooldown('❌ Erreur vérification: $e');
      }

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
    
    // Émettre le changement
    _controller.add(newStatus);
    
    LogConfig.logInfo('🔄 ConnectivityService: $oldStatus → $newStatus');
    
    // Logger seulement les vrais changements d'état
    if (oldStatus != newStatus) {
      if (oldStatus == ConnectionStatus.offline && newStatus != ConnectionStatus.offline) {
        _logWithCooldown('🟢 RECONNEXION: $oldStatus → $newStatus', forceLog: true);
      } else if (oldStatus != ConnectionStatus.offline && newStatus == ConnectionStatus.offline) {
        _logWithCooldown('🔴 DÉCONNEXION: $oldStatus → $newStatus', forceLog: true);
      } else {
        _logWithCooldown('🔄 ConnectivityService: $oldStatus → $newStatus');
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
    if (!SecureConfig.kIsProduction) {
      LogConfig.logInfo('🔄 Vérification forcée...');
    }
    await _checkConnectivityNow();
  }

  // Logging avec cooldown pour éviter le spam
  void _logWithCooldown(String message, {bool isDebug = false, bool forceLog = false}) {
    final now = DateTime.now();
    
    // En production, ne logger que les changements forcés
    if (SecureConfig.kIsProduction && !forceLog) {
      return;
    }
    
    // En debug, respecter le cooldown sauf pour les logs forcés
    if (!forceLog && _lastLogTime != null) {
      final timeSinceLastLog = now.difference(_lastLogTime!);
      if (timeSinceLastLog < _logCooldown && _lastLoggedStatus == _lastStatus) {
        return; // Ignorer le log répétitif
      }
    }
    
    // Logger le message
    if (isDebug && SecureConfig.kIsProduction) {
      // Pas de logs debug en production
      return;
    }
    
    print(message);
    _lastLogTime = now;
    _lastLoggedStatus = _lastStatus;
  }

  ConnectionStatus getCurrentSync() => _lastStatus;
  bool canMakeNetworkCalls() => _isInitialized && !isOffline;

  Future<void> waitForInitialization({Duration timeout = const Duration(seconds: 3)}) async {
    if (_isInitialized) return;
    
    try {
      await _initCompleter?.future.timeout(timeout);
    } catch (e) {
      if (!SecureConfig.kIsProduction) {
        LogConfig.logInfo('Timeout initialisation ConnectivityService');
      }
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
