import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_event.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_state.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';

/// Écran d'historique des transactions
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CreditsBloc>().add(const TransactionHistoryRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.adaptiveBackground,
      appBar: AppBar(
        backgroundColor: context.adaptiveBackground,
        title: Text(
          context.l10n.transactionHistory,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(), 
          icon: Icon(HugeIcons.strokeStandardArrowLeft02),
        ),
      ),
      body: BlocBuilder<CreditsBloc, CreditsState>(
        builder: (context, state) {
          if (state is CreditsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TransactionHistoryLoaded) {
            return _buildHistoryContent(state);
          }

          if (state is CreditsError) {
            return _buildErrorState(state.message);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildHistoryContent(TransactionHistoryLoaded state) {
    if (state.transactions.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Header avec crédits actuels
        if (state.currentCredits != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.adaptiveSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.availableCredits,
                      style: context.bodySmall?.copyWith(
                        color: context.adaptiveTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                    4.h,
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Colors.amber[600],
                        ),
                        4.w,
                        Text(
                          '${state.currentCredits!.availableCredits}',
                          style: context.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      context.l10n.totalUsed,
                      style: context.bodySmall?.copyWith(
                        color: context.adaptiveTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                    4.h,
                    Text(
                      '${state.currentCredits!.totalCreditsUsed}',
                      style: context.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Liste des transactions
        Expanded(
          child: ColoredBox(
            color: Colors.red,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: state.transactions.length,
              itemBuilder: (context, index) {
                final transaction = state.transactions[index];
                return _buildTransactionItem(transaction);
              },
            ),
          ),
        ),
      ],
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
                context.read<CreditsBloc>().add(const TransactionHistoryRequested());
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
}