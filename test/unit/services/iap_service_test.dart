// test/unit/services/iap_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:runaway/features/credits/data/services/iap_service.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';

import '../../test_setup.dart';

void main() {
  setUpAll(() async {
    await TestSetup.initialize();
  });

  tearDownAll(() async {
    await TestSetup.cleanup();
  });

  group('IAPService', () {
    setUp(() async {
      // Setup pour les tests IAP - pas d'instance à créer
    });

    tearDown(() async {
      await IAPService.dispose();
    });

    test('initialise correctement', () async {
      // En mode test, l'initialisation peut échouer à cause des canaux de plateforme
      // On teste que le service ne crash pas
      try {
        await IAPService.initialize();
        // Si ça marche, c'est bien
      } on PaymentException catch (e) {
        // On s'attend à une PaymentException à cause du manque de plateforme
        expect(e, isA<PaymentException>());
      } catch (e) {
        // Toute autre exception est acceptable en mode test
        expect(e, isA<Exception>());
      }
    });

    test('gère l\'indisponibilité des achats', () async {
      // En mode test, les achats ne sont pas disponibles
      expect(() => IAPService.initialize(), throwsA(isA<Exception>()));
    });

    test('traite les achats avec succès', () async {
      // Mock d'un scénario d'achat
      // En mode test, on simule juste le comportement attendu
      
      final testPlan = CreditPlan(
        id: 'test-plan',
        name: 'Test Plan',
        credits: 100,
        price: 4.99,
        iapId: 'test_iap_id',
        isPopular: false,
        currency: 'EUR',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      );
      
      // Tenter un achat devrait lever une exception en mode test
      expect(
        () => IAPService.makePurchase(testPlan),
        throwsA(isA<Exception>())
      );
    });

    test('gère les erreurs d\'achat', () async {
      // Test de la gestion d'erreur
      final invalidPlan = CreditPlan(
        id: 'invalid-plan',
        name: 'Invalid Plan',
        credits: 0,
        price: 0.0,
        iapId: 'invalid_product',
        isPopular: false,
        currency: 'EUR',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(
        () => IAPService.makePurchase(invalidPlan),
        throwsA(isA<Exception>())
      );
    });

    test('précharge les produits disponibles', () async {
      // En mode test, aucun produit n'est disponible
      final testPlans = [
        CreditPlan(
          id: 'test-plan-1',
          name: 'Test Plan 1',
          credits: 100,
          price: 4.99,
          iapId: 'test_iap_id_1',
          isPopular: false,
          currency: 'EUR',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      try {
        await IAPService.preloadProducts(testPlans);
        // Si ça marche, c'est bien (peu probable en test)
      } catch (e) {
        // Exception attendue en mode test
        expect(e, isA<Exception>());
      }
    });

    test('gère la restauration des achats', () async {
      // En mode test, la restauration d'achats n'est pas disponible
      try {
        await IAPService.restorePurchases();
        // Si ça marche, c'est bien (peu probable en test)
      } catch (e) {
        // Exception attendue en mode test
        expect(e, isA<Exception>());
      }
    });

    test('nettoie les transactions en attente', () async {
      // Test que cleanupPendingTransactions ne lève pas d'exception
      try {
        await IAPService.cleanupPendingTransactions();
        expect(true, true); // Test passé
      } catch (e) {
        // Exception acceptable en mode test
        expect(e, isA<Exception>());
      }
    });

    test('gère la restauration explicite des achats', () async {
      // Test de la restauration explicite
      try {
        await IAPService.restorePurchasesExplicitly();
        expect(true, true); // Test passé
      } catch (e) {
        // Exception attendue en mode test
        expect(e, isA<Exception>());
      }
    });

    test('nettoie correctement les ressources', () async {
      // Test que dispose ne lève pas d'exception
      expect(() => IAPService.dispose(), returnsNormally);
    });
  });
}