import 'package:equatable/equatable.dart';

enum CreditTransactionType {
  purchase,   // Achat de crédits
  usage,      // Utilisation pour génération
  bonus,      // Bonus (parrainage, etc.)
  refund,     // Remboursement
  abuse_removal,
}

class CreditTransaction extends Equatable {
  final String id;
  final String userId;
  final int amount;
  final CreditTransactionType type;
  final String? description;
  final String? creditPlanId;
  final String? routeGenerationId;
  final String? paymentIntentId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const CreditTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    this.description,
    this.creditPlanId,
    this.routeGenerationId,
    this.paymentIntentId,
    this.metadata = const {},
    required this.createdAt,
  });

  bool get isPositive => amount > 0;
  bool get isNegative => amount < 0;

  String get formattedAmount {
    if (isPositive) {
      return '+$amount';
    } else {
      return amount.toString();
    }
  }

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: json['amount'] as int,
      type: CreditTransactionType.values.firstWhere(
        (e) => e.name == json['transaction_type'],
        orElse: () => CreditTransactionType.usage,
      ),
      description: json['description'] as String?,
      creditPlanId: json['credit_plan_id'] as String?,
      routeGenerationId: json['route_generation_id'] as String?,
      paymentIntentId: json['payment_intent_id'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'transaction_type': type.name,
      'description': description,
      'credit_plan_id': creditPlanId,
      'route_generation_id': routeGenerationId,
      'payment_intent_id': paymentIntentId,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    amount,
    type,
    description,
    creditPlanId,
    routeGenerationId,
    paymentIntentId,
    metadata,
    createdAt,
  ];
}

/// Extension pour les listes de parcours sauvegardés
extension SavedRouteListExtensions on List<CreditTransaction> {
  /// Tri par date de création
  List<CreditTransaction> sortByCreationDate({bool ascending = false}) {
    final sorted = List<CreditTransaction>.from(this);
    sorted.sort((a, b) => ascending 
        ? a.createdAt.compareTo(b.createdAt)
        : b.createdAt.compareTo(a.createdAt));
    return sorted;
  }
}
