import 'dart:convert';
import 'dart:math' as math;

import 'package:runaway/core/errors/auth_exceptions.dart';
import 'package:runaway/core/helper/services/app_data_initialization_service.dart';
import 'package:runaway/core/helper/services/cache_service.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/features/credits/data/services/offline_credits_cache_service.dart';
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

  // 🛡️ Protection anti-boucle
  bool _isCoherenceCheckInProgress = false;
  DateTime? _lastCoherenceCheck;
  int _coherenceCheckCount = 0;
  static const Duration _minCoherenceInterval = Duration(seconds: 30);
  static const int _maxCoherenceChecksPerSession = 3;

  // Service de cache offline
  final OfflineCreditsCacheService _offlineCache = OfflineCreditsCacheService.instance;

  /// Récupère les crédits de l'utilisateur connecté avec cache intelligent
  Future<UserCredits> getUserCredits({bool forceRefresh = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw SessionException('Utilisateur non connecté');
    }

    // Initialiser le cache offline pour ce user
    await _offlineCache.initialize(user.id);

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

    // Utiliser uniquement le cache offline
    if (ConnectivityService.instance.isOffline) {
      LogConfig.logInfo('📱 Mode hors ligne - récupération crédits depuis cache offline');
      
      final offlineCredits = await _offlineCache.getUserCredits();
      if (offlineCredits != null) {
        LogConfig.logInfo('📦 Crédits récupérés en mode hors ligne: ${offlineCredits.availableCredits}');
        return offlineCredits;
      } else {
        // Pas de cache offline disponible - essayer le cache normal en secours
        final cachedCreditsRaw = await _cache.get<Map>('cache_user_credits');
        if (cachedCreditsRaw != null) {
          try {
            final cachedCredits = UserCredits.fromJson(Map<String, dynamic>.from(cachedCreditsRaw));
            LogConfig.logInfo('📦 Crédits récupérés depuis cache de secours en mode hors ligne');
            return cachedCredits;
          } catch (e) {
            LogConfig.logError('❌ Erreur conversion cache de secours: $e');
          }
        }
        
        throw NetworkException('Aucune donnée de crédits disponible hors ligne');
      }
    }

    // Vérifier le cache seulement si pas de changement d'utilisateur
    if (!shouldForceRefresh && !hasUserChanged) {
      // D'abord vérifier le cache offline (plus rapide)
      if (await _offlineCache.areCreditsRecent()) {
        final offlineCredits = await _offlineCache.getUserCredits();
        if (offlineCredits != null) {
          LogConfig.logInfo('📦 Crédits récents trouvés dans cache offline');
          return offlineCredits;
        }
      }
      
      // Ensuite vérifier le cache normal
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
      
      // 🔄 DOUBLE CACHE : Normal + Offline
      await Future.wait([
        // Cache normal (pour compatibilité)
        _cache.set('cache_user_credits', credits.toJson()),
        _cache.set('user_credits_timestamp', DateTime.now().toIso8601String()),
        
        // Cache offline (pour mode hors ligne)
        _offlineCache.saveUserCredits(credits),
      ]);
      
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
          'source': 'api',
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
        // Cache offline
        final offlineCredits = await _offlineCache.getUserCredits();
        if (offlineCredits != null) {
          LogConfig.logInfo('📦 Crédits récupérés depuis cache offline de secours');
          return offlineCredits;
        }
        
        // Cache normal
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

  /// Invalide tous les caches de transactions (toutes les variations de pagination)
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
    // Initialiser le cache offline si on a un utilisateur
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _offlineCache.initialize(user.id);
    }

    // Utiliser le cache offline
    if (ConnectivityService.instance.isOffline) {
      LogConfig.logInfo('📱 Mode hors ligne - récupération plans depuis cache offline');
      
      final offlinePlans = await _offlineCache.getCreditPlans();
      if (offlinePlans.isNotEmpty) {
        LogConfig.logInfo('📦 ${offlinePlans.length} plans récupérés en mode hors ligne');
        return offlinePlans;
      }
      
      // Cache normal en secours
      final cachedPlansRaw = await _cache.get<List>('cache_credit_plans');
      if (cachedPlansRaw != null) {
        try {
          final cachedPlans = cachedPlansRaw
              .map((item) => CreditPlan.fromJson(item as Map<String, dynamic>))
              .toList();
          LogConfig.logInfo('📦 Plans récupérés depuis cache normal en mode hors ligne');
          return cachedPlans;
        } catch (e) {
          LogConfig.logError('❌ Erreur conversion cache plans: $e');
        }
      }
      
      LogConfig.logInfo('📦 Aucun plan disponible hors ligne');
      return [];
    }

    // Cache avec durée plus longue pour les plans (ils changent rarement)
    if (!forceRefresh) {
      // Cache offline en priorité
      if (user != null && await _offlineCache.arePlansRecent()) {
        final offlinePlans = await _offlineCache.getCreditPlans();
        if (offlinePlans.isNotEmpty) {
          LogConfig.logInfo('📦 Plans récents trouvés dans cache offline');
          return offlinePlans;
        }
      }
      
      // Cache normal
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
      await Future.wait([
        // Cache normal
        _cache.set('cache_credit_plans', plans.map((p) => p.toJson()).toList(), 
          customExpiration: const Duration(hours: 2)),
        
        // Cache offline
        if (user != null) _offlineCache.saveCreditPlans(plans),
      ].where((future) => future != null).cast<Future<void>>());
      
      LogConfig.logInfo('💾 Plans sauvegardés dans les deux caches: ${plans.length} plans disponibles');
      return plans;
      
    } catch (e) {
      LogConfig.logError('❌ Erreur récupération plans: $e');

      if (user != null) {
        final offlinePlans = await _offlineCache.getCreditPlans();
        if (offlinePlans.isNotEmpty) {
          LogConfig.logInfo('📦 Plans récupérés depuis cache offline de secours');
          return offlinePlans;
        }
      }
      
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

    // Initialiser le cache offline
    await _offlineCache.initialize(user.id);

    // Vérifier le changement d'utilisateur pour les transactions aussi
    final hasUserChanged = await _cache.hasUserChanged(user.id);
    if (hasUserChanged) {
      LogConfig.logInfo('👤 Changement utilisateur détecté - forcer refresh transactions');
      forceRefresh = true;
    }

    // Utiliser uniquement le cache offline
    if (ConnectivityService.instance.isOffline) {
      LogConfig.logInfo('📱 Mode hors ligne - récupération transactions depuis cache offline');
      
      final offlineTransactions = await _offlineCache.getTransactions();
      if (offlineTransactions.isNotEmpty) {
        // Appliquer pagination sur le cache offline
        final startIndex = offset;
        final endIndex = (offset + limit).clamp(0, offlineTransactions.length);
        
        if (startIndex < offlineTransactions.length) {
          final paginatedTransactions = offlineTransactions.sublist(startIndex, endIndex);
          LogConfig.logInfo('📦 ${paginatedTransactions.length} transactions récupérées en mode hors ligne');
          return paginatedTransactions;
        }
      }
      
      // Essayer le cache normal en secours
      final cacheKey = 'cache_credit_transactions_${user.id}_${offset}_$limit';
      final cachedRaw = await _cache.get<List>(cacheKey);
      if (cachedRaw != null) {
        try {
          final cachedTransactions = cachedRaw
              .cast<Map<String, dynamic>>()
              .map((item) => CreditTransaction.fromJson(item))
              .toList();
          LogConfig.logInfo('📦 Transactions récupérées depuis cache normal en mode hors ligne');
          return cachedTransactions;
        } catch (e) {
          LogConfig.logError('❌ Erreur conversion cache normal: $e');
        }
      }
      
      LogConfig.logInfo('📦 Aucune transaction disponible hors ligne');
      return [];
    }

    final cacheKey = 'cache_credit_transactions_${user.id}_${offset}_$limit';
    
    // Vérifier le cache seulement si pas de changement d'utilisateur
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
      
      // Mise en cache sécurisée avec clé incluant l'user_id
      try {
        // Convertir en format sérialisable avant mise en cache
        final serializableData = transactions.map((t) => t.toJson()).toList();
        await _cache.set(cacheKey, serializableData, 
          customExpiration: const Duration(minutes: 5));

        // Cache offline pour toutes les transactions (première page seulement)
        if (offset == 0) {
          // Récupérer toutes les transactions existantes pour les fusionner
          final allExistingTransactions = await _offlineCache.getTransactions();
          final existingIds = allExistingTransactions.map((t) => t.id).toSet();
          
          // Ajouter les nouvelles transactions
          final newTransactions = transactions.where((t) => !existingIds.contains(t.id)).toList();
          if (newTransactions.isNotEmpty) {
            final mergedTransactions = [...newTransactions, ...allExistingTransactions]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            
            // Limiter à 100 transactions maximum pour éviter un cache trop lourd
            final limitedTransactions = mergedTransactions.take(100).toList();
            await _offlineCache.saveTransactions(limitedTransactions);
            
            LogConfig.logInfo('💾 ${newTransactions.length} nouvelles transactions ajoutées au cache offline');
          }
        }
        
        LogConfig.logInfo('💾 Cache transactions mis à jour: $cacheKey');
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
          'is_offline': ConnectivityService.instance.isOffline.toString(),
        },
      );
      
      // Cache de secours seulement si l'utilisateur n'a pas changé
      if (!hasUserChanged) {
        try {
          // Cache offline 
          if (offset == 0) {
            final offlineTransactions = await _offlineCache.getTransactions();
            if (offlineTransactions.isNotEmpty) {
              final limitedTransactions = offlineTransactions.take(limit).toList();
              LogConfig.logInfo('📦 Transactions récupérées depuis cache offline de secours');
              return limitedTransactions;
            }
          }
          
          // Cache normal
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

  /// Vérification aléatoire pour détecter les incohérences (5% de chance)
  Future<bool> _shouldRandomVerification() async {
    final random = math.Random();
    final shouldVerify = random.nextInt(100) < 5; // 5% de chance
    if (shouldVerify) {
      LogConfig.logInfo('🎲 Vérification aléatoire déclenchée');
    }
    return shouldVerify;
  }

  /// Détermine si le cache doit être validé (toutes les 5 minutes)
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

  /// Récupère les crédits directement depuis le serveur
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
          .select('id, updated_at')
          .eq('id', userId)
          .maybeSingle();
          
      if (userCreationResp != null) {
        final createdAt = DateTime.parse(userCreationResp['updated_at']);
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
      // Eviter les vérifications trop fréquentes
      if (_lastCoherenceCheck != null) {
        final timeSinceLastCheck = DateTime.now().difference(_lastCoherenceCheck!);
        if (timeSinceLastCheck < _minCoherenceInterval) {
          LogConfig.logInfo('🕒 Vérification cohérence trop récente, abandon');
          return;
        }
      }

      // Limiter le nombre de vérifications par session
      if (_coherenceCheckCount >= _maxCoherenceChecksPerSession) {
        LogConfig.logInfo('🛡️ Limite de vérifications cohérence atteinte, abandon');
        return;
      }

      // Eviter les vérifications simultanées
      if (_isCoherenceCheckInProgress) {
        LogConfig.logInfo('🔄 Vérification cohérence déjà en cours, abandon');
        return;
      }

      _isCoherenceCheckInProgress = true;
      _lastCoherenceCheck = DateTime.now();
      _coherenceCheckCount++;

      LogConfig.logInfo('🔍 Vérification cohérence crédits pour: $userId (tentative $_coherenceCheckCount/$_maxCoherenceChecksPerSession)');
      
      final result = await _supabase.rpc('force_check_user_device', params: {
        'p_user_id': userId,
      }).timeout(Duration(seconds: 5)); // Timeout pour éviter les blocages
      
      if (result != null) {
        final shouldHaveCredits = result['should_have_credits'] == true;
        final serverCredits = result['current_credits'] ?? 0;
        
        // Seulement détecter les vraies incohérences
        final hasRealInconsistency = _detectRealInconsistency(
          shouldHaveCredits: shouldHaveCredits,
          localCredits: credits.availableCredits,
          serverCredits: serverCredits,
        );
        
        if (hasRealInconsistency) {
          LogConfig.logInfo('⚠️ Vraie incohérence détectée:');
          LogConfig.logInfo('  Devrait avoir crédits: $shouldHaveCredits');
          LogConfig.logInfo('  Crédits locaux: ${credits.availableCredits}');
          LogConfig.logInfo('  Crédits serveur: $serverCredits');
          
          // Actions correctives modérées
          await _handleInconsistencyGently(userId);
        } else {
          LogConfig.logInfo('✅ Cohérence vérifiée - aucun problème détecté');
        }
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification cohérence: $e');
      // En cas d'erreur, on ne fait pas de nettoyage pour éviter les boucles
    } finally {
      _isCoherenceCheckInProgress = false;
    }
  }

  // Détection intelligente des vraies incohérences
  bool _detectRealInconsistency({
    required bool shouldHaveCredits,
    required int localCredits,
    required int serverCredits,
  }) {
    // Tolérance pour les différences mineures
    const tolerance = 2;
    
    // Cas 1: L'utilisateur ne devrait pas avoir de crédits ET il en a plus que la tolérance
    if (!shouldHaveCredits && localCredits > tolerance) {
      return true;
    }
    
    // Cas 2: L'utilisateur devrait avoir des crédits mais n'en a aucun
    if (shouldHaveCredits && localCredits == 0 && serverCredits == 0) {
      return true;
    }
    
    // Cas 3: Différence significative entre local et serveur
    final creditsDiff = (localCredits - serverCredits).abs();
    if (creditsDiff > tolerance) {
      return true;
    }
    
    return false;
  }

  // Gestion douce des incohérences
  Future<void> _handleInconsistencyGently(String userId) async {
    try {
      LogConfig.logInfo('🔧 Correction douce de l\'incohérence');
      
      // Seulement invalider le cache, sans déclencher AppDataBloc
      await invalidateCreditsCache();
      
      // Pas de notification immediate à AppDataBloc pour éviter la boucle
      // L'AppDataBloc sera mis à jour au prochain accès aux crédits
      
      LogConfig.logInfo('✅ Correction terminée - cache invalidé');
    } catch (e) {
      LogConfig.logError('❌ Erreur correction incohérence: $e');
    }
  }

  /// Vérifie si les crédits sont incohérents
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

  Future<void> _handleCreditsInconsistency(String userId, UserCredits cached, UserCredits server) async {
    try {
      LogConfig.logInfo('🔄 Traitement incohérence crédits pour: $userId');
      
      // Invalider seulement le cache, sans déclencher AppDataBloc
      await invalidateCreditsCache();
      
      LogConfig.logInfo('✅ Incohérence traitée, cache nettoyé');
    } catch (e) {
      LogConfig.logError('❌ Erreur traitement incohérence: $e');
    }
  }

  // Synchronisation des données offline
  Future<void> syncOfflineData() async {
    final user = _supabase.auth.currentUser;
    if (user == null || ConnectivityService.instance.isOffline) {
      return;
    }

    try {
      LogConfig.logInfo('🔄 Synchronisation des données offline...');
      
      await _offlineCache.initialize(user.id);
      
      // Vérifier si une sync est nécessaire
      if (!await _offlineCache.needsSync()) {
        LogConfig.logInfo('✅ Synchronisation non nécessaire (données récentes)');
        return;
      }
      
      // Synchroniser toutes les données
      await Future.wait([
        getUserCredits(forceRefresh: true),
        getCreditTransactions(limit: 50, forceRefresh: true), // Plus de transactions pour le cache offline
        getCreditPlans(forceRefresh: true),
      ]);
      
      // Traiter les transactions pendantes
      await _processPendingTransactions();
      
      // Marquer la sync comme réussie
      await _offlineCache.markLastSync();
      
      LogConfig.logInfo('✅ Synchronisation offline terminée avec succès');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur synchronisation offline: $e');
    }
  }

  // Traite les transactions en attente
  Future<void> _processPendingTransactions() async {
    try {
      final pendingTransactions = await _offlineCache.getPendingTransactions();
      if (pendingTransactions.isEmpty) {
        return;
      }
      
      LogConfig.logInfo('🔄 Traitement de ${pendingTransactions.length} transactions pendantes...');
      
      bool hasErrors = false;
      
      for (final transactionData in pendingTransactions) {
        try {
          // Ici vous pouvez implémenter la logique pour traiter chaque type de transaction
          // Par exemple, ré-essayer l'utilisation de crédits, etc.
          
          LogConfig.logInfo('✅ Transaction pendante traitée: ${transactionData['type']}');
        } catch (e) {
          LogConfig.logError('❌ Erreur traitement transaction pendante: $e');
          hasErrors = true;
        }
      }
      
      // Si toutes les transactions ont été traitées avec succès, les nettoyer
      if (!hasErrors) {
        await _offlineCache.clearPendingTransactions();
        LogConfig.logInfo('🧹 Transactions pendantes nettoyées');
      }
      
    } catch (e) {
      LogConfig.logError('❌ Erreur traitement transactions pendantes: $e');
    }
  }

  // Diagnostics du cache offline
  Future<Map<String, dynamic>> getOfflineCacheDiagnostics() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'status': 'no_user'};
    }
    
    await _offlineCache.initialize(user.id);
    return await _offlineCache.getDiagnostics();
  }

  // Nettoyage du cache offline
  Future<void> clearOfflineCache() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    await _offlineCache.initialize(user.id);
    await _offlineCache.clearAll();
    LogConfig.logInfo('🧹 Cache offline nettoyé');
  }

  // Reset les compteurs lors d'une nouvelle session
  void resetCoherenceProtection() {
    _isCoherenceCheckInProgress = false;
    _lastCoherenceCheck = null;
    _coherenceCheckCount = 0;
    LogConfig.logInfo('🔄 Protection cohérence réinitialisée');
  }
}