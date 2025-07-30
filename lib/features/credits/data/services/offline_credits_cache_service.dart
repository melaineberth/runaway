import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';

/// Service spécialisé pour la gestion du cache offline des crédits
/// Utilise SharedPreferences avec une couche de sécurité supplémentaire
class OfflineCreditsCacheService {
  static OfflineCreditsCacheService? _instance;
  static OfflineCreditsCacheService get instance => _instance ??= OfflineCreditsCacheService._();
  
  OfflineCreditsCacheService._();
  
  SharedPreferences? _prefs;
  String? _currentUserId;
  
  // Clés de cache standardisées avec user_id
  static const String _keyPrefix = 'offline_credits_';
  static const String _userCreditsKey = 'user_credits';
  static const String _creditsTimestampKey = 'credits_timestamp';
  static const String _transactionsKey = 'transactions';
  static const String _transactionsTimestampKey = 'transactions_timestamp';
  static const String _plansKey = 'plans';
  static const String _plansTimestampKey = 'plans_timestamp';
  static const String _lastSyncKey = 'last_sync';
  static const String _pendingTransactionsKey = 'pending_transactions';
  
  /// Initialise le service avec l'user_id actuel
  Future<void> initialize(String userId) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      
      // Si l'utilisateur a changé, nettoyer l'ancien cache
      if (_currentUserId != null && _currentUserId != userId) {
        LogConfig.logInfo('🧹 Changement utilisateur détecté: $_currentUserId → $userId');
        await _clearUserCache(_currentUserId!);
      }
      
      _currentUserId = userId;
      LogConfig.logInfo('💾 OfflineCreditsCacheService initialisé pour user: $userId');
    } catch (e) {
      LogConfig.logError('❌ Erreur initialisation OfflineCreditsCacheService: $e');
      rethrow;
    }
  }
  
  /// Nettoie le cache d'un utilisateur spécifique
  Future<void> _clearUserCache(String userId) async {
    if (_prefs == null) return;
    
    final keysToRemove = _prefs!.getKeys().where((key) => 
      key.startsWith('$_keyPrefix$userId')).toList();
    
    for (final key in keysToRemove) {
      await _prefs!.remove(key);
    }
    
    LogConfig.logInfo('🧹 Cache utilisateur $userId nettoyé (${keysToRemove.length} clés)');
  }
  
  /// Génère une clé de cache spécifique à l'utilisateur
  String _userKey(String key) {
    if (_currentUserId == null) {
      throw StateError('OfflineCreditsCacheService non initialisé');
    }
    return '$_keyPrefix$_currentUserId\_$key';
  }
  
  // ========== GESTION DES CRÉDITS ==========
  
  /// Sauvegarde les crédits utilisateur avec timestamp
  Future<void> saveUserCredits(UserCredits credits) async {
    try {
      if (_prefs == null) throw StateError('Service non initialisé');
      
      final creditsJson = jsonEncode(credits.toJson());
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await _prefs!.setString(_userKey(_userCreditsKey), creditsJson);
      await _prefs!.setInt(_userKey(_creditsTimestampKey), timestamp);
      
      LogConfig.logInfo('💾 Crédits sauvegardés offline: ${credits.availableCredits} crédits');
    } catch (e) {
      LogConfig.logError('❌ Erreur sauvegarde crédits offline: $e');
    }
  }
  
  /// Récupère les crédits depuis le cache offline
  Future<UserCredits?> getUserCredits() async {
    try {
      if (_prefs == null) return null;
      
      final creditsJson = _prefs!.getString(_userKey(_userCreditsKey));
      if (creditsJson == null) return null;
      
      final creditsMap = jsonDecode(creditsJson) as Map<String, dynamic>;
      final credits = UserCredits.fromJson(creditsMap);
      
      final timestamp = _prefs!.getInt(_userKey(_creditsTimestampKey)) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      
      LogConfig.logInfo('📦 Crédits récupérés du cache offline: ${credits.availableCredits} crédits (âge: ${age ~/ 1000}s)');
      return credits;
    } catch (e) {
      LogConfig.logError('❌ Erreur lecture crédits offline: $e');
      // Nettoyer le cache corrompu
      await _prefs?.remove(_userKey(_userCreditsKey));
      await _prefs?.remove(_userKey(_creditsTimestampKey));
      return null;
    }
  }
  
  /// Vérifie si les crédits en cache sont récents (moins de 5 minutes)
  Future<bool> areCreditsRecent() async {
    try {
      if (_prefs == null) return false;
      
      final timestamp = _prefs!.getInt(_userKey(_creditsTimestampKey)) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      return age < (5 * 60 * 1000); // 5 minutes
    } catch (e) {
      return false;
    }
  }
  
  // ========== GESTION DES TRANSACTIONS ==========
  
  /// Sauvegarde l'historique des transactions
  Future<void> saveTransactions(List<CreditTransaction> transactions) async {
    try {
      if (_prefs == null) throw StateError('Service non initialisé');
      
      final transactionsJson = jsonEncode(
        transactions.map((t) => t.toJson()).toList(),
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await _prefs!.setString(_userKey(_transactionsKey), transactionsJson);
      await _prefs!.setInt(_userKey(_transactionsTimestampKey), timestamp);
      
      LogConfig.logInfo('💾 Transactions sauvegardées offline: ${transactions.length} transactions');
    } catch (e) {
      LogConfig.logError('❌ Erreur sauvegarde transactions offline: $e');
    }
  }
  
  /// Récupère les transactions depuis le cache offline
  Future<List<CreditTransaction>> getTransactions() async {
    try {
      if (_prefs == null) return [];
      
      final transactionsJson = _prefs!.getString(_userKey(_transactionsKey));
      if (transactionsJson == null) return [];
      
      final transactionsList = jsonDecode(transactionsJson) as List<dynamic>;
      final transactions = transactionsList
          .map((t) => CreditTransaction.fromJson(t as Map<String, dynamic>))
          .toList();
      
      final timestamp = _prefs!.getInt(_userKey(_transactionsTimestampKey)) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      
      LogConfig.logInfo('📦 Transactions récupérées du cache offline: ${transactions.length} transactions (âge: ${age ~/ 1000}s)');
      return transactions;
    } catch (e) {
      LogConfig.logError('❌ Erreur lecture transactions offline: $e');
      // Nettoyer le cache corrompu
      await _prefs?.remove(_userKey(_transactionsKey));
      await _prefs?.remove(_userKey(_transactionsTimestampKey));
      return [];
    }
  }
  
  // ========== GESTION DES PLANS ==========
  
  /// Sauvegarde les plans de crédits
  Future<void> saveCreditPlans(List<CreditPlan> plans) async {
    try {
      if (_prefs == null) throw StateError('Service non initialisé');
      
      final plansJson = jsonEncode(
        plans.map((p) => p.toJson()).toList(),
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await _prefs!.setString(_userKey(_plansKey), plansJson);
      await _prefs!.setInt(_userKey(_plansTimestampKey), timestamp);
      
      LogConfig.logInfo('💾 Plans crédits sauvegardés offline: ${plans.length} plans');
    } catch (e) {
      LogConfig.logError('❌ Erreur sauvegarde plans offline: $e');
    }
  }
  
  /// Récupère les plans depuis le cache offline
  Future<List<CreditPlan>> getCreditPlans() async {
    try {
      if (_prefs == null) return [];
      
      final plansJson = _prefs!.getString(_userKey(_plansKey));
      if (plansJson == null) return [];
      
      final plansList = jsonDecode(plansJson) as List<dynamic>;
      final plans = plansList
          .map((p) => CreditPlan.fromJson(p as Map<String, dynamic>))
          .toList();
      
      final timestamp = _prefs!.getInt(_userKey(_plansTimestampKey)) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      
      LogConfig.logInfo('📦 Plans récupérés du cache offline: ${plans.length} plans (âge: ${age ~/ 1000}s)');
      return plans;
    } catch (e) {
      LogConfig.logError('❌ Erreur lecture plans offline: $e');
      // Nettoyer le cache corrompu
      await _prefs?.remove(_userKey(_plansKey));
      await _prefs?.remove(_userKey(_plansTimestampKey));
      return [];
    }
  }
  
  /// Vérifie si les plans en cache sont récents (moins de 2 heures)
  Future<bool> arePlansRecent() async {
    try {
      if (_prefs == null) return false;
      
      final timestamp = _prefs!.getInt(_userKey(_plansTimestampKey)) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      return age < (2 * 60 * 60 * 1000); // 2 heures
    } catch (e) {
      return false;
    }
  }
  
  // ========== GESTION DE LA SYNCHRONISATION ==========
  
  /// Marque la dernière synchronisation réussie
  Future<void> markLastSync() async {
    try {
      if (_prefs == null) return;
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _prefs!.setInt(_userKey(_lastSyncKey), timestamp);
      
      LogConfig.logInfo('✅ Dernière sync marquée: ${DateTime.now()}');
    } catch (e) {
      LogConfig.logError('❌ Erreur marquage sync: $e');
    }
  }
  
  /// Récupère le timestamp de la dernière synchronisation
  Future<DateTime?> getLastSync() async {
    try {
      if (_prefs == null) return null;
      
      final timestamp = _prefs!.getInt(_userKey(_lastSyncKey));
      if (timestamp == null) return null;
      
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      LogConfig.logError('❌ Erreur lecture dernière sync: $e');
      return null;
    }
  }
  
  /// Vérifie si une synchronisation est nécessaire (plus de 30 minutes)
  Future<bool> needsSync() async {
    try {
      final lastSync = await getLastSync();
      if (lastSync == null) return true;
      
      final age = DateTime.now().difference(lastSync);
      return age.inMinutes > 30;
    } catch (e) {
      return true;
    }
  }
  
  // ========== TRANSACTIONS PENDANTES ==========
  
  /// Ajoute une transaction en attente de synchronisation
  Future<void> addPendingTransaction(Map<String, dynamic> transactionData) async {
    try {
      if (_prefs == null) return;
      
      final pendingJson = _prefs!.getString(_userKey(_pendingTransactionsKey));
      List<dynamic> pending = [];
      
      if (pendingJson != null) {
        pending = jsonDecode(pendingJson) as List<dynamic>;
      }
      
      // Ajouter timestamp pour ordre et retry
      transactionData['offline_timestamp'] = DateTime.now().millisecondsSinceEpoch;
      pending.add(transactionData);
      
      await _prefs!.setString(_userKey(_pendingTransactionsKey), jsonEncode(pending));
      
      LogConfig.logInfo('📝 Transaction pendante ajoutée: ${transactionData['type']}');
    } catch (e) {
      LogConfig.logError('❌ Erreur ajout transaction pendante: $e');
    }
  }
  
  /// Récupère les transactions en attente de synchronisation
  Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    try {
      if (_prefs == null) return [];
      
      final pendingJson = _prefs!.getString(_userKey(_pendingTransactionsKey));
      if (pendingJson == null) return [];
      
      final pending = jsonDecode(pendingJson) as List<dynamic>;
      return pending.cast<Map<String, dynamic>>();
    } catch (e) {
      LogConfig.logError('❌ Erreur lecture transactions pendantes: $e');
      return [];
    }
  }
  
  /// Nettoie les transactions pendantes après synchronisation
  Future<void> clearPendingTransactions() async {
    try {
      if (_prefs == null) return;
      
      await _prefs!.remove(_userKey(_pendingTransactionsKey));
      LogConfig.logInfo('🧹 Transactions pendantes nettoyées');
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage transactions pendantes: $e');
    }
  }
  
  // ========== DIAGNOSTIC ET MAINTENANCE ==========
  
  /// Informations de diagnostic du cache
  Future<Map<String, dynamic>> getDiagnostics() async {
    try {
      if (_prefs == null) {
        return {'status': 'non_initialized'};
      }
      
      final credits = await getUserCredits();
      final transactions = await getTransactions();
      final plans = await getCreditPlans();
      final lastSync = await getLastSync();
      final pending = await getPendingTransactions();
      
      return {
        'status': 'initialized',
        'user_id': _currentUserId,
        'credits_available': credits?.availableCredits ?? 0,
        'credits_cached': credits != null,
        'transactions_count': transactions.length,
        'plans_count': plans.length,
        'last_sync': lastSync?.toIso8601String(),
        'pending_transactions': pending.length,
        'needs_sync': await needsSync(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }
  
  /// Nettoie complètement le cache de l'utilisateur actuel
  Future<void> clearAll() async {
    try {
      if (_currentUserId != null) {
        await _clearUserCache(_currentUserId!);
        LogConfig.logInfo('🧹 Cache offline complètement nettoyé');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage cache offline: $e');
    }
  }
  
  /// Vérifie l'intégrité du cache et répare si nécessaire
  Future<bool> verifyIntegrity() async {
    try {
      if (_prefs == null) return false;
      
      bool hasIssues = false;
      
      // Vérifier les crédits
      final credits = await getUserCredits();
      if (credits != null && credits.availableCredits < 0) {
        LogConfig.logWarning('⚠️ Crédits négatifs détectés: ${credits.availableCredits}');
        hasIssues = true;
      }
      
      // Vérifier les transactions
      final transactions = await getTransactions();
      for (final transaction in transactions) {
        if (transaction.userId != _currentUserId) {
          LogConfig.logWarning('⚠️ Transaction avec mauvais user_id: ${transaction.id}');
          hasIssues = true;
          break;
        }
      }
      
      return !hasIssues;
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification intégrité: $e');
      return false;
    }
  }
}