import 'dart:async';
import 'package:flutter/foundation.dart';
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
  StreamController<SessionEvent>? _eventController;
  StreamSubscription<AuthState>? _authSubscription;

  SessionStatus _currentStatus = SessionStatus.unauthenticated;
  DateTime? _lastRefresh;
  int _consecutiveErrors = 0;

  static const Duration _monitoringInterval = Duration(minutes: 2);
  static const Duration _refreshWarningThreshold = Duration(
    minutes: 50,
  ); // Refresh avant expiration
  static const int _maxConsecutiveErrors = 3;

  /// Stream des événements de session
  Stream<SessionEvent> get sessionEvents {
    _eventController ??= StreamController<SessionEvent>.broadcast();
    return _eventController!.stream;
  }

  /// Statut actuel de la session
  SessionStatus get currentStatus => _currentStatus;

  /// Démarre le monitoring des sessions
  void startSessionMonitoring() {
    if (_sessionTimer != null) return; // Déjà démarré

    debugPrint('🔐 Démarrage monitoring des sessions');

    // Monitoring principal
    _sessionTimer = Timer.periodic(_monitoringInterval, (timer) {
      _checkSessionHealth();
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
    _checkSessionHealth();

    LogConfig.logInfo('Monitoring des sessions démarré');
  }

  /// Arrête le monitoring
  void stopSessionMonitoring() {
    _sessionTimer?.cancel();
    _sessionTimer = null;

    _refreshTimer?.cancel();
    _refreshTimer = null;

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

  /// Tente un refresh du token
  Future<void> _attemptRefresh() async {
    if (_currentStatus == SessionStatus.refreshing) return; // Éviter les refresh multiples

    try {
      _updateStatus(SessionStatus.refreshing, 'Refresh en cours');

      await Supabase.instance.client.auth.refreshSession();
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
        break;

      case AuthChangeEvent.signedOut:
        _updateStatus(SessionStatus.unauthenticated, 'Déconnexion');
        _cleanup();
        break;

      case AuthChangeEvent.tokenRefreshed:
        _updateStatus(SessionStatus.authenticated, 'Token refreshed');
        _lastRefresh = DateTime.now();
        break;

      case AuthChangeEvent.userUpdated:
        // Pas de changement de statut nécessaire pour la mise à jour du profil
        LogConfig.logInfo('👤 Profil utilisateur mis à jour');
        break;

      // 🆕 AJOUT : Gestion de l'événement initialSession
      case AuthChangeEvent.initialSession:
        // Session restaurée au démarrage - vérifier sa validité
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null && isSessionValid()) {
          _updateStatus(
            SessionStatus.authenticated,
            'Session initiale restaurée',
          );
          _lastRefresh = DateTime.now();
          LogConfig.logSuccess('Session initiale valide restaurée pour: ${user.email}');
        } else {
          _updateStatus(SessionStatus.expired, 'Session initiale expirée');
          LogConfig.logInfo('Session initiale expirée ou invalide');
        }
        break;

      // 🆕 AJOUT : Gestion des événements de mot de passe
      case AuthChangeEvent.passwordRecovery:
        debugPrint('🔑 Récupération de mot de passe initiée');
        break;

      default:
        debugPrint('🤔 Événement auth non critique: ${authState.event}');
      // Pour les événements non critiques, on ne change pas le statut mais on log
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

  /// Force la déconnexion en cas de problème critique
  void _forceLogout(String reason) async {
    try {
      debugPrint('🚪 Déconnexion forcée: $reason');
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      LogConfig.logError('❌ Erreur déconnexion forcée: $e');
    }
  }

  /// Nettoyage après déconnexion
  void _cleanup() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _lastRefresh = null;
    _consecutiveErrors = 0;
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

  bool isSessionHealthy() {
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

      return now.isBefore(expiresAt.subtract(marginBeforeExpiry));
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification santé session: $e');
      return false;
    }
  }

  // 🆕 AJOUT : Amélioration de la vérification de session
  void _checkSessionHealth() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final session = Supabase.instance.client.auth.currentSession;

      if (user == null || session == null) {
        _updateStatus(SessionStatus.unauthenticated, 'Aucune session active');
        return;
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

      // 🆕 AMÉLIORATION : Log plus détaillé du statut de la session
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

  /// Dispose des ressources
  void dispose() {
    stopSessionMonitoring();
    _eventController?.close();
    _eventController = null;
  }
}
