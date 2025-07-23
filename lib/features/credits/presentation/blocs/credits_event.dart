import 'package:equatable/equatable.dart';

abstract class CreditsEvent extends Equatable {
  const CreditsEvent();

  @override
  List<Object?> get props => [];
}

/// Demande de chargement des crédits utilisateur
class CreditsRequested extends CreditsEvent {
  const CreditsRequested();
}

/// Demande d'utilisation de crédits
class CreditUsageRequested extends CreditsEvent {
  final int amount;
  final String reason;
  final String? routeGenerationId;
  final Map<String, dynamic>? metadata;

  const CreditUsageRequested({
    required this.amount,
    required this.reason,
    this.routeGenerationId,
    this.metadata,
  });

  @override
  List<Object?> get props => [amount, reason, routeGenerationId, metadata];
}

class TransactionCreatedEvent extends CreditsEvent {
  final String transactionId;
  final int amount;
  final String type;

  const TransactionCreatedEvent({
    required this.transactionId,
    required this.amount,
    required this.type,
  });

  @override
  List<Object?> get props => [transactionId, amount, type];
}

class TransactionCoherenceCheckRequested extends CreditsEvent {
  const TransactionCoherenceCheckRequested();

  @override
  List<Object?> get props => [];
}

/// Demande d'achat de crédits
class CreditPurchaseRequested extends CreditsEvent {
  final String planId;

  const CreditPurchaseRequested(this.planId);

  @override
  List<Object?> get props => [planId];
}

/// Confirmation d'achat avec payment intent
class CreditPurchaseConfirmed extends CreditsEvent {
  final String planId;
  final String paymentIntentId;

  const CreditPurchaseConfirmed({
    required this.planId,
    required this.paymentIntentId,
  });

  @override
  List<Object?> get props => [planId, paymentIntentId];
}

/// Demande de chargement des plans
class CreditPlansRequested extends CreditsEvent {
  const CreditPlansRequested();
}

/// Demande de chargement de l'historique
class TransactionHistoryRequested extends CreditsEvent {
  final int? limit;
  final int? offset;
  final bool forceRefresh; // AJOUTÉ

  const TransactionHistoryRequested({
    this.limit,
    this.offset,
    this.forceRefresh = false, // AJOUTÉ avec valeur par défaut
  });

  @override
  List<Object?> get props => [limit, offset, forceRefresh]; // forceRefresh AJOUTÉ
}

/// Reset de l'état des crédits
class CreditsReset extends CreditsEvent {
  const CreditsReset();
}

