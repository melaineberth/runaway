import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:runaway/config/router.dart';
import 'package:runaway/config/secure_config.dart';
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
import 'package:runaway/core/services/session_manager.dart';
import 'package:runaway/core/widgets/auth_data_listener.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/credits/data/services/iap_service.dart';
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

    // ✅ PHASE 1 : Initialisation parallèle des services critiques
    await _initializeCriticalServices();

    // ✅ PHASE 2 : Initialisation parallèle des services secondaires  
    await _initializeSecondaryServices();

    // ✅ PHASE 3 : Finalisation
    await _finalizeInitialization();
    
    runApp(const Trailix());
    
  } catch (e) {
    print('❌ Erreur lors de l\'initialisation: $e');
    SessionManager.instance.stopSessionMonitoring();
    runApp(ErrorApp(error: e.toString()));
  }
}

/// Phase 1 : Services critiques en parallèle
Future<void> _initializeCriticalServices() async {
  print('🚀 Phase 1 : Initialisation services critiques...');
  
  await Future.wait([
    // Configuration et environnement
    _loadEnvironmentConfig(),
    // Storage local pour HydratedBloc
    _initializeHydratedStorage(),
  ]);
  
  print('✅ Phase 1 terminée');
}

/// Phase 2 : Services secondaires en parallèle
Future<void> _initializeSecondaryServices() async {
  print('🚀 Phase 2 : Initialisation services secondaires...');
  
  // ✅ D'abord Supabase, puis les services qui en dépendent
  await _initializeSupabase();
  
  await Future.wait([
    // Services externes (après Supabase)
    _initializeIAP(),
    _initializeSessionMonitoring(), // ✅ Maintenant après Supabase
    // Services de notification
    _initializeNotificationServices(),
  ]);
  
  print('✅ Phase 2 terminée');
}

/// Phase 3 : Finalisation et DI
Future<void> _finalizeInitialization() async {
  print('🚀 Phase 3 : Finalisation...');
  
  await Future.wait([
    // Configuration Mapbox
    _configureMapbox(),
    // Initialisation des services app
    AppInitializationService.initialize(),
    // Injection de dépendances
    ServiceLocator.init(),
    // Services de conversion
    _initializeConversionService(),
  ]);
  
  print('✅ Phase 3 terminée');
}

// ===== SERVICES INDIVIDUELS =====

Future<void> _loadEnvironmentConfig() async {
  try {
    await dotenv.load(fileName: ".env");
    SecureConfig.validateConfiguration();
    print('✅ Configuration environnement chargée');
  } catch (e) {
    print('❌ Erreur chargement environnement: $e');
    rethrow;
  }
}

Future<void> _initializeHydratedStorage() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(directory.path),
    );
    print('✅ HydratedBloc storage initialisé');
  } catch (e) {
    print('❌ Erreur HydratedStorage: $e');
    rethrow;
  }
}

Future<void> _initializeSupabase() async {
  try {
    await Supabase.initialize(
      url: SecureConfig.supabaseUrl,
      anonKey: SecureConfig.supabaseAnonKey,
    );
    print('✅ Supabase initialisé');
  } catch (e) {
    print('❌ Erreur Supabase: $e');
    rethrow;
  }
}

/// ✅ Session monitoring maintenant après Supabase
Future<void> _initializeSessionMonitoring() async {
  try {
    SessionManager.instance.startSessionMonitoring();
    print('✅ Session monitoring démarré');
  } catch (e) {
    print('⚠️ Erreur session monitoring (non bloquant): $e');
    // Non critique, continue l'initialisation
  }
}

Future<void> _initializeIAP() async {
  try {
    await IAPService.initialize();
    print('✅ IAP initialisé');
  } catch (e) {
    print('⚠️ Erreur IAP (non bloquant): $e');
    // Non critique pour le démarrage
  }
}

Future<void> _initializeNotificationServices() async {
  try {
    await NotificationService.instance.initialize();
    print('✅ Notifications initialisées');
  } catch (e) {
    print('⚠️ Erreur notifications (non bloquant): $e');
    // Non critique pour le démarrage
  }
}

Future<void> _configureMapbox() async {
  try {
    MapboxOptions.setAccessToken(SecureConfig.mapboxToken);
    print('✅ Mapbox configuré');
  } catch (e) {
    print('⚠️ Erreur Mapbox (non bloquant): $e');
    // Non critique pour le démarrage
  }
}

Future<void> _initializeConversionService() async {
  try {
    await ConversionService.instance.initializeSession();
    print('✅ Service de conversion initialisé');
  } catch (e) {
    print('⚠️ Erreur service conversion (non bloquant): $e');
    // Non critique pour le démarrage
  }
}

class Trailix extends StatefulWidget {
  const Trailix({super.key});

  @override
  State<Trailix> createState() => _TrailixState();
}

class _TrailixState extends State<Trailix> {
  StreamSubscription<SessionEvent>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    
    // 🆕 Écouter les événements de session
    _sessionSubscription = SessionManager.instance.sessionEvents.listen((event) {
      if (event.status == SessionStatus.expired || event.status == SessionStatus.error) {
        // Rediriger vers l'écran de connexion ou afficher un message
        print('⚠️ Session ${event.status}: ${event.reason}');
      }
    });
  }

  @override
  void dispose() {
    // Nettoyer les services
    _sessionSubscription?.cancel();
    SessionManager.instance.dispose();
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