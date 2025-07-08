import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:runaway/config/environment_config.dart';
import 'package:runaway/config/router.dart';
import 'package:runaway/config/theme.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/core/di/service_locator.dart';
import 'package:runaway/core/services/app_initialization_service.dart';
import 'package:runaway/core/services/conversion_service.dart';
import 'package:runaway/core/services/notification_service.dart';
import 'package:runaway/core/services/route_data_sync_wrapper.dart';
import 'package:runaway/core/widgets/auth_data_listener.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
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
    
    // Initialiser les services avec pré-chargement de géolocalisation
    await AppInitializationService.initialize();

    // Configurer Mapbox
    String mapBoxToken = dotenv.get('MAPBOX_TOKEN');
    MapboxOptions.setAccessToken(mapBoxToken);
    print('✅ Mapbox configuré');

    await NotificationService.instance.initialize();
    await ConversionService.instance.initializeSession();

    // Initialiser l'injection de dépendances
    await ServiceLocator.init();
    print('✅ ServiceLocator initialisé');
    
    runApp(const Trailix());
    
  } catch (e) {
    print('❌ Erreur lors de l\'initialisation: $e');
    runApp(ErrorApp(error: e.toString()));
  }
}

class Trailix extends StatefulWidget {
  const Trailix({super.key});

  @override
  State<Trailix> createState() => _TrailixState();
}

class _TrailixState extends State<Trailix> {

  @override
  void dispose() {
    // Nettoyer les services
    NotificationService.instance.dispose();
    ServiceLocator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Utilisation de GetIt pour récupérer les instances
        BlocProvider<NotificationBloc>.value(value: sl<NotificationBloc>()),
        BlocProvider<AppDataBloc>.value(value: sl<AppDataBloc>()),
        BlocProvider<AuthBloc>.value(value: sl<AuthBloc>()),
        BlocProvider<LocaleBloc>.value(value: sl<LocaleBloc>()),
        BlocProvider<ThemeBloc>.value(value: sl<ThemeBloc>()),
        BlocProvider<CreditsBloc>.value(value: sl<CreditsBloc>()),
        
        // Factory pour les blocs qui peuvent avoir plusieurs instances
        BlocProvider<RouteParametersBloc>(create: (_) => sl<RouteParametersBloc>()),
        BlocProvider<RouteGenerationBloc>(create: (_) => sl<RouteGenerationBloc>()),
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
                    themeMode: themeState.themeMode.toThemeMode(),
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

class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Erreur d\'initialisation'),
              const SizedBox(height: 8),
              Text(error, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}