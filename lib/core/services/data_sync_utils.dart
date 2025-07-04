import 'package:flutter/material.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/services/route_data_sync_service.dart';

/// Utilitaires pour déclencher facilement la synchronisation des données
class DataSyncUtils {
  
  /// Déclenche une mise à jour complète des données depuis n'importe où
  static void refreshAllData(BuildContext context) {
    try {
      context.appDataBloc.add(const AppDataRefreshRequested());
      print('🔄 Rafraîchissement complet déclenché');
    } catch (e) {
      print('❌ Erreur rafraîchissement complet: $e');
    }
  }
  
  /// Déclenche une mise à jour des statistiques d'activité uniquement
  static void refreshActivityData(BuildContext context) {
    try {
      context.appDataBloc.add(const ActivityDataRefreshRequested());
      print('📊 Rafraîchissement activité déclenché');
    } catch (e) {
      print('❌ Erreur rafraîchissement activité: $e');
    }
  }
  
  /// Déclenche une mise à jour de l'historique uniquement
  static void refreshHistoricData(BuildContext context) {
    try {
      context.appDataBloc.add(const HistoricDataRefreshRequested());
      print('📚 Rafraîchissement historique déclenché');
    } catch (e) {
      print('❌ Erreur rafraîchissement historique: $e');
    }
  }
  
  /// Force une synchronisation complète en ignorant le cache
  static void forceDataSync(BuildContext context) {
    try {
      context.appDataBloc.add(const ForceDataSyncRequested());
      print('🔄 Synchronisation forcée déclenchée');
    } catch (e) {
      print('❌ Erreur synchronisation forcée: $e');
    }
  }
  
  /// Notifie l'ajout d'une route
  static void notifyRouteAdded(BuildContext context, String routeId, String routeName) {
    try {
      context.appDataBloc.add(RouteAddedDataSync(
        routeId: routeId,
        routeName: routeName,
      ));
      print('➕ Notification ajout route: $routeName');
    } catch (e) {
      print('❌ Erreur notification ajout route: $e');
    }
  }
  
  /// Notifie la suppression d'une route
  static void notifyRouteDeleted(BuildContext context, String routeId, String routeName) {
    try {
      context.appDataBloc.add(RouteDeletedDataSync(
        routeId: routeId,
        routeName: routeName,
      ));
      print('➖ Notification suppression route: $routeName');
    } catch (e) {
      print('❌ Erreur notification suppression route: $e');
    }
  }
  
  /// Vide le cache des données
  static void clearDataCache(BuildContext context) {
    try {
      context.appDataBloc.add(const AppDataClearRequested());
      print('🗑️ Cache vidé');
    } catch (e) {
      print('❌ Erreur vidage cache: $e');
    }
  }
  
  /// Vérifie si les données sont prêtes
  static bool isDataReady(BuildContext context) {
    try {
      final appDataBloc = context.appDataBloc;
      return appDataBloc.isDataReady;
    } catch (e) {
      print('❌ Erreur vérification données: $e');
      return false;
    }
  }
  
  /// Déclenche une synchronisation via le service global
  static void triggerServiceSync() {
    RouteDataSyncService.instance.forceSyncData();
  }
  
  /// Déclenche un rafraîchissement d'activité via le service global
  static void triggerServiceActivityRefresh() {
    RouteDataSyncService.instance.forceActivityRefresh();
  }
  
  /// Obtient les statistiques du service de synchronisation
  static Map<String, dynamic> getSyncServiceStats() {
    final service = RouteDataSyncService.instance;
    return {
      'isInitialized': service.isInitialized,
      'trackedRoutesCount': service.trackedRoutesCount,
      'trackedRouteIds': service.trackedRouteIds,
    };
  }
}
