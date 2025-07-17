import 'package:runaway/core/helper/config/log_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as su;
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';

/// Résultat de la vérification des crédits
class CreditVerificationResult {
  final bool hasEnoughCredits;
  final int availableCredits;
  final int requiredCredits;
  final String? errorMessage;

  const CreditVerificationResult({
    required this.hasEnoughCredits,
    required this.availableCredits,
    required this.requiredCredits,
    this.errorMessage,
  });

  bool get isValid => hasEnoughCredits && errorMessage == null;
}

/// Résultat de la consommation de crédits
class CreditConsumptionResult {
  final bool success;
  final int? newBalance;
  final String? transactionId;
  final String? errorMessage;

  const CreditConsumptionResult({
    required this.success,
    this.newBalance,
    this.transactionId,
    this.errorMessage,
  });
}

/// Service dédié à la gestion des crédits pour la génération de routes
/// Sépare la logique des crédits du RouteGenerationBloc
class CreditVerificationService {
  final CreditsRepository _creditsRepository;
  final CreditsBloc _creditsBloc;
  final AppDataBloc? _appDataBloc;

  const CreditVerificationService({
    required CreditsRepository creditsRepository,
    required CreditsBloc creditsBloc,
    AppDataBloc? appDataBloc,
  }) : _creditsRepository = creditsRepository,
       _creditsBloc = creditsBloc,
       _appDataBloc = appDataBloc;

  /// Vérifie si l'utilisateur a suffisamment de crédits
  Future<CreditVerificationResult> verifyCreditsForGeneration({
    int requiredCredits = 1,
  }) async {
    try {
      LogConfig.logInfo('💳 === VÉRIFICATION CRÉDITS ===');
      LogConfig.logInfo('💳 Crédits requis: $requiredCredits');

      // Vérifier l'authentification
      final currentUser = su.Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        return CreditVerificationResult(
          hasEnoughCredits: false,
          availableCredits: 0,
          requiredCredits: requiredCredits,
          errorMessage: 'Session expirée. Veuillez vous reconnecter.',
        );
      }

      // Récupérer les crédits via la logique UI First
      int availableCredits;
      
      // Priorité 1: AppDataBloc si données chargées
      if (_appDataBloc != null && _appDataBloc.state.isCreditDataLoaded) {
        availableCredits = _appDataBloc.state.availableCredits;
        LogConfig.logInfo('💳 Crédits depuis AppDataBloc: $availableCredits');
      } 
      // Priorité 2: CreditsBloc local
      else {
        final hasEnough = await _creditsBloc.hasEnoughCredits(requiredCredits);
        if (!hasEnough) {
          // Récupérer le nombre exact via API
          final userCredits = await _creditsRepository.getUserCredits();
          availableCredits = userCredits.availableCredits;
        } else {
          // Si suffisant, récupérer quand même le nombre exact
          final userCredits = await _creditsRepository.getUserCredits();
          availableCredits = userCredits.availableCredits;
        }
        LogConfig.logInfo('💳 Crédits depuis API: $availableCredits');
      }

      final hasEnough = availableCredits >= requiredCredits;
      
      LogConfig.logInfo('💳 Résultat: ${hasEnough ? "✅" : "❌"} ($availableCredits >= $requiredCredits)');

      return CreditVerificationResult(
        hasEnoughCredits: hasEnough,
        availableCredits: availableCredits,
        requiredCredits: requiredCredits,
      );

    } catch (e) {
      LogConfig.logError('❌ Erreur vérification crédits: $e');
      return CreditVerificationResult(
        hasEnoughCredits: false,
        availableCredits: 0,
        requiredCredits: requiredCredits,
        errorMessage: 'Erreur lors de la vérification des crédits. Veuillez réessayer.',
      );
    }
  }

  /// Consomme les crédits avec mise à jour optimiste
  Future<CreditConsumptionResult> consumeCreditsForGeneration({
    required int amount,
    required String generationId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      LogConfig.logInfo('💳 === CONSOMMATION CRÉDITS ===');
      LogConfig.logInfo('💳 Montant: $amount, ID: $generationId');

      // Mise à jour optimiste si AppDataBloc disponible
      int? originalBalance;
      if (_appDataBloc != null && _appDataBloc.state.isCreditDataLoaded) {
        originalBalance = _appDataBloc.state.availableCredits;
        final newBalance = originalBalance - amount;
        
        _appDataBloc.add(CreditBalanceUpdatedInAppData(
          newBalance: newBalance,
          isOptimistic: true,
        ));
        LogConfig.logInfo('Mise à jour optimiste: $originalBalance → $newBalance crédits');
      }

      // Consommation réelle via API
      final usageResult = await _creditsRepository.useCredits(
        amount: amount,
        reason: 'Route generation',
        routeGenerationId: generationId,
        metadata: metadata,
      );

      if (usageResult.success && usageResult.updatedCredits != null) {
        LogConfig.logInfo('Consommation réussie');
        LogConfig.logInfo('💰 Nouveau solde: ${usageResult.updatedCredits!.availableCredits}');
        
        return CreditConsumptionResult(
          success: true,
          newBalance: usageResult.updatedCredits!.availableCredits,
          transactionId: usageResult.transactionId,
        );
      } else {
        LogConfig.logError('❌ Échec consommation: ${usageResult.errorMessage}');
        
        // Annuler la mise à jour optimiste
        if (_appDataBloc != null && originalBalance != null) {
          _appDataBloc.add(CreditBalanceUpdatedInAppData(
            newBalance: originalBalance,
            isOptimistic: false,
          ));
        }

        return CreditConsumptionResult(
          success: false,
          errorMessage: usageResult.errorMessage ?? 'Erreur lors de l\'utilisation des crédits',
        );
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur consommation crédits: $e');
      return CreditConsumptionResult(
        success: false,
        errorMessage: 'Erreur lors de la consommation des crédits: $e',
      );
    }
  }

  /// Vérifie si l'utilisateur peut générer une route (méthode rapide)
  Future<bool> canGenerateRoute() async {
    try {
      // Priorité 1: AppDataBloc si données chargées
      if (_appDataBloc != null && _appDataBloc.state.isCreditDataLoaded) {
        return _appDataBloc.state.canGenerateRoute;
      }
      
      // Fallback vers CreditsBloc
      return await _creditsBloc.hasEnoughCredits(1);
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification possibilité génération: $e');
      return false;
    }
  }

  /// Récupère le nombre de crédits disponibles
  Future<int> getAvailableCredits() async {
    try {
      // Priorité 1: AppDataBloc si disponible
      if (_appDataBloc != null && _appDataBloc.state.isCreditDataLoaded) {
        return _appDataBloc.state.availableCredits;
      }
      
      // Priorité 2: API directe
      final userCredits = await _creditsRepository.getUserCredits();
      return userCredits.availableCredits;
    } catch (e) {
      LogConfig.logError('❌ Erreur récupération crédits: $e');
      return 0;
    }
  }

  /// Déclenche le pré-chargement des crédits si nécessaire
  void ensureCreditDataLoaded() {
    if (_appDataBloc != null && !_appDataBloc.state.isCreditDataLoaded) {
      LogConfig.logInfo('💳 Déclenchement pré-chargement crédits depuis CreditVerificationService');
      _appDataBloc.add(const CreditDataPreloadRequested());
    }
  }
}