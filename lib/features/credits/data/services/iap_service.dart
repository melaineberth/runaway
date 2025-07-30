import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/router/router.dart';
import 'package:runaway/features/credits/data/services/iap_validation_service.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/core/helper/config/log_config.dart';

class PaymentException implements Exception {
  final String message;
  final String? code;
  
  const PaymentException(this.message, [this.code]);
  
  @override
  String toString() => 'PaymentException: $message${code != null ? ' ($code)' : ''}';
}

class IAPService {
  IAPService._();

  static final InAppPurchase _iap = InAppPurchase.instance;
  static bool _isAvailable = false;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static final IapValidationService _validator = IapValidationService();

  static final context = rootNavigatorKey.currentContext!;

  /// Cache des produits : { productId → ProductDetails }
  static final Map<String, ProductDetails> _products = {};

  /// Achats en cours : { purchaseId → Completer }
  static final Map<String, Completer<PurchaseResult>> _pendingPurchases = {};

  /// Récupère les détails d'un produit par son ID
  static ProductDetails? getProductDetails(String iapId) {
    return _products[iapId];
  }

  /// Récupère tous les produits chargés
  static Map<String, ProductDetails> get loadedProducts => Map.unmodifiable(_products);

  static Future<void> initialize() async {
    await _ensureInitialized();
    debugPrint('🛒 IAP Service initialized');
  }

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _products.clear();
    _pendingPurchases.clear();
    debugPrint('🛒 IAP Service disposed');
  }

  static Future<void> _ensureInitialized() async {
    if (_subscription != null) return; // Déjà initialisé

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      LogConfig.logInfo('🚫 In-App Purchases non disponibles');
      return;
    }

    // Simple nettoyage au démarrage
    _pendingPurchases.clear();

    // Écoute du flux d'achats
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _subscription = null,
      onError: (error, stackTrace) {
        LogConfig.logError('❌ Erreur flux achats: $error');
        _completeAllPendingWithError(PaymentException('Erreur système IAP'));
      },
    );

    LogConfig.logInfo('IAP Service stream configuré');
  }

  static Future<void> preloadProducts(List<CreditPlan> plans) async {
    await _ensureInitialized();
    if (!_isAvailable) {
      throw const PaymentException('Les achats in-app ne sont pas disponibles');
    }

    final productIds = plans.map((p) => p.iapId).toSet();
    LogConfig.logInfo('🔍 Chargement des produits: $productIds');

    final response = await _iap.queryProductDetails(productIds);

    if (response.error != null) {
      throw PaymentException(
        'Erreur lors du chargement des produits: ${response.error!.message}',
        response.error!.code,
      );
    }

    _products.clear();
    for (final product in response.productDetails) {
      _products[product.id] = product;
    }

    final missingProducts = productIds.where((id) => !_products.containsKey(id)).toList();
    if (missingProducts.isNotEmpty) {
      LogConfig.logInfo('Produits manquants: $missingProducts');
    }

    LogConfig.logInfo('${_products.length} produits chargés');
  }

  static Future<PurchaseResult> makePurchase(CreditPlan plan) async {
    await _ensureInitialized();
    if (!_isAvailable) {
      throw PaymentException(context.l10n.disabledInAppPurchase);
    }

    final productDetails = _products[plan.iapId];
    if (productDetails == null) {
      throw PaymentException(context.l10n.notFoundProduct(plan.iapId));
    }

    debugPrint('🛒 Début processus d\'achat IAP pour plan: ${plan.iapId}');

    // Pas d'achat multiple simultané
    final existingPendingKeys = _pendingPurchases.keys
        .where((key) => key.startsWith(plan.iapId))
        .toList();
    
    if (existingPendingKeys.isNotEmpty) {
      if (context.mounted) {
        LogConfig.logWarning('⚠️ Achat déjà en cours pour ${plan.iapId}');
        throw PaymentException(context.l10n.purchaseAlreadyInProgress);
      }
    }

    // Simple nettoyage
    _cleanupPendingPurchasesForProduct(plan.iapId);

    final purchaseParam = PurchaseParam(productDetails: productDetails);
    final completer = Completer<PurchaseResult>();

    // Timestamp pour traçabilité
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final purchaseKey = '${plan.iapId}_$timestamp';
    _pendingPurchases[purchaseKey] = completer;

    try {
      LogConfig.logInfo('🚀 Lancement achat pour ${plan.iapId} avec clé: $purchaseKey');

      final launched = await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: !kIsWeb,
      );

      if (!launched) {
        _pendingPurchases.remove(purchaseKey);
        throw PaymentException(context.l10n.purschaseImpossible);
      }

      LogConfig.logInfo('Processus d\'achat lancé pour ${plan.iapId}');

      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          _pendingPurchases.remove(purchaseKey);
          LogConfig.logError('⏰ Timeout achat pour ${plan.iapId}');
          throw PaymentException(context.l10n.purschaseTimeout);
        },
      );
    } catch (e) {
      _pendingPurchases.remove(purchaseKey);
      LogConfig.logError('❌ Erreur lancement achat: $e');
      rethrow;
    }
  }

  static void _cleanupPendingPurchasesForProduct(String productId) {
    final keysToRemove = _pendingPurchases.keys
        .where((key) => key.startsWith(productId))
        .toList();
    
    for (final key in keysToRemove) {
      final completer = _pendingPurchases.remove(key);
      if (completer != null && !completer.isCompleted) {
        completer.completeError(
          const PaymentException('Nouveau processus d\'achat initié')
        );
      }
    }
    
    if (keysToRemove.isNotEmpty) {
      LogConfig.logInfo('🧹 Nettoyé ${keysToRemove.length} pending purchases pour $productId');
    }
  }

  static Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      await _processPurchase(purchaseDetails);
    }
  }

  static Future<void> _processPurchase(PurchaseDetails details) async {
    LogConfig.logInfo('📦 Traitement achat: ${details.productID} - Status: ${details.status}');

    switch (details.status) {
      case PurchaseStatus.pending:
        LogConfig.logInfo('⏳ Achat en attente: ${details.productID}');
        break;

      case PurchaseStatus.error:
        LogConfig.logError('❌ Erreur achat: ${details.error?.message}');
        _completePurchaseWithError(
          details.productID,
          PaymentException(
            details.error?.message ?? 'Erreur inconnue lors de l\'achat',
            details.error?.code,
          ),
        );
        break;

      case PurchaseStatus.canceled:
        LogConfig.logInfo('🚫 Achat annulé: ${details.productID}');
        _completePurchaseWithResult(
          details.productID,
          PurchaseResult.canceled(),
        );
        break;

      case PurchaseStatus.purchased:
        await _handleSuccessfulPurchase(details);
        break;
        
      case PurchaseStatus.restored:
        await _handleRestoredPurchase(details);
        break;
    }
  }

  static Future<void> _handleRestoredPurchase(PurchaseDetails details) async {
    try {
      LogConfig.logInfo('🔄 Gestion achat restauré: ${details.productID}');
      
      final hasPendingPurchase = _pendingPurchases.keys
          .any((key) => key.startsWith(details.productID));

      if (hasPendingPurchase) {
        // S'assurer que c'est vraiment un nouvel achat
        final purchaseTime = details.transactionDate;
        final now = DateTime.now().millisecondsSinceEpoch;

        // Vérifier si l'achat est récent (moins de 5 minutes)
        final isRecentPurchase = purchaseTime != null && (now - int.parse(purchaseTime)) < 300000; // 5 minutes

        // Vérifier l'environnement
        final isTestEnvironment = kDebugMode || !SecureConfig.kIsProduction;

        if (isRecentPurchase && isTestEnvironment) {
          debugPrint('🎯 Restored récent en test = NOUVEL ACHAT (Sandbox)');
          LogConfig.logInfo('✅ Achat restored validé comme nouveau (récent + test env)');
          await _handleSuccessfulPurchase(details);
          return;
        } else {
          // Rejeter si pas récent ou pas en environnement de test
          debugPrint('🚫 Restored rejeté - Pas récent ou env production');
          LogConfig.logInfo('❌ Achat restored rejeté (${isRecentPurchase ? "récent" : "ancien"}, ${isTestEnvironment ? "test" : "prod"})');
          
          // Annuler la pending purchase
          _completePurchaseWithResult(
            details.productID,
            PurchaseResult.canceled(),
          );
        }
      } else {
        // Vraie restauration silencieuse
        debugPrint('🔕 Restauration silencieuse ignorée pour ${details.productID}');
        
        if (details.pendingCompletePurchase) {
          await _iap.completePurchase(details);
          LogConfig.logInfo('Achat restauré complété côté store');
        }
      }

    } catch (e) {
      LogConfig.logError('❌ Erreur gestion achat restauré: $e');
      if (details.pendingCompletePurchase) {
        await _iap.completePurchase(details);
      }

      // Échouer toutes les pending purchases pour ce produit
      _completePurchaseWithError(
        details.productID, 
        PaymentException('Erreur traitement achat restauré: $e')
      );
    }
  }

  static Future<void> _handleSuccessfulPurchase(PurchaseDetails details) async {
    try {
      LogConfig.logInfo('💳 Validation nouvel achat: ${details.productID}');

      final verificationData = _extractVerificationData(details);
      final transactionId = details.purchaseID ?? 
                          details.verificationData.localVerificationData;

      final validationResult = await _validator.validate(
        transactionId: transactionId,
        productId: details.productID,
        verificationData: verificationData,
      );

      // CORRECTION : Si déjà traité, considérer comme succès mais sans nouveaux crédits
      if (validationResult.alreadyProcessed) {
        LogConfig.logInfo('Transaction déjà traitée - Succès sans nouveaux crédits');
        
        if (details.pendingCompletePurchase) {
          await _iap.completePurchase(details);
          LogConfig.logInfo('Achat complété côté store (déjà traité)');
        }

        _completePurchaseWithResult(
          details.productID,
          PurchaseResult.success(
            transactionId: validationResult.transactionId ?? transactionId,
            creditsAdded: 0, // Pas de nouveaux crédits car déjà traité
          ),
        );
        return; // IMPORTANT : Arrêter ici, ne pas appeler _handleRestoredPurchase
      }

      LogConfig.logInfo('Validation serveur OK: ${validationResult.creditsAdded} crédits');

      if (details.pendingCompletePurchase) {
        await _iap.completePurchase(details);
        LogConfig.logInfo('Achat complété côté store');
      }

      _completePurchaseWithResult(
        details.productID,
        PurchaseResult.success(
          transactionId: validationResult.transactionId ?? transactionId,
          creditsAdded: validationResult.creditsAdded,
        ),
      );

    } catch (e) {
      LogConfig.logError('❌ Erreur validation: $e');
      
      if (details.pendingCompletePurchase) {
        await _iap.completePurchase(details);
      }
      
      _completePurchaseWithError(details.productID, e as Exception);
    }
  }

  static String _extractVerificationData(PurchaseDetails details) {
    if (Platform.isIOS) {
      final jws = details.verificationData.serverVerificationData;
      if (jws.isEmpty) {
        throw const PaymentException('Reçu iOS vide ou invalide');
      }
      return jws;
    } else {
      final token = details.verificationData.serverVerificationData;
      if (token.isEmpty) {
        throw const PaymentException('Token Android vide ou invalide');
      }
      return token;
    }
  }

  static Future<void> cleanupPendingTransactions() async {
    await _ensureInitialized();
    if (!_isAvailable) return;

    LogConfig.logInfo('🧹 Nettoyage simple des pending purchases...');
    _pendingPurchases.clear();
    LogConfig.logInfo('Nettoyage simple terminé');
  }

  static Future<void> restorePurchasesExplicitly() async {
    await _ensureInitialized();
    if (!_isAvailable) {
      throw const PaymentException('Les achats in-app ne sont pas disponibles');
    }

    LogConfig.logInfo('🔄 Restoration explicite des achats');
    _pendingPurchases.clear();
    await _iap.restorePurchases();
    LogConfig.logInfo('Restoration explicite terminée');
  }

  static void _completePurchaseWithResult(String productId, PurchaseResult result) {
    final completersToRemove = <String>[];
    
    for (final entry in _pendingPurchases.entries) {
      if (entry.key.startsWith(productId) && !entry.value.isCompleted) {
        entry.value.complete(result);
        completersToRemove.add(entry.key);
      }
    }
    
    for (final key in completersToRemove) {
      _pendingPurchases.remove(key);
    }
  }

  static void _completePurchaseWithError(String productId, Exception error) {
    final completersToRemove = <String>[];
    
    for (final entry in _pendingPurchases.entries) {
      if (entry.key.startsWith(productId) && !entry.value.isCompleted) {
        entry.value.completeError(error);
        completersToRemove.add(entry.key);
      }
    }
    
    for (final key in completersToRemove) {
      _pendingPurchases.remove(key);
    }
  }

  static void _completeAllPendingWithError(Exception error) {
    for (final completer in _pendingPurchases.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pendingPurchases.clear();
  }

  static Future<void> restorePurchases() async {
    await _ensureInitialized();
    if (!_isAvailable) {
      throw const PaymentException('Les achats in-app ne sont pas disponibles');
    }

    LogConfig.logInfo('🔄 Restoration des achats');
    await _iap.restorePurchases();
  }
}

class PurchaseResult {
  final bool isSuccess;
  final bool isCanceled;
  final String? transactionId;
  final int? creditsAdded;
  final String? errorMessage;

  PurchaseResult._({
    required this.isSuccess,
    required this.isCanceled,
    this.transactionId,
    this.creditsAdded,
    this.errorMessage,
  });

  factory PurchaseResult.success({
    required String transactionId,
    required int creditsAdded,
  }) {
    return PurchaseResult._(
      isSuccess: true,
      isCanceled: false,
      transactionId: transactionId,
      creditsAdded: creditsAdded,
    );
  }

  factory PurchaseResult.canceled() {
    return PurchaseResult._(
      isSuccess: false,
      isCanceled: true,
    );
  }

  factory PurchaseResult.error(String message) {
    return PurchaseResult._(
      isSuccess: false,
      isCanceled: false,
      errorMessage: message,
    );
  }
}