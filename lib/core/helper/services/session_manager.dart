import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runaway/core/helper/config/log_config.dart';

enum SessionStatus {
  authenticated,
  unauthenticated,
  expired,
  refreshing,
  error,
}

class SessionEvent {
  final SessionStatus status;
  final String? reason;
  final DateTime timestamp;

  SessionEvent({required this.status, this.reason, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

class SessionManager {
  static SessionManager? _instance;
  static SessionManager get instance => _instance ??= SessionManager._();

  SessionManager._();

  Timer? _sessionTimer;
  Timer? _refreshTimer;
  Timer? _rotationTimer; // 🔒 Timer pour rotation automatique
  StreamController<SessionEvent>? _eventController;
  StreamSubscription<AuthState>? _authSubscription;

  SessionStatus _currentStatus = SessionStatus.unauthenticated;
  DateTime? _lastRefresh;
  DateTime? _lastRotation; // 🔒 Dernière rotation des tokens
  int _consecutiveErrors = 0;
  bool _isRotating = false; // 🔒 Éviter les rotations multiples

  static const Duration _monitoringInterval = Duration(minutes: 2);
  static const Duration _refreshWarningThreshold = Duration(minutes: 50); // Refresh avant expiration
  static const Duration _tokenRotationInterval = Duration(hours: 6); // 🔒 Rotation toutes les 6h
  static const int _maxConsecutiveErrors = 3;

  /// Stream des événements de session
  Stream<SessionEvent> get sessionEvents {
    _eventController ??= StreamController<SessionEvent>.broadcast();
    return _eventController!.stream;
  }

  /// Statut actuel de la session
  SessionStatus get currentStatus => _currentStatus;

  /// Démarre le monitoring des sessions
  void startSessionMonitoring() async {
    if (_sessionTimer != null) return; // Déjà démarré

    debugPrint('🔐 Démarrage monitoring des sessions avec rotation automatique');

    // Vérifier que le stockage sécurisé est disponible
    final isSecureStorageOk = await SecureConfig.isSecureStorageAvailable();
    if (!isSecureStorageOk) {
      LogConfig.logWarning('⚠️ Stockage sécurisé non disponible, fonctionnalités limitées');
    }

    // Monitoring principal
    _sessionTimer = Timer.periodic(_monitoringInterval, (timer) {
      _checkSessionHealth();
    });

    // 🔒 Monitoring de rotation automatique
    _rotationTimer = Timer.periodic(_tokenRotationInterval, (timer) {
      _performTokenRotation();
    });

    // Écouter les changements d'authentification Supabase
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: (error) {
        LogConfig.logError('❌ Erreur stream auth: $error');
        _emitEvent(SessionStatus.error, 'Erreur stream auth: $error');
      },
    );

    // Vérification initiale
    await _initializeStoredTokens();
    _checkSessionHealth();

    LogConfig.logInfo('Monitoring des sessions démarré');
  }

  /// 🔒 Initialise les tokens stockés au démarrage
  Future<void> _initializeStoredTokens() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        // Stocker les tokens de la session actuelle
        await SecureConfig.storeAccessToken(session.accessToken);
        if (session.refreshToken != null) {
          await SecureConfig.storeRefreshToken(session.refreshToken!);
        }
        
        // Générer une clé de rotation si pas déjà présente
        await SecureConfig.generateRotationKey();
        
        LogConfig.logInfo('🔒 Tokens initialisés dans le stockage sécurisé');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur initialisation tokens: $e');
    }
  }

  /// 🔒 Rotation automatique des tokens
  Future<void> _performTokenRotation() async {
    if (_isRotating || _currentStatus != SessionStatus.authenticated) {
      return;
    }

    try {
      _isRotating = true;
      LogConfig.logInfo('🔄 Début rotation automatique des tokens');

      // Vérifier si une rotation est nécessaire
      if (_lastRotation != null) {
        final timeSinceLastRotation = DateTime.now().difference(_lastRotation!);
        if (timeSinceLastRotation < _tokenRotationInterval) {
          LogConfig.logInfo('🔒 Rotation non nécessaire, trop récente');
          return;
        }
      }

      // Effectuer le refresh qui va générer de nouveaux tokens
      await _attemptRefresh();
      
      // Générer une nouvelle clé de rotation
      await SecureConfig.generateRotationKey();
      
      _lastRotation = DateTime.now();
      LogConfig.logSuccess('🔒 Rotation automatique des tokens réussie');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur rotation automatique: $e');
      _emitEvent(SessionStatus.error, 'Erreur rotation: $e');
    } finally {
      _isRotating = false;
    }
  }

  /// Arrête le monitoring
  void stopSessionMonitoring() {
    _sessionTimer?.cancel();
    _sessionTimer = null;

    _refreshTimer?.cancel();
    _refreshTimer = null;

    // 🔒 Arrêter le timer de rotation
    _rotationTimer?.cancel();
    _rotationTimer = null;

    _authSubscription?.cancel();
    _authSubscription = null;

    debugPrint('🛑 Monitoring des sessions arrêté');
  }

  /// Programme un refresh préventif
  void _schedulePreventiveRefresh(Duration timeUntilExpiry) {
    // Programmer le refresh avec une marge de 5 minutes avant expiration
    final refreshDelay = timeUntilExpiry - const Duration(minutes: 5);

    if (refreshDelay.isNegative) {
      // Refresh immédiatement si déjà critique
      _attemptRefresh();
      return;
    }

    _refreshTimer = Timer(refreshDelay, () {
      LogConfig.logInfo('🔄 Refresh préventif programmé');
      _attemptRefresh();
    });

    debugPrint('⏰ Refresh programmé dans ${refreshDelay.inMinutes} minutes');
  }

  /// 🔒 Tente un refresh du token avec stockage sécurisé
  Future<void> _attemptRefresh() async {
    if (_currentStatus == SessionStatus.refreshing) return; // Éviter les refresh multiples

    try {
      _updateStatus(SessionStatus.refreshing, 'Refresh en cours');

      await Supabase.instance.client.auth.refreshSession();
      
      // 🔒 Stocker les nouveaux tokens de façon sécurisée
      final newSession = Supabase.instance.client.auth.currentSession;
      if (newSession != null) {
        await SecureConfig.storeAccessToken(newSession.accessToken);
        if (newSession.refreshToken != null) {
          await SecureConfig.storeRefreshToken(newSession.refreshToken!);
        }
      }
      
      _lastRefresh = DateTime.now();

      LogConfig.logInfo('Session refreshed avec succès');
      _updateStatus(SessionStatus.authenticated, 'Session refreshed');
    } catch (e) {
      LogConfig.logError('❌ Échec refresh session: $e');
      _updateStatus(SessionStatus.expired, 'Impossible de refresher: $e');
      _forceLogout('Échec du refresh de session');
    }
  }

  /// Gère les changements d'état d'authentification
  void _handleAuthStateChange(AuthState authState) {
    LogConfig.logInfo('🔄 Changement état auth: ${authState.event}');

    switch (authState.event) {
      case AuthChangeEvent.signedIn:
        _updateStatus(SessionStatus.authenticated, 'Connexion réussie');
        _lastRefresh = DateTime.now();
        
        // 🔒 Stocker les tokens lors de la connexion
        _storeSessionTokens();
        break;

      case AuthChangeEvent.signedOut:
        _updateStatus(SessionStatus.unauthenticated, 'Déconnexion');
        _cleanup();
        break;

      case AuthChangeEvent.tokenRefreshed:
        _updateStatus(SessionStatus.authenticated, 'Token refreshed');
        _lastRefresh = DateTime.now();
        
        // 🔒 Mettre à jour les tokens stockés
        _storeSessionTokens();
        break;

      case AuthChangeEvent.userUpdated:
        // Pas de changement de statut nécessaire pour la mise à jour du profil
        LogConfig.logInfo('👤 Profil utilisateur mis à jour');
        break;

      case AuthChangeEvent.initialSession:
        // Session restaurée au démarrage - vérifier sa validité
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null && isSessionValid()) {
          _updateStatus(
            SessionStatus.authenticated,
            'Session initiale restaurée',
          );
          _lastRefresh = DateTime.now();
          
          // 🔒 Stocker les tokens de la session restaurée
          _storeSessionTokens();
          
          LogConfig.logSuccess('Session initiale valide restaurée pour: ${user.email}');
        } else {
          _updateStatus(SessionStatus.expired, 'Session initiale expirée');
          LogConfig.logInfo('Session initiale expirée ou invalide');
        }
        break;

      case AuthChangeEvent.passwordRecovery:
        debugPrint('🔑 Récupération de mot de passe initiée');
        break;

      default:
        debugPrint('🤔 Événement auth non critique: ${authState.event}');
    }
  }

  /// 🔒 Stocke les tokens de session de façon sécurisée
  Future<void> _storeSessionTokens() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await SecureConfig.storeAccessToken(session.accessToken);
        if (session.refreshToken != null) {
          await SecureConfig.storeRefreshToken(session.refreshToken!);
        }
        LogConfig.logInfo('🔒 Tokens session stockés de façon sécurisée');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur stockage tokens session: $e');
    }
  }

  /// Met à jour le statut et émet un événement
  void _updateStatus(SessionStatus newStatus, String? reason) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _emitEvent(newStatus, reason);
      debugPrint(
        '🔐 Statut session: $newStatus${reason != null ? ' ($reason)' : ''}',
      );
    }
  }

  /// Émet un événement de session
  void _emitEvent(SessionStatus status, String? reason) {
    _eventController?.add(SessionEvent(status: status, reason: reason));
  }

  /// 🔒 Force la déconnexion avec nettoyage sécurisé
  void _forceLogout(String reason) async {
    try {
      debugPrint('🚪 Déconnexion forcée: $reason');
      
      // 🔒 Nettoyer les tokens stockés avant déconnexion
      await SecureConfig.clearStoredTokens();
      
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      LogConfig.logError('❌ Erreur déconnexion forcée: $e');
    }
  }

  /// 🔒 Nettoyage après déconnexion avec tokens
  void _cleanup() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    
    _rotationTimer?.cancel();
    _rotationTimer = null;
    
    _lastRefresh = null;
    _lastRotation = null;
    _consecutiveErrors = 0;
    _isRotating = false;
    
    // 🔒 Nettoyer les tokens stockés
    await SecureConfig.clearStoredTokens();
  }

  /// Vérifie si la session est réellement valide
  bool isSessionValid() {
    final user = Supabase.instance.client.auth.currentUser;
    final session = Supabase.instance.client.auth.currentSession;

    if (user == null || session == null) return false;

    final now = DateTime.now();
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      session.expiresAt! * 1000,
    );

    return now.isBefore(expiresAt);
  }

  /// 🔒 Vérifie la santé globale avec tokens stockés
  Future<bool> isSessionHealthy() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final session = Supabase.instance.client.auth.currentSession;

      if (user == null || session == null) {
        return false;
      }

      // Vérifier l'expiration avec une marge de sécurité
      final now = DateTime.now();
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        session.expiresAt! * 1000,
      );
      final marginBeforeExpiry = const Duration(minutes: 5);

      // 🔒 Vérifier aussi les tokens stockés
      final isStoredTokenExpired = await SecureConfig.isTokenExpired();
      
      return now.isBefore(expiresAt.subtract(marginBeforeExpiry)) && !isStoredTokenExpired;
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification santé session: $e');
      return false;
    }
  }

  /// 🔒 Forcer une rotation des tokens (méthode publique)
  Future<bool> forceTokenRotation() async {
    if (_currentStatus != SessionStatus.authenticated) {
      LogConfig.logWarning('⚠️ Impossible de forcer rotation: session non authentifiée');
      return false;
    }

    try {
      await _performTokenRotation();
      return true;
    } catch (e) {
      LogConfig.logError('❌ Erreur rotation forcée: $e');
      return false;
    }
  }

  // Amélioration de la vérification de session
  /// 🔒 Validation JWT améliorée
  Future<void> _checkSessionHealth() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final session = Supabase.instance.client.auth.currentSession;

      if (user == null || session == null) {
        _updateStatus(SessionStatus.unauthenticated, 'Aucune session active');
        return;
      }

      // 🔒 Validation du JWT stocké
      final storedToken = await SecureConfig.getStoredAccessToken();
      if (storedToken != null) {
        if (!SecureConfig.isValidJWT(storedToken)) {
          LogConfig.logWarning('⚠️ Token JWT stocké invalide');
          await _attemptRefresh();
          return;
        }

        // Vérifier l'expiration depuis le JWT lui-même
        final jwtExpiry = SecureConfig.getJWTExpiration(storedToken);
        if (jwtExpiry != null) {
          final now = DateTime.now();
          if (now.isAfter(jwtExpiry)) {
            LogConfig.logWarning('⚠️ Token JWT expiré selon payload');
            await _attemptRefresh();
            return;
          }
        }
      }

      // Vérifier l'expiration du token avec plus de détails
      final now = DateTime.now();
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        session.expiresAt! * 1000,
      );
      final timeUntilExpiry = expiresAt.difference(now);

      if (timeUntilExpiry.isNegative) {
        _updateStatus(SessionStatus.expired, 'Token expiré');
        await _attemptRefresh();
        return;
      }

      // 🔒 Vérification du stockage sécurisé
      final isTokenExpired = await SecureConfig.isTokenExpired();
      if (isTokenExpired) {
        LogConfig.logInfo('🔒 Token proche expiration selon stockage sécurisé');
        await _attemptRefresh();
        return;
      }

      // Amélioration : Log plus détaillé du statut de la session
      if (timeUntilExpiry <= _refreshWarningThreshold) {
        debugPrint(
          '⚠️ Session proche de l\'expiration: ${timeUntilExpiry.inMinutes} minutes restantes',
        );
        if (_refreshTimer == null) {
          _schedulePreventiveRefresh(timeUntilExpiry);
        }
      }

      // Session saine
      if (_currentStatus != SessionStatus.authenticated) {
        _updateStatus(
          SessionStatus.authenticated,
          'Session valide (expire dans ${timeUntilExpiry.inMinutes}min)',
        );
      }

      _consecutiveErrors = 0; // Reset compteur d'erreurs
    } catch (e) {
      _consecutiveErrors++;
      debugPrint(
        '❌ Erreur vérification session: $e (tentative $_consecutiveErrors)',
      );

      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        _updateStatus(SessionStatus.error, 'Trop d\'erreurs consécutives: $e');
        _forceLogout('Erreurs répétées de session');
      } else {
        _updateStatus(SessionStatus.error, 'Erreur temporaire: $e');
      }
    }
  }

  /// Force une vérification immédiate
  void forceCheck() {
    _checkSessionHealth();
  }

  /// 🔒 Dispose des ressources avec nettoyage complet
  void dispose() {
    stopSessionMonitoring();
    _cleanup();
    _eventController?.close();
    _eventController = null;
  }
}
