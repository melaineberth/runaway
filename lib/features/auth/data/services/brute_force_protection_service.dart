import 'dart:async';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service simple de protection contre les attaques par force brute
class BruteForceProtectionService {
  static const String _keyFailedAttempts = 'auth_failed_attempts';
  static const String _keyLastAttempt = 'auth_last_attempt';
  static const String _keyLockoutUntil = 'auth_lockout_until';
  
  // Configuration simple
  static const int _maxAttempts = 5;
  static const int _lockoutDurationMinutes = 15;
  static const int _attemptWindowMinutes = 30;
  
  static BruteForceProtectionService? _instance;
  static BruteForceProtectionService get instance {
    _instance ??= BruteForceProtectionService._();
    return _instance!;
  }
  
  BruteForceProtectionService._();

  /// Vérifie si l'utilisateur peut tenter une connexion
  Future<bool> canAttemptLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Vérifier le verrouillage actuel
      final lockoutUntil = prefs.getString(_keyLockoutUntil);
      if (lockoutUntil != null) {
        final lockoutTime = DateTime.parse(lockoutUntil);
        if (DateTime.now().isBefore(lockoutTime)) {
          LogConfig.logWarning('🔒 Compte verrouillé jusqu\'à $lockoutTime');
          return false;
        } else {
          // Verrouillage expiré, nettoyer
          await _clearLockout();
        }
      }
      
      return true;
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification brute force: $e');
      return true; // En cas d'erreur, permettre la tentative
    }
  }
  
  /// Enregistre une tentative de connexion échouée
  Future<void> recordFailedAttempt(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final now = DateTime.now();
      final lastAttempt = prefs.getString(_keyLastAttempt);
      final failedAttempts = prefs.getInt(_keyFailedAttempts) ?? 0;
      
      // Réinitialiser si la dernière tentative est trop ancienne
      if (lastAttempt != null) {
        final lastAttemptTime = DateTime.parse(lastAttempt);
        if (now.difference(lastAttemptTime).inMinutes > _attemptWindowMinutes) {
          await prefs.setInt(_keyFailedAttempts, 1);
          await prefs.setString(_keyLastAttempt, now.toIso8601String());
          LogConfig.logWarning('🔒 Première tentative échouée pour $email');
          return;
        }
      }
      
      // Incrémenter les tentatives échouées
      final newFailedAttempts = failedAttempts + 1;
      await prefs.setInt(_keyFailedAttempts, newFailedAttempts);
      await prefs.setString(_keyLastAttempt, now.toIso8601String());
      
      LogConfig.logWarning('🔒 Tentative échouée $newFailedAttempts/$_maxAttempts pour $email');
      
      // Verrouiller si limite atteinte
      if (newFailedAttempts >= _maxAttempts) {
        final lockoutUntil = now.add(Duration(minutes: _lockoutDurationMinutes));
        await prefs.setString(_keyLockoutUntil, lockoutUntil.toIso8601String());
        
        LogConfig.logWarning('🔒 Compte verrouillé pour $email jusqu\'à $lockoutUntil');
        
        // Nettoyer les compteurs
        await prefs.remove(_keyFailedAttempts);
        await prefs.remove(_keyLastAttempt);
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur enregistrement échec: $e');
    }
  }
  
  /// Nettoie les tentatives après une connexion réussie
  Future<void> clearFailedAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFailedAttempts);
      await prefs.remove(_keyLastAttempt);
      await prefs.remove(_keyLockoutUntil);
      
      LogConfig.logInfo('✅ Compteurs de tentatives nettoyés');
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage tentatives: $e');
    }
  }
  
  /// Obtient le temps restant de verrouillage en minutes
  Future<int> getRemainingLockoutMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutUntil = prefs.getString(_keyLockoutUntil);
      
      if (lockoutUntil != null) {
        final lockoutTime = DateTime.parse(lockoutUntil);
        final now = DateTime.now();
        
        if (now.isBefore(lockoutTime)) {
          return lockoutTime.difference(now).inMinutes + 1;
        }
      }
      
      return 0;
    } catch (e) {
      LogConfig.logError('❌ Erreur calcul verrouillage: $e');
      return 0;
    }
  }
  
  /// Obtient le nombre de tentatives restantes
  Future<int> getRemainingAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failedAttempts = prefs.getInt(_keyFailedAttempts) ?? 0;
      return (_maxAttempts - failedAttempts).clamp(0, _maxAttempts);
    } catch (e) {
      LogConfig.logError('❌ Erreur calcul tentatives restantes: $e');
      return _maxAttempts;
    }
  }
  
  /// Nettoie le verrouillage expiré
  Future<void> _clearLockout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLockoutUntil);
      await prefs.remove(_keyFailedAttempts);
      await prefs.remove(_keyLastAttempt);
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage verrouillage: $e');
    }
  }
}