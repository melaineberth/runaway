import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_state.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'dart:async';

/// Service pour synchroniser automatiquement les données entre RouteGenerationBloc et AppDataBloc
class RouteDataSyncService {
  static RouteDataSyncService? _instance;
  static RouteDataSyncService get instance => _instance ??= RouteDataSyncService._();
  RouteDataSyncService._();

  StreamSubscription<RouteGenerationState>? _routeSubscription;
  AppDataBloc? _appDataBloc;
  List<SavedRoute> _lastKnownRoutes = [];
  bool _isInitialized = false;
  int _syncCount = 0;

  static const Duration _debounceDelay = Duration(milliseconds: 300);
  Timer? _debounceTimer;

  /// Initialise le service avec les BLoCs nécessaires
  void initialize({
    required RouteGenerationBloc routeGenerationBloc,
    required AppDataBloc appDataBloc,
  }) {
    if (_isInitialized) {
      print('⚠️ RouteDataSyncService déjà initialisé');
      return;
    }

    _appDataBloc = appDataBloc;
    _lastKnownRoutes = List.from(routeGenerationBloc.state.savedRoutes);
    
    print('🔄 Initialisation RouteDataSyncService...');
    print('📊 Routes initiales: ${_lastKnownRoutes.length}');

    // Écouter les changements dans RouteGenerationBloc
    _routeSubscription = routeGenerationBloc.stream.listen(
      _onRouteStateChanged,
      onError: (error) {
        print('❌ Erreur dans RouteDataSyncService: $error');
      },
    );

    _isInitialized = true;
    print('✅ RouteDataSyncService initialisé et en écoute');
  }

  /// Traite les changements d'état du RouteGenerationBloc
  void _onRouteStateChanged(RouteGenerationState routeState) {
    final currentRoutes = routeState.savedRoutes;
    
    // Annuler le timer précédent pour éviter les appels multiples
    _debounceTimer?.cancel();
    
    // Debouncing pour éviter les sync trop fréquentes
    _debounceTimer = Timer(_debounceDelay, () {
      _processRouteChange(currentRoutes);
    });
  }

  void _processRouteChange(List<SavedRoute> currentRoutes) {
    if (!_hasRoutesChanged(currentRoutes)) return;
    
    final changeAnalysis = _analyzeChanges(currentRoutes);
    _logChangeDetails(changeAnalysis);
    
    // 🎯 Synchronisation intelligente selon le type de changement
    _triggerIntelligentSync(changeAnalysis);
    
    _lastKnownRoutes = List.from(currentRoutes);
  }

  /// 🧠 Synchronisation intelligente selon le contexte
  void _triggerIntelligentSync(RouteChangeAnalysis analysis) {
    if (_appDataBloc == null) return;

    switch (analysis.changeType) {
      case RouteChangeType.added:
        // Route ajoutée : sync seulement les stats (plus rapide)
        for (final route in analysis.addedRoutes) {
          _appDataBloc!.add(RouteAddedDataSync(
            routeId: route.id,
            routeName: route.name,
          ));
        }
        break;
        
      case RouteChangeType.deleted:
        // Route supprimée : sync complète (nécessaire)
        for (final route in analysis.deletedRoutes) {
          _appDataBloc!.add(RouteDeletedDataSync(
            routeId: route.id,
            routeName: route.name,
          ));
        }
        break;
        
      case RouteChangeType.mixed:
        // Changements mixtes : sync complète
        _appDataBloc!.add(const ForceDataSyncRequested());
        break;
        
      case RouteChangeType.modified:
        // Modifications mineures : sync historique seulement
        _appDataBloc!.add(const HistoricDataRefreshRequested());
        break;
    }
  }

  /// Analyse détaillée des changements
  RouteChangeAnalysis _analyzeChanges(List<SavedRoute> currentRoutes) {
    final currentIds = currentRoutes.map((r) => r.id).toSet();
    final previousIds = _lastKnownRoutes.map((r) => r.id).toSet();
    
    final addedIds = currentIds.difference(previousIds);
    final deletedIds = previousIds.difference(currentIds);
    
    final addedRoutes = currentRoutes.where((r) => addedIds.contains(r.id)).toList();
    final deletedRoutes = _lastKnownRoutes.where((r) => deletedIds.contains(r.id)).toList();
    
    RouteChangeType changeType;
    if (addedIds.isNotEmpty && deletedIds.isEmpty) {
      changeType = RouteChangeType.added;
    } else if (deletedIds.isNotEmpty && addedIds.isEmpty) {
      changeType = RouteChangeType.deleted;
    } else if (addedIds.isNotEmpty && deletedIds.isNotEmpty) {
      changeType = RouteChangeType.mixed;
    } else {
      changeType = RouteChangeType.modified;
    }
    
    return RouteChangeAnalysis(
      changeType: changeType,
      addedRoutes: addedRoutes,
      deletedRoutes: deletedRoutes,
      previousCount: _lastKnownRoutes.length,
      currentCount: currentRoutes.length,
    );
  }

  /// Vérifie si les routes ont changé
  bool _hasRoutesChanged(List<SavedRoute> currentRoutes) {
    if (currentRoutes.length != _lastKnownRoutes.length) {
      return true;
    }
    
    // Vérifier si les IDs des routes sont différents
    final currentIds = currentRoutes.map((r) => r.id).toSet();
    final previousIds = _lastKnownRoutes.map((r) => r.id).toSet();
    
    return !currentIds.containsAll(previousIds) || !previousIds.containsAll(currentIds);
  }

  /// Logs détaillés du changement
  void _logChangeDetails(RouteChangeAnalysis analysis) {
    switch (analysis.changeType) {
      case RouteChangeType.added:
        for (final route in analysis.addedRoutes) {
          print('➕ Route ajoutée: "${route.name}" (${route.formattedDistance})');
        }
        break;
        
      case RouteChangeType.deleted:
        for (final route in analysis.deletedRoutes) {
          print('➖ Route supprimée: "${route.name}" (${route.formattedDistance})');
        }
        break;
        
      case RouteChangeType.mixed:
        print('🔄 Changements mixtes: ${analysis.addedRoutes.length} ajoutées, ${analysis.deletedRoutes.length} supprimées');
        break;
        
      case RouteChangeType.modified:
        print('🔄 Route modifiée');
        break;
    }
  }

  /// Déclenche manuellement une synchronisation
  void forceSyncData() {
    if (_appDataBloc == null) {
      print('❌ AppDataBloc non disponible pour la synchronisation forcée');
      return;
    }
    
    print('🔄 Synchronisation forcée des données');
    _appDataBloc!.add(const ForceDataSyncRequested());
  }

  /// Déclenche manuellement une mise à jour des statistiques d'activité
  void forceActivityRefresh() {
    if (_appDataBloc == null) {
      print('❌ AppDataBloc non disponible pour le rafraîchissement d\'activité');
      return;
    }
    
    print('📊 Rafraîchissement forcé des statistiques d\'activité');
    _appDataBloc!.add(const ActivityDataRefreshRequested());
  }

  /// Nettoie les ressources
  void dispose() {
    print('🗑️ Nettoyage RouteDataSyncService ($_syncCount synchronisations effectuées)');
    _debounceTimer?.cancel();
    _routeSubscription?.cancel();
    _routeSubscription = null;
    _appDataBloc = null;
    _lastKnownRoutes.clear();
    _isInitialized = false;
    _syncCount = 0;
  }

  /// Getters pour le debug
  bool get isInitialized => _isInitialized;
  int get trackedRoutesCount => _lastKnownRoutes.length;
  List<String> get trackedRouteIds => _lastKnownRoutes.map((r) => r.id).toList();
  int get syncCount => _syncCount;
}

/// Types de changements de routes
enum RouteChangeType {
  added,    // Route(s) ajoutée(s)
  deleted,  // Route(s) supprimée(s)  
  modified, // Route modifiée
  mixed,    // Ajouts ET suppressions simultanés
}

/// Analyse détaillée des changements
class RouteChangeAnalysis {
  final RouteChangeType changeType;
  final List<SavedRoute> addedRoutes;
  final List<SavedRoute> deletedRoutes;
  final int previousCount;
  final int currentCount;

  const RouteChangeAnalysis({
    required this.changeType,
    required this.addedRoutes,
    required this.deletedRoutes,
    required this.previousCount,
    required this.currentCount,
  });
}