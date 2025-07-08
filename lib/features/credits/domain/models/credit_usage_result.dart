import 'package:equatable/equatable.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';

class CreditUsageResult extends Equatable {
  final bool success;
  final UserCredits? updatedCredits;
  final String? transactionId;
  final String? errorMessage;

  const CreditUsageResult({
    required this.success,
    this.updatedCredits,
    this.transactionId,
    this.errorMessage,
  });

  factory CreditUsageResult.success({
    required UserCredits updatedCredits,
    required String transactionId,
  }) {
    return CreditUsageResult(
      success: true,
      updatedCredits: updatedCredits,
      transactionId: transactionId,
    );
  }

  factory CreditUsageResult.failure({
    required String errorMessage,
  }) {
    return CreditUsageResult(
      success: false,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    success,
    updatedCredits,
    transactionId,
    errorMessage,
  ];
}