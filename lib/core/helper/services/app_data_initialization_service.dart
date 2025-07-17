import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/helper/config/log_config.dart';

/// Service pour gérer l'initialisation et la synchronisation des données
/// 🆕 Maintenant avec support complet des crédits
class AppDataInitializationService {
  static AppDataBloc? _appDataBloc;
  static bool _isInitialized = false;

  /// Initialise le service avec le BLoC de données
  static void initialize(AppDataBloc appDataBloc) {
    _appDataBloc = appDataBloc;
    _isInitialized = true;
    LogConfig.logInfo('AppDataInitializationService initialisé avec support crédits');
  }

  // ===== MÉTHODES GÉNÉRALES =====

  /// Déclenche le pré-chargement complet (activité + historique + crédits)
  static void startDataPreloading() {
    if (!_isInitialized || _appDataBloc == null) {
      LogConfig.logInfo('AppDataInitializationService non initialisé');
      return;
    }

    LogConfig.logInfo('🚀 Démarrage du pré-chargement complet (y compris crédits)');
    _appDataBloc!.add(const AppDataPreloadRequested());
  }

  /// Rafraîchit toutes les données
  static void refreshAllData() {
    if (!_isInitialized || _appDataBloc == null) return;
    LogConfig.logInfo('🔄 Rafraîchissement complet demandé');
    _appDataBloc!.add(const AppDataRefreshRequested());
  }

  /// Nettoie le cache lors de la déconnexion
  static void clearDataCache() {
    if (!_isInitialized || _appDataBloc == null) return;
    LogConfig.logInfo('🗑️ Nettoyage complet du cache');
    _appDataBloc!.add(const AppDataClearRequested());
  }

  /// Synchronisation forcée avec bypass du cache
  static void forceDataSync() {
    if (!_isInitialized || _appDataBloc == null) return;
    LogConfig.logInfo('Synchronisation forcée demandée');
    _appDataBloc!.add(const ForceDataSyncRequested());
  }

  // ===== MÉTHODES HISTORIQUE =====

  /// Rafraîchit uniquement les données d'historique
  static void refreshHistoricData() {
    if (!_isInitialized || _appDataBloc == null) return;
    LogConfig.logInfo('📚 Rafraîchissement données historique');
    _appDataBloc!.add(const HistoricDataRefreshRequested());
  }

  // ===== 🆕 MÉTHODES CRÉDITS =====

  /// Déclenche le pré-chargement des données de crédits uniquement
  static void preloadCreditData() {
    if (!_isInitialized || _appDataBloc == null) {
      LogConfig.logInfo('AppDataInitializationService non initialisé pour crédits');
      return;
    }

    LogConfig.logInfo('💳 Pré-chargement spécifique des crédits');
    _appDataBloc!.add(const CreditDataPreloadRequested());
  }

  /// Rafraîchit uniquement les données de crédits
  static void refreshCreditData() {
    if (!_isInitialized || _appDataBloc == null) return;
    LogConfig.logInfo('💰 Rafraîchissement données crédits');
    _appDataBloc!.add(const CreditDataRefreshRequested());
  }

  /// Synchronise après utilisation de crédits
  static void syncAfterCreditUsage({
    required int amount,
    required String reason,
    String? routeGenerationId,
    required String transactionId,
  }) {
    if (!_isInitialized || _appDataBloc == null) return;
    
    LogConfig.logInfo('🔄 Synchronisation post-utilisation: $amount crédits');
    _appDataBloc!.add(CreditUsageCompletedInAppData(
      amount: amount,
      reason: reason,
      routeGenerationId: routeGenerationId,
      transactionId: transactionId,
    ));
  }

  /// Synchronise après achat de crédits
  static void syncAfterCreditPurchase({
    required String planId,
    required String paymentIntentId,
    required int creditsAdded,
  }) {
    if (!_isInitialized || _appDataBloc == null) return;
    
    LogConfig.logInfo('🔄 Synchronisation post-achat: $creditsAdded crédits ajoutés');
    _appDataBloc!.add(CreditPurchaseCompletedInAppData(
      planId: planId,
      paymentIntentId: paymentIntentId,
      creditsAdded: creditsAdded,
    ));
  }

  /// Mise à jour optimiste du solde de crédits
  static void updateCreditBalanceOptimistic(int newBalance) {
    if (!_isInitialized || _appDataBloc == null) return;
    
    LogConfig.logInfo('Mise à jour optimiste: $newBalance crédits');
    _appDataBloc!.add(CreditBalanceUpdatedInAppData(
      newBalance: newBalance,
      isOptimistic: true,
    ));
  }

  /// Confirmation du solde de crédits
  static void confirmCreditBalance(int confirmedBalance) {
    if (!_isInitialized || _appDataBloc == null) return;
    
    LogConfig.logInfo('Confirmation solde: $confirmedBalance crédits');
    _appDataBloc!.add(CreditBalanceUpdatedInAppData(
      newBalance: confirmedBalance,
      isOptimistic: false,
    ));
  }

  /// Nettoie uniquement les données de crédits
  static void clearCreditData() {
    if (!_isInitialized || _appDataBloc == null) return;
    LogConfig.logInfo('🗑️ Nettoyage données crédits');
    _appDataBloc!.add(const CreditDataClearRequested());
  }

  // ===== GETTERS =====

  /// Vérifie si les données sont prêtes (incluant crédits)
  static bool get isDataReady {
    if (!_isInitialized || _appDataBloc == null) return false;
    return _appDataBloc!.isDataReady;
  }

  /// Vérifie si les données de crédits sont disponibles
  static bool get isCreditDataReady {
    if (!_isInitialized || _appDataBloc == null) return false;
    return _appDataBloc!.state.isCreditDataLoaded;
  }

  /// Retourne le nombre de crédits disponibles
  static int get availableCredits {
    if (!_isInitialized || _appDataBloc == null) return 0;
    return _appDataBloc!.state.availableCredits;
  }

  /// Vérifie si l'utilisateur a des crédits
  static bool get hasCredits {
    if (!_isInitialized || _appDataBloc == null) return false;
    return _appDataBloc!.state.hasCredits;
  }

  /// Vérifie si l'utilisateur peut générer un parcours
  static bool get canGenerateRoute {
    if (!_isInitialized || _appDataBloc == null) return false;
    return _appDataBloc!.state.canGenerateRoute;
  }

  /// Vérifie si le service est initialisé
  static bool get isInitialized => _isInitialized;

  /// Accès au BLoC de données (pour les widgets)
  static AppDataBloc? get appDataBloc => _appDataBloc;

  // ===== MÉTHODES HELPER =====

  /// Initialisation complète au démarrage de l'app
  static void initializeOnAppStart() {
    if (!_isInitialized) {
      LogConfig.logInfo('Service non initialisé, impossible de démarrer');
      return;
    }

    print('🌟 Initialisation complète au démarrage');
    
    // Pré-charger toutes les données
    startDataPreloading();
    
    // Log de l'état
    Future.delayed(const Duration(seconds: 2), () {
      if (_appDataBloc != null) {
        final state = _appDataBloc!.state;
        LogConfig.logInfo('📊 État après initialisation:');
        print('   - Historique: ${state.hasHistoricData ? "✅" : "❌"} (${state.savedRoutes.length} parcours)');
        print('   - Crédits: ${state.hasCreditData ? "✅" : "❌"} (${state.availableCredits} disponibles)');
        print('   - Données complètes: ${state.isDataLoaded ? "✅" : "❌"}');
      }
    });
  }

  /// Méthode appelée lors de la connexion utilisateur
  static void onUserAuthenticated() {
    LogConfig.logInfo('👤 Utilisateur connecté - démarrage pré-chargement');
    startDataPreloading();
  }

  /// Méthode appelée lors de la déconnexion utilisateur
  static void onUserSignedOut() {
    print('👋 Utilisateur déconnecté - nettoyage des données');
    clearDataCache();
  }
}