import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/services/cache_service.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/data/services/credit_verification_service.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_event.dart';
import 'package:runaway/features/home/presentation/blocs/route_parameters_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'service_locator.dart';

/// Extension pour accéder facilement aux blocs via GetIt
extension BlocAccess on BuildContext {
  // ===== ACCÈS DIRECT AUX BLOCS SINGLETON =====
  NotificationBloc get notificationBloc => sl<NotificationBloc>();
  AppDataBloc get appDataBloc => sl<AppDataBloc>();
  AuthBloc get authBloc => sl<AuthBloc>();
  LocaleBloc get localeBloc => sl<LocaleBloc>();
  ThemeBloc get themeBloc => sl<ThemeBloc>();
  CreditsBloc get creditsBloc => read<CreditsBloc>();
  
  // ===== ACCÈS AUX SERVICES =====
  CreditVerificationService get creditService => sl<CreditVerificationService>(); // 🆕
  
  // ===== BLOCS AVEC INSTANCES MULTIPLES =====
  RouteParametersBloc get routeParametersBloc => read<RouteParametersBloc>();
  RouteGenerationBloc get routeGenerationBloc => read<RouteGenerationBloc>();

  // ===== 🆕 MÉTHODES HELPER POUR LES CRÉDITS =====
  
  /// Nombre de crédits disponibles (0 si pas de données)
  int get availableCredits => appDataBloc.state.availableCredits;
  
  /// Vérifie si l'utilisateur a des crédits
  bool get hasCredits => appDataBloc.state.hasCredits;
  
  /// Vérifie si l'utilisateur peut générer un parcours
  bool get canGenerateRoute => appDataBloc.state.canGenerateRoute;
  
  /// Vérifie si les données de crédits sont chargées
  bool get isCreditDataLoaded => appDataBloc.state.isCreditDataLoaded;
  
  /// Plans de crédits actifs
  List<CreditPlan> get activeCreditPlans => appDataBloc.state.activePlans;
  
  /// Plan populaire
  CreditPlan? get popularCreditPlan => 
    appDataBloc.state.activePlans.cast<CreditPlan?>().firstWhere(
      (plan) => plan?.isPopular == true,
      orElse: () => null,
    );
  
  /// Transactions récentes
  List<CreditTransaction> get recentCreditTransactions => 
    appDataBloc.state.recentTransactions;

  // ===== 🆕 MÉTHODES D'ACTION POUR LES CRÉDITS =====

  /// Vérifie de manière asynchrone si l'utilisateur peut générer une route
  /// Utilise le service dédié pour plus de fiabilité
  Future<bool> canGenerateRouteAsync() async {
    try {
      return await creditService.canGenerateRoute();
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification génération async: $e');
      return false;
    }
  }

  /// Récupère le nombre de crédits disponibles de manière asynchrone
  /// Utilise le service dédié pour les données les plus à jour
  Future<int> getAvailableCreditsAsync() async {
    try {
      return await creditService.getAvailableCredits();
    } catch (e) {
      LogConfig.logError('❌ Erreur récupération crédits async: $e');
      return 0;
    }
  }

  /// 🆕 Force un nettoyage complet lors d'un changement d'utilisateur
  void clearUserSession() {
    try {
      LogConfig.logInfo('🧹 Nettoyage session utilisateur...');
            
      // 1. D'abord CreditsBloc
      try {
        creditsBloc.add(const CreditsReset());
        LogConfig.logInfo('💳 CreditsBloc nettoyé');
      } catch (e) {
        LogConfig.logError('❌ Erreur nettoyage CreditsBloc: $e');
      }
      
      // 2. Puis AppDataBloc  
      try {
        appDataBloc.add(const AppDataClearRequested());
        LogConfig.logInfo('📊 AppDataBloc nettoyé');
      } catch (e) {
        LogConfig.logError('❌ Erreur nettoyage AppDataBloc: $e');
      }
      
      // 3. Invalider le cache
      try {
        final cacheService = CacheService.instance;
        cacheService.invalidateCreditsCache();
        LogConfig.logInfo('🧹 Cache invalidé');
      } catch (e) {
        LogConfig.logError('❌ Erreur invalidation cache: $e');
      }
      
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage session: $e');
    }
  }

  /// 🆕 Vérifie et corrige les données si changement d'utilisateur détecté
  Future<void> ensureUserDataConsistency() async {
    try {
      final currentUser = sl.get<AuthBloc>().state;
      if (currentUser is Authenticated) {
        final userId = currentUser.profile.id;
        
        final cacheService = CacheService.instance;
        final hasChanged = await cacheService.hasUserChanged(userId);
        
        if (hasChanged) {
          LogConfig.logInfo('🔄 Incohérence utilisateur détectée - correction...');
          
          // Nettoyage dans le bon ordre
          clearUserSession();
          
          // Attendre plus longtemps pour que le nettoyage soit complet
          await Future.delayed(Duration(milliseconds: 800));
          
          // Confirmer le changement d'utilisateur
          await cacheService.confirmUserChange(userId);
          
          // Forcer le rechargement des crédits
          preloadCreditData();
        }
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification cohérence utilisateur: $e');
    }
  }

  /// 🆕 Force une synchronisation complète des crédits
  void forceCreditSync({String reason = 'manual'}) {
    LogConfig.logInfo('🔄 Demande de synchronisation forcée des crédits');
    
    // Ajouter un délai pour éviter les conflits
    Future.delayed(Duration(milliseconds: 100), () {
      appDataBloc.add(CreditsForceSyncRequested(reason: reason));
    });
  }

  /// 🆕 Vérifie la cohérence des crédits et corrige si nécessaire
  Future<void> validateAndFixCredits() async {
    try {
      LogConfig.logInfo('🔍 Validation et correction des crédits...');
      
      // S'assurer qu'on a un utilisateur connecté
      final currentUser = sl.get<AuthBloc>().state;
      if (currentUser is! Authenticated) {
        LogConfig.logInfo('❌ Pas d\'utilisateur connecté - validation annulée');
        return;
      }
      
      // Vérifier la cohérence du cache d'abord
      final cacheService = CacheService.instance;
      final hasChanged = await cacheService.hasUserChanged(currentUser.profile.id);
      
      if (hasChanged) {
        LogConfig.logInfo('🔄 Changement utilisateur détecté pendant validation - correction...');
        await ensureUserDataConsistency();
        return;
      }
      
      // Forcer un refresh depuis le repository
      final creditsRepo = sl.get<CreditsRepository>();
      await creditsRepo.getUserCredits(forceRefresh: true);
      
      LogConfig.logInfo('✅ Validation terminée');
    } catch (e) {
      LogConfig.logError('❌ Erreur validation crédits: $e');
      
      // En cas d'erreur, forcer un nettoyage minimal
      try {
        clearUserSession();
      } catch (e2) {
        LogConfig.logError('❌ Erreur nettoyage après validation: $e2');
      }
    }
  }

  Future<void> diagnoseCacheState() async {
    try {
      LogConfig.logInfo('🔍 Diagnostic de l\'état du cache...');
      
      final currentUser = sl.get<AuthBloc>().state;
      if (currentUser is Authenticated) {
        final userId = currentUser.profile.id;
        LogConfig.logInfo('👤 Utilisateur actuel: $userId');
        
        final cacheService = CacheService.instance;
        final hasChanged = await cacheService.hasUserChanged(userId);
        LogConfig.logInfo('🔄 Changement utilisateur détecté: $hasChanged');
        
        // Vérifier le cache des crédits
        final cachedCredits = await cacheService.get<Map>('cache_user_credits');
        LogConfig.logInfo('💳 Cache crédits présent: ${cachedCredits != null}');
        
        if (cachedCredits != null) {
          try {
            final credits = UserCredits.fromJson(Map<String, dynamic>.from(cachedCredits));
            LogConfig.logInfo('💰 Crédits en cache: ${credits.availableCredits}');
          } catch (e) {
            LogConfig.logError('❌ Cache crédits corrompu: $e');
          }
        }
      } else {
        LogConfig.logInfo('❌ Aucun utilisateur connecté');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur diagnostic cache: $e');
    }
  }

  /// Déclenche le pré-chargement des crédits si nécessaire
  void ensureCreditDataLoaded() {
    creditService.ensureCreditDataLoaded();
  }

  /// Vérifie les crédits pour une génération spécifique
  Future<CreditVerificationResult> verifyCreditForGeneration({int requiredCredits = 1}) async {
    try {
      return await creditService.verifyCreditsForGeneration(requiredCredits: requiredCredits);
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification crédits pour génération: $e');
      return CreditVerificationResult(
        hasEnoughCredits: false,
        availableCredits: 0,
        requiredCredits: requiredCredits,
        errorMessage: 'Erreur lors de la vérification des crédits',
      );
    }
  }
  
  /// Rafraîchit les données de crédits
  void refreshCreditData() {
    appDataBloc.add(const CreditDataRefreshRequested());
  }
  
  /// Pré-charge les données de crédits
  void preloadCreditData() {
    appDataBloc.add(const CreditDataPreloadRequested());
  }
  
  /// Mise à jour optimiste du solde
  void updateCreditBalanceOptimistic(int newBalance) {
    appDataBloc.add(CreditBalanceUpdatedInAppData(
      newBalance: newBalance,
      isOptimistic: true,
    ));
  }
  
  /// Synchronise après utilisation de crédits
  void syncAfterCreditUsage({
    required int amount,
    required String reason,
    String? routeGenerationId,
    required String transactionId,
  }) {
    appDataBloc.add(CreditUsageCompletedInAppData(
      amount: amount,
      reason: reason,
      routeGenerationId: routeGenerationId,
      transactionId: transactionId,
    ));
  }
  
  /// Synchronise après achat de crédits
  void syncAfterCreditPurchase({
    required String planId,
    required String paymentIntentId,
    required int creditsAdded,
  }) {
    appDataBloc.add(CreditPurchaseCompletedInAppData(
      planId: planId,
      paymentIntentId: paymentIntentId,
      creditsAdded: creditsAdded,
    ));
  }

  // ===== 🆕 MÉTHODES HELPER POUR LES AUTRES DONNÉES =====

  /// Vérifie si les données principales sont prêtes
  bool get isAppDataReady => appDataBloc.state.isDataReady;
    
  /// Nettoie les données de l'application
  void clearAppData() {
    appDataBloc.add(const AppDataClearRequested());
  }
  
  /// Vérifie si toutes les données sont chargées
  bool get isAllDataLoaded => appDataBloc.state.isDataLoaded;
    
  /// Vérifie si les données d'historique sont chargées
  bool get isHistoricDataLoaded => appDataBloc.state.hasHistoricData;
  
  /// Nombre de parcours sauvegardés
  int get savedRoutesCount => appDataBloc.state.savedRoutes.length;
  
  /// Rafraîchit toutes les données
  void refreshAllData() {
    appDataBloc.add(const AppDataRefreshRequested());
  }
    
  /// Rafraîchit les données d'historique
  void refreshHistoricData() {
    appDataBloc.add(const HistoricDataRefreshRequested());
  }

  // ===== MÉTHODES DE DEBUG =====
  
  /// Affiche les statistiques des crédits pour debug
  void debugCreditStats() {
    final state = appDataBloc.state;
    print('🎯 === DEBUG CREDIT STATS ===');
    LogConfig.logInfo('💳 Available Credits: ${state.availableCredits}');
    LogConfig.logInfo('📊 Has Credits: ${state.hasCredits}');
    LogConfig.logInfo('Can Generate Route: ${state.canGenerateRoute}');
    LogConfig.logInfo('📦 Credit Data Loaded: ${state.isCreditDataLoaded}');
    print('📋 Active Plans: ${state.activePlans.length}');
    LogConfig.logInfo('🔄 Recent Transactions: ${state.recentTransactions.length}');
    print('🎯 === END DEBUG STATS ===');
  }

  /// Affiche les statistiques générales de l'app pour debug
  void debugAppStats() {
    final state = appDataBloc.state;
    print('🎯 === DEBUG APP STATS ===');
    LogConfig.logInfo('Is Loading: ${state.isLoading}');
    LogConfig.logInfo('📊 Data Ready: ${state.isDataReady}');
    print('📋 Historic Data: ${state.hasHistoricData}');
    LogConfig.logInfo('💳 Credit Data: ${state.hasCreditData}');
    LogConfig.logError('❌ Last Error: ${state.lastError}');
    print('🎯 === END APP STATS ===');
  }
}

/// Widget helper pour créer des BlocProvider avec GetIt
class GetItBlocProvider<T extends BlocBase<Object?>> extends StatelessWidget {
  final Widget child;
  final T Function() create;

  const GetItBlocProvider({
    super.key,
    required this.child,
    required this.create,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<T>.value(
      value: create(),
      child: child,
    );
  }
}

/// Widget pour les pages nécessitant des blocs spécifiques
class RoutePageWrapper extends StatelessWidget {
  final Widget child;

  const RoutePageWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<RouteParametersBloc>(create: (_) => sl<RouteParametersBloc>()),
        BlocProvider<RouteGenerationBloc>(create: (_) => sl<RouteGenerationBloc>()),
      ],
      child: child,
    );
  }
}

/// 🆕 Widget wrapper pour les pages nécessitant un accès aux crédits
class CreditAwarePageWrapper extends StatelessWidget {
  final Widget child;
  final bool preloadOnInit;

  const CreditAwarePageWrapper({
    super.key,
    required this.child,
    this.preloadOnInit = true,
  });

  @override
  Widget build(BuildContext context) {
    // Déclencher le pré-chargement si nécessaire
    if (preloadOnInit && !context.isCreditDataLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.preloadCreditData();
      });
    }

    return child;
  }
}

/// 🆕 Widget wrapper pour les pages de génération de parcours
class RouteGenerationPageWrapper extends StatelessWidget {
  final Widget child;

  const RouteGenerationPageWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<RouteParametersBloc>(create: (_) => sl<RouteParametersBloc>()),
        BlocProvider<RouteGenerationBloc>(create: (_) => sl<RouteGenerationBloc>()),
      ],
      child: CreditAwarePageWrapper(child: child),
    );
  }
}

/// Extension pour accéder aux méthodes avancées de crédits
extension CreditAdvancedAccess on BuildContext {
  
  /// Vérifie les crédits et affiche un message d'erreur si insuffisant
  Future<bool> checkCreditsWithUserFeedback({
    int requiredCredits = 1,
    String? customErrorMessage,
  }) async {
    final result = await verifyCreditForGeneration(requiredCredits: requiredCredits);
    
    if (!result.isValid) {
      // Ici vous pourriez afficher un snackbar ou une modal
      // En fonction de votre système de notifications
      LogConfig.logInfo('Crédits insuffisants: ${result.errorMessage}');
      return false;
    }
    
    return true;
  }

  /// Méthode utilitaire pour la génération de route avec vérification intégrée
  Future<bool> canGenerateRouteWithPreload() async {
    // S'assurer que les données sont chargées
    ensureCreditDataLoaded();
    
    // Attendre un court instant pour le pré-chargement si nécessaire
    if (!isCreditDataLoaded) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Vérifier via le service
    return await canGenerateRouteAsync();
  }
}