import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/services/conversion_triggers.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/historic/presentation/widgets/shimmer_historic_card.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_event.dart';
import 'package:hugeicons/hugeicons.dart';
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
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    // 🔄 Charger les données si nécessaire
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appDataState = context.appDataBloc.state;
      if (!appDataState.hasHistoricData && !appDataState.isLoading) {
        context.appDataBloc.add(const HistoricDataRefreshRequested());
      }

      ConversionTriggers.onActivityViewed(context);
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
    print('🔄 Chargement manuel des parcours via AppDataBloc');
    context.appDataBloc.add(const HistoricDataRefreshRequested());
  }

  /// 🧭 Navigation vers le parcours sélectionné - Chargement dans HomeScreen
  void _navigateToRoute(SavedRoute route) async {
    print('🧭 === DÉBUT NAVIGATION VERS PARCOURS ===');
    print('📊 Route ID: ${route.id}');
    print('📊 Route Name: ${route.name}');
    
    try {
      // 🔑 ÉTAPE 1: S'assurer que RouteGenerationBloc a les données nécessaires
      final routeGenerationBloc = context.routeGenerationBloc;
      
      // Vérifier si RouteGenerationBloc a déjà les parcours sauvegardés
      if (routeGenerationBloc.state.savedRoutes.isEmpty) {
        print('🔄 Chargement des parcours dans RouteGenerationBloc...');
        routeGenerationBloc.add(const SavedRoutesRequested());
        
        // Attendre un peu que les données se chargent
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // 🔑 ÉTAPE 2: Charger le parcours spécifique
      routeGenerationBloc.add(SavedRouteLoaded(route.id));
      print('✅ Événement SavedRouteLoaded envoyé au bloc');
      
      // 🔑 ÉTAPE 3: Mettre à jour les statistiques d'utilisation via AppDataBloc
      context.appDataBloc.add(SavedRouteUsageUpdatedInAppData(route.id));
      
      // 🔑 ÉTAPE 4: Naviguer vers HomeScreen
      if (mounted) {
        context.go('/home');
        print('✅ Navigation vers /home lancée');
      }
      
      print('🧭 === FIN NAVIGATION VERS PARCOURS ===');
      
    } catch (e) {
      print('❌ Erreur lors de la navigation: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement du parcours'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Suppression d'un parcours avec confirmation
  Future<void> _deleteRoute(SavedRoute route) async {
    try {
      final confirmed = await _showDeleteConfirmationDialog(route.name);
      if (confirmed != true) return;
      
      print('🗑️ Suppression via AppDataBloc: ${route.name}');
      
      // 🔥 UTILISER AppDataBloc AU LIEU DE RouteGenerationBloc
      context.appDataBloc.add(SavedRouteDeletedFromAppData(route.id));
      
      // Afficher un message de confirmation
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: 'Parcours "${route.name}" supprimé',
            icon: HugeIcons.strokeRoundedCheckmarkCircle03,
            color: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      print('❌ Erreur suppression: $e');
      
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: 'Erreur lors de la suppression',
            icon: HugeIcons.solidRoundedAlert02,
            color: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog(String routeName) async {
    final result = await showModalBottomSheet<bool>(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      context: context,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (BuildContext context) {
        return ModalDialog(
          isDestructive: true,
          title: context.l10n.confirmRouteDeletionTitle,
          subtitle: context.l10n.confirmRouteDeletionMessage(routeName),
          validLabel: context.l10n.delete,
          onCancel: () => Navigator.of(context).pop(false),
          onValid: () {
            HapticFeedback.mediumImpact();
            
            Navigator.of(context).pop(true);
            print('🗑️ Suppression confirmée via AppDataBloc');
          },
        );
      },
    );
    
    return result ?? false;
  }

  /// Interface pour les utilisateurs non connectés
  Widget _buildUnauthenticatedView() {
    return AskRegistration();
  }

  /// 🎭 Interface principale avec animations intégrées
  Widget _buildMainView(AppDataState appDataState, List<SavedRoute> routes) {
    // Mettre à jour les animations en fonction du nombre de routes
    if (routes.isNotEmpty) {
      _updateAnimationsForRoutes(routes.length);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: BlurryPage(
        children: [
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
          _buildAnimatedRoutesList(routes),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      forceMaterialTransparency: true,
      title: FadeTransition(
        opacity: _fadeAnimation,
        child: Text(
          context.l10n.historic,
          style: context.bodySmall?.copyWith(color: context.adaptiveTextPrimary),
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
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20.0,
      ),
      child: Column(
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
      ),
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
          context.l10n.historic,
          style: context.bodySmall?.copyWith(color: context.adaptiveTextPrimary),
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
          IconButton(
            onPressed: _loadSavedRoutes,
            icon: Icon(HugeIcons.strokeRoundedRefresh, color: context.adaptiveTextPrimary),
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
              context.l10n.loadingError,
              style: context.bodyLarge?.copyWith(
                color: context.adaptiveTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            8.h,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                error,
                style: context.bodyMedium?.copyWith(color: context.adaptiveTextPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            24.h,
            ElevatedButton.icon(
              onPressed: _loadSavedRoutes,
              icon: Icon(HugeIcons.strokeRoundedRefresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  /// Interface vide (aucun parcours)
  Widget _buildEmptyView(AppDataState appDataState) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
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
                context.l10n.emptySavedRouteTitle,
                style: context.bodyLarge?.copyWith(
                  color: context.adaptiveTextPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              8.h,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  context.l10n.emptySavedRouteMessage,
                  style: context.bodyMedium?.copyWith(
                    color: context.adaptiveTextSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 17,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
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
    
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SquircleContainer(
        radius: 40.0,
        padding: EdgeInsets.all(20),
        color: context.adaptiveBorder.withValues(alpha: 0.08),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: HugeIcons.strokeRoundedRoute01,
              value: totalRoutes.toString(),
              label: context.l10n.route,
            ),
            _buildStatItem(
              icon: HugeIcons.strokeRoundedNavigator01,
              value: '${totalDistance.toStringAsFixed(1)}km',
              label: context.l10n.total,
            ),
            if (unsyncedCount > 0)
            _buildStatItem(
              icon: HugeIcons.strokeRoundedWifiOff01,
              value: unsyncedCount.toString(),
              label: context.l10n.unsynchronized,
              color: Colors.orange,
            )
          else
            _buildStatItem(
              icon: HugeIcons.strokeRoundedWifi01,
              value: syncedCount.toString(),
              label: context.l10n.synchronized,
              color: Colors.green,
            ),
      
          ],
        ),
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
        Icon(icon, color: color ?? context.adaptiveTextPrimary, size: 24),
        4.h,
        Text(
          value,
          style: context.bodyMedium?.copyWith(
            color: color ?? context.adaptiveTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: context.bodySmall?.copyWith(
            color: (color ?? context.adaptiveTextPrimary).withAlpha(180),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _refreshData() async {
    print('🔄 Refresh manuel optimisé');
    
    // Déclencher les updates en parallèle
    final context = this.context;
    context.routeGenerationBloc.add(const SavedRoutesRequested());
    context.appDataBloc.add(const AppDataRefreshRequested());
    
    // Petite pause pour l'animation
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _syncData() {
    print('☁️ Synchronisation des données demandée');
    context.routeGenerationBloc.add(SyncPendingRoutesRequested());
    
    // Ensuite rafraîchir les données
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        context.appDataBloc.add(const HistoricDataRefreshRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) {
          return _buildUnauthenticatedView();
        }

        // 🔥 UTILISER EXCLUSIVEMENT AppDataBloc
        return BlocBuilder<AppDataBloc, AppDataState>(
          builder: (context, appDataState) {
            return _buildMainContent(appDataState);
          },
        );
      },
    );
  }

  Widget _buildMainContent(AppDataState appDataState) {
    // États de chargement
    if (!appDataState.isDataLoaded && appDataState.isLoading) {
      return _buildLoadingView(appDataState);
    }

    // Erreur de chargement
    if (appDataState.lastError != null && !appDataState.hasHistoricData) {
      return _buildErrorView(appDataState.lastError!);
    }

    // Données disponibles
    if (appDataState.hasHistoricData) {
      final routes = appDataState.savedRoutes;
      
      if (routes.isEmpty) {
        return _buildEmptyView(appDataState);
      }

      return _buildMainView(appDataState, routes);
    }

    // État initial
    return _buildEmptyView(appDataState);
  }

  Widget _buildLoadingView(AppDataState appDataState) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: BlurryPage(
        contentPadding: EdgeInsets.only(top: kToolbarHeight + 60, left: 20, right: 20),
        children: [
          ...List.generate(5, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: ShimmerHistoricCard(),
            );
          })
        ],
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