import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:runaway/features/credits/data/services/iap_validation_service.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';

class PaymentException implements Exception {
  final String message;
  const PaymentException(this.message);
  @override
  String toString() => 'PaymentException: $message';
}

class IAPService {
  IAPService._();

  // ---------------------------------------------------------------------------
  // ▸ ATTRIBUTS
  // ---------------------------------------------------------------------------
  static final InAppPurchase _iap = InAppPurchase.instance;
  static bool _isAvailable = false;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// { productId → ProductDetails }
  static final _products = <String, ProductDetails>{};

  /// { purchaseId → _PendingPurchase }
  static final _pending = <String, _PendingPurchase>{};

  // ---------------------------------------------------------------------------
  // ▸ INIT / DISPOSE
  // ---------------------------------------------------------------------------
  static Future<void> initialise() => _ensureInit();

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _products.clear();
    _pending.clear();
  }

  static Future<void> _ensureInit() async {
    if (_subscription != null) return; // déjà initialisé

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('🚫 In-App Purchases non disponibles.');
      return;
    }

    // 2️⃣ Ecoute du flux
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _subscription = null,
      onError: (e, __) => debugPrint('❌ Flux achats: $e'),
    );
  }

  // ---------------------------------------------------------------------------
  // ▸ PRODUITS
  // ---------------------------------------------------------------------------
  static Future<void> preloadProducts(List<CreditPlan> plans) async {
    await _ensureInit();
    if (!_isAvailable) return;

    final ids = plans.map((p) => p.iapId).toSet();
    final response = await _iap.queryProductDetails(ids);

    if (response.error != null) {
      throw PaymentException('Store error: ${response.error!.message}');
    }
    for (final d in response.productDetails) {
      _products[d.id] = d;
    }
  }

  // ---------------------------------------------------------------------------
  // ▸ ACHAT
  // ---------------------------------------------------------------------------
  static Future<String?> makePurchase({
    required CreditPlan plan,
    required BuildContext context, // conservé si besoin de UI plus tard
  }) async {
    await _ensureInit();
    if (!_isAvailable) {
      throw const PaymentException('Les achats in-app ne sont pas disponibles');
    }

    final details = _products[plan.iapId];
    if (details == null) {
      throw const PaymentException('Produit introuvable dans le Store');
    }

    // On crée un identifiant *local* pour suivre cette session d’achat
    final purchaseKey = UniqueKey().toString();
    final completer = Completer<String?>();
    _pending[purchaseKey] = _PendingPurchase(
      productId: plan.iapId,
      startedAt: DateTime.now(),
      completer: completer,
    );

    final launched = await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
      autoConsume: false, // ⚠️ toujours false sur iOS
    );

    if (!launched) {
      _pending.remove(purchaseKey);
      throw const PaymentException('Impossible d’ouvrir le paiement');
    }

    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // ▸ FLUX D’ACHATS
  // ---------------------------------------------------------------------------
  static Future<void> _onPurchaseUpdated(
      List<PurchaseDetails> list) async {
    for (final details in list) {
      // Cherche le _PendingPurchase correspondant
      final entry = _pending.values.firstWhere(
        (p) => p.productId == details.productID,
        orElse: () => _PendingPurchase.empty(),
      );
      final completer = entry.completer;

      // 1. Si aucune session n’attend ce produit ⇒ on termine/laisse passer
      if (completer == null) {
        if (details.pendingCompletePurchase) {
          await _iap.completePurchase(details);
        }
        continue;
      }

      switch (details.status) {
        case PurchaseStatus.pending:
          break; // on attend…

        case PurchaseStatus.error:
          if (!completer.isCompleted) {
            completer.completeError(
              PaymentException(details.error?.message ?? 'Erreur inconnue'),
            );
          }
          _pending.remove(entry.key);
          break;

        case PurchaseStatus.canceled:
          if (!completer.isCompleted) completer.complete(null);
          _pending.remove(entry.key);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            // -- ① Reçu / JWS garanti non vide
            final payload = await _payloadFor(details);

            // -- ② Validation serveur
            await IapValidationService().validate(
              transactionId:
                  details.purchaseID ?? details.verificationData.localVerificationData,
              productId: details.productID,
              verificationData: payload,
            );

            debugPrint('✅ Validation serveur OK pour ${details.productID}');

            // -- ③ Consommation (iOS & Android)
            if (details.pendingCompletePurchase) {
              await _iap.completePurchase(details);
            }

            if (!completer.isCompleted) completer.complete(details.purchaseID);
          } catch (e) {
            debugPrint('❌ Validation serveur KO: $e');
            if (!completer.isCompleted) completer.completeError(e);
          }
          _pending.remove(entry.key);
          break;
      }
    }
  }

  /// Retourne un payload **non vide** conforme aux attentes du backend.
  static Future<String> _payloadFor(PurchaseDetails d) async {
    // Android ⇒ purchaseToken (inchangé)
    if (!Platform.isIOS) return d.verificationData.serverVerificationData;

    // iOS ⇒ JWS signé StoreKit 2
    final jws = d.verificationData.serverVerificationData;
    if (jws.isEmpty) {
      throw const PaymentException(
        'JWS vide : impossible de valider la transaction iOS',
      );
    }
    return jws;
  }
}

// -----------------------------------------------------------------------------
// ▸ PRIVATE SUPPORT CLASS
// -----------------------------------------------------------------------------
class _PendingPurchase {
  final String key = UniqueKey().toString();
  final String productId;
  final DateTime startedAt;
  final Completer<String?>? completer;
  _PendingPurchase({
    required this.productId,
    required this.startedAt,
    required this.completer,
  });
  _PendingPurchase.empty()
      : productId = '',
        startedAt = DateTime.fromMillisecondsSinceEpoch(0),
        completer = null;
}
