import 'dart:io' show Platform;
import 'package:runaway/features/credits/domain/models/validated_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runaway/features/credits/data/services/iap_service.dart';

class IapValidationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<ValidatedPurchase> validate({
    required String transactionId,
    required String productId,
    required String verificationData,
  }) async {
    final response = await _supabase.functions.invoke(
      'verify_iap',
      body: {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'userId': _supabase.auth.currentUser!.id,
        'transactionId': transactionId,
        'productId': productId,
        'verificationData': verificationData,
      },
    );

    if (response.status != 200) {
      throw const PaymentException('Validation serveur échouée');
    }

    final result = ValidatedPurchase.fromJson(response.data);
    if (!result.valid) throw const PaymentException('Achat refusé par le serveur');
    return result;
  }
}
