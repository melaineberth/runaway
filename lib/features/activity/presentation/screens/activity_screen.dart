import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/activity/data/repositories/activity_repository.dart';
import 'package:runaway/features/activity/presentation/widgets/goal_templates_dialog.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../../../config/extensions.dart';
import '../../../../core/widgets/ask_registration.dart';
import '../../../../core/widgets/top_snackbar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/models/activity_stats.dart';
import '../blocs/activity_bloc.dart';
import '../blocs/activity_event.dart';
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
          // ✅ Vérifier d'abord l'authentification
          if (authState is! Authenticated) {
            return AskRegistration();
          }

          // ✅ Utiliser EXCLUSIVEMENT AppDataBloc
          return BlocBuilder<AppDataBloc, AppDataState>(
            builder: (context, appDataState) {
              return Scaffold(
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
    // Débogage : afficher l'état des données
    print('🔍 ActivityScreen - État des données:');
    print('   - isLoading: ${appDataState.isLoading}');
    print('   - isDataLoaded: ${appDataState.isDataLoaded}');
    print('   - hasActivityData: ${appDataState.hasActivityData}');
    print('   - lastError: ${appDataState.lastError}');
    
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
        context.read<AppDataBloc>().add(const AppDataPreloadRequested());
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
                    SizedBox(width: 8),
                    Text('Exporter les données', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset_goals',
                child: Row(
                  children: [
                    Icon(HugeIcons.strokeRoundedRefresh, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
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

  Widget _buildScrollableContent(AppDataState appDataState) {
    print('✅ Affichage du contenu avec les données pré-chargées');
    
    // ✅ Créer un état ActivityLoaded virtuel à partir des données pré-chargées
    final virtualState = ActivityLoaded(
      generalStats: appDataState.activityStats!,
      typeStats: appDataState.activityTypeStats ?? [],
      periodStats: appDataState.periodStats ?? [],
      goals: appDataState.personalGoals ?? [],
      records: appDataState.personalRecords ?? [],
      currentPeriod: PeriodType.monthly, // Valeur par défaut
      selectedActivityFilter: null,
    );

    return BlurryPage(
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
    );
  }

  void _refreshData() {
    print('🔄 Rafraîchissement des données d\'activité demandé depuis ActivityScreen');
    context.read<AppDataBloc>().add(const ActivityDataRefreshRequested());
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
                showModalBottomSheet(
                  useRootNavigator: true,
                  isScrollControlled: true,
                  isDismissible: true,
                  enableDrag: false,
                  context: context,
                  backgroundColor: Colors.black,
                  builder: (context) => GoalTemplatesDialog(),
                );
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

}