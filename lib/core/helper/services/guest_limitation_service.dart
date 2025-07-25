import 'package:runaway/core/helper/config/log_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gérer les limitations des utilisateurs non connectés
class GuestLimitationService {
  static const String _keyGuestGenerations = 'guest_generations_count';
  static const String _keyFirstUseDate = 'guest_first_use_date';
  static const int _maxGuestGenerations = 3; // 🔧 Générations gratuites pour les guests
  static const Duration _limitPeriod = Duration(days: 30); // Période de 30 jours

  static GuestLimitationService? _instance;
  static GuestLimitationService get instance => _instance ??= GuestLimitationService._();
  GuestLimitationService._();

  /// Vérifie si un utilisateur non connecté peut générer une route
  Future<bool> canGuestGenerate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Récupérer les données stockées
      final generationsCount = prefs.getInt(_keyGuestGenerations) ?? 0;
      final firstUseDateString = prefs.getString(_keyFirstUseDate);
      
      // Si c'est la première utilisation, initialiser
      if (firstUseDateString == null) {
        await _initializeGuestData(prefs);
        return true; // Première génération autorisée
      }
      
      final firstUseDate = DateTime.parse(firstUseDateString);
      final now = DateTime.now();
      
      // Vérifier si la période de limitation est expirée
      if (now.difference(firstUseDate) > _limitPeriod) {
        // Réinitialiser le compteur après la période
        await _resetGuestData(prefs);
        return true;
      }
      
      // Vérifier si l'utilisateur a encore des générations disponibles
      return generationsCount < _maxGuestGenerations;
      
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification limitation guest: $e');
      return false; // En cas d'erreur, refuser par sécurité
    }
  }

  /// Consomme une génération pour un utilisateur non connecté
  Future<bool> consumeGuestGeneration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Vérifier d'abord si la génération est possible
      if (!await canGuestGenerate()) {
        return false;
      }
      
      // Récupérer le compteur actuel
      final currentCount = prefs.getInt(_keyGuestGenerations) ?? 0;
      
      // Incrémenter le compteur
      await prefs.setInt(_keyGuestGenerations, currentCount + 1);
      
      LogConfig.logInfo('💳 Génération guest consommée: ${currentCount + 1}/$_maxGuestGenerations');
      return true;
      
    } catch (e) {
      LogConfig.logError('❌ Erreur consommation génération guest: $e');
      return false;
    }
  }

  /// Retourne le nombre de générations restantes pour un guest
  Future<int> getRemainingGuestGenerations() async {
    try {
      if (!await canGuestGenerate()) {
        return 0;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final used = prefs.getInt(_keyGuestGenerations) ?? 0;
      return _maxGuestGenerations - used;
      
    } catch (e) {
      LogConfig.logError('❌ Erreur récupération générations restantes: $e');
      return 0;
    }
  }

  /// Initialise les données guest
  Future<void> _initializeGuestData(SharedPreferences prefs) async {
    await prefs.setInt(_keyGuestGenerations, 0);
    await prefs.setString(_keyFirstUseDate, DateTime.now().toIso8601String());
    LogConfig.logSuccess('Données guest initialisées');
  }

  /// ⚠️ À n’utiliser que pour le debug / les tests.
  /// Remet le compteur de générations invité à 0 et redémarre la période.
  Future<void> resetGuestGenerationsForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetGuestData(prefs); // on réutilise la méthode privée
  }

  /// Réinitialise les données guest
  Future<void> _resetGuestData(SharedPreferences prefs) async {
    await prefs.setInt(_keyGuestGenerations, 0);
    await prefs.setString(_keyFirstUseDate, DateTime.now().toIso8601String());
    LogConfig.logInfo('🔄 Données guest réinitialisées');
  }

  /// Nettoie les données guest lors de la connexion utilisateur
  Future<void> clearGuestDataOnLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyGuestGenerations);
      await prefs.remove(_keyFirstUseDate);
      LogConfig.logInfo('🧹 Données guest nettoyées après connexion');
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage données guest: $e');
    }
  }

  /// Obtient des informations de debug
  Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final used = prefs.getInt(_keyGuestGenerations) ?? 0;
      final firstUseDate = prefs.getString(_keyFirstUseDate);
      final remaining = await getRemainingGuestGenerations();
      
      return {
        'used': used,
        'remaining': remaining,
        'maxGenerations': _maxGuestGenerations,
        'firstUseDate': firstUseDate,
        'canGenerate': await canGuestGenerate(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
