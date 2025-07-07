import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/config/constants.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/services/conversion_triggers.dart';
import 'package:runaway/core/widgets/blurry_app_bar.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/historic/presentation/widgets/shimmer_historic_card.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
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

  /// Suppression d'un parcours avec confirmation
  Future<void> _deleteRoute(SavedRoute route) async {
    try {
      final confirmed = await _showDeleteConfirmationDialog(route.name);
      if (confirmed != true) return;
      
      print('🗑️ Suppression via AppDataBloc: ${route.name}');
            
      // Afficher un message de confirmation
      if (mounted) {
        context.appDataBloc.add(SavedRouteDeletedFromAppData(route.id));
        
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

  // 🆕 Affiche le parcours sur la carte dans HomeScreen
  Future<void> _showRouteOnMap(SavedRoute route) async {
    try {
      print('🗺️ Affichage du parcours sur la carte: ${route.id}');
      
      // Charger le parcours dans RouteGenerationBloc
      context.routeGenerationBloc.add(SavedRouteLoaded(route.id));
      
      // Naviguer vers HomeScreen
      context.go('/home');
      
      // Feedback haptique
      HapticFeedback.lightImpact();
      
      print('✅ Navigation vers HomeScreen avec parcours: ${route.name}');

    } catch (e) {
      print('❌ Erreur affichage parcours: $e');
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: 'Erreur lors de l\'affichage du parcours',
            icon: HugeIcons.solidRoundedAlert02,
            color: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _renameRoute(SavedRoute route, String newName) async {
    try {
      print('✏️ Renommage via HistoricScreen: ${route.id} -> $newName');
      
      // Validation côté écran également
      if (newName.trim().isEmpty) {
        throw Exception('Le nom ne peut pas être vide');
      }
      
      // Déclencher l'événement de renommage via AppDataBloc
      context.appDataBloc.add(SavedRouteRenamedInAppData(
        routeId: route.id,
        newName: newName.trim(),
      ));
      
      // Feedback haptique de succès
      HapticFeedback.lightImpact();
      
      print('✅ Événement de renommage envoyé avec succès');

    } catch (e) {
      print('❌ Erreur renommage: $e');
      
      // Feedback haptique d'erreur
      HapticFeedback.mediumImpact();
      
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: 'Erreur: ${e.toString().replaceFirst('Exception: ', '')}',
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

  /// 🎭 Interface principale avec animations intégrées
  Widget _buildMainView(AppDataState appDataState, List<SavedRoute> routes) {
    // Mettre à jour les animations en fonction du nombre de routes
    if (routes.isNotEmpty) {
      _updateAnimationsForRoutes(routes.length);
    }

    return BlurryAppBar(
      title: context.l10n.historic, 
      children: [
        20.h,

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

          _buildAnimatedRoutesList(routes),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(bool activeBlur) {
    return AppBar(
      forceMaterialTransparency: true,
      title: FadeTransition(
        opacity: _fadeAnimation,
        child: Text(
          context.l10n.historic,
          style: context.bodySmall?.copyWith(color: context.adaptiveTextPrimary),
        ),
      ),
      flexibleSpace: activeBlur ? FlexibleSpaceBar(
        background: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(
            color: context.adaptiveBackground.withValues(alpha: 0.3),
          ),
        ),
      ) : null,
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
                          onDelete: () => _deleteRoute(route),
                          onSync: routes == routes.unsyncedRoutes ? _syncData : null,
                          onRename: (newName) => _renameRoute(route, newName), // 🆕 Callback de renommage
                          onShowOnMap: () => _showRouteOnMap(route), // 🆕 Callback ajouté
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
      appBar: _buildAppBar(false),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SquircleContainer(     
                isGlow: true,         
                color: context.adaptivePrimary,
                padding: EdgeInsets.all(30.0),
                child: Icon(
                  HugeIcons.strokeRoundedRoute01,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              30.h,
              Text(
                context.l10n.emptySavedRouteTitle,
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
                  context.l10n.emptySavedRouteMessage,
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
      padding: const EdgeInsets.symmetric(
        horizontal: 20.0,
      ),
      child: SquircleContainer(
        gradient: false,
        radius: 40.0,
        padding: EdgeInsets.all(20),
        color: context.adaptiveBorder.withValues(alpha: 0.05),
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
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is Unauthenticated) {
          showAuthModal(context);
        } else if (authState is AuthError) {
          // Afficher l'erreur de suppression de compte
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${authState.message}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (_, authState) {      
          // Si l'utilisateur est connecté, afficher le contenu
          if (authState is Authenticated) {
            return BlocBuilder<AppDataBloc, AppDataState>(
              builder: (context, appDataState) {
                return _buildMainContent(appDataState);
              },
            );
          }
      
          return _buildEmptyUnauthenticated();
        },
      ),
    );
  }

  Widget _buildEmptyUnauthenticated() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            context.l10n.historic,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextPrimary,
            ),
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
              child: BlurryPage(
                physics: const NeverScrollableScrollPhysics(),
                children: [ 
                  ...List.generate(3, (index) {
                    return Padding(
                      padding: const EdgeInsets.all(20.0),
                        child: SquircleContainer(
                          radius: 50.0,
                          gradient: false,
                          padding: EdgeInsets.all(15.0),
                          color: context.adaptiveBorder.withValues(alpha: 0.08),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                child: SquircleContainer(
                                  height: 250,
                                  width: double.infinity,
                                  radius: 30.0,
                                  color: context.adaptivePrimary,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
              
                              15.h,
              
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SquircleContainer(
                                    width: 200,
                                    radius: 15.0,
                                    height: 20,
                                    color: context.adaptivePrimary,
                                  ),
                                  8.h,
                                  SquircleContainer(
                                    width: 300,
                                    radius: 20.0,
                                    height: 30,
                                    color: context.adaptivePrimary,
                                  ),
                                ],
                              ),
              
                              25.h,
              
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: [
                                  _buildEmptyDetailChip(40, 90),
                                  _buildEmptyDetailChip(40, 80),
                                  _buildEmptyDetailChip(40, 80),
                                  _buildEmptyDetailChip(40, 80),
                                  _buildEmptyDetailChip(40, 80),
                                  _buildEmptyDetailChip(40, 100),
                                  _buildEmptyDetailChip(40, 100),
                                ],
                              ),
                          
                              25.h,
                          
                              // Boutons d'action
                              SquircleContainer(
                                height: 50,
                                radius: 30.0,
                                color: context.adaptivePrimary,
                                padding: EdgeInsets.symmetric(vertical: 15.0),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildEmptyDetailChip(double height, double width) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: context.adaptivePrimary,
        borderRadius: BorderRadius.circular(100),
      ),
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
    return BlurryAppBar(
      title: context.l10n.historic, 
      children: [
        ...List.generate(5, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: ShimmerHistoricCard(),
          );
        }),
      ],
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