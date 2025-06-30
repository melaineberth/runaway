import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:runaway/config/environment_config.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/config/router.dart';
import 'package:runaway/config/theme.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/core/services/app_data_initialization_service.dart';
import 'package:runaway/core/services/app_initialization_service.dart';
import 'package:runaway/core/services/route_data_sync_wrapper.dart';
import 'package:runaway/core/widgets/auth_data_listener.dart';
import 'package:runaway/features/activity/data/repositories/activity_repository.dart';
import 'package:runaway/features/activity/presentation/blocs/activity_bloc.dart';
import 'package:runaway/features/auth/data/repositories/auth_repository.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/blocs/app_bloc_observer.dart';
import 'features/home/presentation/blocs/route_parameters_bloc.dart';
import 'features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Observer pour debug
    Bloc.observer = AppBlocObserver();

    // Charger les variables d'environnement
    await dotenv.load(fileName: ".env");

    // Valider la configuration d'environnement
    EnvironmentConfig.validate();

    // Initialiser HydratedBloc pour la persistance
    final directory = await getApplicationDocumentsDirectory();
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(directory.path),
    );
    print('✅ HydratedBloc storage initialisé');

    // Initialiser Supabase
    await Supabase.initialize(
      url: dotenv.get('SUPABASE_URL'),
      anonKey: dotenv.get('SUPABASE_ANON_KEY'),
    );
    print('✅ Supabase initialisé');
    
    // ✅ NOUVEAU: Initialiser les services avec pré-chargement de géolocalisation
    await AppInitializationService.initialize();

    // Configurer Mapbox
    String mapBoxToken = dotenv.get('MAPBOX_TOKEN');
    MapboxOptions.setAccessToken(mapBoxToken);
    print('✅ Mapbox configuré');
    
    runApp(const RunAway());
    
  } catch (e) {
    print('❌ Erreur lors de l\'initialisation: $e');
    runApp(ErrorApp(error: e.toString()));
  }
}

class RunAway extends StatelessWidget {
  const RunAway({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // AppDataBloc - DOIT être créé EN PREMIER
        BlocProvider<AppDataBloc>(
          create: (context) {
            print('🔧 Création du AppDataBloc...');
            final appDataBloc = AppDataBloc(
              activityRepository: ActivityRepository(),
              routesRepository: RoutesRepository(),
            );
            
            // Initialiser le service IMMÉDIATEMENT après création du BLoC
            AppDataInitializationService.initialize(appDataBloc);
            print('✅ AppDataInitializationService initialisé');
            
            return appDataBloc;
          },
        ),
        
        // AuthBloc - créé APRÈS AppDataBloc
        BlocProvider(
          create: (context) {
            print('🔧 Création du AuthBloc...');
            final authBloc = AuthBloc(AuthRepository());
            // Déclencher l'initialisation de l'authentification
            authBloc.add(AppStarted());
            return authBloc;
          },
        ),
        
        BlocProvider(
          create: (_) => RouteParametersBloc(
            startLongitude: 0.0, // Sera mis à jour avec la position réelle
            startLatitude: 0.0,
          ),
        ),
        
        // RouteGenerationBloc - IMPORTANT pour la synchronisation
        BlocProvider(
          create: (_) {
            print('🔧 Création du RouteGenerationBloc...');
            return RouteGenerationBloc(
              routesRepository: RoutesRepository(),
            );
          },
        ),

        BlocProvider(
          create: (_) {
            final localeBloc = LocaleBloc();
            localeBloc.add(const LocaleInitialized());
            return localeBloc;
          },
        ),

        // ActivityBloc - maintenant moins critique
        BlocProvider<ActivityBloc>(
          create: (context) => ActivityBloc(
            activityRepository: ActivityRepository(),
            routesRepository: RoutesRepository(),
          ),
        ),

        BlocProvider(
          create: (_) {
            final themeBloc = ThemeBloc();
            themeBloc.add(const ThemeInitialized());
            return themeBloc;
          },
        ),
      ],
      child: AuthDataListener(
        child: RouteDataSyncWrapper(
          child: BlocBuilder<LocaleBloc, LocaleState>(
            builder: (context, localeState) {
              return BlocBuilder<ThemeBloc, ThemeState>(
                builder: (context, themeState) {
                  return MaterialApp.router(
                    title: 'Trailix',
                    debugShowCheckedModeBanner: false,
                    routerConfig: router,
                    theme: getAppTheme(Brightness.light),
                    darkTheme: getAppTheme(Brightness.dark),
                    themeMode: themeState.themeMode.toThemeMode(), // ← Changement ici
                    locale: localeState.locale,
                    localizationsDelegates: AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
                        child: child ?? Container(),
                      );
                    },
                  );
                }
              );
            }
          ),
        ),
      ),
    );
  }
}

/// 🆕 Widget d'erreur en cas d'échec d'initialisation
class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  context.l10n.error,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Redémarrer l'app
                    main();
                  },
                  child: Text(context.l10n.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}