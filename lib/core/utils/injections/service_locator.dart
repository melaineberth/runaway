import 'package:get_it/get_it.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/blocs/connectivity/connectivity_cubit.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_event.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/core/helper/services/app_data_initialization_service.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';
import 'package:runaway/core/helper/services/guest_limitation_service.dart';
import 'package:runaway/features/auth/data/repositories/auth_repository.dart';
import 'package:runaway/features/auth/data/services/brute_force_protection_service.dart';
import 'package:runaway/features/auth/data/services/security_logging_service.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/data/services/credit_verification_service.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_event.dart';
import 'package:runaway/features/home/data/services/map_state_service.dart';
import 'package:runaway/features/home/presentation/blocs/route_parameters_bloc.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/core/helper/config/log_config.dart';

final GetIt sl = GetIt.instance;

class ServiceLocator {
  static Future<void> init() async {
    // ===== REPOSITORIES =====
    sl.registerLazySingleton<RoutesRepository>(() => RoutesRepository());
    sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
    sl.registerLazySingleton<MapStateService>(() => MapStateService());
    sl.registerLazySingleton<CreditsRepository>(() => CreditsRepository());

    // ===== SERVICES =====

    sl.registerLazySingleton<GuestLimitationService>(
      () => GuestLimitationService.instance,
    );

    // 🆕 CreditVerificationService - Service dédié aux crédits
    sl.registerLazySingleton<CreditVerificationService>(() {
      LogConfig.logInfo('🔧 Création du CreditVerificationService...');
      return CreditVerificationService(
        creditsRepository: sl<CreditsRepository>(),
        creditsBloc: sl<CreditsBloc>(),
        appDataBloc: sl<AppDataBloc>(),
      );
    });

    // ===== SERVICES DE SÉCURITÉ =====
    sl.registerLazySingleton<BruteForceProtectionService>(
      () => BruteForceProtectionService.instance,
    );

    sl.registerLazySingleton<SecurityLoggingService>(
      () => SecurityLoggingService.instance,
    );

    // --- Connectivité ----------------------
    // Utiliser l'instance déjà initialisée
    sl.registerLazySingleton<ConnectivityService>(() => ConnectivityService.instance);

    // Ne pas réinitialiser si déjà fait
    if (!ConnectivityService.instance.isInitialized) {
      LogConfig.logInfo('ConnectivityService pas encore initialisé - initialisation de secours');
      await ConnectivityService.instance.initialize();
    }

    sl.registerLazySingleton<ConnectivityCubit>(() => ConnectivityCubit(sl<ConnectivityService>()));

    // ===== BLOCS PRINCIPAUX =====

    // NotificationBloc
    sl.registerLazySingleton<NotificationBloc>(() {
      final bloc = NotificationBloc();
      bloc.add(NotificationInitializeRequested());
      return bloc;
    });

    // AppDataBloc (avec CreditsRepository)
    sl.registerLazySingleton<AppDataBloc>(() {
      LogConfig.logInfo('🔧 Création du AppDataBloc avec support crédits...');
      final appDataBloc = AppDataBloc(
        routesRepository: sl<RoutesRepository>(),
        mapStateService: sl<MapStateService>(), 
        creditsRepository: sl<CreditsRepository>(), // 🆕 Ajout
      );
      
      // Initialiser le service IMMÉDIATEMENT après création du BLoC
      AppDataInitializationService.initialize(appDataBloc);
      LogConfig.logInfo('AppDataInitializationService initialisé avec support crédits');
      
      return appDataBloc;
    });

    // 🆕 CreditsBloc (avec référence à AppDataBloc)
    sl.registerLazySingleton<CreditsBloc>(() {
      LogConfig.logInfo('🔧 Création du CreditsBloc intégré...');
      final creditsBloc = CreditsBloc(
        creditsRepository: sl<CreditsRepository>(),
        appDataBloc: sl<AppDataBloc>(), // 🆕 Injection du AppDataBloc
      );
      LogConfig.logInfo('CreditsBloc créé avec intégration AppDataBloc');
      return creditsBloc;
    });

    // 🆕 AuthBloc utilise l'instance SINGLETON de CreditsBloc
    sl.registerLazySingleton<AuthBloc>(() {
      LogConfig.logInfo('🔧 Création du AuthBloc...');
      final authBloc = AuthBloc(
        authRepository: sl<AuthRepository>(),
        creditsBloc: sl<CreditsBloc>(), // 🔑 Utiliser l'instance singleton
      );

      // Déclencher l'initialisation de l'authentification
      authBloc.add(AppStarted());
      return authBloc;
    });

    sl.registerLazySingleton<LocaleBloc>(() {
      LogConfig.logInfo('🔧 Création du LocaleBloc...');
      final localeBloc = LocaleBloc();
      LogConfig.logInfo('LocaleBloc créé');
      localeBloc.add(const LocaleInitialized());
      return localeBloc;
    });

    sl.registerLazySingleton<ThemeBloc>(() {
      LogConfig.logInfo('🔧 Création du ThemeBloc...');
      final themeBloc = ThemeBloc();
      LogConfig.logInfo('ThemeBloc créé');
      themeBloc.add(const ThemeInitialized());
      return themeBloc;
    });

    // ===== BLOCS AVEC INSTANCES MULTIPLES =====

    // Factory pour les blocs qui peuvent avoir plusieurs instances
    sl.registerFactory<RouteParametersBloc>(() => RouteParametersBloc(
      startLongitude: 0.0,
      startLatitude: 0.0,
    ));

    // 🆕 RouteGenerationBloc utilise l'instance SINGLETON de CreditsBloc
    sl.registerFactory<RouteGenerationBloc>(() {
      LogConfig.logInfo('🔧 Création RouteGenerationBloc refactorisé...');
      final bloc = RouteGenerationBloc(
        routesRepository: sl<RoutesRepository>(),
        creditService: sl<CreditVerificationService>(), // 🆕 Service dédié
        appDataBloc: sl<AppDataBloc>(),
      );
      LogConfig.logInfo('RouteGenerationBloc refactorisé créé');
      return bloc;
    });
  }

  /// 🆕 Méthode helper pour initialiser les données au démarrage
  static void initializeAppData() {
    try {
      final appDataBloc = sl<AppDataBloc>();
      appDataBloc.add(const AppDataPreloadRequested());
      LogConfig.logInfo('🚀 Pré-chargement des données déclenché');
    } catch (e) {
      LogConfig.logError('❌ Erreur initialisation données: $e');
    }
  }

  /// 🆕 Méthode helper pour déclencher le chargement des crédits
  static void initializeCreditData() {
    try {
      final appDataBloc = sl<AppDataBloc>();
      appDataBloc.add(const CreditDataPreloadRequested());
      LogConfig.logInfo('💳 Pré-chargement des crédits déclenché');
    } catch (e) {
      LogConfig.logError('❌ Erreur initialisation crédits: $e');
    }
  }

  /// 🆕 Méthode pour nettoyer les données lors de la déconnexion
  static void clearUserData() {
    try {
      final appDataBloc = sl<AppDataBloc>();
      final creditsBloc = sl<CreditsBloc>();
      
      appDataBloc.add(const AppDataClearRequested());
      creditsBloc.add(const CreditsReset());
      
      LogConfig.logInfo('🗑️ Données utilisateur nettoyées');
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage données: $e');
    }
  }

  /// 🆕 Méthode pour rafraîchir toutes les données
  static void refreshAllData() {
    try {
      final appDataBloc = sl<AppDataBloc>();
      appDataBloc.add(const AppDataRefreshRequested());
      LogConfig.logInfo('🔄 Rafraîchissement complet déclenché');
    } catch (e) {
      LogConfig.logError('❌ Erreur rafraîchissement: $e');
    }
  }

  static void dispose() {
    sl.reset();
  }

  /// Méthode de nettoyage pour les tests
  static Future<void> reset() async {
    LogConfig.logInfo('🧹 Reset du Service Locator...');
    await sl.reset();
    LogConfig.logInfo('Service Locator reseté');
  }
}

/// Extensions pour accéder facilement aux services via GetIt
extension ServiceAccess on Object {
  // Services
  CreditVerificationService get creditService => sl<CreditVerificationService>();
  GuestLimitationService get guestService => sl<GuestLimitationService>();
  
  // Repositories
  CreditsRepository get creditsRepository => sl<CreditsRepository>();
  RoutesRepository get routesRepository => sl<RoutesRepository>();
  AuthRepository get authRepository => sl<AuthRepository>();
  
  // Blocs singleton
  AppDataBloc get appDataBloc => sl<AppDataBloc>();
  CreditsBloc get creditsBloc => sl<CreditsBloc>();
  AuthBloc get authBloc => sl<AuthBloc>();
  NotificationBloc get notificationBloc => sl<NotificationBloc>();
  LocaleBloc get localeBloc => sl<LocaleBloc>();
  ThemeBloc get themeBloc => sl<ThemeBloc>();
}