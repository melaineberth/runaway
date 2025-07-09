import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ValidatedPurchase {
  final bool valid;
  final int creditsAdded;
  final String? transactionId;
  final String? planName;
  final bool alreadyProcessed;
  final String? reason;

  const ValidatedPurchase({
    required this.valid,
    required this.creditsAdded,
    this.transactionId,
    this.planName,
    this.alreadyProcessed = false,
    this.reason,
  });

  factory ValidatedPurchase.fromJson(Map<String, dynamic> json) {
    return ValidatedPurchase(
      valid: json['valid'] as bool,
      creditsAdded: json['creditsAdded'] as int? ?? 0,
      transactionId: json['transactionId'] as String?,
      planName: json['planName'] as String?,
      alreadyProcessed: json['alreadyProcessed'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

class ValidationException implements Exception {
  final String message;
  final String? code;
  
  const ValidationException(this.message, [this.code]);
  
  @override
  String toString() => 'ValidationException: $message${code != null ? ' ($code)' : ''}';
}

class IapValidationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Valide un achat auprès du serveur
  Future<ValidatedPurchase> validate({
    required String transactionId,
    required String productId,
    required String verificationData,
  }) async {
    try {
      debugPrint('🔍 Validation serveur pour $productId (${Platform.isIOS ? 'iOS' : 'Android'})');
      
      // Vérification de l'authentification
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw const ValidationException('Utilisateur non authentifié', 'auth_required');
      }

      // Préparation de la requête
      final requestBody = {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'transactionId': transactionId,
        'productId': productId,
        'verificationData': verificationData,
      };

      debugPrint('📤 Envoi requête validation: $requestBody');

      // Appel de l'edge function
      final response = await _supabase.functions.invoke(
        'verify_iap',
        body: requestBody,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      debugPrint('📥 Réponse serveur (${response.status}): ${response.data}');

      // Gestion des erreurs HTTP
      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>? ?? {};
        final reason = errorData['reason'] ?? 'unknown_error';
        final message = _getErrorMessage(reason, response.status);
        throw ValidationException(message, reason);
      }

      // Parsing de la réponse
      final result = ValidatedPurchase.fromJson(response.data as Map<String, dynamic>);
      
      if (!result.valid) {
        final reason = result.reason ?? 'validation_failed';
        final message = _getErrorMessage(reason, response.status);
        throw ValidationException(message, reason);
      }

      debugPrint('✅ Validation réussie: ${result.creditsAdded} crédits');
      return result;

    } catch (e) {
      if (e is ValidationException) {
        rethrow;
      }
      
      debugPrint('❌ Erreur validation: $e');
      throw ValidationException('Erreur de connexion au serveur: $e', 'network_error');
    }
  }

  /// Convertit les codes d'erreur serveur en messages utilisateur
  String _getErrorMessage(String reason, int statusCode) {
    switch (reason) {
      case 'missing-params':
        return 'Paramètres manquants pour la validation';
      case 'unauthorized':
        return 'Vous devez être connecté pour effectuer cet achat';
      case 'store-verification-failed':
        return 'La vérification de l\'achat a échoué. Veuillez réessayer.';
      case 'plan-not-found':
        return 'Plan de crédits introuvable. Veuillez contacter le support.';
      case 'invalid-platform':
        return 'Plateforme non supportée';
      case 'server-error':
        return 'Erreur serveur. Veuillez réessayer plus tard.';
      case 'network_error':
        return 'Erreur de connexion. Vérifiez votre connexion internet.';
      default:
        return 'Erreur de validation ($reason)';
    }
  }

  /// Vérifie la connectivité et l'état du service
  Future<bool> healthCheck() async {
    try {
      final response = await _supabase.functions.invoke(
        'verify_iap',
        body: {'health_check': true},
      );
      return response.status == 405; // Method not allowed pour GET, c'est normal
    } catch (e) {
      debugPrint('❌ Health check failed: $e');
      return false;
    }
  }
}