import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/styles/colors.dart';
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

class _CreditPlansScreenState extends State<CreditPlansScreen> with TickerProviderStateMixin {
  String? selectedPlanId;
  String? _errorMessage;
  
  late String _screenLoadId;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;

  late List<AnimationController> _itemControllers;
  late List<Animation<Offset>> _itemSlideAnimations;
  late List<Animation<double>> _itemFadeAnimations;

  final List<Animation<double>> _slideAnimations = [];
  final List<Animation<double>> _scaleAnimations = [];

  // Gestion du délai minimum et transition
  Timer? _minimumLoadingTimer;
  bool _minimumLoadingCompleted = false;
  bool _canShowContent = false;
  static const Duration _minimumLoadingDuration = Duration(milliseconds: 300);

  static const int _itemsPerPage = 8;
  static const int _initialItemCount = 5;
  List<CreditTransaction> _allTransactions = [];
  List<CreditTransaction> _displayedTransactions = [];
  bool _isLoadingMore = false;
  bool _hasMoreData = true;  
  final bool _shouldShowLoading = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _screenLoadId = context.trackScreenLoad('credit_plans_screen');

    // Déclencher le pré-chargement si les données ne sont pas disponibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isDataLoaded = context.isCreditDataLoaded;
      LogConfig.logInfo('💳 État initial - données chargées: $isDataLoaded');
      
      if (!isDataLoaded) {
        LogConfig.logInfo('💳 Pré-chargement des données de crédits depuis CreditPlansScreen');
        context.preloadCreditData();
        _startMinimumLoadingTimer();
      } else {
        // Les données sont déjà chargées, pas de shimmer
        LogConfig.logInfo('💳 Données déjà disponibles, affichage direct');
        _minimumLoadingCompleted = true;
        _canShowContent = true;
      }
      context.finishScreenLoad(_screenLoadId);
      _trackCreditsScreenView();
    });
  }

  /// Démarre le timer de délai minimum
  void _startMinimumLoadingTimer() {
    _minimumLoadingTimer = Timer(_minimumLoadingDuration, () {
      if (mounted) {
        LogConfig.logInfo('⏰ Délai minimum écoulé');
        setState(() {
          _minimumLoadingCompleted = true;
        });
        _checkIfCanShowContent();
      }
    });
  }

  /// Vérifie si on peut afficher le contenu (données + délai minimum)
  void _checkIfCanShowContent() {
    final appDataState = context.read<AppDataBloc>().state;
    final hasData = appDataState.isCreditDataLoaded;
    final delayCompleted = _minimumLoadingCompleted;
    
    LogConfig.logInfo('🔍 Check transition - hasData: $hasData, delayCompleted: $delayCompleted, canShow: $_canShowContent');
    
    if (_minimumLoadingCompleted && appDataState.isCreditDataLoaded && !_canShowContent) {
      LogConfig.logInfo('🎯 Transition shimmer → contenu autorisée');
      setState(() {
        _canShowContent = true;
      });
    }
  }

  /// Initialise les contrôleurs d'animation
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _fadeController.forward();
    _staggerController.forward();
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

  void _updateAnimationsForRoutes(int itemCount) {
    // Clear existing animations
    _slideAnimations.clear();
    _scaleAnimations.clear();

    // Create new animations for each item
    for (int i = 0; i < itemCount; i++) {
      final slideAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(
          (i * 0.1).clamp(0.0, 1.0),
          ((i * 0.1) + 0.3).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      ));

      final scaleAnimation = Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(
          (i * 0.1).clamp(0.0, 1.0),
          ((i * 0.1) + 0.5).clamp(0.0, 1.0),
          curve: Curves.elasticOut,
        ),
      ));

      _slideAnimations.add(slideAnimation);
      _scaleAnimations.add(scaleAnimation);
    }
  }

  /// Vérifie si les transactions doivent être mises à jour
  bool _needsTransactionUpdate(List<CreditTransaction> newTransactions) {
    // Vérifier la longueur
    if (_allTransactions.length != newTransactions.length) {
      return true;
    }
    
    // Vérifier les IDs des transactions (plus robuste que la comparaison d'objets)
    final currentIds = _allTransactions.map((t) => t.id).toSet();
    final newIds = newTransactions.map((t) => t.id).toSet();
    
    return !currentIds.containsAll(newIds) || !newIds.containsAll(currentIds);
  }

  /// Met à jour la liste des transactions avec reset du lazy loading
  void _updateTransactionList(List<CreditTransaction> newTransactions) {
    _allTransactions = List.from(newTransactions);
    
    // Reset du lazy loading
    _displayedTransactions = _allTransactions.take(_initialItemCount).toList();
    _hasMoreData = _allTransactions.length > _initialItemCount;
    _isLoadingMore = false;
    
    LogConfig.logInfo('📋 Transactions mises à jour: ${_allTransactions.length} total, ${_displayedTransactions.length} affichées');
  }

  // Méthode pour charger plus d'éléments
  void _loadMoreTransactions() {
    if (_isLoadingMore || !_hasMoreData || _allTransactions.isEmpty) {
      LogConfig.logInfo('⏸️ Chargement ignoré - isLoading: $_isLoadingMore, hasMore: $_hasMoreData, total: ${_allTransactions.length}');
      return;
    }

    LogConfig.logInfo('📋 Chargement de plus de transactions...');
    setState(() => _isLoadingMore = true);

    // Simuler un délai de chargement léger pour l'UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final currentCount = _displayedTransactions.length;
      final remainingItems = _allTransactions.length - currentCount;
      
      LogConfig.logInfo('📊 État lazy loading: affiché=$currentCount, total=${_allTransactions.length}, restant=$remainingItems');
      
      if (remainingItems <= 0) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
        LogConfig.logInfo('✅ Fin du lazy loading - toutes les transactions affichées');
        return;
      }

      final nextBatchSize = _itemsPerPage.clamp(0, remainingItems);
      final nextBatch = _allTransactions
          .skip(currentCount)
          .take(nextBatchSize)
          .toList();

      setState(() {
        _displayedTransactions.addAll(nextBatch);
        _hasMoreData = _displayedTransactions.length < _allTransactions.length;
        _isLoadingMore = false;
      });

      LogConfig.logInfo('📋 Batch chargé: +${nextBatch.length} transactions (${_displayedTransactions.length}/${_allTransactions.length})');

      // Mettre à jour les animations pour les nouveaux éléments
      _updateAnimationsForRoutes(_displayedTransactions.length);
    });
  }

  @override
  void dispose() {
    _minimumLoadingTimer?.cancel();
    _fadeController.dispose();
    _staggerController.dispose();
    super.dispose();
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
              // Écouter les succès d'achat depuis CreditsBloc
              BlocListener<CreditsBloc, CreditsState>(
                listener: (context, state) {
                  if (state is CreditPurchaseSuccess) {
                    if (context.mounted) {
                      showTopSnackBar(
                        Overlay.of(context),
                        TopSnackBar(
                          title: context.l10n.purchaseSuccess,
                        ),
                      );
                    }
                  } else if (state is CreditsError) {
                    _showErrorSnackBar(state.message);
                  }
                },
              ),
            ],
            child: BlocBuilder<AppDataBloc, AppDataState>(
              builder: (context, appDataState) {
                // Vérifier si on peut montrer le contenu quand les données arrivent
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _checkIfCanShowContent();
                });

                return _buildMainContent(appDataState);
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Construction du contenu principal avec transition fluide
  Widget _buildMainContent(AppDataState appDataState) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600), // Durée de la transition
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Transition de fondu avec léger décalage vertical
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: _shouldShowShimmer(appDataState) 
        ? _buildShimmerLoadingState()
        : _shouldShowError(appDataState)
          ? _buildErrorState(appDataState.lastError!)
          : _buildLoadedContent(appDataState),
    );
  }

  /// Détermine si on doit afficher le shimmer
  bool _shouldShowShimmer(AppDataState appDataState) {
    // Afficher le shimmer si on ne peut pas encore afficher le contenu
    final hasData = appDataState.isCreditDataLoaded;
    final isLoading = appDataState.isLoading;
    
    LogConfig.logInfo('🔍 Shimmer check - hasData: $hasData, isLoading: $isLoading, canShow: $_canShowContent');
    
    return !hasData && isLoading && !_canShowContent;
  }

  /// Détermine si on doit afficher l'erreur
  bool _shouldShowError(AppDataState appDataState) {
    return appDataState.lastError != null && 
      !appDataState.hasCreditData && 
      _canShowContent; // Seulement après le délai minimum
  }

  Widget _buildShimmerLoadingState() {
    return Column(
      key: const ValueKey('shimmer'), // Clé pour AnimatedSwitcher
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShimmerContainer(radius: 30, height: 24, width: 100),
        15.h,
        _buildShimmerContainer(radius: 40, height: 85),
        
        // Statistiques supplémentaires
        8.h,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: _buildShimmerContainer(radius: 40, height: 85)),
            8.w,
            Expanded(child: _buildShimmerContainer(radius: 40, height: 85)),
          ],
        ),

        30.h,

        _buildShimmerContainer(radius: 30, height: 24, width: 250),
        15.h,

        Expanded(
          child: BlurryPage(
            physics: const BouncingScrollPhysics(),
            shrinkWrap: false,
            children: [
              ...List.generate(10, (index) {
                return Padding(
                  padding: EdgeInsets.only(bottom: index == 10 - 1 ? 0.0 : 12.0),
                  child: _buildShimmerContainer(radius: 50, height: 70),
                );
              })
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerContainer({required double radius, required double height, double? width}) {
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(radius),
          ),
        ),
      ),
      child: Container(
        height: height,
        width: width,
        // radius: 20,
        // gradient: false,
        decoration: BoxDecoration(
          // borderRadius: BorderRadius.circular(15),
          color: context.adaptiveDisabled.withValues(alpha: 0.05),
        ),
      ).animate(onPlay: (controller) => controller.loop()).shimmer(color: context.adaptiveBorder.withValues(alpha: 0.05), duration: Duration(seconds: 2), blendMode: BlendMode.dstOver),
    );
  }

  /// Contenu avec données chargées (UI First)
  Widget _buildLoadedContent(AppDataState appDataState) {
    // Données immédiatement disponibles depuis AppDataBloc
    final userCredits = appDataState.userCredits;
    final transactions = appDataState.creditTransactions;

    // Utiliser une méthode plus robuste pour détecter les changements
    if (_needsTransactionUpdate(transactions)) {
      LogConfig.logInfo('🔄 Mise à jour des transactions: ${transactions.length} total');
      _updateTransactionList(transactions);
    }

    final shouldUseLazyLoading = transactions.length > 12;
    final transactionsToDisplay = shouldUseLazyLoading ? _displayedTransactions : transactions;

    // Mettre à jour les animations en fonction du nombre de transactions
    if (transactionsToDisplay.isNotEmpty) {
      _updateAnimationsForRoutes(transactionsToDisplay.length);
    }

    return Stack(
      key: const ValueKey('content'), // Clé pour AnimatedSwitcher
      children: [
        transactions.isEmpty 
          ? _buildEmptyState() 
          : BlurryPage(
            physics: const BouncingScrollPhysics(),
            shrinkWrap: false,
            enableLazyLoading: shouldUseLazyLoading,
            initialItemCount: _initialItemCount,
            itemsPerPage: _itemsPerPage,
            onLoadMore: _loadMoreTransactions,
            isLoading: _isLoadingMore,
            hasMoreData: _hasMoreData,
            children: [
              _buildCreditsHeader(userCredits!),
              
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
          
              _buildAnimatedTransactionsList(transactionsToDisplay),
              
              // 🚀 Espace pour le bouton en bas (éviter que le dernier élément soit caché)
              SizedBox(height: 100 + (Platform.isAndroid ? MediaQuery.of(context).padding.bottom : 10)),
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

  Widget _buildCreditsHeader(UserCredits userCredits) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
            child: Column(
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
                Row(
                  children: [
                    _buildStatItem(
                      context.l10n.availableCredits,
                      '${userCredits.availableCredits}',
                      AppColors.thirty,
                    ),
                  ],
                ),
                
                // Statistiques supplémentaires
                if (userCredits.totalCreditsPurchased > 0) ...[
                  8.h,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        context.l10n.purchasedCredits,
                        '${userCredits.totalCreditsPurchased}',
                        AppColors.secondary,
                      ),
                      8.w,
                      _buildStatItem(
                        context.l10n.usedCredits,
                        '${userCredits.totalCreditsUsed}',
                        AppColors.binary,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }
    );
  }

  /// Widget helper pour les statistiques
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
      key: const ValueKey('error'), // Clé pour AnimatedSwitcher
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
                
                // 🆕 Redémarrer complètement le processus
                setState(() {
                  _minimumLoadingCompleted = false;
                  _canShowContent = false;
                });
                
                context.refreshCreditData();
                _startMinimumLoadingTimer();
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

  /// Liste animée avec transition shimmer ↔ chargé
  Widget _buildAnimatedTransactionsList(List<CreditTransaction> transactions) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550), // Timing optimisé
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) {
        // Animation de fondu progressive
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );
        
        // Animation de glissement subtile avec rebond
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.03), // Mouvement très subtil
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack, // Léger effet de rebond
        ));
        
        // Animation de scale pour la fluidité
        final scaleAnimation = Tween<double>(
          begin: 0.96,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          ),
        );
      },
      child: _shouldShowLoading ? _buildShimmerList() : _buildLoadedList(transactions),
    );
  }

  /// Liste shimmer pendant le chargement
  Widget _buildShimmerList() {
    return Column(
      key: const ValueKey('shimmer'),
      children: [
        ...List.generate(10, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index == 10 - 1 ? 0.0 : 12.0),
            child: _buildShimmerContainer(radius: 50, height: 70),
          );
        })
      ]
    );
  }

  /// Liste chargée avec animations staggered
  Widget _buildLoadedList(List<CreditTransaction> transactions) {
    // Utiliser _displayedTransactions pour le lazy loading
    final transactionsToShow = transactions.length > 12 ? _displayedTransactions : transactions;
    final sortedTransactions = transactionsToShow.sortByCreationDate();
    
    LogConfig.logInfo('📋 Affichage de ${sortedTransactions.length} transactions sur ${_allTransactions.length} total');
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey('loaded'),
      children: [
        ...sortedTransactions.asMap().entries.map((entry) {
          final index = entry.key;
          final transaction = entry.value;
          return AnimatedBuilder(
            animation: _staggerController,
            builder: (context, child) {
              // Animations avec fallback sécurisé
              final slideValue = index < _slideAnimations.length 
                  ? _slideAnimations[index].value 
                  : 0.0;
              final scaleValue = index < _scaleAnimations.length 
                  ? _scaleAnimations[index].value 
                  : 1.0;

              // Animation d'apparition progressive améliorée
              final itemAnimation = CurvedAnimation(
                parent: _staggerController,
                curve: Interval(
                  (index * 0.06).clamp(0.0, 0.7), // Timing optimisé
                  ((index * 0.06) + 0.35).clamp(0.2, 1.0),
                  curve: Curves.easeOutExpo, // Courbe d'accélération naturelle
                ),
              );
              
              return Opacity(
                opacity: _fadeAnimation.value * itemAnimation.value,
                child: Transform.translate(
                offset: Offset(0, slideValue * (1.0 - itemAnimation.value)),
                child: Transform.scale(
                  scale: 0.85 + (scaleValue * itemAnimation.value * 0.15),
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: index == sortedTransactions.length - 1 ? 0.0 : 12.0,
                    ),
                      child: _buildTransactionItem(transaction),
                    ),
                  ),
                ),
              );
            }
          );
        }),
      ],
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
                  style: GoogleFonts.inter(
                    color: context.adaptiveTextSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500
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