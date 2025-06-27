import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/historic/presentation/widgets/shimmer_historic_card.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_event.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_state.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../widgets/historic_card.dart';

class HistoricScreen extends StatefulWidget {  
  /// Durée minimum d'affichage du loading pour que les animations soient visibles
  final Duration minimumLoadingDuration;

  const HistoricScreen({
    super.key,
    this.minimumLoadingDuration = const Duration(milliseconds: 800),
  });

  @override
  State<HistoricScreen> createState() => _HistoricScreenState();
}

class _HistoricScreenState extends State<HistoricScreen> with TickerProviderStateMixin {
  bool isEditMode = true;

  // 🎭 Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;
  
  final List<Animation<double>> _slideAnimations = [];
  final List<Animation<double>> _scaleAnimations = [];
  
  // ⏱️ Gestion du loading minimum
  final bool _shouldShowLoading = false;

  // 🆕 Variable pour tracker les changements de parcours
  List<SavedRoute> _lastKnownRoutes = [];
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedRoutes();
    });  
  }

  /// 🎬 Initialise les contrôleurs d'animation
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

  void _updateAnimationsForRoutes(List<SavedRoute> routes) {
    _slideAnimations.clear();
    _scaleAnimations.clear();

    for (int i = 0; i < routes.length; i++) {
      final slideInterval = Interval(
        (i * 0.1).clamp(0.0, 1.0),
        ((i * 0.1) + 0.3).clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      );

      final scaleInterval = Interval(
        (i * 0.05).clamp(0.0, 1.0),
        ((i * 0.05) + 0.4).clamp(0.0, 1.0),
        curve: Curves.elasticOut,
      );

      _slideAnimations.add(
        Tween<double>(begin: 50.0, end: 0.0).animate(
          CurvedAnimation(parent: _staggerController, curve: slideInterval),
        ),
      );

      _scaleAnimations.add(
        Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: _staggerController, curve: scaleInterval),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    if (isEditMode == true) {
      setState(() {
        isEditMode = false;
      });
      print("Enable edit mode");
    } else {
      setState(() {
        isEditMode = true;
      });
      
      print("Disable edit mode");
    }
  }

  /// Charge les parcours sauvegardés
  void _loadSavedRoutes() {
    print('🔄 Chargement manuel des parcours');
    context.read<AppDataBloc>().add(const HistoricDataRefreshRequested());
  }

  /// 🧭 Navigation vers le parcours sélectionné - Chargement dans HomeScreen
  void _navigateToRoute(SavedRoute route) {
    print('🧭 === DÉBUT NAVIGATION VERS PARCOURS ===');
    print('📊 Route ID: ${route.id}');
    print('📊 Route Name: ${route.name}');
    print('📊 Route Distance: ${route.formattedDistance}');
    print('📊 Route Points: ${route.coordinates.length}');
    print('📊 Created: ${route.createdAt}');
    print('📊 Times Used: ${route.timesUsed}');
    
    // 🔑 ÉTAPE 1: Charger le parcours dans le bloc pour l'afficher sur la carte
    // Note: Ceci va déclencher SavedRouteLoaded dans RouteGenerationBloc
    // qui va mettre isLoadedFromHistory = true pour éviter la double sauvegarde
    context.read<RouteGenerationBloc>().add(SavedRouteLoaded(route.id));
    print('✅ Événement SavedRouteLoaded envoyé au bloc');
    
    // 🔑 ÉTAPE 2: Naviguer vers HomeScreen où le parcours sera affiché
    // HomeScreen va détecter que isLoadedFromHistory = true et ne pas sauvegarder automatiquement
    context.go('/home');
    print('✅ Navigation vers /home lancée');
    
    print('✅ Notification utilisateur affichée');
    print('🧭 === FIN NAVIGATION VERS PARCOURS ===');
  }

  /// Suppression d'un parcours avec confirmation
  void _deleteRoute(SavedRoute route) {
    print('🗑️ Demande de suppression: ${route.name} (${route.id})');
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Supprimer le parcours',
          style: context.titleMedium?.copyWith(color: Colors.white),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${route.name}" ?\n\nCette action est irréversible.',
          style: context.bodyMedium?.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              print('❌ Suppression annulée par l\'utilisateur');
            },
            child: Text(
              'Annuler', 
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              
              print('🗑️ Suppression confirmée - envoi de SavedRouteDeleted');
              context.read<RouteGenerationBloc>().add(SavedRouteDeleted(route.id));
              
              // Afficher un feedback
              showTopSnackBar(
                Overlay.of(context),
                TopSnackBar(
                  title: 'Parcours supprimé',
                  icon: HugeIcons.solidRoundedDelete02,
                  color: Colors.red,
                ),
              );
              print('✅ Notification suppression affichée');
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

  /// Interface pour les utilisateurs non connectés
  Widget _buildUnauthenticatedView() {
    return AskRegistration();
  }

  /// 🎭 Interface principale avec animations intégrées
  Widget _buildMainView(AppDataState appDataState) {
    final routes = appDataState.savedRoutes;
    final isLoading = appDataState.isLoading;

    // Mettre à jour les animations en fonction du nombre de routes
    if (routes.isNotEmpty) {
      _updateAnimationsForRoutes(routes);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isLoading),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20.0, kTextTabBarHeight * 3, 20.0, 0.0),
        child: Column(
          children: [
            // Stats card avec animation si plus d'un parcours
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                    child: _buildStatsCard(routes),
                  ),
                );
              },
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _refreshData();
                },
                child: BlurryPage(
                  contentPadding: EdgeInsets.only(top: 20.0, bottom: 40.0),
                  children: [
                    _buildAnimatedRoutesList(routes),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isLoading, {Widget? child}) {
    return AppBar(
      centerTitle: true,
      forceMaterialTransparency: true,
      backgroundColor: Colors.transparent,
      title: FadeTransition(
        opacity: _fadeAnimation,
        child: Text(
          "Historique",
          style: context.bodySmall?.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  /// 🎬 Liste animée avec transition shimmer ↔ chargé
  Widget _buildAnimatedRoutesList(List<SavedRoute> routes) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: _shouldShowLoading ? _buildShimmerList() : _buildLoadedList(routes),
    );
  }

  /// 🎭 Liste shimmer pendant le chargement
  Widget _buildShimmerList() {
    return Column(
      key: const ValueKey('shimmer'),
      children: List.generate(3, (index) => Padding(
          padding: EdgeInsets.only(bottom: index >= 2 ? 90.0 : 15.0),
          child: ShimmerHistoricCard(),
        ),
      ),
    );
  }

  /// ✨ Liste chargée avec animations staggered
  Widget _buildLoadedList(List<SavedRoute> routes) {
    final sortedRoutes = routes.sortByCreationDate();
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey('loaded'),
      children: [
        // Parcours avec animations décalées
        ...sortedRoutes.asMap().entries.map((entry) {
          final index = entry.key;
          final route = entry.value;
          
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
              
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, slideValue),
                  child: Transform.scale(
                    scale: scaleValue,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: index >= sortedRoutes.length - 1 ? 90.0 : 20.0,
                      ),
                      child: HistoricCard(
                        route: route,
                        isEdit: isEditMode,
                        onTap: () => _navigateToRoute(route),
                        onDelete: () => _deleteRoute(route),
                        onSync: routes == routes.unsyncedRoutes ? _syncData : null,
                        onRename: _toggleEditMode,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  /// Interface d'erreur
  Widget _buildErrorView(String error) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        title: Text(
          "Historique",
          style: context.bodySmall?.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: _loadSavedRoutes,
            icon: Icon(HugeIcons.strokeRoundedRefresh, color: Colors.white),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              HugeIcons.strokeRoundedAlert02,
              size: 64,
              color: Colors.red,
            ),
            16.h,
            Text(
              'Erreur de chargement',
              style: context.bodyLarge?.copyWith(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            8.h,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                error,
                style: context.bodyMedium?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            24.h,
            ElevatedButton.icon(
              onPressed: _loadSavedRoutes,
              icon: Icon(HugeIcons.strokeRoundedRefresh),
              label: Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Interface vide (aucun parcours)
  Widget _buildEmptyView(AppDataState appDataState) {
    final isLoading = appDataState.isLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(
        isLoading,
        child: IconButton(
          onPressed: _loadSavedRoutes,
          icon: Icon(HugeIcons.strokeRoundedRefresh, color: Colors.white),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SquircleContainer(              
              color: AppColors.primary.withValues(alpha: 0.3),
              padding: EdgeInsets.all(30.0),
              child: Icon(
                HugeIcons.strokeRoundedRoute01,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            30.h,
            Text(
              'Aucun parcours sauvegardé',
              style: context.bodyLarge?.copyWith(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            8.h,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Générez votre premier parcours depuis l\'accueil pour le voir apparaître ici',
                style: context.bodyMedium?.copyWith(
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                  fontSize: 17,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            24.h,
            ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: Icon(HugeIcons.strokeRoundedAiMagic),
              label: Text('Générer un parcours'),
            ),
          ],
        ),
      ),
    );
  }

  /// Carte de statistiques rapides
  Widget _buildStatsCard(List<SavedRoute> routes) {
    final totalDistance = routes.fold<double>(
      0, 
      (sum, route) => sum + (route.actualDistance ?? route.parameters.distanceKm),
    );
    final totalRoutes = routes.length;
    final unsyncedCount = routes.unsyncedRoutes.length;
    final syncedCount = totalRoutes - unsyncedCount;
    
    return SquircleContainer(
      radius: 40.0,
      padding: EdgeInsets.all(20),
      color: Colors.white10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: HugeIcons.strokeRoundedRoute01,
            value: totalRoutes.toString(),
            label: 'Parcours',
          ),
          _buildStatItem(
            icon: HugeIcons.strokeRoundedNavigator01,
            value: '${totalDistance.toStringAsFixed(1)}km',
            label: 'Total',
          ),
          if (unsyncedCount > 0)
          _buildStatItem(
            icon: HugeIcons.strokeRoundedWifiOff01,
            value: unsyncedCount.toString(),
            label: 'Non sync',
            color: Colors.orange,
          )
        else
          _buildStatItem(
            icon: HugeIcons.strokeRoundedWifi01,
            value: syncedCount.toString(),
            label: 'Sync',
            color: Colors.green,
          ),

        ],
      ),
    );
  }

  /// Item de statistique
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white, size: 24),
        4.h,
        Text(
          value,
          style: context.bodyMedium?.copyWith(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: context.bodySmall?.copyWith(
            color: (color ?? Colors.white).withAlpha(180),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _refreshData() {
    print('🔄 Rafraîchissement de l\'historique demandé');
    context.read<AppDataBloc>().add(const HistoricDataRefreshRequested());
  }

  void _syncData() {
    print('☁️ Synchronisation des données demandée');
    context.read<RouteGenerationBloc>().add(SyncPendingRoutesRequested());
    
    // Ensuite rafraîchir les données
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        context.read<AppDataBloc>().add(const HistoricDataRefreshRequested());
      }
    });
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
            return _buildUnauthenticatedView();
          }

          // Surveiller RouteGenerationBloc.savedRoutes
          return BlocListener<RouteGenerationBloc, RouteGenerationState>(
            listener: (context, routeState) {
              // Comparer le nombre de routes pour détecter les changements
              if (_lastKnownRoutes.length != routeState.savedRoutes.length) {
                print('🔄 Changement détecté: ${_lastKnownRoutes.length} -> ${routeState.savedRoutes.length} parcours');
                
                // Déclencher un rafraîchissement immédiat de l'AppDataBloc
                context.read<AppDataBloc>().add(const HistoricDataRefreshRequested());
                
                // Mettre à jour le tracker
                _lastKnownRoutes = List.from(routeState.savedRoutes);
              }
            },
            child: BlocBuilder<AppDataBloc, AppDataState>(
              builder: (context, appDataState) {
                print('🔍 HistoricScreen - État AppData: hasData=${appDataState.hasHistoricData}, routes=${appDataState.savedRoutes.length}');
                
                if (!appDataState.hasHistoricData) {
                  return _buildEmptyView(appDataState);
                }
                if (appDataState.lastError != null && !appDataState.hasHistoricData) {
                  return _buildErrorView(appDataState.lastError!);
                }
                return _buildMainView(appDataState);
              },
            ),
          );
        },
      ),
    );
  }
}

class Item extends StatelessWidget {
  const Item({
    super.key,
    this.color = Colors.blue,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final EdgeInsets padding;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: child,
      ),
    );
  }
}