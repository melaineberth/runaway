import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/utils/cache_performance_utils.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_event.dart';

/// Mixin pour optimiser la gestion du cache des routes dans les écrans
mixin OptimizedRouteCacheMixin<T extends StatefulWidget> on State<T> {
  // Cache local optimisé
  List<SavedRoute> _localRouteCache = [];
  bool _hasPendingSync = false;
  DateTime? _lastCacheUpdate;
  
  // Configuration
  static const Duration _cacheValidityDuration = Duration(minutes: 5);
  static const Duration _syncDebounceDelay = Duration(milliseconds: 300);

  /// Routes effectives à utiliser dans l'UI
  List<SavedRoute> get effectiveRoutes => _localRouteCache;
  
  /// Indique si une synchronisation est en attente
  bool get hasPendingSync => _hasPendingSync;
  
  /// Indique si le cache local est valide
  bool get isCacheValid {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheValidityDuration;
  }

  /// Initialise le cache avec les données existantes
  void initializeRouteCache() {
    final routeBloc = context.read<RouteGenerationBloc>();
    final appDataBloc = context.read<AppDataBloc>();
    
    // Prioriser les données de RouteGenerationBloc (plus fraîches)
    if (routeBloc.state.savedRoutes.isNotEmpty) {
      _updateLocalCache(routeBloc.state.savedRoutes, source: 'RouteGeneration');
    } else if (appDataBloc.state.hasHistoricData) {
      _updateLocalCache(appDataBloc.state.savedRoutes, source: 'AppData');
    }
  }

  /// Met à jour le cache local de manière optimisée
  void updateCacheFromRouteBloc(List<SavedRoute> newRoutes) {
    if (_shouldUpdateCache(newRoutes)) {
      final oldCount = _localRouteCache.length;
      _updateLocalCache(newRoutes, source: 'RouteGeneration');
      
      // Déclencher la sync en arrière-plan si nécessaire
      if (oldCount != newRoutes.length) {
        _triggerBackgroundSync(oldCount, newRoutes.length);
      }
    }
  }

  /// Met à jour le cache depuis AppDataBloc
  void updateCacheFromAppData(List<SavedRoute> routes) {
    // Seulement si pas de données plus fraîches dans le cache local
    if (_localRouteCache.isEmpty || !isCacheValid) {
      _updateLocalCache(routes, source: 'AppData');
    }
    
    // Marquer la sync comme terminée
    if (_hasPendingSync) {
      setState(() {
        _hasPendingSync = false;
      });
    }
  }

  /// Ajoute une route de manière optimiste
  void addRouteOptimistically(SavedRoute route) {
    setState(() {
      _localRouteCache = [..._localRouteCache, route];
      _lastCacheUpdate = DateTime.now();
      _hasPendingSync = true;
    });
    
    // Déclencher la sync des statistiques
    CachePerformanceUtils.debounce(
      'route_added_sync',
      () => _syncActivityData(),
      delay: _syncDebounceDelay,
    );
  }

  /// Supprime une route de manière optimiste
  void removeRouteOptimistically(String routeId) {
    setState(() {
      _localRouteCache = _localRouteCache.where((r) => r.id != routeId).toList();
      _lastCacheUpdate = DateTime.now();
      _hasPendingSync = true;
    });
    
    // Déclencher une sync complète
    CachePerformanceUtils.debounce(
      'route_deleted_sync',
      () => _syncAllData(),
      delay: _syncDebounceDelay,
    );
  }

  /// Force un refresh complet du cache
  void refreshCache() {
    print('🔄 Refresh forcé du cache des routes');
    
    // Invalider le cache local
    _lastCacheUpdate = null;
    
    // Déclencher le rechargement des deux sources
    context.read<RouteGenerationBloc>().add(const SavedRoutesRequested());
    context.read<AppDataBloc>().add(const AppDataRefreshRequested());
  }

  /// Méthodes privées pour la gestion interne

  bool _shouldUpdateCache(List<SavedRoute> newRoutes) {
    // Mise à jour si différence de taille ou contenu
    if (_localRouteCache.length != newRoutes.length) return true;
    
    // Vérification rapide des IDs
    for (int i = 0; i < _localRouteCache.length; i++) {
      if (_localRouteCache[i].id != newRoutes[i].id) return true;
    }
    
    return false;
  }

  void _updateLocalCache(List<SavedRoute> routes, {required String source}) {
    setState(() {
      _localRouteCache = List.from(routes);
      _lastCacheUpdate = DateTime.now();
    });
    
    print('✅ Cache local mis à jour depuis $source (${routes.length} routes)');
  }

  void _triggerBackgroundSync(int oldCount, int newCount) {
    setState(() {
      _hasPendingSync = true;
    });
    
    CachePerformanceUtils.debounce(
      'background_sync',
      () {
        if (newCount > oldCount) {
          _syncActivityData();
        } else {
          _syncAllData();
        }
      },
      delay: _syncDebounceDelay,
    );
  }

  void _syncActivityData() {
    if (!mounted) return;
    context.read<AppDataBloc>().add(const ActivityDataRefreshRequested());
    print('📊 Sync statistiques activité déclenchée');
  }

  void _syncAllData() {
    if (!mounted) return;
    context.read<AppDataBloc>().add(const AppDataRefreshRequested());
    print('🔄 Sync complète déclenchée');
  }

  @override
  void dispose() {
    CachePerformanceUtils.cleanup();
    super.dispose();
  }
}
