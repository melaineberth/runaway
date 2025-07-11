import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:runaway/config/constants.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/services/conversion_triggers.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/activity/data/repositories/activity_repository.dart';
import 'package:runaway/features/activity/presentation/widgets/goal_templates_dialog.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../../../config/extensions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/models/activity_stats.dart';
import '../blocs/activity_state.dart';
import '../widgets/stats_overview_card.dart';
import '../widgets/activity_type_stats_card.dart';
import '../widgets/goals_section.dart';
import '../widgets/records_section.dart';
import '../widgets/add_goal_dialog.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();  

    // 🆕 DÉCLENCHER l'événement de consultation d'activité
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConversionTriggers.onActivityViewed(context);
    });  
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is Unauthenticated) {
          context.go('/home');
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (_, authState) {
          if (authState is! Authenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showAuthModal(context);
            });  
          }

          return BlocBuilder<AppDataBloc, AppDataState>(
            builder: (context, appDataState) {
              return Scaffold(
                extendBodyBehindAppBar: true,
                appBar: _buildAppBar(),
                body: _buildBody(appDataState),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(AppDataState appDataState) {    
    // Si les données ne sont pas encore chargées ET qu'on charge
    if (!appDataState.isDataLoaded && appDataState.isLoading) {
      return _buildLoadingState();
    }

    // Si erreur de chargement
    if (appDataState.lastError != null && !appDataState.hasActivityData) {
      return _buildErrorState(appDataState.lastError!);
    }

    // Si les données sont disponibles
    if (appDataState.hasActivityData) {
      return _buildScrollableContent(appDataState);
    }

    // État initial - déclencher le chargement si nécessaire
    if (!appDataState.isDataLoaded && !appDataState.isLoading) {
      print('📊 Déclenchement du pré-chargement depuis ActivityScreen');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.appDataBloc.add(const AppDataPreloadRequested());
      });
      return _buildLoadingState();
    }

    // Fallback
    return _buildInitialState();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      forceMaterialTransparency: true,
      backgroundColor: Colors.transparent,
      title: FadeTransition(
        opacity: _fadeAnimation,
        child: Text(
          context.l10n.activityTitle,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(
            color: context.adaptiveBackground.withValues(alpha: 0.3),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: PullDownButton(
              itemBuilder: (context) => [
                PullDownMenuItem(
                  icon: HugeIcons.strokeRoundedShare08,
                  title: context.l10n.exportData,
                  onTap: () => _handleMenuSelection("export"),
                ),
                PullDownMenuItem(
                  icon: HugeIcons.solidRoundedLoading03,
                  title: context.l10n.resetGoals,
                  onTap: () => _handleMenuSelection("reset_goals"),
                ),
              ],
              buttonBuilder: (context, showMenu) => GestureDetector(
                onTap: () {
                  showMenu();
                  HapticFeedback.mediumImpact();
                },
                child: Icon(
                  HugeIcons.strokeRoundedMoreVerticalCircle02,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            20.h,
            Text(
              context.l10n.statisticsCalculation,
              style: context.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                HugeIcons.strokeRoundedAlert02,
                size: 64,
                color: Colors.red,
              ),
              24.h,
              Text(
                context.l10n.error,
                style: context.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              12.h,
              Text(
                message,
                style: context.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              32.h,
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: Icon(HugeIcons.strokeRoundedRefresh),
                label: Text(context.l10n.retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              HugeIcons.strokeRoundedActivity01,
              size: 64,
              color: Colors.white54,
            ),
            24.h,
            Text(
              context.l10n.loading,
              style: context.bodyLarge?.copyWith(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableContent(AppDataState appDataState) {
    print('✅ Affichage du contenu avec les données pré-chargées');
    
    // ✅ Créer un état ActivityLoaded virtuel à partir des données pré-chargées
    final virtualState = ActivityLoaded(
      generalStats: appDataState.activityStats!,
      typeStats: appDataState.activityTypeStats,
      periodStats: appDataState.periodStats,
      goals: appDataState.personalGoals,
      records: appDataState.personalRecords,
      currentPeriod: PeriodType.monthly, // Valeur par défaut
      selectedActivityFilter: null,
    );

    return RefreshIndicator(
      onRefresh: () async {
        _refreshData();
      },
      child: BlurryPage(
        padding: EdgeInsets.symmetric(horizontal: 20.0),
        children: [      
          20.h,
            
          // Vue d'ensemble
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                  child: StatsOverviewCard(
                    stats: virtualState.generalStats,
                  ),
                ),
              );
            }
          ),
          
          40.h,
          
          // Statistiques par activité
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                  child: ActivityTypeStatsCard(
                    stats: virtualState.typeStats,
                    selectedType: virtualState.selectedActivityFilter,
                    onTypeSelected: (type) {
                      // Pour l'instant, on garde simple - on pourrait améliorer plus tard
                      print('🏃 Filtrage par type demandé: $type');
                    },
                  ),
                ),
              );
            }
          ),
          
          40.h,
          
          // Objectifs personnels
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                  child: GoalsSection(
                    goals: virtualState.goals,
                    onAddGoal: _showAddGoalOptions,
                    onEditGoal: _editGoal,
                    onDeleteGoal: _deleteGoal,
                  ),
                ),
              );
            }
          ),
          
          40.h,
          
          // Records personnels
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                  child: RecordsSection(
                    records: virtualState.records,
                  ),
                ),
              );
            }
          ),
          
          50.h,
        ],
      ),
    );
  }

  void _refreshData() {
    print('🔄 Rafraîchissement des données d\'activité demandé depuis ActivityScreen');
    context.appDataBloc.add(const ActivityDataRefreshRequested());
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'export':
        (){};
        break;
      case 'reset_goals':
        _showResetGoalsDialog();
        break;
    }
  }

  void _showAddGoalOptions() {
    showModalSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      child: _buildGoalOptions(),
    );
  }

  Widget _buildGoalOptions() {
    return ModalSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.createGoal,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextPrimary,
            ),
          ),
          20.h,
          _buildGoalOption(
            context: context,
            icon: HugeIcons.solidRoundedAddCircle,
            title: context.l10n.customGoal,
            subtitle: context.l10n.createCustomGoal,
            onTap: () {
              context.pop();
              _showAddGoalDialog();
            },
          ),
          10.h,
          _buildGoalOption(
            context: context,
            icon: HugeIcons.solidRoundedGridView,
            title: context.l10n.goalsModels,
            subtitle: context.l10n.predefinedGoals,
            onTap: () {
              context.pop();
              _showGoalTemplatesDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalOption({required BuildContext context, required IconData icon, required String title, required String subtitle, Function()? onTap}) {    
    return SquircleContainer(
      onTap: onTap,
      radius: 50,
      color: context.adaptiveBorder.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SquircleContainer(
                radius: 30,
                isGlow: true,
                color: context.adaptivePrimary,
                padding: const EdgeInsets.all(15),
                child: Icon(
                  icon, 
                  color: Colors.white, 
                  size: 25,
                ),
              ),

              15.w,

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.bodyMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: context.bodySmall?.copyWith(
                      fontSize: 14,
                      color: context.adaptiveTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              HugeIcons.strokeRoundedArrowRight01,
              color: context.adaptiveTextPrimary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddGoalDialog([PersonalGoal? existingGoal]) async {
    final result = await showModalBottomSheet<PersonalGoal>(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AddGoalDialog(existingGoal: existingGoal),
    );

    if (result != null) {
      // 🔥 UTILISER AppDataBloc AU LIEU D'ActivityBloc
      if (existingGoal != null) {
        // Afficher un message de confirmation
        if (mounted) {
          context.appDataBloc.add(PersonalGoalUpdatedInAppData(result));
          
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              title: context.l10n.updatedGoal,
            ),
          );
        }
      } else {        
        // Afficher un message de confirmation
        if (mounted) {
          context.appDataBloc.add(PersonalGoalAddedToAppData(result));
          
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              title: context.l10n.createdGoal,
            ),
          );
        }
      }
    }
  }

  Future<void> _showGoalTemplatesDialog() async {
    final result = await showModalBottomSheet<PersonalGoal>(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GoalTemplatesDialog(),
    );

    if (result != null) {
      // Afficher un message de confirmation
      if (mounted) {
        context.appDataBloc.add(PersonalGoalAddedToAppData(result));
        
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: context.l10n.createdGoal,
          ),
        );
      }
    }
  }

  void _editGoal(PersonalGoal goal) {
    _showAddGoalDialog(goal);
  }

  void _deleteGoal(String goalId) {
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: ModalDialog(
        isDestructive: true,
        activeCancel: false,
        title: context.l10n.deleteGoalTitle,
        subtitle: context.l10n.deleteGoalMessage,
        validLabel: context.l10n.delete,
        onValid: () {
          HapticFeedback.mediumImpact();
          
          context.pop(context);
              
          context.appDataBloc.add(PersonalGoalDeletedFromAppData(goalId));
          
          // Afficher un message de confirmation
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              title: context.l10n.removedGoal,
            ),
          );
        },
      ),
    );
  }

  void _showResetGoalsDialog() {
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: ModalDialog(
        isDestructive: true,
        activeCancel: false,
        title: context.l10n.goalsResetTitle,
        subtitle: context.l10n.goalsResetMessage,
        validLabel: context.l10n.reset,
        onValid: () {
          HapticFeedback.mediumImpact();
          
          context.pop(context);
              
          context.appDataBloc.add(const PersonalGoalsResetInAppData());
              
          // Afficher un message de confirmation
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              title: 'Tous les objectifs ont été supprimés',
            ),
          );
        },
      ),
    );
  }
}