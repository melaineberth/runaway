import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/account/presentation/screens/account_screen.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/navigation/presentation/screens/navigation_screen.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_event.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_state.dart';
import 'package:hugeicons/hugeicons.dart';

import '../widgets/historic_card.dart';

class HistoricScreen extends StatefulWidget {  
  const HistoricScreen({super.key});

  @override
  State<HistoricScreen> createState() => _HistoricScreenState();
}

class _HistoricScreenState extends State<HistoricScreen> {
  
  @override
  void initState() {
    super.initState();
    // Charger les parcours sauvegardés au démarrage
    _loadSavedRoutes();
  }

  /// Charge les parcours sauvegardés
  Future<void> _loadSavedRoutes() async {
    context.read<RouteGenerationBloc>().add(SavedRoutesRequested());
  }

  /// Navigation vers le parcours sélectionné
  void _navigateToRoute(SavedRoute route) {
    // Charger le parcours dans le bloc pour l'afficher sur la carte
    context.read<RouteGenerationBloc>().add(SavedRouteLoaded(route.id));
    
    // Naviguer vers la navigation
    final args = NavigationArgs(
      route: route.coordinates,
      routeDistanceKm: route.actualDistance ?? route.parameters.distanceKm,
      estimatedDurationMinutes: route.actualDuration ?? route.parameters.estimatedDuration.inMinutes,
    );
    
    context.push('/navigation', extra: args);
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Parcours "${route.name}" supprimé'),
                  backgroundColor: Colors.red,
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

  /// Interface de chargement
  Widget _buildLoadingView() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        title: Text(
          "Historique",
          style: context.bodySmall?.copyWith(color: Colors.white),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            16.h,
            Text(
              'Chargement des parcours...',
              style: context.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
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

  /// Interface avec la liste des parcours
  Widget _buildRoutesListView(List<SavedRoute> routes) {
    // Trier les parcours par date de création (plus récents en premier)
    final sortedRoutes = routes.sortByCreationDate();
    
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
          // Bouton de synchronisation
          IconButton(
            onPressed: () {
              context.read<RouteGenerationBloc>().add(SyncPendingRoutesRequested());
            },
            icon: Icon(HugeIcons.strokeRoundedCloudUpload, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSavedRoutes,
        child: BlurryPage(
          padding: EdgeInsets.all(20.0),
          children: [          
            // Statistiques rapides
            if (routes.length > 1) ...[
              _buildStatsCard(routes),
              20.h,
            ],
            
            // Liste des parcours
            ...sortedRoutes.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final route = entry.value;
                
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index >= sortedRoutes.length - 1 ? 90.0 : 15.0,
                  ),
                  child: HistoricCard(
                    route: route,
                    onTap: () => _navigateToRoute(route),
                    onDelete: () => _deleteRoute(route),
                  ),
                );
              },
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
    
    return SquircleContainer(
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
              // Chargement en cours
              if (routeState.isAnalyzingZone) {
                return _buildLoadingView();
              }

              // Erreur de chargement
              if (routeState.errorMessage != null) {
                return _buildErrorView(routeState.errorMessage!);
              }

              // Aucun parcours sauvegardé
              if (routeState.savedRoutes.isEmpty) {
                return _buildEmptyView();
              }

              // Afficher la liste des parcours
              return _buildRoutesListView(routeState.savedRoutes);
            },
          );
        },
      ),
    );
  }
}