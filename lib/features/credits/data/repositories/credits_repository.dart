import 'dart:convert';
import 'package:runaway/core/errors/auth_exceptions.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/domain/models/credit_usage_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreditsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _creditsCacheKey = 'cached_user_credits';
  static const String _plansCacheKey = 'cached_credit_plans';

  /// Récupère les crédits de l'utilisateur connecté
  Future<UserCredits> getUserCredits() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw SessionException('Utilisateur non connecté');
    }

    try {
      print('💰 Récupération des crédits pour: ${user.id}');
      
      final data = await _supabase
          .from('user_credits')
          .select()
          .eq('user_id', user.id)
          .single();

      final credits = UserCredits.fromJson(data);
      
      // Cache local pour mode offline
      await _cacheCredits(credits);
      
      print('✅ Crédits récupérés: ${credits.availableCredits} disponibles');
      return credits;
      
    } catch (e) {
      print('❌ Erreur récupération crédits: $e');
      
      // Tentative de récupération depuis le cache
      final cachedCredits = await _getCachedCredits();
      if (cachedCredits != null) {
        print('📦 Crédits récupérés depuis le cache');
        return cachedCredits;
      }
      
      if (e is PostgrestException) {
        throw ServerException(
          'Erreur lors de la récupération des crédits',
          e.code?.isNotEmpty == true ? int.tryParse(e.code!) ?? 500 : 500,
        );
      }
      
      throw NetworkException('Impossible de récupérer les crédits');
    }
  }

  /// Utilise des crédits pour une action
  Future<CreditUsageResult> useCredits({
    required int amount,
    required String reason,
    String? routeGenerationId,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw SessionException('Utilisateur non connecté');
    }

    if (amount <= 0) {
      throw ValidationException([
        ValidationError(field: 'amount', message: 'Le nombre de crédits doit être positif')
      ]);
    }

    try {
      print('💸 Utilisation de $amount crédits pour: $reason');
      
      // Appel de la fonction PostgreSQL pour garantir l'atomicité
      final result = await _supabase.rpc('process_credit_transaction', params: {
        'p_user_id': user.id,
        'p_amount': -amount, // Négatif pour utilisation
        'p_transaction_type': 'usage',
        'p_description': reason,
        'p_route_generation_id': routeGenerationId,
        'p_metadata': metadata ?? {},
      });

      if (result['success'] == true) {
        // Récupérer les crédits mis à jour
        final updatedCredits = await getUserCredits();
        
        print('✅ Crédits utilisés avec succès. Solde: ${updatedCredits.availableCredits}');
        
        return CreditUsageResult.success(
          updatedCredits: updatedCredits,
          transactionId: result['transaction_id'],
        );
      } else {
        throw Exception('Échec de la transaction: ${result['error'] ?? 'Erreur inconnue'}');
      }
      
    } catch (e) {
      print('❌ Erreur utilisation crédits: $e');
      
      if (e.toString().contains('Crédits insuffisants')) {
        return CreditUsageResult.failure(
          errorMessage: 'Vous n\'avez pas assez de crédits pour cette action',
        );
      }
      
      return CreditUsageResult.failure(
        errorMessage: 'Erreur lors de l\'utilisation des crédits',
      );
    }
  }

  /// Achète des crédits selon un plan
  Future<UserCredits> refreshUserCredits() => getUserCredits();

  /// Récupère tous les plans de crédits disponibles
  Future<List<CreditPlan>> getCreditPlans() async {
    try {
      print('📋 Récupération des plans de crédits');
      
      final data = await _supabase
          .from('credit_plans')
          .select()
          .eq('is_active', true)
          .order('price');

      final plans = (data as List<dynamic>)
          .map((planData) => CreditPlan.fromJson(planData))
          .toList();
      
      // Cache local
      await _cachePlans(plans);
      
      print('✅ ${plans.length} plans récupérés');
      return plans;
      
    } catch (e) {
      print('❌ Erreur récupération plans: $e');
      
      // Tentative de récupération depuis le cache
      final cachedPlans = await _getCachedPlans();
      if (cachedPlans != null && cachedPlans.isNotEmpty) {
        print('📦 Plans récupérés depuis le cache');
        return cachedPlans;
      }
      
      throw NetworkException('Impossible de récupérer les plans de crédits');
    }
  }

  /// Récupère un plan spécifique par son ID
  Future<CreditPlan?> getCreditPlan(String planId) async {
    try {
      final data = await _supabase
          .from('credit_plans')
          .select()
          .eq('id', planId)
          .eq('is_active', true)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return CreditPlan.fromJson(data);
      
    } catch (e) {
      print('❌ Erreur récupération plan $planId: $e');
      return null;
    }
  }

  /// Récupère l'historique des transactions
  Future<List<CreditTransaction>> getTransactionHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw SessionException('Utilisateur non connecté');
    }

    try {
      print('📊 Récupération historique transactions (limit: $limit, offset: $offset)');
      
      final data = await _supabase
          .from('credit_transactions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final transactions = (data as List<dynamic>)
          .map((transactionData) => CreditTransaction.fromJson(transactionData))
          .toList();
      
      print('✅ ${transactions.length} transactions récupérées');
      return transactions;
      
    } catch (e) {
      print('❌ Erreur récupération historique: $e');
      throw NetworkException('Impossible de récupérer l\'historique');
    }
  }

  /// Vérifie si l'utilisateur a suffisamment de crédits
  Future<bool> hasEnoughCredits(int requiredCredits) async {
    try {
      final credits = await getUserCredits();
      return credits.availableCredits >= requiredCredits;
    } catch (e) {
      print('❌ Erreur vérification crédits: $e');
      return false;
    }
  }

  // ============================================
  // MÉTHODES PRIVÉES POUR LE CACHE LOCAL
  // ============================================

  Future<void> _cacheCredits(UserCredits credits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_creditsCacheKey, jsonEncode(credits.toJson()));
    } catch (e) {
      print('⚠️ Erreur cache crédits: $e');
    }
  }

  Future<UserCredits?> _getCachedCredits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_creditsCacheKey);
      if (cached != null) {
        return UserCredits.fromJson(jsonDecode(cached));
      }
    } catch (e) {
      print('⚠️ Erreur lecture cache crédits: $e');
    }
    return null;
  }

  Future<void> _cachePlans(List<CreditPlan> plans) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plansJson = plans.map((plan) => plan.toJson()).toList();
      await prefs.setString(_plansCacheKey, jsonEncode(plansJson));
    } catch (e) {
      print('⚠️ Erreur cache plans: $e');
    }
  }

  Future<List<CreditPlan>?> _getCachedPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_plansCacheKey);
      if (cached != null) {
        final plansJson = jsonDecode(cached) as List<dynamic>;
        return plansJson.map((planData) => CreditPlan.fromJson(planData)).toList();
      }
    } catch (e) {
      print('⚠️ Erreur lecture cache plans: $e');
    }
    return null;
  }

  /// Clear cache (utile pour logout)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_creditsCacheKey);
      await prefs.remove(_plansCacheKey);
      print('🧹 Cache crédits nettoyé');
    } catch (e) {
      print('⚠️ Erreur nettoyage cache: $e');
    }
  }
}