import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';

/// Service de logging des événements de sécurité
class SecurityLoggingService {
  static SecurityLoggingService? _instance;
  static SecurityLoggingService get instance {
    _instance ??= SecurityLoggingService._();
    return _instance!;
  }
  
  SecurityLoggingService._();

  /// Log une tentative de connexion
  void logLoginAttempt({
    required String email,
    required bool success,
    String? reason,
    String? ipAddress,
  }) {
    final logData = {
      'event': 'login_attempt',
      'email': _maskEmail(email),
      'success': success,
      'timestamp': DateTime.now().toIso8601String(),
      if (reason != null) 'reason': reason,
      if (ipAddress != null) 'ip_address': _maskIpAddress(ipAddress),
    };
    
    if (success) {
      LogConfig.logInfo('✅ Connexion réussie: ${_maskEmail(email)}');
    } else {
      LogConfig.logWarning('❌ Échec connexion: ${_maskEmail(email)} - $reason');
    }
    
    // Envoyer au monitoring pour analyse
    MonitoringService.instance.recordMetric(
      'auth_login_attempt',
      1,
      tags: {
        'success': success.toString(),
        'has_reason': (reason != null).toString(),
        'data': logData,
      },
    );
  }
  
  /// Log une tentative d'inscription
  void logSignUpAttempt({
    required String email,
    required bool success,
    String? reason,
  }) {
    final logData = {
      'event': 'signup_attempt',
      'email': _maskEmail(email),
      'success': success,
      'timestamp': DateTime.now().toIso8601String(),
      if (reason != null) 'reason': reason,
    };
    
    if (success) {
      LogConfig.logInfo('✅ Inscription réussie: ${_maskEmail(email)}');
    } else {
      LogConfig.logWarning('❌ Échec inscription: ${_maskEmail(email)} - $reason');
    }
    
    MonitoringService.instance.recordMetric(
      'auth_signup_attempt',
      1,
      tags: {
        'success': success.toString(),
        'has_reason': (reason != null).toString(),
        'data': logData,
      },
    );
  }
  
  /// Log un verrouillage de compte
  void logAccountLockout({
    required String email,
    required int attemptCount,
    required int lockoutMinutes,
  }) {
    LogConfig.logWarning(
      '🔒 Compte verrouillé: ${_maskEmail(email)} - '
      '$attemptCount tentatives, verrouillé $lockoutMinutes min'
    );
    
    MonitoringService.instance.recordMetric(
      'auth_account_lockout',
      1,
      tags: {
        'attempt_count': attemptCount.toString(),
        'lockout_minutes': lockoutMinutes.toString(),
      },
    );
  }
  
  /// Log une entrée suspecte
  void logSuspiciousInput({
    required String inputType,
    required String reason,
    String? email,
  }) {
    LogConfig.logWarning(
      '⚠️ Entrée suspecte détectée - Type: $inputType, Raison: $reason'
      '${email != null ? ', Email: ${_maskEmail(email)}' : ''}'
    );
    
    MonitoringService.instance.recordMetric(
      'auth_suspicious_input',
      1,
      tags: {
        'input_type': inputType,
        'reason': reason,
      },
    );
  }
  
  /// Log une tentative de réinitialisation de mot de passe
  void logPasswordResetAttempt({
    required String email,
    required bool success,
    String? reason,
  }) {
    if (success) {
      LogConfig.logInfo('🔄 Réinitialisation mot de passe: ${_maskEmail(email)}');
    } else {
      LogConfig.logWarning('❌ Échec réinitialisation: ${_maskEmail(email)} - $reason');
    }
    
    MonitoringService.instance.recordMetric(
      'auth_password_reset',
      1,
      tags: {
        'success': success.toString(),
      },
    );
  }
  
  /// Log une déconnexion
  void logLogout({
    required String email,
    bool forced = false,
  }) {
    LogConfig.logInfo(
      '👋 Déconnexion${forced ? ' forcée' : ''}: ${_maskEmail(email)}'
    );
    
    MonitoringService.instance.recordMetric(
      'auth_logout',
      1,
      tags: {
        'forced': forced.toString(),
      },
    );
  }
  
  /// Log une session expirée
  void logSessionExpired({
    required String email,
  }) {
    LogConfig.logInfo('⏱️ Session expirée: ${_maskEmail(email)}');
    
    MonitoringService.instance.recordMetric(
      'auth_session_expired',
      1,
    );
  }
  
  /// Log une activité multi-appareils suspecte
  void logSuspiciousDeviceActivity({
    required String email,
    required String reason,
  }) {
    LogConfig.logWarning(
      '📱 Activité appareil suspecte: ${_maskEmail(email)} - $reason'
    );
    
    MonitoringService.instance.recordMetric(
      'auth_suspicious_device',
      1,
      tags: {
        'reason': reason,
      },
    );
  }
  
  /// Masque l'email pour la confidentialité (garde le domaine)
  String _maskEmail(String email) {
    if (!email.contains('@')) return '***';
    
    final parts = email.split('@');
    final username = parts[0];
    final domain = parts[1];
    
    if (username.length <= 2) {
      return '***@$domain';
    }
    
    return '${username.substring(0, 2)}***@$domain';
  }
  
  /// Masque l'adresse IP pour la confidentialité
  String _maskIpAddress(String ipAddress) {
    final parts = ipAddress.split('.');
    if (parts.length != 4) return '***';
    
    return '${parts[0]}.${parts[1]}.***.***.';
  }
}