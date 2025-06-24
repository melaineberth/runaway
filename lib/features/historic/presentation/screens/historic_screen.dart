import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/account/presentation/screens/account_screen.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/historic/presentation/widgets/shimmer_historic_card.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_event.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_state.dart';
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
  // 🎭 Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;
  
  final List<Animation<double>> _slideAnimations = [];
  final List<Animation<double>> _scaleAnimations = [];
  
  // ⏱️ Gestion du loading minimum
  DateTime? _loadingStartTime;
  bool _isCurrentlyLoading = false;
  bool _shouldShowLoading = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // Charger les parcours sauvegardés au démarrage
    _loadSavedRoutes();
  }

  /// 🎬 Initialise les contrôleurs d'animation
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  /// 🔄 Configure les animations décalées selon le nombre de routes
  void _setupStaggeredAnimations(int routeCount) {
    _slideAnimations.clear();
    _scaleAnimations.clear();
    
    for (int i = 0; i < routeCount; i++) {
      final startTime = i * 0.1; // Délai de 100ms entre chaque carte
      final endTime = startTime + 0.4; // Animation sur 400ms
      
      // Animation de slide depuis le bas
      final slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(startTime, endTime.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
        ),
      );
      
      // Animation de scale avec effet bounce
      final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(startTime, endTime.clamp(0.0, 1.0), curve: Curves.easeOutBack),
        ),
      );
      
      _slideAnimations.add(slideAnimation);
      _scaleAnimations.add(scaleAnimation);
    }
  }

  /// ⏱️ Gère le loading minimum et lance les animations
  Future<void> _handleLoadingTransition(bool isLoading, List<SavedRoute> routes) async {
    if (isLoading && !_isCurrentlyLoading) {
      // Début du chargement
      _loadingStartTime = DateTime.now();
      _isCurrentlyLoading = true;
      _shouldShowLoading = true;
      _resetAnimations();
      
    } else if (!isLoading && _isCurrentlyLoading) {
      // Fin du chargement - vérifier le délai minimum
      _isCurrentlyLoading = false;
      
      if (_loadingStartTime != null) {
        final elapsed = DateTime.now().difference(_loadingStartTime!);
        final remaining = widget.minimumLoadingDuration - elapsed;
        
        if (remaining.inMilliseconds > 0) {
          // Attendre le délai minimum
          print('⏱️ Attente délai minimum: ${remaining.inMilliseconds}ms');
          await Future.delayed(remaining);
        }
      }
      
      // Maintenant on peut afficher le contenu chargé
      if (mounted) {
        setState(() {
          _shouldShowLoading = false;
        });
        
        if (routes.isNotEmpty) {
          _setupStaggeredAnimations(routes.length);
          _startLoadedAnimations();
        }
      }
    }
  }

  /// 🚀 Lance les animations de chargement terminé
  void _startLoadedAnimations() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _fadeController.forward();
        _staggerController.forward();
      }
    });
  }

  /// 🔄 Reset les animations pour un nouveau chargement
  void _resetAnimations() {
    _fadeController.reset();
    _staggerController.reset();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  /// Charge les parcours sauvegardés
  Future<void> _loadSavedRoutes() async {
    context.read<RouteGenerationBloc>().add(SavedRoutesRequested());
  }

  /// 🧭 Navigation vers le parcours sélectionné - Chargement dans HomeScreen
  void _navigateToRoute(SavedRoute route) {
    // Charger le parcours dans le bloc pour l'afficher sur la carte
    context.read<RouteGenerationBloc>().add(SavedRouteLoaded(route.id));
    
    // Naviguer vers HomeScreen où le parcours sera affiché
    context.go('/home');
    
    // Feedback optionnel pour l'utilisateur
    showTopSnackBar(
      Overlay.of(context),
      TopSnackBar(
        title: 'Parcours "${route.name}" chargé sur la carte',
        icon: HugeIcons.solidRoundedTick04,
        color: Colors.lightGreen,
      ),
    );
  }

  /// Suppression d'un parcours avec confirmation
  void _deleteRoute(SavedRoute route) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Supprimer le parcours',
          style: context.titleMedium?.copyWith(color: Colors.white),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${route.name}" ?',
          style: context.bodyMedium?.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Annuler', 
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<RouteGenerationBloc>().add(SavedRouteDeleted(route.id));
              
              // Afficher un feedback
              showTopSnackBar(
                Overlay.of(context),
                TopSnackBar(
                  title: 'Parcours "${route.name}" supprimé',
                  icon: HugeIcons.solidRoundedDelete02,
                ),
              );
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
  Widget _buildMainView(List<SavedRoute> routes, bool isDataLoading) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        title: Text(
          "Historique",
          style: context.bodySmall?.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: (_shouldShowLoading || isDataLoading) ? null : () {
              context.read<RouteGenerationBloc>().add(SyncPendingRoutesRequested());
            },
            icon: Icon(
              HugeIcons.strokeRoundedCloudUpload, 
              color: (_shouldShowLoading || isDataLoading) ? Colors.white54 : Colors.white,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSavedRoutes,
        child: BlurryPage(
          padding: EdgeInsets.all(20.0),
          children: [
            _buildAnimatedRoutesList(routes),
          ],
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
      key: const ValueKey('loaded'),
      children: [
        // Stats card avec animation si plus d'un parcours
        if (routes.length > 1) ...[
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
          20.h,
        ],
        
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
                        bottom: index >= sortedRoutes.length - 1 ? 90.0 : 15.0,
                      ),
                      child: HistoricCard(
                        route: route,
                        onTap: () => _navigateToRoute(route),
                        onDelete: () => _deleteRoute(route),
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
  Widget _buildEmptyView() {
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
              HugeIcons.strokeRoundedRoute01,
              size: 64,
              color: Colors.white54,
            ),
            16.h,
            Text(
              'Aucun parcours sauvegardé',
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
                'Générez votre premier parcours depuis l\'accueil pour le voir apparaître ici',
                style: context.bodyMedium?.copyWith(color: Colors.white70),
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is Unauthenticated) {
          // L'utilisateur s'est déconnecté, rediriger vers l'accueil
          context.go('/home');
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (_, authState) {
          // Utilisateur non connecté
          if (authState is! Authenticated) {
            return _buildUnauthenticatedView();
          }

          // Utilisateur connecté : afficher les parcours
          return BlocBuilder<RouteGenerationBloc, RouteGenerationState>(
            builder: (context, routeState) {
              // Gestion du loading minimum
              _handleLoadingTransition(routeState.isAnalyzingZone, routeState.savedRoutes);

              // Erreur de chargement
              if (routeState.errorMessage != null) {
                return _buildErrorView(routeState.errorMessage!);
              }

              // Aucun parcours ET pas de chargement
              if (routeState.savedRoutes.isEmpty && !_shouldShowLoading) {
                return _buildEmptyView();
              }

              // Interface principale avec animations
              return _buildMainView(routeState.savedRoutes, routeState.isAnalyzingZone);
            },
          );
        },
      ),
    );
  }
}