// lib/features/credits/data/services/stripe_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:runaway/config/environment_config.dart';
import 'package:runaway/core/errors/auth_exceptions.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StripeService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Initialise Stripe avec la clé publique
  static Future<void> initialize() async {
    try {
      Stripe.publishableKey = EnvironmentConfig.stripePublishableKey;
      Stripe.merchantIdentifier = EnvironmentConfig.merchantIdentifier;
      
      // Configuration pour Android
      await Stripe.instance.applySettings();
      
      print('✅ Stripe initialisé avec succès');
    } catch (e) {
      print('❌ Erreur initialisation Stripe: $e');
      throw Exception('Impossible d\'initialiser Stripe: $e');
    }
  }

  /// Processus de paiement complet pour un plan de crédits
  static Future<String?> makePayment({
    required CreditPlan plan,
    required BuildContext context,
  }) async {
    try {
      print('🛒 Début processus de paiement pour: ${plan.name}');
      
      // ÉTAPE 1: Créer le Payment Intent
      final paymentIntentData = await _createPaymentIntent(plan);
      
      if (paymentIntentData == null) {
        throw PaymentException('Impossible de créer le Payment Intent');
      }

      // ÉTAPE 2: Initialiser la Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['client_secret'],
          style: ThemeMode.system,
          merchantDisplayName: 'Trailix',
        ),
      );

      // ÉTAPE 3: Présenter la Payment Sheet
      await _displayPaymentSheet(context);
      
      // Extraire l'ID du Payment Intent pour confirmation
      final paymentIntentId = _extractPaymentIntentId(paymentIntentData['client_secret']);
      print('✅ Paiement terminé avec succès: $paymentIntentId');
      
      return paymentIntentId;

    } catch (e) {
      print('❌ Erreur processus paiement: $e');
      
      if (e is StripeException && e.error.code == FailureCode.Canceled) {
        // L'utilisateur a annulé - pas d'erreur
        return null;
      }
      
      rethrow;
    }
  }

  /// Crée un Payment Intent via votre backend
  static Future<Map<String, dynamic>?> _createPaymentIntent(CreditPlan plan) async {
    try {
      print('🛒 Création Payment Intent pour plan: ${plan.name}');
      
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw SessionException('Utilisateur non connecté');
      }

      // Calcul du montant en centimes
      final amountInCents = (plan.price * 100).round();

      // Appel à votre backend
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${EnvironmentConfig.stripeSecretKey}',
        },
        body: jsonEncode({
          'planId': plan.id,
          'amount': amountInCents,
          'currency': plan.currency.toLowerCase(),
          'metadata': {
            'plan_id': plan.id,
            'plan_name': plan.name,
            'credits': plan.credits,
            'bonus_percentage': plan.bonusPercentage,
            'user_id': user.id,
          },
        }),
      ).timeout(EnvironmentConfig.apiTimeout);

      print('📥 Réponse Payment Intent: status=${response.statusCode}');

      if (response.statusCode != 200) {
        throw ServerException(
          'Erreur lors de la création du Payment Intent',
          response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Erreur inconnue');
      }

      print('✅ Payment Intent créé: ${data['payment_intent_id']}');
      return data;

    } catch (e) {
      print('❌ Erreur création Payment Intent: $e');
      
      if (e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw NetworkException('Problème de connexion réseau');
      }
      
      rethrow;
    }
  }

  /// Présente la Payment Sheet et gère le résultat
  static Future<void> _displayPaymentSheet(BuildContext context) async {
    try {
      print('📋 Présentation de la Payment Sheet...');
      
      await Stripe.instance.presentPaymentSheet();
      
      print('✅ Payment Sheet fermée avec succès');

    } on StripeException catch (e) {
      print('❌ Erreur Stripe: $e');
      
      if (e.error.code == FailureCode.Canceled) {
        // L'utilisateur a annulé - relancer l'exception pour gestion upstream
        rethrow;
      }
      
      // Autres erreurs Stripe
      throw PaymentException(_mapStripeError(e));
      
    } catch (e) {
      print('❌ Erreur générale Payment Sheet: $e');
      throw PaymentException('Erreur lors du paiement: $e');
    }
  }

  /// Extrait l'ID du Payment Intent depuis le client secret
  static String _extractPaymentIntentId(String clientSecret) {
    try {
      // Format: pi_xxxxx_secret_yyyyy
      final parts = clientSecret.split('_secret_');
      if (parts.isNotEmpty) {
        return parts[0];
      }
      throw Exception('Format client secret invalide');
    } catch (e) {
      print('❌ Erreur extraction Payment Intent ID: $e');
      rethrow;
    }
  }

  /// Mappe les erreurs Stripe en messages utilisateur
  static String _mapStripeError(StripeException error) {
    switch (error.error.code) {
      case FailureCode.Timeout:
        return 'Le code de sécurité (CVC) de votre carte est incorrect.';
      case FailureCode.Unknown:
        return 'Erreur de traitement du paiement. Veuillez réessayer.';
      case FailureCode.Canceled:
        return 'Paiement annulé';
      case FailureCode.Failed:
        return 'Le paiement a échoué. Veuillez réessayer.';
    }
  }
}

/// Exception personnalisée pour les erreurs de paiement
class PaymentException implements Exception {
  final String message;
  
  const PaymentException(this.message);
  
  @override
  String toString() => 'PaymentException: $message';
}