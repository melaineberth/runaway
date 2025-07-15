import 'package:runaway/core/errors/auth_exceptions.dart';
import 'package:runaway/core/services/cache_service.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/domain/models/credit_usage_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository optimisé pour les crédits avec CacheService intégré
class CreditsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CacheService _cache = CacheService.instance;

  /// Récupère les crédits de l'utilisateur connecté avec cache intelligent
  Future<UserCredits> getUserCredits({bool forceRefresh = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw SessionException('Utilisateur non connecté');
    }

    // Vérifier le cache d'abord (sauf si forceRefresh)
    if (!forceRefresh) {
      // ✅ FIX: Récupérer comme Map puis convertir
      final cachedCreditsRaw = await _cache.get<Map>('cache_user_credits');
      if (cachedCreditsRaw != null) {
        try {
          final cachedCredits = UserCredits.fromJson(Map<String, dynamic>.from(cachedCreditsRaw));
          print('📦 Crédits récupérés depuis le cache: ${cachedCredits.availableCredits}');
          return cachedCredits;
        } catch (e) {
          print('❌ Erreur conversion cache crédits: $e');
          // Continuer vers l'API si erreur de conversion
        }
      }
    }

    try {
      print('🌐 Récupération des crédits depuis l\'API pour: ${user.id}');
      
      final data = await _supabase
          .from('user_credits')
          .select()
          .eq('user_id', user.id)
          .single();

      final credits = UserCredits.fromJson(data);
      
      // Mise en cache avec expiration
      await _cache.set('cache_user_credits', credits);
      
      print('✅ Crédits récupérés: ${credits.availableCredits} disponibles');
      return credits;
      
    } catch (e) {
      print('❌ Erreur récupération crédits: $e');
      
      // Tentative de récupération depuis le cache en cas d'erreur
      final cachedCreditsRaw = await _cache.get<Map>('cache_user_credits');
      if (cachedCreditsRaw != null) {
        try {
          final cachedCredits = UserCredits.fromJson(Map<String, dynamic>.from(cachedCreditsRaw));
          print('📦 Crédits récupérés depuis le cache de secours');
          return cachedCredits;
        } catch (e) {
          print('❌ Erreur conversion cache de secours: $e');
        }
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

  /// Utilise des crédits avec transaction atomique et cache intelligent
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

    try {
      print('💰 Utilisation de $amount crédits pour: $reason');
      
      // Appel de la fonction Supabase avec transaction atomique
      final response = await _supabase.rpc('use_credits', params: {
        'user_id': user.id,
        'amount': amount,
        'reason': reason,
        'route_generation_id': routeGenerationId,
        'metadata': metadata,
      });

      final result = CreditUsageResult.fromJson(response);
      
      if (result.success) {
        // Invalider le cache des crédits après utilisation
        await _cache.invalidateCreditsCache();
        
        // Optionnel: Mettre à jour le cache avec les nouvelles données
        if (result.newCredits != null) {
          await _cache.set('cache_user_credits', result.newCredits!);
        }
        
        print('✅ Crédits utilisés avec succès. Nouveau solde: ${result.newCredits?.availableCredits}');
      } else {
        print('❌ Échec utilisation crédits: ${result.error}');
      }
      
      return result;
      
    } catch (e) {
      print('❌ Erreur utilisation crédits: $e');
      
      if (e is PostgrestException) {
        throw ServerException(
          'Erreur lors de l\'utilisation des crédits',
          e.code?.isNotEmpty == true ? int.tryParse(e.code!) ?? 500 : 500,
        );
      }
      
      throw NetworkException('Impossible d\'utiliser les crédits');
    }
  }

  /// Récupère les plans de crédits disponibles avec cache long terme
  Future<List<CreditPlan>> getCreditPlans({bool forceRefresh = false}) async {
    // Cache avec durée plus longue pour les plans (ils changent rarement)
    if (!forceRefresh) {
      // ✅ FIX: Récupérer comme List<dynamic> puis convertir
      final cachedPlansRaw = await _cache.get<List>('cache_credit_plans');
      if (cachedPlansRaw != null) {
        try {
          final cachedPlans = cachedPlansRaw
              .map((item) => CreditPlan.fromJson(item as Map<String, dynamic>))
              .toList();
          print('📦 Plans récupérés depuis le cache: ${cachedPlans.length} plans');
          return cachedPlans;
        } catch (e) {
          print('❌ Erreur conversion cache plans: $e');
          // Continuer vers l'API si erreur de conversion
        }
      }
    }

    try {
      print('🌐 Récupération des plans depuis l\'API');
      
      final data = await _supabase
          .from('credit_plans')
          .select()
          .eq('is_active', true)
          .order('price');

      final plans = data.map((item) => CreditPlan.fromJson(item)).toList();
      
      // Cache avec expiration longue (2 heures)
      await _cache.set('cache_credit_plans', plans, 
        customExpiration: const Duration(hours: 2));
      
      print('✅ Plans récupérés: ${plans.length} plans disponibles');
      return plans;
      
    } catch (e) {
      print('❌ Erreur récupération plans: $e');
      
      // Tentative de récupération depuis le cache en cas d'erreur
      final cachedPlansRaw = await _cache.get<List>('cache_credit_plans');
      if (cachedPlansRaw != null) {
        try {
          final cachedPlans = cachedPlansRaw
              .map((item) => CreditPlan.fromJson(item as Map<String, dynamic>))
              .toList();
          print('📦 Plans récupérés depuis le cache de secours');
          return cachedPlans;
        } catch (e) {
          print('❌ Erreur conversion cache de secours: $e');
        }
      }
      
      if (e is PostgrestException) {
        throw ServerException(
          'Erreur lors de la récupération des plans',
          e.code?.isNotEmpty == true ? int.tryParse(e.code!) ?? 500 : 500,
        );
      }
      
      throw NetworkException('Impossible de récupérer les plans');
    }
  }

  /// Récupère l'historique des transactions avec pagination et cache
    Future<List<CreditTransaction>> getCreditTransactions({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw SessionException('Utilisateur non connecté');
    }

    final cacheKey = 'cache_credit_transactions_${offset}_$limit';
    
    // Vérifier le cache
    if (!forceRefresh) {
      // ✅ FIX: Récupérer comme List<dynamic> puis convertir
      final cachedTransactionsRaw = await _cache.get<List>(cacheKey);
      if (cachedTransactionsRaw != null) {
        try {
          final cachedTransactions = cachedTransactionsRaw
              .map((item) => CreditTransaction.fromJson(item as Map<String, dynamic>))
              .toList();
          print('📦 Transactions récupérées depuis le cache: ${cachedTransactions.length}');
          return cachedTransactions;
        } catch (e) {
          print('❌ Erreur conversion cache transactions: $e');
          // Continuer vers l'API si erreur de conversion
        }
      }
    }

    try {
      print('🌐 Récupération des transactions depuis l\'API');
      
      final data = await _supabase
          .from('credit_transactions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);

      final transactions = data.map((item) => CreditTransaction.fromJson(item)).toList();
      
      // Cache avec expiration courte (5 minutes)
      await _cache.set(cacheKey, transactions, 
        customExpiration: const Duration(minutes: 5));
      
      print('✅ Transactions récupérées: ${transactions.length}');
      return transactions;
      
    } catch (e) {
      print('❌ Erreur récupération transactions: $e');
      
      // Tentative de récupération depuis le cache
      final cachedTransactionsRaw = await _cache.get<List>(cacheKey);
      if (cachedTransactionsRaw != null) {
        try {
          final cachedTransactions = cachedTransactionsRaw
              .map((item) => CreditTransaction.fromJson(item as Map<String, dynamic>))
              .toList();
          print('📦 Transactions récupérées depuis le cache de secours');
          return cachedTransactions;
        } catch (e) {
          print('❌ Erreur conversion cache de secours: $e');
        }
      }
      
      if (e is PostgrestException) {
        throw ServerException(
          'Erreur lors de la récupération des transactions',
          e.code?.isNotEmpty == true ? int.tryParse(e.code!) ?? 500 : 500,
        );
      }
      
      throw NetworkException('Impossible de récupérer les transactions');
    }
  }

  /// Ajoute des crédits après un achat IAP
  Future<UserCredits> addCredits({
    required int amount,
    required String transactionId,
    required String productId,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw SessionException('Utilisateur non connecté');
    }

    try {
      print('💰 Ajout de $amount crédits après achat IAP');
      
      // Appel de la fonction Supabase avec transaction atomique
      final response = await _supabase.rpc('add_credits', params: {
        'user_id': user.id,
        'amount': amount,
        'transaction_id': transactionId,
        'product_id': productId,
        'metadata': metadata,
      });

      final newCredits = UserCredits.fromJson(response);
      
      // Invalider tout le cache crédits après ajout
      await _cache.invalidateCreditsCache();
      
      // Mettre à jour le cache avec les nouvelles données
      await _cache.set('cache_user_credits', newCredits);
      
      print('✅ Crédits ajoutés avec succès. Nouveau solde: ${newCredits.availableCredits}');
      return newCredits;
      
    } catch (e) {
      print('❌ Erreur ajout crédits: $e');
      
      if (e is PostgrestException) {
        throw ServerException(
          'Erreur lors de l\'ajout des crédits',
          e.code?.isNotEmpty == true ? int.tryParse(e.code!) ?? 500 : 500,
        );
      }
      
      throw NetworkException('Impossible d\'ajouter les crédits');
    }
  }

  /// Invalide spécifiquement le cache des crédits
  Future<void> invalidateCreditsCache() async {
    await _cache.invalidateCreditsCache();
    print('🧹 Cache crédits invalidé');
  }

  /// Vérifie si l'utilisateur a suffisamment de crédits
  Future<bool> hasEnoughCredits(int requiredAmount) async {
    try {
      final credits = await getUserCredits();
      return credits.availableCredits >= requiredAmount;
    } catch (e) {
      print('❌ Erreur vérification crédits: $e');
      return false;
    }
  }

  /// Obtient le solde actuel rapidement (cache uniquement)
  Future<int> getQuickBalance() async {
    try {
      final cachedCredits = await _cache.get<UserCredits>('cache_user_credits');
      return cachedCredits?.availableCredits ?? 0;
    } catch (e) {
      print('❌ Erreur lecture solde rapide: $e');
      return 0;
    }
  }
}