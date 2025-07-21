import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/errors/api_exceptions.dart';
import 'package:runaway/core/helper/extensions/monitoring_extensions.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/credits/data/services/iap_service.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_event.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_state.dart';
import 'package:runaway/features/credits/presentation/widgets/credit_plan_card.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:runaway/core/helper/config/log_config.dart';

/// Écran d'achat de crédits
class CreditPlanModal extends StatefulWidget {
  const CreditPlanModal({super.key});

  @override
  State<CreditPlanModal> createState() => _CreditPlanModalState();
}

class _CreditPlanModalState extends State<CreditPlanModal> {
  String? selectedPlanId;

  @override
  void initState() {
    super.initState();
    
    // 🆕 Déclencher le pré-chargement si les données ne sont pas disponibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.isCreditDataLoaded) {
        LogConfig.logInfo('💳 Pré-chargement des plans depuis CreditPlanModal');
        context.preloadCreditData();
      }
    });
  }

  void _handlePurchase(String planId, int credits, double price) async {
    if (selectedPlanId == null) return;

    final operationId = MonitoringService.instance.trackOperation(
      'credit_purchase',
      description: 'Achat de crédits via IAP',
      data: {
        'plan_id': planId,
        'credits': credits,
        'price': price,
      },
    );

    try {
      print('🛒 Début processus d\'achat IAP pour plan: $selectedPlanId');
      
      // Récupérer le plan depuis AppDataBloc (UI First)
      final appDataState = context.appDataBloc.state;
      
      if (!appDataState.hasCreditData) {
        _showErrorSnackBar(context.l10n.notAvailablePlans);
        return;
      }
      
      final selectedPlan = appDataState.activePlans.firstWhere(
        (plan) => plan.id == selectedPlanId,
        orElse: () => throw Exception('Plan non trouvé dans AppDataBloc'),
      );
      
      LogConfig.logInfo('Plan trouvé: ${selectedPlan.name} (${selectedPlan.credits} crédits)');

      // Effectuer l'achat - chaque achat doit être un NOUVEAU achat (consommable)
      final purchaseResult = await IAPService.makePurchase(selectedPlan);
      
      // Vérifier le résultat de l'achat
      if (purchaseResult.isSuccess) {
        // ✅ Nouveau achat réussi
        final transactionId = purchaseResult.transactionId;
        if (transactionId != null && mounted) {
          LogConfig.logInfo('Nouveau achat réussi avec transaction: $transactionId');
          
          // Confirmer l'achat via CreditsBloc
          context.creditsBloc.add(
            CreditPurchaseConfirmed(
              planId: selectedPlan.id,
              paymentIntentId: transactionId,
            ),
          );

          MonitoringService.instance.finishOperation(operationId, success: true);

          // Métrique business importante
          MonitoringService.instance.recordMetric(
            'revenue',
            price,
            unit: 'eur',
            tags: {
              'source': 'credit_purchase',
              'plan_id': planId,
              'credits': credits.toString(),
            },
          );

        } else {
          if (mounted) {
            _showErrorSnackBar(context.l10n.missingTransactionID);
          }
        }
      } else if (purchaseResult.isCanceled) {
        // 🚫 Achat annulé par l'utilisateur
        LogConfig.logInfo('🚫 Achat annulé par l\'utilisateur');
        if (mounted) {
          _showErrorSnackBar(context.l10n.purchaseCanceled);
        }
      } else {
        // ❌ Erreur lors de l'achat
        if (mounted) {
          final errorMessage = purchaseResult.errorMessage ?? context.l10n.unknownError;
          LogConfig.logError('❌ Erreur achat: $errorMessage');
          
          // Gestion spéciale pour les problèmes de restauration/finalisation
          if (errorMessage.contains('restauré au lieu de nouveau')) {
            _showSystemErrorDialog();
          } else {
            _showErrorSnackBar(errorMessage);
          }
        }
      }
      
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur processus achat: $e');
      
      if (mounted) {
        
        String errorMessage = context.l10n.duringPaymentError;

        if (e is PaymentException) {
          errorMessage = e.message;
        } else if (e is NetworkException) {
          errorMessage = context.l10n.networkException;
        } else if (e.toString().contains('Plan non trouvé')) {
          errorMessage = context.l10n.retryNotAvailablePlans;
          if (mounted) {
            context.refreshCreditData();
          }
        }
      
        _showErrorSnackBar(errorMessage);

        context.captureError(e, stackTrace, extra: {
          'operation': 'credit_purchase',
          'plan_id': planId,
          'credits': credits,
          'price': price,
        });
        
        MonitoringService.instance.finishOperation(
          operationId, 
          success: false, 
          errorMessage: e.toString(),
        );
      }
    }
  }

  // Méthode pour gérer les erreurs système
  void _showSystemErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Colors.orange[600],
              size: 24,
            ),
            8.w,
            Text(context.l10n.systemIssueDetectedTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.systemIssueDetectedSubtitle),
            16.h,
            Text(
              context.l10n.systemIssueDetectedDesc,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.close),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                // Forcer un nettoyage complet
                await IAPService.cleanupPendingTransactions();
                if (context.mounted) _showErrorSnackBar(context.l10n.cleaningDone);
              } catch (e) {
                if (context.mounted) _showErrorSnackBar(context.l10n.cleaningError(e.toString()));
              }
            },
            child: Text(context.l10n.cleaning),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // 🆕 Écouter les événements de CreditsBloc pour les achats
        BlocListener<CreditsBloc, CreditsState>(
          listener: (context, state) {
            if (state is CreditPurchaseSuccess) {
              // Fermer immédiatement la modal
              context.pop();
              
              showTopSnackBar(
                Overlay.of(context),
                TopSnackBar(
                  title: state.message,
                ),
              );              
            } else if (state is CreditsError) {
              _showErrorSnackBar(state.message);
            }
          },
        ),
      ],
      child: BlocBuilder<AppDataBloc, AppDataState>(
        builder: (context, appDataState) {
          return _buildMainContent(appDataState);
        },
      ),
    );
  }

  /// 🆕 Construction du contenu principal basé sur AppDataState
  Widget _buildMainContent(AppDataState appDataState) {
    // État de chargement
    if (!appDataState.isCreditDataLoaded && appDataState.isLoading) {
      return ModalSheet(
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // État d'erreur
    if (appDataState.lastError != null && !appDataState.hasCreditData) {
      return _buildErrorState(appDataState.lastError!);
    }

    // Données disponibles
    if (appDataState.hasCreditData) {
      return _buildPlansContent(appDataState);
    }

    // État initial - déclencher le chargement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !appDataState.isLoading) {
        LogConfig.logInfo('🔄 Données non disponibles, déclenchement du chargement');
        context.preloadCreditData();
      }
    });

    return ModalSheet(
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildPlansContent(AppDataState appDataState) {
    final plans = appDataState.activePlans;

    return ModalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [    
          Text(
            context.l10n.creditPlanModalTitle,
            style: context.bodyMedium?.copyWith(
              color: context.adaptiveTextPrimary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          20.h, 
          if (plans.isNotEmpty) ...[
              ...List.generate(
              plans.length,
              (index) {
                final plan = plans[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: index == plans.length - 1 ? 0 : 8),
                  child: CreditPlanCard(
                    plan: plan,
                    isSelected: selectedPlanId == plan.id,
                    onTap: () {
                      setState(() {
                        selectedPlanId = plan.id;
                      });
                    },
                  ),
                ); 
              }
            ), 
          ]
          else ...[
            // Aucun plan disponible
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.adaptiveSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: context.adaptiveTextSecondary,
                    size: 32,
                  ),
                  12.h,
                  Text(
                    context.l10n.notAvailablePlans,
                    style: context.bodyMedium?.copyWith(
                      color: context.adaptiveTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],

          30.h,

          Text(
            context.l10n.creditPlanModalSubtitle,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          15.h,

          SquircleBtn(
            isPrimary: true,
            onTap: selectedPlanId != null ? () {
              // Récupérer le plan sélectionné depuis appDataState
              final selectedPlan = appDataState.activePlans.firstWhere(
                (plan) => plan.id == selectedPlanId,
                orElse: () => throw Exception(context.l10n.notAvailablePlans),
              );
              
              // Appeler _handlePurchase avec les bons paramètres
              _handlePurchase(
                selectedPlan.id,      // String planId
                selectedPlan.credits, // int credits
                selectedPlan.price,   // double price
              );
            } : null,
            label: selectedPlanId != null 
              ? context.l10n.buySelectedPlan
              : context.l10n.selectPlan,
          ),

          // 🆕 Bouton de rafraîchissement si pas de plans
          if (plans.isEmpty) ...[
            12.h,
            SquircleBtn(
              isPrimary: false,
              onTap: () {
                LogConfig.logInfo('🔄 Rafraîchissement des plans demandé');
                context.refreshCreditData();
              },
              label: context.l10n.refresh,
            ),
          ],

          12.h,

          Text(
            context.l10n.creditPlanModalWarning,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: context.adaptiveTextSecondary,
            ),
            16.h,
            Text(
              message,
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            20.h,
            SquircleContainer(
              onTap: () {
                context.read<CreditsBloc>().add(const CreditPlansRequested());
              },
              height: 44,
              color: context.adaptivePrimary,
              radius: 22.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: Text(
                    context.l10n.retry,
                    style: context.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    showTopSnackBar(
      Overlay.of(context),
      TopSnackBar(
        isError: true,
        title: message,
      ),
    );
  }
}