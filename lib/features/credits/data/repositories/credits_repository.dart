import 'dart:convert';
import 'dart:math' as math;

import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/errors/auth_exceptions.dart';
import 'package:runaway/core/helper/services/app_data_initialization_service.dart';
import 'package:runaway/core/helper/services/cache_service.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/core/utils/injections/service_locator.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/domain/models/credit_usage_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runaway/core/helper/config/log_config.dart';

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

    // Vérifier si l'utilisateur a changé avec la nouvelle logique
    final hasUserChanged = await _cache.hasUserChanged(user.id);
    if (hasUserChanged) {
      LogConfig.logInfo('👤 Changement d\'utilisateur détecté - nettoyage forcé');
      
      // Nettoyage dans le bon ordre
      await _cache.forceCompleteClearing();
      
      // Confirmer le changement d'utilisateur APRÈS le nettoyage
      await _cache.confirmUserChange(user.id);
      
      forceRefresh = true; // Forcer le refresh pour le nouvel utilisateur
    }

    // TOUJOURS forcer le refresh pour un nouvel utilisateur
    final shouldForceRefresh = forceRefresh || 
                            await _shouldForceRefreshForNewUser(user.id) ||
                            await _shouldRandomVerification() ||
                            hasUserChanged;

    // Vérifier le cache seulement si pas de changement d'utilisateur
    if (!shouldForceRefresh && !hasUserChanged) {
      final cachedCreditsRaw = await _cache.get<Map>('cache_user_credits');
      if (cachedCreditsRaw != null) {
        try {
          final cachedCredits = UserCredits.fromJson(Map<String, dynamic>.from(cachedCreditsRaw));
          
          // Validation périodique du cache
          if (await _shouldValidateCache(cachedCredits)) {
            final serverCredits = await _getCreditsFromServer(user.id);
            if (_areCreditsInconsistent(cachedCredits, serverCredits)) {
              LogConfig.logInfo('⚠️ Incohérence détectée cache vs serveur - invalidation');
              await _handleCreditsInconsistency(user.id, cachedCredits, serverCredits);
              return serverCredits; // Retourner les données serveur
            }
          }
          
          LogConfig.logInfo('📦 Crédits récupérés depuis le cache: ${cachedCredits.availableCredits}');
          return cachedCredits;
        } catch (e) {
          LogConfig.logError('❌ Erreur conversion cache crédits: $e');
          await _cache.remove('cache_user_credits'); // Nettoyer le cache corrompu
        }
      }
    }

    try {
      LogConfig.logInfo('🌐 Récupération des crédits depuis l\'API pour: ${user.id}');
      final credits = await _getCreditsFromServer(user.id);

      // Vérification de cohérence renforcée
      await _verifyCreditsCoherence(user.id, credits);
      
      // Mise en cache avec clé spécifique à l'utilisateur
      await _cache.set('cache_user_credits', credits);
      await _cache.set('user_credits_timestamp', DateTime.now().toIso8601String());
      
      LogConfig.logInfo('Crédits récupérés: ${credits.availableCredits} disponibles');
      
      // Métrique des crédits utilisateur
      MonitoringService.instance.recordMetric(
        'user_credits_loaded',
        credits.availableCredits,
        tags: {
          'user_id': user.id,
          'has_credits': (credits.availableCredits > 0).toString(),
          'total_purchased': credits.totalCreditsPurchased.toString(),
          'cache_refresh': shouldForceRefresh.toString(),
        },
      );

      return credits;
      
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur récupération crédits: $e');

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'CreditsRepository.getUserCredits',
        extra: {
          'user_id': user.id,
          'has_user_changed': hasUserChanged.toString(),
        },
      );
      
      // Tentative de récupération depuis le cache en cas d'erreur
      // mais seulement si l'utilisateur n'a pas changé
      if (!hasUserChanged) {
        final cachedCreditsRaw = await _cache.get<Map>('cache_user_credits');
        if (cachedCreditsRaw != null) {
          try {
            final cachedCredits = UserCredits.fromJson(Map<String, dynamic>.from(cachedCreditsRaw));
            LogConfig.logInfo('📦 Crédits récupérés depuis le cache de secours');
            return cachedCredits;
          } catch (e) {
            LogConfig.logError('❌ Erreur conversion cache de secours: $e');
          }
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
      LogConfig.logInfo('💰 Utilisation de $amount crédits pour: $reason');
      
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

      LogConfig.logInfo('Consommation des crédits réussie');

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
        LogConfig.logInfo('Transaction créée: $transactionId');
      } catch (e) {
        LogConfig.logInfo('Erreur création transaction: $e');
        // Continue quand même car les crédits ont été débités
      }

      // ✅ ÉTAPE 3: CORRECTION - Invalider TOUS les caches liés aux transactions
      await _invalidateAllTransactionCaches();
      
      // ✅ ÉTAPE 4: Invalider le cache des crédits
      await _cache.invalidateCreditsCache();

      // ✅ ÉTAPE 5: Récupérer les crédits mis à jour
      try {
        final updatedData = await _supabase
            .from('user_credits')
            .select()
            .eq('user_id', user.id)
            .single();

        final updatedCredits = UserCredits.fromJson(updatedData);
        
        // Mettre à jour le cache avec les nouvelles données
        await _cache.set('cache_user_credits', updatedCredits);
        
        LogConfig.logInfo('Nouveau solde: ${updatedCredits.availableCredits} crédits');

        return CreditUsageResult.success(
          updatedCredits: updatedCredits,
          transactionId: transactionId ?? 'unknown',
        );

      } catch (e) {
        LogConfig.logError('❌ Erreur récupération crédits mis à jour: $e');
        
        // En cas d'erreur, on retourne quand même un succès car les crédits ont été débités
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
      LogConfig.logError('❌ Erreur utilisation crédits: $e');
      
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
        if (e.code == '23514') {
          return CreditUsageResult.failure(
            errorMessage: 'Crédits insuffisants',
          );
        }
        
        return CreditUsageResult.failure(
          errorMessage: 'Erreur serveur lors de l\'utilisation des crédits',
        );
      }
      
      return CreditUsageResult.failure(
        errorMessage: 'Erreur réseau lors de l\'utilisation des crédits',
      );
    }
  }

  /// 🆕 Invalide tous les caches de transactions (toutes les variations de pagination)
  Future<void> _invalidateAllTransactionCaches() async {
    try {
      LogConfig.logInfo('🧹 Invalidation de tous les caches de transactions...');
      
      // CORRECTION 1: Invalider toutes les clés de cache de transactions
      final allKeys = await _cache.getAllKeys();
      final transactionCacheKeys = allKeys.where((key) => 
        key.startsWith('cache_credit_transactions_') ||
        key.contains('credit_transactions') ||
        key.contains('transaction_history')
      ).toList();
      
      for (final key in transactionCacheKeys) {
        await _cache.remove(key);
      }
      
      LogConfig.logInfo('🧹 ${transactionCacheKeys.length} caches de transactions invalidés');
    } catch (e) {
      LogConfig.logError('❌ Erreur invalidation caches transactions: $e');
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
          LogConfig.logInfo('📦 Plans récupérés depuis le cache: ${cachedPlans.length} plans');
          return cachedPlans;
        } catch (e) {
          LogConfig.logError('❌ Erreur conversion cache plans: $e');
          // Continuer vers l'API si erreur de conversion
        }
      }
    }

    try {
      LogConfig.logInfo('🌐 Récupération des plans depuis l\'API');
      
      final data = await _supabase
          .from('credit_plans')
          .select()
          .eq('is_active', true)
          .order('price');

      final plans = data.map((item) => CreditPlan.fromJson(item)).toList();
      
      // Cache avec expiration longue (2 heures)
      await _cache.set('cache_credit_plans', plans, 
        customExpiration: const Duration(hours: 2));
      
      LogConfig.logInfo('Plans récupérés: ${plans.length} plans disponibles');
      return plans;
      
    } catch (e) {
      LogConfig.logError('❌ Erreur récupération plans: $e');
      
      // Tentative de récupération depuis le cache en cas d'erreur
      final cachedPlansRaw = await _cache.get<List>('cache_credit_plans');
      if (cachedPlansRaw != null) {
        try {
          final cachedPlans = cachedPlansRaw
              .map((item) => CreditPlan.fromJson(item as Map<String, dynamic>))
              .toList();
          LogConfig.logInfo('📦 Plans récupérés depuis le cache de secours');
          return cachedPlans;
        } catch (e) {
          LogConfig.logError('❌ Erreur conversion cache de secours: $e');
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

    // CORRECTION 2: Vérifier le changement d'utilisateur pour les transactions aussi
    final hasUserChanged = await _cache.hasUserChanged(user.id);
    if (hasUserChanged) {
      LogConfig.logInfo('👤 Changement utilisateur détecté - forcer refresh transactions');
      forceRefresh = true;
    }

    final cacheKey = 'cache_credit_transactions_${user.id}_${offset}_$limit';
    
    // CORRECTION 3: Vérifier le cache seulement si pas de changement d'utilisateur
    if (!forceRefresh && !hasUserChanged) {
      try {
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
              LogConfig.logError('❌ Cache transactions corrompu (JSON invalide): $e');
              await _cache.remove(cacheKey);
              cachedList = [];
            }
          } else {
            LogConfig.logError('❌ Cache transactions format inattendu: ${cachedRaw.runtimeType}');
            await _cache.remove(cacheKey);
            cachedList = [];
          }

          if (cachedList.isNotEmpty) {
            try {
              final cachedTransactions = cachedList
                  .cast<Map<String, dynamic>>()
                  .map((item) => CreditTransaction.fromJson(item))
                  .toList();
              LogConfig.logInfo('📦 Transactions récupérées depuis le cache: ${cachedTransactions.length}');
              return cachedTransactions;
            } catch (e) {
              LogConfig.logError('❌ Erreur conversion cache transactions: $e');
              // Supprimer le cache corrompu
              await _cache.remove(cacheKey);
            }
          }
        }
      } catch (e) {
        LogConfig.logError('❌ Erreur lecture cache transactions: $e');
        // Continuer vers l'API
      }
    }

    try {
      LogConfig.logInfo('🌐 Récupération des transactions depuis l\'API');
      
      final data = await _supabase
          .from('credit_transactions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);

      final transactions = data.map((item) => CreditTransaction.fromJson(item)).toList();
      
      // CORRECTION 4: Mise en cache sécurisée avec clé incluant l'user_id
      try {
        // Convertir en format sérialisable avant mise en cache
        final serializableData = transactions.map((t) => t.toJson()).toList();
        await _cache.set(cacheKey, serializableData, 
          customExpiration: const Duration(minutes: 5));
        LogConfig.logInfo('💾 Cache transactions mis à jour: $cacheKey (expire dans 5min)');
      } catch (e) {
        LogConfig.logInfo('Erreur mise en cache transactions: $e');
        // Continuer même si le cache échoue
      }
      
      LogConfig.logInfo('Transactions récupérées: ${transactions.length}');
      return transactions;
      
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur récupération transactions: $e');
      
      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'CreditsRepository.getCreditTransactions',
        extra: {
          'user_id': user.id,
          'limit': limit,
          'offset': offset,
          'has_user_changed': hasUserChanged.toString(),
        },
      );
      
      // CORRECTION 5: Cache de secours seulement si l'utilisateur n'a pas changé
      if (!hasUserChanged) {
        try {
          final cachedRaw = await _cache.get<List>(cacheKey);
          if (cachedRaw != null) {
            final cachedTransactions = cachedRaw
                .cast<Map<String, dynamic>>()
                .map((item) => CreditTransaction.fromJson(item))
                .toList();
            LogConfig.logInfo('📦 Transactions récupérées depuis le cache de secours');
            return cachedTransactions;
          }
        } catch (cacheError) {
          LogConfig.logError('❌ Erreur cache de secours: $cacheError');
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
      LogConfig.logInfo('💰 Ajout de $amount crédits après achat IAP');
      
      // ✅ ÉTAPE 1: Appel de la fonction corrigée add_user_credits
      await _supabase.rpc('add_user_credits', params: {
        'p_user_id': user.id,
        'p_amount': amount,
      });

      LogConfig.logInfo('Ajout des crédits réussi');

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
        
        LogConfig.logInfo('Transaction d\'achat créée');
      } catch (e) {
        LogConfig.logInfo('Erreur création transaction d\'achat: $e');
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
      
      // Notifier immédiatement l'AppDataBloc pour mise à jour du cache
      try {
        AppDataInitializationService.confirmCreditBalance(newCredits.availableCredits);
        AppDataInitializationService.refreshCreditData();
        LogConfig.logInfo('✅ AppDataBloc notifié pour mise à jour immédiate');
      } catch (e) {
        LogConfig.logError('❌ Erreur notification AppDataBloc: $e');
      }
      
      LogConfig.logInfo('Crédits ajoutés avec succès. Nouveau solde: ${newCredits.availableCredits}');
      return newCredits;
      
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur ajout crédits: $e');

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
    LogConfig.logInfo('🧹 Cache crédits invalidé');
  }

  /// Vérifie si l'utilisateur a suffisamment de crédits
  Future<bool> hasEnoughCredits(int requiredAmount) async {
    try {
      final credits = await getUserCredits();
      return credits.availableCredits >= requiredAmount;
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification crédits: $e');
      return false;
    }
  }

  /// Obtient le solde actuel rapidement (cache uniquement)
  Future<int> getQuickBalance() async {
    try {
      final cachedCredits = await _cache.get<UserCredits>('cache_user_credits');
      return cachedCredits?.availableCredits ?? 0;
    } catch (e) {
      LogConfig.logError('❌ Erreur lecture solde rapide: $e');
      return 0;
    }
  }

  /// 🆕 Vérification aléatoire pour détecter les incohérences (5% de chance)
  Future<bool> _shouldRandomVerification() async {
    final random = math.Random();
    final shouldVerify = random.nextInt(100) < 5; // 5% de chance
    if (shouldVerify) {
      LogConfig.logInfo('🎲 Vérification aléatoire déclenchée');
    }
    return shouldVerify;
  }

  /// 🆕 Détermine si le cache doit être validé (toutes les 5 minutes)
  Future<bool> _shouldValidateCache(UserCredits cachedCredits) async {
    try {
      final lastValidation = await _cache.get<String>('last_cache_validation');
      if (lastValidation != null) {
        final lastValidationTime = DateTime.parse(lastValidation);
        final timeSinceValidation = DateTime.now().difference(lastValidationTime);
        
        // Valider le cache toutes les 5 minutes
        if (timeSinceValidation.inMinutes < 5) {
          return false;
        }
      }
      
      // Enregistrer la nouvelle validation
      await _cache.set('last_cache_validation', DateTime.now().toIso8601String());
      return true;
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification timing cache: $e');
      return true; // En cas d'erreur, valider par sécurité
    }
  }

  /// 🆕 Récupère les crédits directement depuis le serveur
  Future<UserCredits> _getCreditsFromServer(String userId) async {
    final data = await _supabase
      .from('user_credits')
      .select()
      .eq('user_id', userId)
      .single();

    return UserCredits.fromJson(data);
  }

  // Vérifier si on doit forcer le refresh pour un nouvel utilisateur
  Future<bool> _shouldForceRefreshForNewUser(String userId) async {
    try {
      // Forcer le refresh pour les utilisateurs créés dans les dernières 24h
      final userCreationResp = await _supabase
          .from('profiles')
          .select('id, created_at')
          .eq('id', userId)
          .maybeSingle();
          
      if (userCreationResp != null) {
        final createdAt = DateTime.parse(userCreationResp['created_at']);
        final now = DateTime.now();
        final accountAge = now.difference(createdAt);
        
        // Forcer le refresh pour les comptes de moins de 24h
        return accountAge.inHours < 24;
      }
      
      return false;
    } catch (e) {
      LogConfig.logInfo('⚠️ Erreur vérification âge compte: $e');
      return false;
    }
  }

  // Vérifier la cohérence des crédits avec le système anti-abus
  Future<void> _verifyCreditsCoherence(String userId, UserCredits credits) async {
    try {
      LogConfig.logInfo('🔍 Vérification cohérence crédits pour: $userId');
      
      final result = await _supabase.rpc('force_check_user_device', params: {
        'p_user_id': userId,
      });
      
      if (result != null) {
        final shouldHaveCredits = result['should_have_credits'] == true;
        final serverCredits = result['current_credits'] ?? 0;
        
        // 🆕 AMÉLIORATION : Comparaison plus précise
        final hasInconsistency = (!shouldHaveCredits && credits.availableCredits > 0) || 
                                (shouldHaveCredits && credits.availableCredits == 0 && serverCredits == 0) ||
                                (credits.availableCredits != serverCredits);
        
        if (hasInconsistency) {
          LogConfig.logInfo('⚠️ Incohérence majeure détectée:');
          LogConfig.logInfo('  Devrait avoir crédits: $shouldHaveCredits');
          LogConfig.logInfo('  Crédits locaux: ${credits.availableCredits}');
          LogConfig.logInfo('  Crédits serveur: $serverCredits');
          
          // Nettoyage immédiat
          await _supabase.rpc('cleanup_abusive_credits');
          await invalidateCreditsCache();
          
          // 🆕 Forcer le refresh de AppDataBloc
          try {
            final appDataBloc = sl.get<AppDataBloc>();
            appDataBloc.add(CreditDataClearRequested());
            
            // Attendre un peu puis recharger
            Future.delayed(Duration(milliseconds: 500), () {
              appDataBloc.add(CreditDataPreloadRequested());
            });
          } catch (e) {
            LogConfig.logInfo('⚠️ AppDataBloc non disponible: $e');
          }
          
          LogConfig.logInfo('🧹 Nettoyage et synchronisation terminés');
        }
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification cohérence: $e');
    }
  }

  /// 🆕 Vérifie si les crédits sont incohérents
  bool _areCreditsInconsistent(UserCredits cached, UserCredits server) {
    // Tolérance de 1 crédit pour les mises à jour en cours
    const tolerance = 1;
    
    final availableDiff = (cached.availableCredits - server.availableCredits).abs();
    final purchasedDiff = (cached.totalCreditsPurchased - server.totalCreditsPurchased).abs();
    final usedDiff = (cached.totalCreditsUsed - server.totalCreditsUsed).abs();
    
    final isInconsistent = availableDiff > tolerance || 
                          purchasedDiff > tolerance || 
                          usedDiff > tolerance;
    
    if (isInconsistent) {
      LogConfig.logInfo('⚠️ Incohérence détectée:');
      LogConfig.logInfo('  Cache: ${cached.availableCredits}/${cached.totalCreditsPurchased}/${cached.totalCreditsUsed}');
      LogConfig.logInfo('  Serveur: ${server.availableCredits}/${server.totalCreditsPurchased}/${server.totalCreditsUsed}');
    }
    
    return isInconsistent;
  }

  /// 🆕 Gère les incohérences détectées
  Future<void> _handleCreditsInconsistency(String userId, UserCredits cached, UserCredits server) async {
    try {
      LogConfig.logInfo('🔄 Traitement incohérence crédits pour: $userId');
      
      // Invalider tout le cache des crédits
      await invalidateCreditsCache();
      
      // Déclencher une vérification anti-abus
      await _forceAntiAbuseCheck(userId);
      
      // Notifier AppDataBloc de l'incohérence
      try {
        final appDataBloc = sl.get<AppDataBloc>();
        appDataBloc.add(CreditDataClearRequested());
        appDataBloc.add(CreditDataPreloadRequested());
      } catch (e) {
        LogConfig.logInfo('⚠️ AppDataBloc non disponible pour notification: $e');
      }
      
      LogConfig.logInfo('✅ Incohérence traitée, cache nettoyé');
    } catch (e) {
      LogConfig.logError('❌ Erreur traitement incohérence: $e');
    }
  }

  /// 🆕 Force une vérification anti-abus complète
  Future<void> _forceAntiAbuseCheck(String userId) async {
    try {
      LogConfig.logInfo('🛡️ Vérification anti-abus forcée pour: $userId');
      
      final result = await _supabase.rpc('force_check_user_device', params: {
        'p_user_id': userId,
      });
      
      if (result != null) {
        final shouldHaveCredits = result['should_have_credits'] == true;
        final currentCredits = result['current_credits'] ?? 0;
        
        LogConfig.logInfo('📊 Résultat vérification anti-abus:');
        LogConfig.logInfo('  Devrait avoir crédits: $shouldHaveCredits');
        LogConfig.logInfo('  Crédits actuels: $currentCredits');
        
        // Si abus détecté, nettoyer
        if (!shouldHaveCredits && currentCredits > 0) {
          LogConfig.logInfo('🧹 Nettoyage abus détecté');
          await _supabase.rpc('cleanup_abusive_credits');
        }
        // Si utilisateur légitime sans crédits, corriger
        else if (shouldHaveCredits && currentCredits == 0) {
          LogConfig.logInfo('🔄 Correction utilisateur légitime');
          await _supabase.rpc('admin_grant_credits', params: {
            'p_user_email': result['email'],
            'p_amount': 10,
            'p_reason': 'Correction automatique suite à vérification d\'incohérence'
          });
        }
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification anti-abus: $e');
    }
  }
}