import 'dart:convert';

import 'package:runaway/core/errors/auth_exceptions.dart';
import 'package:runaway/core/helper/services/cache_service.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
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
      
      // 🆕 Métrique des crédits utilisateur
      MonitoringService.instance.recordMetric(
        'user_credits_loaded',
        credits.availableCredits,
        tags: {
          'user_id': user.id,
          'has_credits': (credits.availableCredits > 0).toString(),
          'total_purchased': credits.totalCreditsPurchased.toString(),
        },
      );

      return credits;
      
    } catch (e, stackTrace) {
      print('❌ Erreur récupération crédits: $e');

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'CreditsRepository.getUserCredits',
        extra: {
          'user_id': user.id,
        },
      );
      
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
    String? purpose,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw SessionException('Utilisateur non connecté');
    }

    try {
      print('💰 Utilisation de $amount crédits pour: $reason');
      
      // ✅ ÉTAPE 1: Appel de la fonction corrigée use_user_credits
      final success = await _supabase.rpc('use_user_credits', params: {
        'p_user_id': user.id,
        'p_amount': amount,
      });

      if (success != true) {
        return CreditUsageResult.failure(
          errorMessage: 'Échec de la consommation des crédits',
        );
      }

      print('✅ Consommation des crédits réussie');

      // ✅ ÉTAPE 2: Créer la transaction manuellement
      String? transactionId;
      try {
        final transactionData = await _supabase
            .from('credit_transactions')
            .insert({
              'user_id': user.id,
              'amount': -amount, // Négatif pour une utilisation
              'transaction_type': 'usage',
              'description': reason,
              'route_generation_id': routeGenerationId,
              'metadata': metadata ?? {},
            })
            .select('id')
            .single();
        
        transactionId = transactionData['id'] as String;
        print('✅ Transaction créée: $transactionId');
      } catch (e) {
        print('⚠️ Erreur création transaction: $e');
        // Continue quand même car les crédits ont été débités
      }

      // ✅ ÉTAPE 3: Récupérer les crédits mis à jour
      try {
        final updatedData = await _supabase
            .from('user_credits')
            .select()
            .eq('user_id', user.id)
            .single();

        final updatedCredits = UserCredits.fromJson(updatedData);
        
        // Invalider le cache après utilisation
        await _cache.invalidateCreditsCache();
        
        // Mettre à jour le cache avec les nouvelles données
        await _cache.set('cache_user_credits', updatedCredits);
        
        print('✅ Nouveau solde: ${updatedCredits.availableCredits} crédits');

        return CreditUsageResult.success(
          updatedCredits: updatedCredits,
          transactionId: transactionId ?? 'unknown',
        );

      } catch (e) {
        print('❌ Erreur récupération crédits mis à jour: $e');
        
        // En cas d'erreur, on retourne quand même un succès car les crédits ont été débités
        // mais sans les données mises à jour
        return CreditUsageResult.success(
          updatedCredits: UserCredits(
            id: '',
            userId: user.id,
            availableCredits: 0, // On ne connaît pas le nouveau solde
            totalCreditsPurchased: 0,
            totalCreditsUsed: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          transactionId: transactionId ?? 'unknown',
        );
      }
      
    } catch (e, stackTrace) {
      print('❌ Erreur utilisation crédits: $e');

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'CreditsRepository.useCredits',
        extra: {
          'user_id': user.id,
          'amount': amount,
          'reason': reason,
        },
      );
      
      if (e is PostgrestException) {
        // Gérer les erreurs spécifiques de la base de données
        if (e.message.contains('Insufficient credits')) {
          return CreditUsageResult.failure(
            errorMessage: 'Crédits insuffisants pour cette opération',
          );
        } else if (e.message.contains('User credits not found')) {
          return CreditUsageResult.failure(
            errorMessage: 'Compte de crédits non trouvé. Veuillez vous reconnecter.',
          );
        }
        
        return CreditUsageResult.failure(
          errorMessage: 'Erreur lors de l\'utilisation des crédits',
        );
      }
      
      return CreditUsageResult.failure(
        errorMessage: 'Erreur lors de l\'utilisation des crédits',
      );
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
      try {
        // ✅ FIX: Gestion robuste du cache
        final cachedRaw = await _cache.get<dynamic>(cacheKey);
        if (cachedRaw != null) {
          List<dynamic> cachedList;
          
          // Gérer différents formats de cache
          if (cachedRaw is List) {
            cachedList = cachedRaw;
          } else if (cachedRaw is String) {
            // Si c'est une string JSON, la parser
            try {
              final parsed = jsonDecode(cachedRaw);
              cachedList = parsed is List ? parsed : [parsed];
            } catch (e) {
              print('❌ Cache corrompu (JSON invalide): $e');
              await _cache.remove(cacheKey);
              cachedList = [];
            }
          } else {
            print('❌ Cache format inattendu: ${cachedRaw.runtimeType}');
            await _cache.remove(cacheKey);
            cachedList = [];
          }

          if (cachedList.isNotEmpty) {
            try {
              final cachedTransactions = cachedList
                  .cast<Map<String, dynamic>>()
                  .map((item) => CreditTransaction.fromJson(item))
                  .toList();
              print('📦 Transactions récupérées depuis le cache: ${cachedTransactions.length}');
              return cachedTransactions;
            } catch (e) {
              print('❌ Erreur conversion cache transactions: $e');
              // Supprimer le cache corrompu
              await _cache.remove(cacheKey);
            }
          }
        }
      } catch (e) {
        print('❌ Erreur lecture cache transactions: $e');
        // Continuer vers l'API
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
      
      // ✅ FIX: Mise en cache sécurisée
      try {
        // Convertir en format sérialisable avant mise en cache
        final serializableData = transactions.map((t) => t.toJson()).toList();
        await _cache.set(cacheKey, serializableData, 
          customExpiration: const Duration(minutes: 5));
        print('💾 Cache mis à jour: $cacheKey (expire dans 5min)');
      } catch (e) {
        print('⚠️ Erreur mise en cache transactions: $e');
        // Continuer même si le cache échoue
      }
      
      print('✅ Transactions récupérées: ${transactions.length}');
      return transactions;
      
    } catch (e, stackTrace) {
      print('❌ Erreur récupération transactions: $e');
      
      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'CreditsRepository.getCreditTransactions',
        extra: {
          'user_id': user.id,
          'limit': limit,
          'offset': offset,
        },
      );
      
      // Dernière tentative avec le cache en cas d'erreur réseau
      try {
        final cachedRaw = await _cache.get<List>(cacheKey);
        if (cachedRaw != null) {
          final cachedTransactions = cachedRaw
              .cast<Map<String, dynamic>>()
              .map((item) => CreditTransaction.fromJson(item))
              .toList();
          print('📦 Transactions récupérées depuis le cache de secours');
          return cachedTransactions;
        }
      } catch (cacheError) {
        print('❌ Erreur cache de secours: $cacheError');
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
      
      // ✅ ÉTAPE 1: Appel de la fonction corrigée add_user_credits
      await _supabase.rpc('add_user_credits', params: {
        'p_user_id': user.id,
        'p_amount': amount,
      });

      print('✅ Ajout des crédits réussi');

      // ✅ ÉTAPE 2: Créer la transaction d'achat
      try {
        await _supabase
            .from('credit_transactions')
            .insert({
              'user_id': user.id,
              'amount': amount, // Positif pour un achat
              'transaction_type': 'purchase',
              'description': 'Achat de crédits via $productId',
              'payment_intent_id': transactionId,
              'metadata': {
                'product_id': productId,
                'transaction_id': transactionId,
                ...?metadata,
              },
            });
        
        print('✅ Transaction d\'achat créée');
      } catch (e) {
        print('⚠️ Erreur création transaction d\'achat: $e');
        // Continue quand même car les crédits ont été ajoutés
      }

      // ✅ ÉTAPE 3: Récupérer les crédits mis à jour
      final updatedData = await _supabase
          .from('user_credits')
          .select()
          .eq('user_id', user.id)
          .single();

      final newCredits = UserCredits.fromJson(updatedData);
      
      // Invalider tout le cache crédits après ajout
      await _cache.invalidateCreditsCache();
      
      // Mettre à jour le cache avec les nouvelles données
      await _cache.set('cache_user_credits', newCredits);
      
      print('✅ Crédits ajoutés avec succès. Nouveau solde: ${newCredits.availableCredits}');
      return newCredits;
      
    } catch (e, stackTrace) {
      print('❌ Erreur ajout crédits: $e');

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'CreditsRepository.addCredits',
        extra: {
          'user_id': user.id,
          'amount': amount,
          'transaction_id': transactionId,
          'product_id': productId,
        },
      );
      
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