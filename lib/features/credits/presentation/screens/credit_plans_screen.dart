import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/extensions/monitoring_extensions.dart';
import 'package:runaway/core/services/monitoring_service.dart';
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
        print('💳 Pré-chargement des données de crédits depuis CreditPlansScreen');
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
      child: Scaffold(
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
        ),
        body: MultiBlocListener(
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
        Column(
          children: [
            20.h, 
        
            // 1️⃣ Header avec crédits
            _buildCreditsHeader(userCredits),
        
            // 2️⃣ Liste des transactions
            Expanded(
              child: transactions.isEmpty
                ? _buildEmptyState()
                : BlurryPage(
                  contentPadding: EdgeInsets.all(20.0),
                  children: [
                    ...transactions.asMap().entries.map((entry) {
                      final i = entry.key;
                      final value = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(bottom: i == transactions.length - 1 ? 0.0 : 12.0),
                        child: _buildTransactionItem(value),
                      );
                    }),
                    150.h,
                  ],
                ),
            ),
          ],
        ),
        Positioned(
          left: 20.0,
          right: 20.0,
          bottom: 40.0,
          child: SquircleBtn(
            isPrimary: true,
            label: context.l10n.buyCredits,
            onTap: () => showModalSheet(
              context: context, 
              backgroundColor: Colors.transparent,
              child: CreditPlanModal(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreditsHeader(UserCredits? userCredits) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20.0,
      ),
      child: SquircleContainer(
        radius: 50,
        gradient: false,
        color: context.adaptiveBorder.withValues(alpha: 0.08),
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.currentCredits,
                  style: context.bodySmall?.copyWith(color: context.adaptiveTextSecondary),
                ),
                // 🆕 Bouton de rafraîchissement
                GestureDetector(
                  onTap: () {
                    print('🔄 Rafraîchissement des données de crédits demandé');
                    context.refreshCreditData();
                  },
                  child: Icon(
                    HugeIcons.strokeRoundedRefresh,
                    size: 16,
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ],
            ),
            8.h,
            
            if (userCredits != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 24, color: Colors.amber[600]),
                  8.w,
                  Text(
                    '${userCredits.availableCredits}',
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
              
              // 🆕 Statistiques supplémentaires
              if (userCredits.totalCreditsPurchased > 0) ...[
                8.h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      'Achetés',
                      '${userCredits.totalCreditsPurchased}',
                      Colors.green,
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      color: context.adaptiveBorder,
                    ),
                    _buildStatItem(
                      'Utilisés',
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
                    'Chargement...',
                    style: context.bodyMedium?.copyWith(
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 🆕 Widget helper pour les statistiques
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: context.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextSecondary,
            fontSize: 11,
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
                // 🆕 Utiliser AppDataBloc pour le retry
                print('🔄 Retry: rafraîchissement des données de crédits');
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
                  transaction.description ?? transaction.typeDisplayName,
                  style: context.bodySmall?.copyWith(
                    color: context.adaptiveTextPrimary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _formatDate(transaction.createdAt),
                  style: context.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                    fontSize: 16,
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