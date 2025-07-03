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

    // Blocs - Singletons pour ceux qui doivent être partagés
    sl.registerLazySingleton<NotificationBloc>(() {
      final bloc = NotificationBloc();
      bloc.add(NotificationInitializeRequested());
      return bloc;
    });

    sl.registerLazySingleton<AppDataBloc>(() {
      print('🔧 Création du AppDataBloc...');
      final appDataBloc = AppDataBloc(
        activityRepository: sl<ActivityRepository>(),
        routesRepository: sl<RoutesRepository>(),
      );
      
      // Initialiser le service IMMÉDIATEMENT après création du BLoC
      AppDataInitializationService.initialize(appDataBloc);
      print('✅ AppDataInitializationService initialisé');
      
      return appDataBloc;
    });

    sl.registerLazySingleton<AuthBloc>(() {
      print('🔧 Création du AuthBloc...');
      final authBloc = AuthBloc(sl<AuthRepository>());
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

    sl.registerFactory<RouteGenerationBloc>(() {
      print('🔧 Création du RouteGenerationBloc...');
      return RouteGenerationBloc(
        routesRepository: sl<RoutesRepository>(),
      );
    });
  }

  static void dispose() {
    sl.reset();
  }
}