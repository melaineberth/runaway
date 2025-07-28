import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/helper/extensions/monitoring_extensions.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
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

  late String _screenLoadId;

  @override
  void initState() {
    super.initState();
    _screenLoadId = context.trackScreenLoad('credit_plans_screen');

    // 🆕 Déclencher le pré-chargement si les données ne sont pas disponibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.isCreditDataLoaded) {
        LogConfig.logInfo('💳 Pré-chargement des données de crédits depuis CreditPlansScreen');
        context.preloadCreditData();
      }
      context.finishScreenLoad(_screenLoadId);
      _trackCreditsScreenView();
    });
  }

  void _trackCreditsScreenView() {
    MonitoringService.instance.recordMetric(
      'credits_screen_view',
      1,
      tags: {
        'user_credits': context.availableCredits.toString(),
        'has_credits': context.hasCredits.toString(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MonitoredScreen(
      screenName: 'credit_plans',
      screenData: {
        'user_credits': context.availableCredits,
        'has_credits': context.hasCredits,
      },
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
        child: Container(
          height: MediaQuery.of(context).size.height / 1.1,
          padding: EdgeInsets.symmetric(
            horizontal: 30.0,
            vertical: 30.0,
          ),
          color: context.adaptiveBackground,
          child: MultiBlocListener(
            listeners: [
              // 🆕 Écouter les succès d'achat depuis CreditsBloc
              BlocListener<CreditsBloc, CreditsState>(
                listener: (context, state) {
                  if (state is CreditPurchaseSuccess) {
                    _showPurchaseSuccessDialog(state);
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
          ),
        ),
      ),
    );
  }

  /// 🆕 Construction du contenu principal basé sur AppDataState
  Widget _buildMainContent(AppDataState appDataState) {
    // État de chargement
    if (!appDataState.isCreditDataLoaded && appDataState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // État d'erreur
    if (appDataState.lastError != null && !appDataState.hasCreditData) {
      return _buildErrorState(appDataState.lastError!);
    }

    // Données disponibles ou état initial
    return _buildLoadedContent(appDataState);
  }

  /// 🆕 Contenu avec données chargées (UI First)
  Widget _buildLoadedContent(AppDataState appDataState) {
    // 🎯 Données immédiatement disponibles depuis AppDataBloc
    final userCredits = appDataState.userCredits;
    final transactions = appDataState.creditTransactions;

    return Stack(
      children: [
        transactions.isEmpty 
          ? _buildEmptyState() 
          : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCreditsHeader(userCredits),
            30.h,
            
            Text(
              context.l10n.transactionHistory,
              style: context.bodyMedium?.copyWith(
                fontSize: 18,
                color: context.adaptiveTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            15.h,
            
            Expanded(
              child: BlurryPage(
                physics: const BouncingScrollPhysics(),
                shrinkWrap: false,
                children: [
                  ...transactions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final value = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: i == transactions.length - 1 ? 0.0 : 12.0),
                      child: _buildTransactionItem(value),
                    );
                  }),
                  
                  // 🚀 Espace pour le bouton en bas (éviter que le dernier élément soit caché)
                  SizedBox(height: 100 + (Platform.isAndroid ? MediaQuery.of(context).padding.bottom : 10)),
                ],
              ),
            ),
          ],
        ),

        
        Positioned(
          left: 0,
          right: 0,
          bottom: Platform.isAndroid ? MediaQuery.of(context).padding.bottom : 10,
          child: SquircleBtn(
            isPrimary: true,
            label: context.l10n.buyCredits,
            onTap: () => showModalSheet(
              context: context, 
              isDismissible: true,
              enableDrag: true,
              backgroundColor: Colors.transparent,
              child: CreditPlanModal(),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildCreditsHeader(UserCredits? userCredits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.userBalance,
          style: context.bodyMedium?.copyWith(
            fontSize: 18,
            color: context.adaptiveTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        15.h,
        if (userCredits != null) ...[
          Row(
            children: [
              _buildStatItem(
                context.l10n.availableCredits,
                '${userCredits.availableCredits}',
                Colors.blue,
              ),
            ],
          ),
          
          // 🆕 Statistiques supplémentaires
          if (userCredits.totalCreditsPurchased > 0) ...[
            8.h,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  context.l10n.purchasedCredits,
                  '${userCredits.totalCreditsPurchased}',
                  Colors.green,
                ),
                8.w,
                _buildStatItem(
                  context.l10n.usedCredits,
                  '${userCredits.totalCreditsUsed}',
                  Colors.orange,
                ),
              ],
            ),
          ],
        ] else ...[
          // État de chargement pour les crédits spécifiquement
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.adaptiveTextSecondary,
                ),
              ),
              8.w,
              Text(
                context.l10n.loading,
                style: context.bodyMedium?.copyWith(
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 🆕 Widget helper pour les statistiques
  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: SquircleContainer(
        radius: 40,
        color: color,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: context.bodyMedium?.copyWith(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: context.bodyMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
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
                // 🆕 Utiliser AppDataBloc pour le retry
                LogConfig.logInfo('🔄 Retry: rafraîchissement des données de crédits');
                context.refreshCreditData();
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SquircleContainer(     
            isGlow: true,         
            color: context.adaptivePrimary,
            padding: EdgeInsets.all(30.0),
            child: Icon(
              Icons.history_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
          30.h,
          Text(
            context.l10n.transactionHistory,
            style: context.bodyLarge?.copyWith(
              color: context.adaptiveTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          8.h,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              context.l10n.noTransactions,
              style: context.bodyMedium?.copyWith(
                color: context.adaptiveTextSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 15,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(CreditTransaction transaction) {
    final isPositive = transaction.isPositive;
    
    return SquircleContainer(
      radius: 50,
      gradient: false,
      color: context.adaptiveBorder.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // Icône selon le type
          SquircleContainer(
            radius: 30,
            isGlow: true,
            color: _getTransactionColor(transaction.type),
            padding: const EdgeInsets.all(15),
            child: Icon(
              _getTransactionIcon(transaction.type),
              size: 25,
              color: Colors.white,
            ),
          ),
          
          10.w,
          
          // Détails
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTransactionDisplay(transaction.type),
                  style: context.bodySmall?.copyWith(
                    color: context.adaptiveTextPrimary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _formatDate(transaction.createdAt),
                  style: context.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Montant
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              transaction.formattedAmount,
              style: context.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isPositive ? Colors.green[600] : Colors.red[600],
              ),
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
      case CreditTransactionType.abuse_removal:
        return Colors.red;
    }
  }

  IconData _getTransactionIcon(CreditTransactionType type) {
    switch (type) {
      case CreditTransactionType.purchase:
        return HugeIcons.solidRoundedAddCircle;
      case CreditTransactionType.usage:
        return HugeIcons.solidRoundedMinusSignCircle;
      case CreditTransactionType.bonus:
        return HugeIcons.solidRoundedParty;
      case CreditTransactionType.refund:
        return HugeIcons.solidRoundedRefresh;
      case CreditTransactionType.abuse_removal:
        return HugeIcons.solidRoundedCancelCircle;
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

  String _getTransactionDisplay(CreditTransactionType type) {
    switch (type) {
      case CreditTransactionType.purchase:
        return context.l10n.purchaseCreditsTitle;
      case CreditTransactionType.usage:
        return context.l10n.usageCreditsTitle;
      case CreditTransactionType.bonus:
        return context.l10n.bonusCreditsTitle;
      case CreditTransactionType.refund:
        return context.l10n.refundCreditsTitle;
      case CreditTransactionType.abuse_removal:
        return context.l10n.abuseConnection;
    }
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