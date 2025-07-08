import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/errors/api_exceptions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/credits/data/services/stripe_service.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_event.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_state.dart';
import 'package:runaway/features/credits/presentation/screens/transaction_history_screen.dart';
import 'package:runaway/features/credits/presentation/widgets/credit_plan_card.dart';

/// Écran d'achat de crédits
class CreditPlansScreen extends StatefulWidget {
  const CreditPlansScreen({super.key});

  @override
  State<CreditPlansScreen> createState() => _CreditPlansScreenState();
}

class _CreditPlansScreenState extends State<CreditPlansScreen> {
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
    print('🛒 Début processus d\'achat Stripe pour plan: $selectedPlanId');
    
    // Récupérer le plan sélectionné
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

    // Processus de paiement Stripe
    final paymentIntentId = await StripeService.makePayment(
      plan: selectedPlan,
      context: context,
    );

    if (paymentIntentId != null) {
      // Paiement réussi - confirmer l'achat côté backend
      if (mounted) {
        creditsBloc.add(
          CreditPurchaseConfirmed(
            planId: selectedPlan.id,
            paymentIntentId: paymentIntentId,
          ),
        );
      }
    }
    // Si paymentIntentId est null, l'utilisateur a annulé - pas d'action nécessaire

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
    return Scaffold(
      backgroundColor: context.adaptiveBackground,
      appBar: AppBar(
        backgroundColor: context.adaptiveBackground,
        title: Text(
          context.l10n.buyCredits,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(), 
          icon: Icon(HugeIcons.strokeStandardArrowLeft02),
        ),
        actions: [
          IconButton(
            onPressed: () => _showTransactionHistory(context), 
            icon: Icon(HugeIcons.strokeRoundedClock03),
          ),
        ],
      ),
      body: BlocConsumer<CreditsBloc, CreditsState>(
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
      ),
    );
  }

  Widget _buildPlansContent(CreditPlansLoaded state) {
    return Column(
      children: [
        // Header avec crédits actuels
        if (state.currentCredits != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.adaptiveSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  context.l10n.currentCredits,
                  style: context.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                  ),
                ),
                8.h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 24,
                      color: Colors.amber[600],
                    ),
                    8.w,
                    Text(
                      '${state.currentCredits!.availableCredits}',
                      style: context.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                    4.w,
                    Text(
                      'crédits',
                      style: context.bodyMedium?.copyWith(
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Liste des plans
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: state.plans.length,
            itemBuilder: (context, index) {
              final plan = state.plans[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
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
            },
          ),
        ),

        // Bouton d'achat
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: SquircleContainer(
                onTap: selectedPlanId != null ? _handlePurchase : null,
                height: 56,
                color: selectedPlanId != null 
                    ? context.adaptivePrimary 
                    : context.adaptiveTextSecondary.withValues(alpha: 0.3),
                radius: 28.0,
                child: Center(
                  child: Text(
                    selectedPlanId != null 
                        ? context.l10n.buySelectedPlan
                        : context.l10n.selectPlan,
                    style: context.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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

  void _showTransactionHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TransactionHistoryScreen(),
      ),
    );
  }
}
