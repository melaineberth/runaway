import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/errors/api_exceptions.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/data/services/iap_service.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';

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
  }

  Future<bool> hasEnoughCredits(int requiredCredits) async {
    try {
      // 🆕 Prioriser AppDataBloc si disponible
      if (_appDataBloc != null) {
        final appState = _appDataBloc.state;
        if (appState.hasCreditData) {
          final hasEnough = appState.availableCredits >= requiredCredits;
          print('💰 Vérification crédits (AppData): $requiredCredits requis, ${appState.availableCredits} disponibles → ${hasEnough ? "✅" : "❌"}');
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
        print('💰 Vérification crédits (local): $requiredCredits requis, ${currentCredits.availableCredits} disponibles → ${hasEnough ? "✅" : "❌"}');
        return hasEnough;
      }

      // Dernier recours: appel direct au repository
      print('💰 Vérification crédits via API...');
      return await _creditsRepository.hasEnoughCredits(requiredCredits);
    } catch (e) {
      print('❌ Erreur vérification crédits: $e');
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
      print('❌ Erreur chargement crédits: $e');
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

        print('✅ Utilisation de ${event.amount} crédits réussie');
      } else {
        // 🆕 Annuler la mise à jour optimiste
        _appDataBloc?.add(CreditBalanceUpdatedInAppData(
          newBalance: currentCredits.availableCredits,
          isOptimistic: false,
        ));
        
        emit(CreditsError(result.errorMessage ?? 'Erreur lors de l\'utilisation'));
      }
    } catch (e) {
      print('❌ Erreur utilisation crédits: $e');
      
      // 🆕 Annuler la mise à jour optimiste
      _appDataBloc?.add(CreditBalanceUpdatedInAppData(
        newBalance: currentCredits.availableCredits,
        isOptimistic: false,
      ));
      
      emit(CreditsError(_getErrorMessage(e), currentCredits: currentCredits));
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
      print('❌ Erreur préparation achat: $e');
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
      final updatedCredits = await _creditsRepository.refreshUserCredits();
      
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

      print('✅ Achat de crédits confirmé');
    } catch (e) {
      print('❌ Erreur confirmation achat: $e');
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
      print('❌ Erreur chargement plans: $e');
      emit(CreditsError(_getErrorMessage(e)));
    }
  }

  /// Charge l'historique des transactions
  Future<void> _onTransactionHistoryRequested(
    TransactionHistoryRequested event,
    Emitter<CreditsState> emit,
  ) async {
    // 🆕 Si AppDataBloc a les données, les utiliser
    if (_appDataBloc != null && _appDataBloc.state.creditTransactions.isNotEmpty) {
      final transactions = _appDataBloc.state.creditTransactions;
      final currentCredits = _appDataBloc.state.userCredits;
      emit(TransactionHistoryLoaded(transactions, currentCredits: currentCredits));
      return;
    }

    // Sinon, charger via repository
    emit(const CreditsLoading());

    try {
      final transactions = await _creditsRepository.getTransactionHistory(
        limit: event.limit,
        offset: event.offset,
      );
      final currentCredits = getCurrentCredits();
      
      emit(TransactionHistoryLoaded(transactions, currentCredits: currentCredits));
    } catch (e) {
      print('❌ Erreur chargement historique: $e');
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
    if (error is NetworkException) {
      return 'Problème de connexion. Veuillez réessayer.';
    } else if (error is ServerException) {
      return 'Erreur serveur. Veuillez réessayer plus tard.';
    } else if (error is PaymentException) {
      return error.message;
    } else {
      return 'Une erreur est survenue. Veuillez réessayer.';
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