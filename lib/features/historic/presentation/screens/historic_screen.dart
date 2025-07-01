import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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

  // ✅ Cache local optimisé pour l'UI
  List<SavedRoute> _uiRoutes = [];
  bool _hasPendingSync = false;
  DateTime? _lastUIUpdate;
  
  // 🛡️ Protection contre les doublons de sync
  bool _isSyncInProgress = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    // 🔄 Charger les données si nécessaire
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appDataState = context.read<AppDataBloc>().state;
      if (!appDataState.hasHistoricData && !appDataState.isLoading) {
        context.read<AppDataBloc>().add(const HistoricDataRefreshRequested());
      }
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

  /// ✅ Met à jour le cache UI de manière thread-safe
  void _updateUICache(List<SavedRoute> routes, {required String source}) {
    if (!mounted) return;
    
    _uiRoutes = List.from(routes);
    _lastUIUpdate = DateTime.now();
    
    print('✅ Cache UI mis à jour depuis $source (${routes.length} routes)');
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
    context.read<AppDataBloc>().add(const HistoricDataRefreshRequested());
  }

  /// 🧭 Navigation vers le parcours sélectionné - Chargement dans HomeScreen
  void _navigateToRoute(SavedRoute route) {
    print('🧭 === DÉBUT NAVIGATION VERS PARCOURS ===');
    print('📊 Route ID: ${route.id}');
    print('📊 Route Name: ${route.name}');
    
    // 🔑 ÉTAPE 1: Charger le parcours dans RouteGenerationBloc pour l'afficher sur la carte
    context.read<RouteGenerationBloc>().add(SavedRouteLoaded(route.id));
    print('✅ Événement SavedRouteLoaded envoyé au bloc');
    
    // 🔑 ÉTAPE 2: Mettre à jour les statistiques d'utilisation via AppDataBloc
    context.read<AppDataBloc>().add(SavedRouteUsageUpdatedInAppData(route.id));
    
    // 🔑 ÉTAPE 3: Naviguer vers HomeScreen
    context.go('/home');
    print('✅ Navigation vers /home lancée');
    print('🧭 === FIN NAVIGATION VERS PARCOURS ===');
  }

   /// ⏰ Vérifie si le cache UI est encore frais (5 minutes)
  bool _isUICacheFresh() {
    if (_lastUIUpdate == null) return false;
    return DateTime.now().difference(_lastUIUpdate!) < const Duration(minutes: 5);
  }

  /// Suppression d'un parcours avec confirmation
  Future<void> _deleteRoute(SavedRoute route) async {
    try {
      final confirmed = await _showDeleteConfirmationDialog(route.name);
      if (confirmed != true) return;
      
      print('🗑️ Suppression via AppDataBloc: ${route.name}');
      
      // 🔥 UTILISER AppDataBloc AU LIEU DE RouteGenerationBloc
      context.read<AppDataBloc>().add(SavedRouteDeletedFromAppData(route.id));
      
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
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.confirmRouteDeletionTitle),
          content: Text(context.l10n.confirmRouteDeletionMessage(routeName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                print('🗑️ Suppression confirmée via AppDataBloc');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(context.l10n.delete),
            ),
          ],
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
    final isLoading = appDataState.isLoading;
    final hasBackground = _hasPendingSync && !isLoading;

    // Mettre à jour les animations en fonction du nombre de routes
    if (routes.isNotEmpty) {
      _updateAnimationsForRoutes(routes.length);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isLoading, pendingSync: hasBackground),
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

  PreferredSizeWidget _buildAppBar(bool isLoading, {bool pendingSync = false}) {
    return AppBar(
      centerTitle: true,
      forceMaterialTransparency: true,
      backgroundColor: Colors.transparent,
      title: FadeTransition(
        opacity: _fadeAnimation,
        child: Text(
          context.l10n.historic,
          style: context.bodySmall?.copyWith(color: context.adaptiveTextPrimary),
        ),
      ),
      actions: [
        if (pendingSync) ...[
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ],
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
          context.l10n.historic,
          style: context.bodySmall?.copyWith(color: context.adaptiveTextPrimary),
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
    final isLoading = appDataState.isLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(
        isLoading,
      ),
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
    
    return SquircleContainer(
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
    
    // Réinitialiser les verrous
    _isSyncInProgress = false;
    
    setState(() {
      _hasPendingSync = true;
    });
    
    // Déclencher les updates en parallèle
    final context = this.context;
    context.read<RouteGenerationBloc>().add(const SavedRoutesRequested());
    context.read<AppDataBloc>().add(const AppDataRefreshRequested());
    
    // Petite pause pour l'animation
    await Future.delayed(const Duration(milliseconds: 800));
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

  // 🚀 LOGIQUE UI-FIRST : Mise à jour immédiate depuis RouteGenerationBloc
  void _onRouteStateChanged(BuildContext context, RouteGenerationState routeState) {
    final newRoutes = routeState.savedRoutes;
    final oldCount = _uiRoutes.length;
    final newCount = newRoutes.length;
    
    // ✅ ÉTAPE 1: Mise à jour IMMÉDIATE de l'UI
    if (_shouldUpdateUI(newRoutes)) {
      _updateUICache(newRoutes, source: 'RouteGeneration');
      
      // 🎭 Mettre à jour les animations
      if (newRoutes.isNotEmpty) {
        _updateAnimationsForRoutes(newRoutes.length);
      }
      
      print('🎯 UI mise à jour immédiatement: $oldCount -> $newCount routes');
    }
    
    // ✅ ÉTAPE 2: Synchronisation EN ARRIÈRE-PLAN (protégée contre les doublons)
    if (oldCount != newCount && !_isSyncInProgress) {
      _triggerBackgroundSync(context, oldCount, newCount);
    }
  }

  // 🔄 Synchronisation intelligente en arrière-plan
  void _triggerBackgroundSync(BuildContext context, int oldCount, int newCount) {
    _isSyncInProgress = true;
    
    setState(() {
      _hasPendingSync = true;
    });
    
    // Utiliser Future.delayed pour ne pas bloquer l'UI
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      
      print('🔄 Sync arrière-plan protégée ($oldCount -> $newCount)');
      
      if (newCount > oldCount) {
        // Route ajoutée - sync statistiques seulement
        context.read<AppDataBloc>().add(const ActivityDataRefreshRequested());
        print('➕ Sync statistiques (route ajoutée)');
      } else if (newCount < oldCount) {
        // Route supprimée - sync historique seulement (pas complète)
        context.read<AppDataBloc>().add(const HistoricDataRefreshRequested());
        print('➖ Sync historique (route supprimée)');
      }
      
      // Libérer le verrou après un délai
      Future.delayed(const Duration(seconds: 2), () {
        _isSyncInProgress = false;
      });
    });
  }

  // 📊 Gestion des changements d'AppDataBloc
  void _onAppDataChanged(AppDataState appDataState) {
    // Marquer la sync comme terminée
    if (_hasPendingSync && !appDataState.isLoading) {
      setState(() {
        _hasPendingSync = false;
      });
      print('✅ Synchronisation arrière-plan terminée');
    }
  }

  // 🎯 Détermine les meilleures données à utiliser pour l'UI
  List<SavedRoute> _getEffectiveRoutes(AppDataState appDataState) {
    // Priorité : cache UI frais > données AppData > vide
    if (_uiRoutes.isNotEmpty && _isUICacheFresh()) {
      return _uiRoutes;
    }
    
    if (appDataState.hasHistoricData) {
      // Initialiser avec les données d'AppData si cache UI vide
      if (_uiRoutes.isEmpty) {
        _updateUICache(appDataState.savedRoutes, source: 'AppData-Init');
      }
      return _uiRoutes.isNotEmpty ? _uiRoutes : appDataState.savedRoutes;
    }
    
    return _uiRoutes;
  }

  // 🔍 Vérifie si le contenu des routes a changé (pas seulement la longueur)
  bool _shouldUpdateUI(List<SavedRoute> newRoutes) {
    if (_uiRoutes.length != newRoutes.length) return true;
    
    // Vérification rapide des IDs
    for (int i = 0; i < _uiRoutes.length; i++) {
      if (i >= newRoutes.length || _uiRoutes[i].id != newRoutes[i].id) {
        return true;
      }
    }
    
    return false;
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
    return _buildLoadingView(appDataState);
  }

  Widget _buildLoadingView(AppDataState appDataState) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(true),
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