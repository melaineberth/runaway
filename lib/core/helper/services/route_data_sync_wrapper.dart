import 'package:flutter/material.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/helper/services/route_data_sync_service.dart';

/// Widget wrapper qui initialise automatiquement la synchronisation des données
/// entre RouteGenerationBloc et AppDataBloc
class RouteDataSyncWrapper extends StatefulWidget {
  final Widget child;

  const RouteDataSyncWrapper({
    super.key,
    required this.child,
  });

  @override
  State<RouteDataSyncWrapper> createState() => _RouteDataSyncWrapperState();
}

class _RouteDataSyncWrapperState extends State<RouteDataSyncWrapper> {
  bool _isSyncInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialiser le service de synchronisation une fois que les BLoCs sont disponibles
    if (!_isSyncInitialized) {
      _initializeSyncService();
    }
  }

  void _initializeSyncService() {
    try {
      // Récupérer les BLoCs depuis le contexte
      final routeGenerationBloc = context.routeGenerationBloc;
      final appDataBloc = context.appDataBloc;

      // Initialiser le service de synchronisation
      RouteDataSyncService.instance.initialize(
        routeGenerationBloc: routeGenerationBloc,
        appDataBloc: appDataBloc,
      );

      _isSyncInitialized = true;
      LogConfig.logSuccess('Synchronisation automatique des données initialisée');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur initialisation synchronisation: $e');
      // Réessayer lors du prochain build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isSyncInitialized) {
          _initializeSyncService();
        }
      });
    }
  }

  @override
  void dispose() {
    // Nettoyer le service lors de la destruction du widget
    if (_isSyncInitialized) {
      RouteDataSyncService.instance.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
