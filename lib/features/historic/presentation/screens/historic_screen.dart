import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/helper/services/conversion_triggers.dart';
import 'package:runaway/core/widgets/blurry_app_bar.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
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
  bool isEditMode = false; // Changé à false par défaut
  Set<String> selectedRouteIds = {}; // Routes sélectionnées

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;

  // Animation Controller pour le bouton d'édition (effet d'aspiration Apple)
  late AnimationController _editButtonController;
  late Animation<double> _editButtonAnimation;
  
  final List<Animation<double>> _slideAnimations = [];
  final List<Animation<double>> _scaleAnimations = [];

  // Variables pour LazyLoading
  static const int _itemsPerPage = 8;
  static const int _initialItemCount = 5;
  List<SavedRoute> _allRoutes = [];
  List<SavedRoute> _displayedRoutes = [];
  bool _isLoadingMore = false;
  bool _hasMoreData = true;  
  final bool _shouldShowLoading = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    // Charger les données si nécessaire
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appDataState = context.appDataBloc.state;
      if (!appDataState.hasHistoricData && !appDataState.isLoading) {
        context.appDataBloc.add(const HistoricDataRefreshRequested());
      }

      ConversionTriggers.onActivityViewed(context);
    });
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

    // Controller pour l'animation du bouton d'édition
    _editButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Animation d'aspiration pour le bouton d'édition
    _editButtonAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(
      parent: _editButtonController,
      curve: Curves.easeInOut,
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
    _editButtonController.dispose();
    super.dispose();
  }

  // Basculer le mode édition
  void _toggleEditMode() async {
    debugPrint("Mode édition : $isEditMode");

    // 🎭 Déclencher l'animation d'aspiration
    await _editButtonController.forward();
    await _editButtonController.reverse();

    setState(() {
      isEditMode = !isEditMode;
      if (!isEditMode) {
        selectedRouteIds.clear(); // Vider la sélection en sortant du mode édition
      }
    });

    HapticFeedback.lightImpact();
    debugPrint("Mode édition : $isEditMode");
  }

  // Sélectionner/désélectionner un parcours
  void _toggleRouteSelection(String routeId) {
    setState(() {
      if (selectedRouteIds.contains(routeId)) {
        selectedRouteIds.remove(routeId);
      } else {
        selectedRouteIds.add(routeId);
      }
    });
    HapticFeedback.selectionClick();
  }

  // Supprimer les parcours sélectionnés
  Future<void> _deleteSelectedRoutes() async {
    if (selectedRouteIds.isEmpty) return;
    
    try {
      final confirmed = await _showDeleteConfirmationDialog(context.l10n.confirmMultipleRouteDeletionMessage);
      if (confirmed != true) return;

      LogConfig.logSuccess('🗑️ Suppression multiple via AppDataBloc: ${selectedRouteIds.length} parcours');
      
      // Supprimer chaque parcours sélectionné
      for (final routeId in selectedRouteIds) {
        if (mounted) {
          context.appDataBloc.add(SavedRouteDeletedFromAppData(routeId));
        }
      }
      
      // Vider la sélection et quitter le mode édition
      setState(() {
        selectedRouteIds.clear();
        isEditMode = false;
      });

      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: context.l10n.successRouteDeleted,
          ),
        );
      }
      
    } catch (e) {
      LogConfig.logError('❌ Erreur suppression multiple: $e');
      
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            isError: true,
            title: context.l10n.errorRouteDeleted,
          ),
        );
      }
    }
  }

  /// Charge les parcours sauvegardés
  void _loadSavedRoutes() {
    LogConfig.logInfo('🔄 Chargement manuel des parcours via AppDataBloc');
    context.appDataBloc.add(const HistoricDataRefreshRequested());
  }

  // Méthode pour charger plus d'éléments
  void _loadMoreRoutes() {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    // Simuler un délai de chargement léger pour l'UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final currentCount = _displayedRoutes.length;
      final remainingRoutes = _allRoutes.length - currentCount;
      
      if (remainingRoutes <= 0) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
        return;
      }

      final nextBatchSize = _itemsPerPage.clamp(0, remainingRoutes);
      final nextBatch = _allRoutes
          .skip(currentCount)
          .take(nextBatchSize)
          .toList();

      setState(() {
        _displayedRoutes.addAll(nextBatch);
        _hasMoreData = _displayedRoutes.length < _allRoutes.length;
        _isLoadingMore = false;
      });

      // Mettre à jour les animations pour les nouveaux éléments
      _updateAnimationsForRoutes(_displayedRoutes.length);
    });
  }

  /// Suppression d'un parcours avec confirmation
  Future<void> _deleteRoute(SavedRoute route) async {
    final routeName = '"${route.name}"';
    try {
      final confirmed = await _showDeleteConfirmationDialog(context.l10n.confirmRouteDeletionMessage(routeName));
      if (confirmed != true) return;

      LogConfig.logSuccess('🗑️ Suppression via AppDataBloc: ${route.name}');
                  
      // Afficher un message de confirmation
      if (mounted) {
        context.appDataBloc.add(SavedRouteDeletedFromAppData(route.id));
        
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: context.l10n.successRouteDeleted,
          ),
        );
      }
      
    } catch (e) {
      LogConfig.logError('❌ Erreur suppression: $e');
      
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            isError: true,
            title: context.l10n.errorRouteDeleted,
          ),
        );
      }
    }
  }

  // Affiche le parcours sur la carte dans HomeScreen
  Future<void> _showRouteOnMap(SavedRoute route) async {
    try {
      print('🗺️ Affichage du parcours sur la carte: ${route.id}');
      
      // Charger le parcours dans RouteGenerationBloc
      context.routeGenerationBloc.add(SavedRouteLoaded(route.id));
      
      // Naviguer vers HomeScreen
      context.pop();
      
      // Feedback haptique
      HapticFeedback.lightImpact();
      
      LogConfig.logInfo('Navigation vers HomeScreen avec parcours: ${route.name}');

    } catch (e) {
      LogConfig.logError('❌ Erreur affichage parcours: $e');
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            isError: true,
            title: context.l10n.displayRouteError,
          ),
        );
      }
    }
  }

  Future<void> _renameRoute(SavedRoute route, String newName) async {
    try {
      LogConfig.logInfo('✏️ Renommage via HistoricScreen: ${route.id} -> $newName');
      
      // Validation côté écran également
      if (newName.trim().isEmpty) {
        throw Exception(context.l10n.routeNameUpdateException);
      }
      
      // Déclencher l'événement de renommage via AppDataBloc
      context.appDataBloc.add(SavedRouteRenamedInAppData(
        routeId: route.id,
        newName: newName.trim(),
      ));
      
      // Feedback haptique de succès
      HapticFeedback.lightImpact();
      
      LogConfig.logInfo('Événement de renommage envoyé avec succès');

      if (mounted) {
      showTopSnackBar(
        Overlay.of(context),
        TopSnackBar(
          title: context.l10n.routeNameUpdateDone,
        ),
      );
    }

    } catch (e) {
      LogConfig.logError('❌ Erreur renommage: $e');
      
      // Feedback haptique d'erreur
      HapticFeedback.mediumImpact();

      print(e.toString().replaceFirst('Exception: ', ''));      
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
          subtitle: routeName,
          validLabel: context.l10n.delete,
          onCancel: () => Navigator.of(context).pop(false),
          onValid: () {
            HapticFeedback.mediumImpact();
            
            Navigator.of(context).pop(true);
          },
        );
      },
    );
    
    return result ?? false;
  }

  // Barre d'actions pour le mode édition
  Widget _buildEditModeActions(List<SavedRoute> routes) {
    if (!isEditMode || selectedRouteIds.isEmpty) return SizedBox.shrink();

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: SquircleContainer(
            radius: 50.0,
            isGlow: true,
            gradient: false,
            color: context.adaptivePrimary,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 8.0,
                    ),
                    child: Text(
                      '${selectedRouteIds.length} parcours sélectionné${selectedRouteIds.length > 1 ? 's' : ''}',
                      style: context.bodySmall?.copyWith(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SquircleContainer(
                    radius: 30.0,
                    isGlow: true,
                    color: Colors.white,
                    onTap: _deleteSelectedRoutes,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Icon(
                      HugeIcons.solidRoundedDelete02,
                      color: context.adaptivePrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Interface principale avec animations intégrées
  Widget _buildMainView(AppDataState appDataState, List<SavedRoute> routes) {    
    // Initialiser les routes pour LazyLoading si nécessaire
    if (_allRoutes != routes) {
      _allRoutes = routes;
      _displayedRoutes = routes.take(_initialItemCount).toList();
      _hasMoreData = routes.length > _initialItemCount;
    }

    // Déterminer si on doit utiliser LazyLoading (seuil : 12 routes)
    final shouldUseLazyLoading = routes.length > 12;
    final routesToDisplay = shouldUseLazyLoading ? _displayedRoutes : routes;

    // Mettre à jour les animations en fonction du nombre de routes affichées
    if (routesToDisplay.isNotEmpty) {
      _updateAnimationsForRoutes(routesToDisplay.length);
    }

    return Stack(
      children: [
        BlurryPage(
          physics: const BouncingScrollPhysics(),
          shrinkWrap: false,
          enableLazyLoading: shouldUseLazyLoading,
          initialItemCount: _initialItemCount,
          itemsPerPage: _itemsPerPage,
          onLoadMore: _loadMoreRoutes,
          isLoading: _isLoadingMore,
          hasMoreData: _hasMoreData,
          children: [
            30.h,
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
        
            30.h,
        
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
              ),
              child: Text(
                context.l10n.savedRoute,
                style: context.bodyMedium?.copyWith(
                  fontSize: 18,
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            15.h,
            
            _buildAnimatedRoutesList(routesToDisplay),
          ],
        ),

        // Barre d'actions pour le mode édition
        Positioned(
          left: 20.0,
          right: 20.0,
          bottom: Platform.isAndroid ? MediaQuery.of(context).padding.bottom + 20.0 : 50.0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 1.0), // Depuis le bas
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                  reverseCurve: Curves.easeInBack,
                )),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: (isEditMode && selectedRouteIds.isNotEmpty)
              ? _buildEditModeActions(routes)
              : SizedBox.shrink(key: ValueKey('hidden')),
          ),
        ),
      ],
    );
  }

  /// Liste animée avec transition shimmer ↔ chargé
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

  /// Liste shimmer pendant le chargement
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

  /// Liste chargée avec animations staggered
  Widget _buildLoadedList(List<SavedRoute> routes) {
    final sortedRoutes = routes.sortByCreationDate();
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
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
                        bottom: index >= sortedRoutes.length - 1 ? 0.0 : 20.0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                        ),
                        child: Dismissible(
                          direction: isEditMode ? DismissDirection.none : DismissDirection.endToStart,
                          key: ValueKey("eraseRoute_${route.id}_${DateTime.now().millisecondsSinceEpoch}"),
                          confirmDismiss: (DismissDirection direction) async {
                            final routeName = '"${route.name}"';
                            
                            // Afficher la modal de confirmation et attendre la réponse
                            final confirmed = await _showDeleteConfirmationDialog(
                              context.l10n.confirmRouteDeletionMessage(routeName)
                            );
                            
                            // Retourner true seulement si confirmé
                            return confirmed;
                          },
                          // 🆕 onDismissed se déclenche seulement si confirmDismiss retourne true
                          onDismissed: (DismissDirection direction) {
                            // Appeler directement la logique de suppression SANS la modal
                            // car la confirmation a déjà été faite dans confirmDismiss
                            _deleteRoute(route);
                          },
                          background: Container(
                            color: Colors.transparent,
                            alignment: Alignment.centerRight,
                            child: IconBtn(
                              icon: HugeIcons.solidRoundedDelete02,
                              backgroundColor: Colors.red,
                              iconColor: Colors.white,
                            ),
                          ),
                          child: HistoricCard(
                            route: route,
                            isEdit: isEditMode,
                            isSelected: selectedRouteIds.contains(route.id),
                            onDelete: () => _deleteRoute(route),
                            onSync: !route.isSynced ? _syncData : null,
                            onRename: (newName) => _renameRoute(route, newName),
                            onShowOnMap: () => _showRouteOnMap(route),
                            onToggleSelection: () => _toggleRouteSelection(route.id),
                          ),
                        ),
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
    return Center(
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
    );
  }

  /// Interface vide (aucun parcours)
  Widget _buildEmptyView(AppDataState appDataState) {
    return FadeTransition(
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
                HugeIcons.solidRoundedRoute01,
                size: 50,
                color: Colors.white,
              ),
            ),
            30.h,
            Text(
              context.l10n.emptySavedRouteTitle,
              style: context.bodyLarge?.copyWith(
                color: context.adaptiveTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            8.h,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                context.l10n.emptySavedRouteMessage,
                style: GoogleFonts.inter(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
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
      (sum, route) => sum + (route.parameters.distanceKm),
    );
    final totalRoutes = routes.length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.userSummary,
            style: context.bodyMedium?.copyWith(
              fontSize: 18,
              color: context.adaptiveTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ), 

          15.h,

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: HugeIcons.strokeRoundedRoute01,
                value: totalRoutes.toString(),
                label: context.l10n.route,
                color: Colors.blue,
              ),
              8.w,
              _buildStatItem(
                icon: HugeIcons.strokeRoundedNavigator01,
                value: '${totalDistance.toStringAsFixed(0)}km',
                label: context.l10n.total,
                color: Colors.green,
              ),
            ],
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
    return Expanded(
      child: SquircleContainer(
        radius: 50,
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

  Future<void> _syncData() async {
    try {
      LogConfig.logInfo('🔄 Démarrage de la synchronisation manuelle');
      
      // Déclencher la synchronisation via AppDataBloc
      context.appDataBloc.add(const ForceDataSyncRequested());
      
      // Feedback visuel pour l'utilisateur
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: 'Synchronisation en cours...',
          ),
        );
      }
      
      // Feedback haptique
      HapticFeedback.lightImpact();
      
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de la synchronisation: $e');
      
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            isError: true,
            title: context.l10n.syncError,
          ),
        );
      }
    }
  }

  // Bouton d'édition avec effet d'aspiration
  Widget _buildEditButton(bool enableRoute) {
    return AnimatedBuilder(
      animation: _editButtonAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _editButtonAnimation.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isEditMode ? context.adaptivePrimary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconBtn(
              padding: 8.0,
              onPressed: enableRoute ? _toggleEditMode : null,
              backgroundColor: Colors.transparent,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  isEditMode 
                    ? HugeIcons.solidRoundedTick02
                    : HugeIcons.strokeRoundedCheckmarkCircle02,
                  key: ValueKey(isEditMode),
                  color: enableRoute 
                    ? (isEditMode ? Colors.white : context.adaptiveWhite) 
                    : context.adaptiveDisabled.withValues(alpha: 0.15),
                  size: 28,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(40),
        topRight: Radius.circular(40),
      ),
      child: Container(
        color: context.adaptiveBackground,
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (_, authState) {          
            // Si l'utilisateur est connecté, afficher le contenu
            if (authState is Authenticated) {
              return BlocBuilder<AppDataBloc, AppDataState>(
                builder: (context, appDataState) {
                  final enableRoute = appDataState.savedRoutes.isNotEmpty;
                  
                  return Column(
                    children: [
                      Padding(
                        padding: EdgeInsetsGeometry.only(
                          top: kToolbarHeight * 1.2,
                          left: 20.0,
                          right: 20.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconBtn(
                              padding: 8.0,
                              onPressed: () => context.pop(),
                              backgroundColor: Colors.transparent,
                              child: Icon(
                                HugeIcons.strokeStandardArrowDown01,
                                color: context.adaptiveWhite,
                                size: 28,
                              ),
                            ),
                            Text(
                              context.l10n.historic,
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            _buildEditButton(enableRoute),
                          ],
                        ),
                      ),
                      Expanded(child: _buildMainContent(appDataState)),
                    ],
                  );
                },
              );
            }
        
            return _buildEmptyUnauthenticated();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyUnauthenticated() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
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

    // Erreur de chargement SEULEMENT si les données d'historique n'ont jamais été chargées
    if (appDataState.lastError != null && 
        !appDataState.isHistoricDataLoaded && 
        !appDataState.isLoading) {
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