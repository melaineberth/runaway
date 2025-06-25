// lib/features/activity/presentation/screens/activity_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/account/presentation/screens/account_screen.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../../../config/extensions.dart';
import '../../../../core/widgets/ask_registration.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/widgets/top_snackbar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../route_generator/domain/models/activity_type.dart';
import '../../domain/models/activity_stats.dart';
import '../blocs/activity_bloc.dart';
import '../blocs/activity_event.dart';
import '../blocs/activity_state.dart';
import '../widgets/stats_overview_card.dart';
import '../widgets/activity_type_stats_card.dart';
import '../widgets/goals_section.dart';
import '../widgets/records_section.dart';
import '../widgets/progress_charts.dart';
import '../widgets/add_goal_dialog.dart';
import '../widgets/goal_templates_dialog.dart';

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
    
    // Charger les statistiques au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityBloc>().add(ActivityStatsRequested());
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
            return AskRegistration();
          }

          return Scaffold(
            extendBodyBehindAppBar: true,
            extendBody: true,
            appBar: _buildAppBar(),
            body: BlocConsumer<ActivityBloc, ActivityState>(
              listener: _handleStateChanges,
              builder: (context, state) {
                if (state is ActivityLoading) {
                  return _buildLoadingState();
                }
                
                if (state is ActivityError) {
                  return _buildErrorState(state.message);
                }
                
                if (state is ActivityLoaded) {
                  return _buildScrollableContent(state);
                }

                return _buildInitialState();
              },
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      forceMaterialTransparency: true,
      backgroundColor: Colors.transparent,
      centerTitle: true,
      title: FadeTransition(
        opacity: _fadeAnimation,
        child: Text(
          "Activité",
          style: context.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      actions: [
        FadeTransition(
          opacity: _fadeAnimation,
          child: IconButton(
            onPressed: () => _refreshData(),
            icon: Icon(
              HugeIcons.solidRoundedRefresh,
              color: Colors.white,
            ),
          ),
        ),
        FadeTransition(
          opacity: _fadeAnimation,
          child: PopupMenuButton<String>(
            icon: Icon(
              HugeIcons.strokeRoundedMoreVertical,
              color: Colors.white,
            ),
            color: Colors.black87,
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(HugeIcons.strokeRoundedDownload01, color: Colors.white, size: 20),
                    8.w,
                    Text('Exporter les données', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset_goals',
                child: Row(
                  children: [
                    Icon(HugeIcons.strokeRoundedRefresh, color: Colors.orange, size: 20),
                    8.w,
                    Text('Réinitialiser objectifs', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
            ],
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
              'Calcul des statistiques...',
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
                'Erreur',
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
                label: Text('Réessayer'),
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
              'Chargement...',
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

  Widget _buildScrollableContent(ActivityLoaded state) {
    return BlurryPage(
      padding: EdgeInsets.all(20.0),
      children: [        
        // Vue d'ensemble
        StatsOverviewCard(stats: state.generalStats),
        
        40.h,
        
        // Graphiques de progression
        ProgressChartsSection(
          periodStats: state.periodStats,
          currentPeriod: state.currentPeriod,
          onPeriodChanged: (period) {
            context.read<ActivityBloc>().add(ActivityPeriodChanged(period));
          },
        ),
        
        40.h,
        
        // Statistiques par activité
        ActivityTypeStatsCard(
          stats: state.typeStats,
          selectedType: state.selectedActivityFilter,
          onTypeSelected: (type) {
            context.read<ActivityBloc>().add(ActivityFilterChanged(type));
          },
        ),
        
        40.h,
        
        // Objectifs personnels
        GoalsSection(
          goals: state.goals,
          onAddGoal: _showAddGoalOptions,
          onEditGoal: _editGoal,
          onDeleteGoal: _deleteGoal,
        ),
        
        40.h,
        
        // Records personnels
        RecordsSection(records: state.records),
        
        50.h,
      ],
    );
  }

  void _handleStateChanges(BuildContext context, ActivityState state) {
    if (state is ActivityError) {
      _showErrorSnackbar(state.message);
    }
  }

  void _refreshData() {
    context.read<ActivityBloc>().add(ActivityStatsRequested());
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'export':
        _exportData();
        break;
      case 'reset_goals':
        _showResetGoalsDialog();
        break;
    }
  }

  void _showAddGoalOptions() {
    showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      context: context,
      backgroundColor: Colors.black,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Créer un objectif',
              style: context.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            20.h,
            _buildGoalOption(
              context: context,
              icon: HugeIcons.strokeRoundedAdd01,
              title: 'Objectif personnalisé',
              subtitle: 'Créer un objectif sur mesure',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showAddGoalDialog();
              },
            ),
            _buildGoalOption(
              context: context,
              icon: HugeIcons.strokeRoundedAdd01,
              title: 'Modèles d\'objectifs',
              subtitle: 'Choisir parmi des objectifs pré-définis',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _showAddGoalDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalOption({required BuildContext context, required IconData icon, Color color = Colors.white10, required String title, required String subtitle, Function()? onTap}) {    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SquircleContainer(
        onTap: onTap,
        radius: 40,
        color: Colors.white10,
        padding: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SquircleContainer(
                  padding: EdgeInsets.all(8),
                  radius: 18,
                  color: color.withValues(alpha: 0.1),
                  child: Icon(icon, color: color, size: 30),
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
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Icon(
              HugeIcons.strokeRoundedArrowRight01,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog([PersonalGoal? existingGoal]) async {
    final result = await showModalBottomSheet<PersonalGoal>(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      context: context,
      backgroundColor: Colors.black,
      builder: (context) => AddGoalDialog(existingGoal: existingGoal),
    );

    if (result != null) {
      if (existingGoal != null) {
        context.read<ActivityBloc>().add(PersonalGoalUpdated(result));
      } else {
        context.read<ActivityBloc>().add(PersonalGoalAdded(result));
      }
      
      _showSuccessSnackbar(
        existingGoal != null ? 'Objectif mis à jour' : 'Objectif créé'
      );
    }
  }

  void _editGoal(PersonalGoal goal) {
    _showAddGoalDialog(goal);
  }

  void _deleteGoal(String goalId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text('Supprimer l\'objectif', style: TextStyle(color: Colors.white)),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer cet objectif ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ActivityBloc>().add(PersonalGoalDeleted(goalId));
              _showSuccessSnackbar('Objectif supprimé');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    _showSuccessSnackbar('Export des données en cours...');
    // TODO: Implémenter l'export des données
  }

  void _showResetGoalsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text('Réinitialiser les objectifs', style: TextStyle(color: Colors.white)),
        content: Text(
          'Cette action supprimera tous vos objectifs. Êtes-vous sûr ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetAllGoals();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  void _resetAllGoals() {
    // TODO: Implémenter la réinitialisation des objectifs
    _showSuccessSnackbar('Objectifs réinitialisés');
  }

  void _showSuccessSnackbar(String message) {
    showTopSnackBar(
      Overlay.of(context),
      TopSnackBar(
        title: message,
        icon: HugeIcons.solidRoundedCheckmarkCircle02,
        color: Colors.green,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    showTopSnackBar(
      Overlay.of(context),
      TopSnackBar(
        title: message,
        icon: HugeIcons.solidRoundedAlert02,
        color: Colors.red,
      ),
    );
  }
}