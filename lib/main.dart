import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:runaway/config/environment_config.dart';
import 'package:runaway/config/router.dart';
import 'package:runaway/config/theme.dart';
import 'package:runaway/features/auth/data/repositories/auth_repository.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/blocs/app_bloc_observer.dart';
import 'features/home/presentation/blocs/route_parameters_bloc.dart';
import 'features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Observer pour debug
  Bloc.observer = AppBlocObserver();

  // Charger les variables d'environnement
  await dotenv.load(fileName: ".env");

  // Valider la configuration d'environnement
  try {
    EnvironmentConfig.validate();
  } catch (e) {
    print('❌ Erreur de configuration: $e');
    // En mode debug, continuer malgré les erreurs de config
    // En production, vous pourriez vouloir arrêter l'app
  }

  // Initialiser HydratedBloc pour la persistance
  try {
    final directory = await getApplicationDocumentsDirectory();
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(directory.path),
    );
    print('✅ HydratedBloc storage initialisé');
  } catch (e) {
    print('❌ Erreur HydratedBloc storage: $e');
  }

  // Initialiser Supabase
  try {
    await Supabase.initialize(
      url: dotenv.get('SUPABASE_URL'),
      anonKey: dotenv.get('SUPABASE_ANON_KEY'),
    );
    print('✅ Supabase initialisé');
  } catch (e) {
    print('❌ Erreur Supabase: $e');
  }

  // Configurer Mapbox
  try {
    String mapBoxToken = dotenv.get('MAPBOX_TOKEN');
    MapboxOptions.setAccessToken(mapBoxToken);
    print('✅ Mapbox configuré');
  } catch (e) {
    print('❌ Erreur Mapbox: $e');
  }

  runApp(const RunAway());
}

class RunAway extends StatelessWidget {
  const RunAway({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // AuthBloc - IMPORTANT: doit être en premier pour les dépendances
        BlocProvider(
          create: (context) {
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
        
        BlocProvider(
          create: (_) => RouteGenerationBloc(
            routesRepository: RoutesRepository(),
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'RunAway - Générateur de Parcours',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: getAppTheme(Brightness.light),
        darkTheme: getAppTheme(Brightness.dark),
        themeMode: ThemeMode.dark, // Force le thème sombre pour votre design
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
        ],
        // Configuration globale
        builder: (context, child) {
          return MediaQuery(
            // Empêcher le scaling des polices système
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
            child: child ?? Container(),
          );
        },
      ),
    );
  }
}