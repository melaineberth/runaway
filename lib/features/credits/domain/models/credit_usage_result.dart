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
  }) => CreditUsageResult(
        success: true,
        updatedCredits: updatedCredits,
        transactionId: transactionId,
      );

  factory CreditUsageResult.failure({
    required String errorMessage,
  }) => CreditUsageResult(
        success: false,
        errorMessage: errorMessage,
      );

  /// ----------  🔑  fromJson  ----------
  factory CreditUsageResult.fromJson(dynamic raw) {
    final json = raw.asJson();

    final isSuccess = json['success'] == true;

    if (isSuccess) {
      return CreditUsageResult.success(
        updatedCredits: UserCredits.fromJson(Map<String, dynamic>.from(json['new_credits'] as Map)),
        transactionId: json['transaction_id'] as String,
      );
    }

    return CreditUsageResult.failure(
      errorMessage: (json['error'] ?? json['message'] ?? 'Une erreur inconnue')
          .toString(),
    );
  }

  // ---- Alias pratiques pour coller au code existant ----
  UserCredits? get newCredits => updatedCredits;
  String? get error => errorMessage;

  @override
  List<Object?> get props => [
        success,
        updatedCredits,
        transactionId,
        errorMessage,
      ];
}
