import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/errors/api_exceptions.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/cache_service.dart';
import 'package:runaway/core/router/router.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/data/services/iap_service.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'credits_event.dart';
import 'credits_state.dart';

class CreditsBloc extends Bloc<CreditsEvent, CreditsState> {
  final CreditsRepository _creditsRepository;
  final AppDataBloc? _appDataBloc; // 🆕 Référence au AppDataBloc

  CreditsBloc({
    CreditsRepository? creditsRepository,
    AppDataBloc? appDataBloc, // 🆕 Paramètre optionnel
  }) : _creditsRepository = creditsRepository ?? CreditsRepository(),
       _appDataBloc = appDataBloc,
       super(const CreditsInitial()) {
    on<CreditsRequested>(_onCreditsRequested);
    on<CreditUsageRequested>(_onCreditUsageRequested);
    on<CreditPurchaseRequested>(_onCreditPurchaseRequested);
    on<CreditPurchaseConfirmed>(_onCreditPurchaseConfirmed);
    on<CreditPlansRequested>(_onCreditPlansRequested);
    on<TransactionHistoryRequested>(_onTransactionHistoryRequested);
    on<CreditsReset>(_onCreditsReset);

    on<TransactionCreatedEvent>(_onTransactionCreatedEvent);
    on<TransactionCoherenceCheckRequested>(_onTransactionCoherenceCheck);
    
    LogConfig.logInfo('💳 CreditsBloc initialisé avec gestion des transactions améliorée');
  }

  Future<bool> hasEnoughCredits(int requiredCredits) async {
    try {
      // 🆕 Prioriser AppDataBloc si disponible
      if (_appDataBloc != null) {
        final appState = _appDataBloc.state;
        if (appState.hasCreditData) {
          final hasEnough = appState.availableCredits >= requiredCredits;
          LogConfig.logInfo('💰 Vérification crédits (AppData): $requiredCredits requis, ${appState.availableCredits} disponibles → ${hasEnough ? "✅" : "❌"}');
          return hasEnough;
        }
      }

      // Fallback: vérifier dans l'état local du CreditsBloc
      final currentState = state;
      UserCredits? currentCredits;
      
      if (currentState is CreditsLoaded) {
        currentCredits = currentState.credits;
      } else if (currentState is CreditUsageSuccess) {
        currentCredits = currentState.updatedCredits;
      } else if (currentState is CreditPurchaseSuccess) {
        currentCredits = currentState.updatedCredits;
      }

      if (currentCredits != null) {
        final hasEnough = currentCredits.availableCredits >= requiredCredits;
        LogConfig.logInfo('💰 Vérification crédits (local): $requiredCredits requis, ${currentCredits.availableCredits} disponibles → ${hasEnough ? "✅" : "❌"}');
        return hasEnough;
      }

      // Dernier recours: appel direct au repository
      LogConfig.logInfo('💰 Vérification crédits via API...');
      return await _creditsRepository.hasEnoughCredits(requiredCredits);
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification crédits: $e');
      return false;
    }
  }

  /// Charge les crédits de l'utilisateur
  Future<void> _onCreditsRequested(
    CreditsRequested event,
    Emitter<CreditsState> emit,
  ) async {
    // 🆕 Si AppDataBloc a les données, les utiliser directement
    if (_appDataBloc != null && _appDataBloc.state.hasCreditData) {
      final credits = _appDataBloc.state.userCredits!;
      emit(CreditsLoaded(credits));
      return;
    }

    // Sinon, charger via repository et synchroniser avec AppDataBloc
    emit(const CreditsLoading());

    try {
      final credits = await _creditsRepository.getUserCredits();
      emit(CreditsLoaded(credits));
      
      // 🆕 Déclencher le pré-chargement dans AppDataBloc
      _appDataBloc?.add(const CreditDataPreloadRequested());
      
    } catch (e) {
      LogConfig.logError('❌ Erreur chargement crédits: $e');
      emit(CreditsError(_getErrorMessage(e)));
    }
  }

  /// Utilise des crédits pour une action
  Future<void> _onCreditUsageRequested(
    CreditUsageRequested event,
    Emitter<CreditsState> emit,
  ) async {
    // Obtenir les crédits actuels
    final currentCredits = getCurrentCredits();
    
    if (currentCredits == null) {
      emit(const CreditsError('Crédits non disponibles'));
      return;
    }

    // Vérification du solde
    if (currentCredits.availableCredits < event.amount) {
      emit(InsufficientCreditsError(
        currentCredits: currentCredits,
        requiredCredits: event.amount,
        action: event.reason,
      ));
      return;
    }

    // 🆕 Mise à jour optimiste dans AppDataBloc
    final newBalance = currentCredits.availableCredits - event.amount;
    _appDataBloc?.add(CreditBalanceUpdatedInAppData(
      newBalance: newBalance,
      isOptimistic: true,
    ));

    emit(CreditUsageInProgress(
      currentCredits: currentCredits,
      pendingAmount: event.amount,
      reason: event.reason,
    ));

    try {
      final result = await _creditsRepository.useCredits(
        amount: event.amount,
        reason: event.reason,
        routeGenerationId: event.routeGenerationId,
        metadata: event.metadata,
      );

      if (result.success && result.updatedCredits != null) {
        emit(CreditUsageSuccess(
          updatedCredits: result.updatedCredits!,
          message: 'Crédits utilisés avec succès',
          transactionId: result.transactionId!,
        ));

        // 🆕 Synchroniser avec AppDataBloc
        _appDataBloc?.add(CreditUsageCompletedInAppData(
          amount: event.amount,
          reason: event.reason,
          routeGenerationId: event.routeGenerationId,
          transactionId: result.transactionId!,
        ));

        // Forcer le rechargement des transactions pour l'UI
        // avec un délai pour s'assurer que la transaction est bien en DB
        Future.delayed(Duration(milliseconds: 500), () {
          add(TransactionHistoryRequested(forceRefresh: true));
        });

        LogConfig.logInfo('Utilisation de ${event.amount} crédits réussie');
      } else {
        // Annuler la mise à jour optimiste
        _appDataBloc?.add(CreditBalanceUpdatedInAppData(
          newBalance: currentCredits.availableCredits,
          isOptimistic: false,
        ));
        
        emit(CreditsError(result.errorMessage ?? 'Erreur lors de l\'utilisation'));
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur utilisation crédits: $e');
      
      // Annuler la mise à jour optimiste
      _appDataBloc?.add(CreditBalanceUpdatedInAppData(
        newBalance: currentCredits.availableCredits,
        isOptimistic: false,
      ));
      
      emit(CreditsError(_getErrorMessage(e), currentCredits: currentCredits));
    }
  }

  Future<void> _onTransactionCreatedEvent(
    TransactionCreatedEvent event,
    Emitter<CreditsState> emit,
  ) async {
    try {
      LogConfig.logInfo('🔄 Rechargement après création transaction: ${event.transactionId}');
      
      // Attendre un peu pour s'assurer que la transaction est en DB
      await Future.delayed(Duration(milliseconds: 300));
      
      // Recharger les transactions avec force refresh
      add(TransactionHistoryRequested(forceRefresh: true));
      
    } catch (e) {
      LogConfig.logError('❌ Erreur rechargement après transaction: $e');
    }
  }

  Future<void> _onTransactionCoherenceCheck(
    TransactionCoherenceCheckRequested event,
    Emitter<CreditsState> emit,
  ) async {
    if (!SecureConfig.kIsProduction) return; // Seulement en mode debug
    
    try {
      LogConfig.logInfo('🔍 Vérification cohérence transactions...');
      
      final credits = await _creditsRepository.getUserCredits(forceRefresh: true);
      final transactions = await _creditsRepository.getCreditTransactions(
        limit: 100, // Récupérer plus de transactions pour vérification
        forceRefresh: true,
      );
      
      final totalPurchased = transactions
          .where((t) => t.amount > 0)
          .fold<int>(0, (sum, t) => sum + t.amount);
      
      final totalUsed = transactions
          .where((t) => t.amount < 0)
          .fold<int>(0, (sum, t) => sum + t.amount.abs());
      
      final calculatedAvailable = totalPurchased - totalUsed;
      
      LogConfig.logInfo('📊 DIAGNOSTIC COHÉRENCE:');
      LogConfig.logInfo('   Crédits disponibles (DB): ${credits.availableCredits}');
      LogConfig.logInfo('   Crédits disponibles (calculé): $calculatedAvailable');
      LogConfig.logInfo('   Total acheté (DB): ${credits.totalCreditsPurchased}');
      LogConfig.logInfo('   Total acheté (transactions): $totalPurchased');
      LogConfig.logInfo('   Total utilisé (DB): ${credits.totalCreditsUsed}');
      LogConfig.logInfo('   Total utilisé (transactions): $totalUsed');
      LogConfig.logInfo('   Nombre de transactions: ${transactions.length}');
      
      final isCoherent = credits.availableCredits == calculatedAvailable &&
                        credits.totalCreditsPurchased == totalPurchased &&
                        credits.totalCreditsUsed == totalUsed;
      
      LogConfig.logInfo('   Cohérent: ${isCoherent ? "✅" : "❌"}');
      
      if (!isCoherent) {
        // En cas d'incohérence, forcer une invalidation complète
        final cacheService = CacheService.instance;
        await cacheService.invalidateCreditsCache();
        LogConfig.logInfo('🧹 Cache invalidé à cause d\'incohérence');
      }
      
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification cohérence: $e');
    }
  }

  /// Initie un achat de crédits
  Future<void> _onCreditPurchaseRequested(
    CreditPurchaseRequested event,
    Emitter<CreditsState> emit,
  ) async {
    try {
      // 🆕 Récupérer les plans depuis AppDataBloc si disponibles
      List<CreditPlan> plans = [];
      if (_appDataBloc != null && _appDataBloc.state.creditPlans.isNotEmpty) {
        plans = _appDataBloc.state.creditPlans;
      } else {
        plans = await _creditsRepository.getCreditPlans();
      }

      final plan = plans.firstWhere(
        (p) => p.id == event.planId,
        orElse: () => throw Exception('Plan non trouvé'),
      );

      final currentCredits = getCurrentCredits();

      emit(CreditPurchaseInProgress(plan, currentCredits: currentCredits));

      print('🛒 Début processus d\'achat: ${plan.name}');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur préparation achat: $e');
      emit(CreditsError(_getErrorMessage(e)));
    }
  }

  /// Confirme un achat après paiement réussi
  Future<void> _onCreditPurchaseConfirmed(
    CreditPurchaseConfirmed event,
    Emitter<CreditsState> emit,
  ) async {
    try {
      // Rafraîchir les crédits utilisateur après l'achat
      final updatedCredits = await _creditsRepository.getUserCredits();
      
      // Récupérer le plan acheté
      final plans = await _creditsRepository.getCreditPlans();
      final purchasedPlan = plans.firstWhere(
        (plan) => plan.id == event.planId,
        orElse: () => throw Exception('Plan non trouvé'),
      );

      emit(CreditPurchaseSuccess(
        updatedCredits: updatedCredits,
        message: 'Achat réussi ! ${purchasedPlan.totalCreditsWithBonus} crédits ajoutés',
        purchasedPlan: purchasedPlan,
      ));

      // 🆕 Synchroniser avec AppDataBloc
      _appDataBloc?.add(CreditPurchaseCompletedInAppData(
        planId: event.planId,
        paymentIntentId: event.paymentIntentId,
        creditsAdded: purchasedPlan.totalCreditsWithBonus,
      ));

      LogConfig.logInfo('Achat de crédits confirmé');
    } catch (e) {
      LogConfig.logError('❌ Erreur confirmation achat: $e');
      emit(CreditsError(_getErrorMessage(e)));
    }
  }

  /// Charge les plans de crédits
  Future<void> _onCreditPlansRequested(
    CreditPlansRequested event,
    Emitter<CreditsState> emit,
  ) async {
    // 🆕 Si AppDataBloc a les données, les utiliser
    if (_appDataBloc != null && _appDataBloc.state.creditPlans.isNotEmpty) {
      final plans = _appDataBloc.state.activePlans;
      final currentCredits = _appDataBloc.state.userCredits;
      emit(CreditPlansLoaded(plans, currentCredits: currentCredits));
      return;
    }

    // Sinon, charger via repository
    emit(const CreditsLoading());

    try {
      final plans = await _creditsRepository.getCreditPlans();
      final activePlans = plans.where((p) => p.isActive).toList();
      final currentCredits = getCurrentCredits();
      
      emit(CreditPlansLoaded(activePlans, currentCredits: currentCredits));
    } catch (e) {
      LogConfig.logError('❌ Erreur chargement plans: $e');
      emit(CreditsError(_getErrorMessage(e)));
    }
  }

  /// Charge l'historique des transactions
  Future<void> _onTransactionHistoryRequested(
    TransactionHistoryRequested event,
    Emitter<CreditsState> emit,
  ) async {
    // CORRECTION 2: Vérifier le changement d'utilisateur avant de charger les transactions
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      emit(const CreditsError('Utilisateur non connecté'));
      return;
    }

    // CORRECTION 3: Si forceRefresh, invalider d'abord le cache des transactions
    if (event.forceRefresh) {
      try {
        final cacheService = CacheService.instance;
        await cacheService.invalidateTransactionsCache();
        LogConfig.logInfo('🧹 Cache transactions invalidé avant rechargement');
      } catch (e) {
        LogConfig.logError('❌ Erreur invalidation cache transactions: $e');
      }
    }

    emit(const CreditsLoading());

    try {
      // CORRECTION 4: Charger les crédits actuels ET les transactions en parallèle
      final results = await Future.wait([
        _creditsRepository.getUserCredits(forceRefresh: event.forceRefresh),
        _creditsRepository.getCreditTransactions(
          limit: event.limit ?? 20,
          offset: event.offset ?? 0,
          forceRefresh: event.forceRefresh,
        ),
      ]);

      final credits = results[0] as UserCredits;
      final transactions = results[1] as List<CreditTransaction>;

      // CORRECTION 5: Vérifier la cohérence entre crédits et transactions
      if (transactions.isNotEmpty && !SecureConfig.kIsProduction) {
        final totalUsedFromTransactions = transactions
            .where((t) => t.amount < 0)
            .fold<int>(0, (sum, t) => sum + t.amount.abs());
        
        if (totalUsedFromTransactions != credits.totalCreditsUsed) {
          LogConfig.logInfo('⚠️ Incohérence détectée:');
          LogConfig.logInfo('   Total utilisé (DB): ${credits.totalCreditsUsed}');
          LogConfig.logInfo('   Total utilisé (transactions): $totalUsedFromTransactions');
          LogConfig.logInfo('   Nombre de transactions: ${transactions.length}');
        } else {
          LogConfig.logInfo('✅ Cohérence vérifiée: ${transactions.length} transactions');
        }
      }

      emit(TransactionHistoryLoaded(transactions, currentCredits: credits));

      // CORRECTION 6: Synchroniser avec AppDataBloc si les crédits ont changé
      _appDataBloc?.add(const CreditDataPreloadRequested());

    } catch (e) {
      LogConfig.logError('❌ Erreur chargement historique: $e');
      emit(CreditsError(_getErrorMessage(e)));
    }
  }

  /// Reset l'état des crédits
  Future<void> _onCreditsReset(
    CreditsReset event,
    Emitter<CreditsState> emit,
  ) async {
    emit(const CreditsInitial());
    
    // 🆕 Reset dans AppDataBloc aussi
    _appDataBloc?.add(const CreditDataClearRequested());
  }

  /// Helper pour extraire le message d'erreur approprié
  String _getErrorMessage(dynamic error) {
    final context = rootNavigatorKey.currentContext!;
    if (error is NetworkException) {
      return context.l10n.networkException;
    } else if (error is ServerException) {
      return context.l10n.serverErrorRetry;
    } else if (error is PaymentException) {
      return error.message;
    } else {
      return context.l10n.genericErrorRetry;
    }
  }

  /// 🆕 Retourne les crédits depuis AppDataBloc ou l'état local
  UserCredits? getCurrentCredits() {
    // Prioriser AppDataBloc
    if (_appDataBloc != null && _appDataBloc.state.hasCreditData) {
      return _appDataBloc.state.userCredits;
    }

    // Fallback: état local
    final currentState = state;
    if (currentState is CreditsLoaded) {
      return currentState.credits;
    } else if (currentState is CreditUsageSuccess) {
      return currentState.updatedCredits;
    } else if (currentState is CreditPurchaseSuccess) {
      return currentState.updatedCredits;
    }

    return null;
  }
}