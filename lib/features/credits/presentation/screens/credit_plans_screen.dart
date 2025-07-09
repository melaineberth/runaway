import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_event.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_state.dart';
import 'package:runaway/features/credits/presentation/widgets/credit_plan_modal.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

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
    context.read<CreditsBloc>().add(const TransactionHistoryRequested());
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
            onPressed: () => showModalSheet(
              context: context, 
              backgroundColor: Colors.transparent,
              child: CreditPlanModal(),
            ), 
            icon: Icon(HugeIcons.strokeRoundedCreditCardPos),
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
          if (state is CreditsLoading) return const Center(child: CircularProgressIndicator());
          if (state is CreditsError)  return _buildErrorState(state.message);

          // On récupère le solde et la liste (s’ils existent)
          final UserCredits? summary =
              (state is TransactionHistoryLoaded) ? state.currentCredits : null;
          final List<CreditTransaction> transactions =
              (state is TransactionHistoryLoaded) ? state.transactions : const [];

          return Column(
            children: [
              // 1️⃣ Header fixe
              _creditsHeader(summary),

              // 2️⃣ Liste scrollable qui occupe le reste
              Expanded(
                child: transactions.isEmpty
                    ? _buildEmptyState()          // rien à scroller
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (c, i) => _buildTransactionItem(transactions[i]),
                      ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _creditsHeader(UserCredits? summary) {
    if (summary == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.adaptiveSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            context.l10n.currentCredits,
            style: context.bodySmall?.copyWith(color: context.adaptiveTextSecondary),
          ),
          8.h,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, size: 24, color: Colors.amber[600]),
              8.w,
              Text(
                '${summary.availableCredits}',
                style: context.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              4.w,
              Text(
                'crédits',
                style: context.bodyMedium?.copyWith(color: context.adaptiveTextPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3️⃣  Section “historique”
  List<Widget> _historySection(TransactionHistoryLoaded state) {
    if (state.transactions.isEmpty) return [_buildEmptyState()];
    return [
      ...state.transactions.map(
        (t) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildTransactionItem(t),
        ),
      ),
      40.h,
    ];
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: context.adaptiveTextSecondary,
            ),
            16.h,
            Text(
              context.l10n.noTransactions,
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(CreditTransaction transaction) {
    final isPositive = transaction.isPositive;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.adaptiveSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icône selon le type
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTransactionColor(transaction.type).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTransactionIcon(transaction.type),
              size: 20,
              color: _getTransactionColor(transaction.type),
            ),
          ),
          
          12.w,
          
          // Détails
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ?? transaction.typeDisplayName,
                  style: context.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                4.h,
                Text(
                  _formatDate(transaction.createdAt),
                  style: context.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Montant
          Text(
            transaction.formattedAmount,
            style: context.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isPositive ? Colors.green[600] : Colors.red[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTransactionColor(CreditTransactionType type) {
    switch (type) {
      case CreditTransactionType.purchase:
        return Colors.green;
      case CreditTransactionType.usage:
        return Colors.orange;
      case CreditTransactionType.bonus:
        return Colors.blue;
      case CreditTransactionType.refund:
        return Colors.purple;
    }
  }

  IconData _getTransactionIcon(CreditTransactionType type) {
    switch (type) {
      case CreditTransactionType.purchase:
        return Icons.add_circle_rounded;
      case CreditTransactionType.usage:
        return Icons.remove_circle_rounded;
      case CreditTransactionType.bonus:
        return Icons.card_giftcard_rounded;
      case CreditTransactionType.refund:
        return Icons.refresh_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return context.l10n.yesterday;
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ${context.l10n.daysAgo}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
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
    showTopSnackBar(
      Overlay.of(context),
      TopSnackBar(
        isError: true,
        title: message,
      ),
    );
  }

}