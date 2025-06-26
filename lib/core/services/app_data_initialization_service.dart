import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';

/// Service pour gérer l'initialisation et la synchronisation des données
class AppDataInitializationService {
  static AppDataBloc? _appDataBloc;
  static bool isInitialized = false;

  /// Initialise le service avec le BLoC de données
  static void initialize(AppDataBloc appDataBloc) {
    _appDataBloc = appDataBloc;
    isInitialized = true;
    print('✅ AppDataInitializationService initialisé');
  }

  /// Déclenche le pré-chargement des données quand l'utilisateur s'authentifie
  static void startDataPreloading() {
    if (!isInitialized || _appDataBloc == null) {
      print('⚠️ AppDataInitializationService non initialisé');
      return;
    }

    print('🚀 Démarrage du pré-chargement des données');
    _appDataBloc!.add(const AppDataPreloadRequested());
  }

  /// Rafraîchit toutes les données
  static void refreshAllData() {
    if (!isInitialized || _appDataBloc == null) return;
    _appDataBloc!.add(const AppDataRefreshRequested());
  }

  /// Rafraîchit uniquement les données d'activité
  static void refreshActivityData() {
    if (!isInitialized || _appDataBloc == null) return;
    _appDataBloc!.add(const ActivityDataRefreshRequested());
  }

  /// Rafraîchit uniquement les données d'historique
  static void refreshHistoricData() {
    if (!isInitialized || _appDataBloc == null) return;
    _appDataBloc!.add(const HistoricDataRefreshRequested());
  }

  /// Nettoie le cache lors de la déconnexion
  static void clearDataCache() {
    if (!isInitialized || _appDataBloc == null) return;
    print('🗑️ Nettoyage du cache des données');
    _appDataBloc!.add(const AppDataClearRequested());
  }

  /// Vérifie si les données sont prêtes
  static bool get isDataReady {
    if (!isInitialized || _appDataBloc == null) return false;
    return _appDataBloc!.isDataReady;
  }

  /// Accès au BLoC de données (pour les widgets)
  static AppDataBloc? get appDataBloc => _appDataBloc;
}

