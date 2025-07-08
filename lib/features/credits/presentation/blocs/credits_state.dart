import 'package:equatable/equatable.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';

abstract class CreditsState extends Equatable {
  const CreditsState();

  @override
  List<Object?> get props => [];
}

class CreditsInitial extends CreditsState {
  const CreditsInitial();
}

class CreditsLoading extends CreditsState {
  const CreditsLoading();
}

class CreditsLoaded extends CreditsState {
  final UserCredits credits;

  const CreditsLoaded(this.credits);

  @override
  List<Object?> get props => [credits];
}

class CreditPlansLoaded extends CreditsState {
  final List<CreditPlan> plans;
  final UserCredits? currentCredits;

  const CreditPlansLoaded(this.plans, {this.currentCredits});

  @override
  List<Object?> get props => [plans, currentCredits];
}

class TransactionHistoryLoaded extends CreditsState {
  final List<CreditTransaction> transactions;
  final UserCredits? currentCredits;

  const TransactionHistoryLoaded(this.transactions, {this.currentCredits});

  @override
  List<Object?> get props => [transactions, currentCredits];
}

class CreditUsageInProgress extends CreditsState {
  final UserCredits currentCredits;
  final int pendingAmount;
  final String reason;

  const CreditUsageInProgress({
    required this.currentCredits,
    required this.pendingAmount,
    required this.reason,
  });

  @override
  List<Object?> get props => [currentCredits, pendingAmount, reason];
}

class CreditUsageSuccess extends CreditsState {
  final UserCredits updatedCredits;
  final String message;
  final String transactionId;

  const CreditUsageSuccess({
    required this.updatedCredits,
    required this.message,
    required this.transactionId,
  });

  @override
  List<Object?> get props => [updatedCredits, message, transactionId];
}

class CreditPurchaseInProgress extends CreditsState {
  final CreditPlan plan;
  final UserCredits? currentCredits;

  const CreditPurchaseInProgress(this.plan, {this.currentCredits});

  @override
  List<Object?> get props => [plan, currentCredits];
}

class CreditPurchaseSuccess extends CreditsState {
  final UserCredits updatedCredits;
  final String message;
  final CreditPlan purchasedPlan;

  const CreditPurchaseSuccess({
    required this.updatedCredits,
    required this.message,
    required this.purchasedPlan,
  });

  @override
  List<Object?> get props => [updatedCredits, message, purchasedPlan];
}

class InsufficientCreditsError extends CreditsState {
  final UserCredits currentCredits;
  final int requiredCredits;
  final String action;

  const InsufficientCreditsError({
    required this.currentCredits,
    required this.requiredCredits,
    required this.action,
  });

  @override
  List<Object?> get props => [currentCredits, requiredCredits, action];
}

class CreditsError extends CreditsState {
  final String message;
  final UserCredits? currentCredits;

  const CreditsError(this.message, {this.currentCredits});

  @override
  List<Object?> get props => [message, currentCredits];
}