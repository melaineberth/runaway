import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/data/services/iap_validation_service.dart';

/// Même exception que dans IAP pour ré-utiliser la gestion d’erreurs
class PaymentException implements Exception {
  final String message;
  const PaymentException(this.message);
  @override
  String toString() => 'PaymentException: $message';
}

class IAPService {
  IAPService._();

  /* -------------------------------------------------------------------------
   *  Champs statiques
   * ---------------------------------------------------------------------- */

  static final InAppPurchase _iap = InAppPurchase.instance;

  static bool _isAvailable = false;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Produits renvoyés par la requête au store (productId → ProductDetails)
  static final Map<String, ProductDetails> _products = {};

  /// Completers attachés aux achats en cours (productId → Completer)
  static final Map<String, Completer<String?>> _pending = {};

  /* -------------------------------------------------------------------------
   *  Initialisation
   * ---------------------------------------------------------------------- */

  /// À appeler une seule fois (par `initialise()` ou implicitement au besoin).
  static Future<void> _ensureInit() async {
    if (_subscription != null) return;

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('🚫 In-App Purchases non disponibles sur cet appareil.');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _subscription = null,
      onError: (Object e, __) => debugPrint('❌ Erreur flux achats: $e'),
    );
  }

  /// Optionnel : appel direct au démarrage.
  static Future<void> initialise() => _ensureInit();

  /* -------------------------------------------------------------------------
   *  Préchargement des produits
   * ---------------------------------------------------------------------- */

  /// Interroge le store et met en cache les `ProductDetails` des plans.
  static Future<void> preloadProducts(List<CreditPlan> plans) async {
    await _ensureInit();
    if (!_isAvailable) return;

    final productIds = plans.map((p) => p.iapId).toSet();
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(productIds);

    if (response.error != null) {
      debugPrint('❌ Query IAP error: ${response.error}');
      throw PaymentException('Impossible de contacter le Store');
    }

    for (final details in response.productDetails) {
      _products[details.id] = details;
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('⚠️ Produits non trouvés: ${response.notFoundIDs}');
    }
  }

  /* -------------------------------------------------------------------------
   *  Achat
   * ---------------------------------------------------------------------- */

  /// Lance l’achat d’un plan et renvoie `purchaseId` (ou `null` si annulé).
  static Future<String?> makePurchase({
    required CreditPlan plan,
    required BuildContext context, // gardé pour compatibilité éventuelle
  }) async {
    await _ensureInit();
    if (!_isAvailable) {
      throw const PaymentException('Les achats in-app ne sont pas disponibles');
    }

    final productDetails = _products[plan.iapId];
    if (productDetails == null) {
      throw const PaymentException('Produit introuvable dans le Store');
    }

    final completer = Completer<String?>();
    _pending[plan.iapId] = completer;

    final purchaseParam = PurchaseParam(productDetails: productDetails);

    final bool launched = await _iap.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: Platform.isAndroid, // iOS ⇒ `completePurchase`
    );

    if (!launched) {
      _pending.remove(plan.iapId);
      throw const PaymentException('Échec de l’ouverture du flux de paiement');
    }

    // On attend le résultat via le flux PurchaseStream
    return completer.future;
  }

  /* -------------------------------------------------------------------------
   *  Restore
   * ---------------------------------------------------------------------- */

  /// Restaure les achats (obligatoire sur iOS) puis met à jour le backend.
  static Future<void> restorePurchases() async {
    await _ensureInit();
    if (!_isAvailable) return;

    await _iap.restorePurchases();
  }

  /* -------------------------------------------------------------------------
   *  Purchase listener
   * ---------------------------------------------------------------------- */

  static Future<void> _onPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails details in purchaseDetailsList) {
      final productId = details.productID;
      final completer = _pending[productId];

      switch (details.status) {
        case PurchaseStatus.pending:
          break; // on attend…

        case PurchaseStatus.error:
          completer?.completeError(
            PaymentException(details.error?.message ?? 'Erreur inconnue'),
          );
          _pending.remove(productId);
          break;

        case PurchaseStatus.canceled:
          completer?.complete(null);
          _pending.remove(productId);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            // Validation serveur-à-serveur
            await IapValidationService().validate(
              transactionId: details.purchaseID ??
                  details.verificationData.localVerificationData,
              productId: productId,
              verificationData: details
                  .verificationData.serverVerificationData, // reçu du SDK
            );

            debugPrint('✅ Validation serveur OK pour $productId');

            // On finalise la transaction côté Store
            if (details.pendingCompletePurchase) {
              await _iap.completePurchase(details);
            }

            completer?.complete(details.purchaseID);
          } catch (e) {
            debugPrint('❌ Validation serveur KO: $e');
            completer?.completeError(e);
          }
          _pending.remove(productId);
          break;
      }
    }
  }

  /* -------------------------------------------------------------------------
   *  Nettoyage
   * ---------------------------------------------------------------------- */

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _products.clear();
    _pending.clear();
  }
}
