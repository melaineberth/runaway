import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/errors/api_exceptions.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';

import 'credits_event.dart';
import 'credits_state.dart';

class CreditsBloc extends Bloc<CreditsEvent, CreditsState> {
  final CreditsRepository _creditsRepository;

  CreditsBloc({CreditsRepository? creditsRepository})
      : _creditsRepository = creditsRepository ?? CreditsRepository(),
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
      // Vérifier d'abord dans l'état actuel pour éviter un appel API
      final currentState = state;
      UserCredits? currentCredits;
      
      if (currentState is CreditsLoaded) {
        currentCredits = currentState.credits;
      } else if (currentState is CreditUsageSuccess) {
        currentCredits = currentState.updatedCredits;
      } else if (currentState is CreditPurchaseSuccess) {
        currentCredits = currentState.updatedCredits;
      }

      // Si on a les crédits en cache, les utiliser
      if (currentCredits != null) {
        final hasEnough = currentCredits.availableCredits >= requiredCredits;
        print('💰 Vérification crédits (cache): $requiredCredits requis, ${currentCredits.availableCredits} disponibles → ${hasEnough ? "✅" : "❌"}');
        return hasEnough;
      }

      // Sinon, appel au repository
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
    emit(const CreditsLoading());

    try {
      final credits = await _creditsRepository.getUserCredits();
      emit(CreditsLoaded(credits));
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
    // Vérifier l'état actuel
    final currentState = state;
    UserCredits? currentCredits;
    
    if (currentState is CreditsLoaded) {
      currentCredits = currentState.credits;
    } else if (currentState is CreditUsageSuccess) {
      currentCredits = currentState.updatedCredits;
    }

    // Si on n'a pas les crédits, les charger d'abord
    if (currentCredits == null) {
      try {
        currentCredits = await _creditsRepository.getUserCredits();
      } catch (e) {
        emit(CreditsError('Impossible de vérifier vos crédits'));
        return;
      }
    }

    // Vérifier si l'utilisateur a suffisamment de crédits
    if (currentCredits.availableCredits < event.amount) {
      emit(InsufficientCreditsError(
        currentCredits: currentCredits,
        requiredCredits: event.amount,
        action: event.reason,
      ));
      return;
    }

    // Indiquer que l'utilisation est en cours
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
          message: '${event.amount} crédit${event.amount > 1 ? 's' : ''} utilisé${event.amount > 1 ? 's' : ''} pour ${event.reason}',
          transactionId: result.transactionId!,
        ));
      } else {
        emit(CreditsError(
          result.errorMessage ?? 'Erreur lors de l\'utilisation des crédits',
          currentCredits: currentCredits,
        ));
      }
    } catch (e) {
      print('❌ Erreur utilisation crédits: $e');
      emit(CreditsError(
        _getErrorMessage(e),
        currentCredits: currentCredits,
      ));
    }
  }

  /// Initie un achat de crédits
  Future<void> _onCreditPurchaseRequested(
    CreditPurchaseRequested event,
    Emitter<CreditsState> emit,
  ) async {
    try {
      // Récupérer le plan
      final plan = await _creditsRepository.getCreditPlan(event.planId);
      if (plan == null) {
        emit(const CreditsError('Plan de crédits non trouvé'));
        return;
      }

      // Récupérer les crédits actuels
      UserCredits? currentCredits;
      try {
        currentCredits = await _creditsRepository.getUserCredits();
      } catch (e) {
        // Continuer même si on ne peut pas récupérer les crédits actuels
        print('⚠️ Impossible de récupérer les crédits actuels: $e');
      }

      emit(CreditPurchaseInProgress(plan, currentCredits: currentCredits));
      
      // TODO: Ici on devrait intégrer Stripe/RevenueCat/In-App Purchase
      // Pour l'instant, on émet juste l'état en attente
      
    } catch (e) {
      print('❌ Erreur initiation achat: $e');
      emit(CreditsError(_getErrorMessage(e)));
    }
  }

  /// Confirme un achat après paiement réussi
  Future<void> _onCreditPurchaseConfirmed(
    CreditPurchaseConfirmed event,
    Emitter<CreditsState> emit,
  ) async {
    try {
      final updatedCredits = await _creditsRepository.purchaseCredits(
        planId: event.planId,
        paymentIntentId: event.paymentIntentId,
      );

      final plan = await _creditsRepository.getCreditPlan(event.planId);
      
      emit(CreditPurchaseSuccess(
        updatedCredits: updatedCredits,
        message: 'Achat réussi ! ${plan?.totalCreditsWithBonus ?? 0} crédits ajoutés',
        purchasedPlan: plan!,
      ));
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
    emit(const CreditsLoading());

    try {
      final plans = await _creditsRepository.getCreditPlans();
      
      // Récupérer aussi les crédits actuels
      UserCredits? currentCredits;
      try {
        currentCredits = await _creditsRepository.getUserCredits();
      } catch (e) {
        print('⚠️ Impossible de récupérer les crédits actuels: $e');
      }

      emit(CreditPlansLoaded(plans, currentCredits: currentCredits));
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
    emit(const CreditsLoading());

    try {
      final transactions = await _creditsRepository.getTransactionHistory(
        limit: event.limit,
        offset: event.offset,
      );

      // Récupérer aussi les crédits actuels
      UserCredits? currentCredits;
      try {
        currentCredits = await _creditsRepository.getUserCredits();
      } catch (e) {
        print('⚠️ Impossible de récupérer les crédits actuels: $e');
      }

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
  }

  /// Helper pour extraire le message d'erreur approprié
  String _getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    } else if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return 'Une erreur inattendue s\'est produite';
  }

  /// Méthode publique pour obtenir les crédits actuels sans changer l'état
  Future<UserCredits?> getCurrentCredits() async {
    try {
      return await _creditsRepository.getUserCredits();
    } catch (e) {
      print('❌ Erreur récupération crédits actuels: $e');
      return null;
    }
  }
}