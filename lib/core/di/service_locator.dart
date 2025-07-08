// ============================================
// CORRECTION du lib/core/di/service_locator.dart
// ============================================

import 'package:get_it/get_it.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_event.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/core/services/app_data_initialization_service.dart';
import 'package:runaway/features/activity/data/repositories/activity_repository.dart';
import 'package:runaway/features/auth/data/repositories/auth_repository.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/home/data/services/map_state_service.dart';
import 'package:runaway/features/home/presentation/blocs/route_parameters_bloc.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';

final GetIt sl = GetIt.instance;

class ServiceLocator {
  static Future<void> init() async {
    // Repositories
    sl.registerLazySingleton<ActivityRepository>(() => ActivityRepository());
    sl.registerLazySingleton<RoutesRepository>(() => RoutesRepository());
    sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
    sl.registerLazySingleton<MapStateService>(() => MapStateService());
    sl.registerLazySingleton<CreditsRepository>(() => CreditsRepository());

    // Blocs - Singletons pour ceux qui doivent être partagés
    sl.registerLazySingleton<NotificationBloc>(() {
      final bloc = NotificationBloc();
      bloc.add(NotificationInitializeRequested());
      return bloc;
    });

    // 🆕 CreditsBloc comme SINGLETON (une seule instance partagée)
    sl.registerLazySingleton<CreditsBloc>(() {
      print('🔧 Création du CreditsBloc (SINGLETON)...');
      final creditsBloc = CreditsBloc(
        creditsRepository: sl<CreditsRepository>(),
      );
      return creditsBloc;
    });

    sl.registerLazySingleton<AppDataBloc>(() {
      print('🔧 Création du AppDataBloc...');
      final appDataBloc = AppDataBloc(
        activityRepository: sl<ActivityRepository>(),
        routesRepository: sl<RoutesRepository>(),
        mapStateService: sl<MapStateService>(), 
      );
      
      // Initialiser le service IMMÉDIATEMENT après création du BLoC
      AppDataInitializationService.initialize(appDataBloc);
      print('✅ AppDataInitializationService initialisé');
      
      return appDataBloc;
    });

    // 🆕 AuthBloc utilise l'instance SINGLETON de CreditsBloc
    sl.registerLazySingleton<AuthBloc>(() {
      print('🔧 Création du AuthBloc...');
      final authBloc = AuthBloc(
        authRepository: sl<AuthRepository>(),
        creditsBloc: sl<CreditsBloc>(), // 🔑 Utiliser l'instance singleton
      );
      // Déclencher l'initialisation de l'authentification
      authBloc.add(AppStarted());
      return authBloc;
    });

    sl.registerLazySingleton<LocaleBloc>(() {
      final localeBloc = LocaleBloc();
      localeBloc.add(const LocaleInitialized());
      return localeBloc;
    });

    sl.registerLazySingleton<ThemeBloc>(() {
      final themeBloc = ThemeBloc();
      themeBloc.add(const ThemeInitialized());
      return themeBloc;
    });

    // Factory pour les blocs qui peuvent avoir plusieurs instances
    sl.registerFactory<RouteParametersBloc>(() => RouteParametersBloc(
      startLongitude: 0.0,
      startLatitude: 0.0,
    ));

    // 🆕 RouteGenerationBloc utilise l'instance SINGLETON de CreditsBloc
    sl.registerFactory<RouteGenerationBloc>(() {
      print('🔧 Création du RouteGenerationBloc...');
      return RouteGenerationBloc(
        routesRepository: sl<RoutesRepository>(), 
        creditsBloc: sl<CreditsBloc>(), // 🔑 Utiliser l'instance singleton
        creditsRepository: sl<CreditsRepository>(), // 🆕 Injecter le repository aussi
      );
    });
  }

  static void dispose() {
    sl.reset();
  }
}