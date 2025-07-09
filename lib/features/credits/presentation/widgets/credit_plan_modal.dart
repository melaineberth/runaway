import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/errors/api_exceptions.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/credits/data/services/iap_service.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_event.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_state.dart';
import 'package:runaway/features/credits/presentation/widgets/credit_plan_card.dart';

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
    // Charger les plans au démarrage
    context.read<CreditsBloc>().add(const CreditPlansRequested());
  }

  void _handlePurchase() async {
    if (selectedPlanId == null) return;

    try {
      print('🛒 Début processus d\'achat IAP pour plan: $selectedPlanId');
      
      final creditsBloc = context.read<CreditsBloc>();
      final currentState = creditsBloc.state;
      
      CreditPlan? selectedPlan;
      if (currentState is CreditPlansLoaded) {
        selectedPlan = currentState.plans.firstWhere(
          (plan) => plan.id == selectedPlanId,
          orElse: () => throw Exception('Plan non trouvé'),
        );
      }
      
      if (selectedPlan == null) {
        _showErrorSnackBar('Plan non trouvé');
        return;
      }

      final purchaseId = await IAPService.makePurchase(
        plan: selectedPlan,
        context: context,
      );

      if (purchaseId != null) {
        if (mounted) {
          creditsBloc.add(
            CreditPurchaseConfirmed(
              planId: selectedPlan.id,
              paymentIntentId: purchaseId,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Erreur processus achat: $e');
      
      String errorMessage = 'Erreur lors du paiement';
      if (e is PaymentException) {
        errorMessage = e.message;
      } else if (e is NetworkException) {
        errorMessage = 'Problème de connexion. Veuillez réessayer.';
      }
      
      if (mounted) {
        _showErrorSnackBar(errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreditsBloc, CreditsState>(
      listener: (context, state) {
        if (state is CreditPurchaseSuccess) {
          _showPurchaseSuccessDialog(state);
        } else if (state is CreditsError) {
          _showErrorSnackBar(state.message);
        }
      },
      builder: (context, state) {
        if (state is CreditsLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (state is CreditPlansLoaded) {
          return _buildPlansContent(state);
        }

        if (state is CreditsError) {
          return _buildErrorState(state.message);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPlansContent(CreditPlansLoaded state) {
    return ModalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [    
          Text(
            "Faites le plein de crédits pour vivre de nouvelles aventures !",
            style: context.bodyMedium?.copyWith(
              color: context.adaptiveTextPrimary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          20.h, 
          ...List.generate(
            state.plans.length,
            (index) {
              final plan = state.plans[index];
              return Padding(
                padding: EdgeInsets.only(bottom: index == state.plans.length - 1 ? 0 : 8),
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

          30.h,

          Text(
            "Choisissez votre formule favorite, puis appuyez ici pour commencer l’exploration !",
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
            onTap: selectedPlanId != null ? _handlePurchase : null,
            label: selectedPlanId != null 
              ? context.l10n.buySelectedPlan
              : context.l10n.selectPlan,
          ),     

          12.h,

          Text(
            "Paiement débité à la confirmation de l’achat. Les crédits sont non remboursables et valables uniquement dans l’application",
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontSize: 12,
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

  void _showPurchaseSuccessDialog(CreditPurchaseSuccess state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.green[600],
              size: 24,
            ),
            8.w,
            Text(context.l10n.purchaseSuccess),
          ],
        ),
        content: Text(state.message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Retourner à l'écran précédent
            },
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
      ),
    );
  }
}