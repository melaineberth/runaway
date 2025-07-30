import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:runaway/core/blocs/connectivity/connectivity_cubit.dart';
import 'package:runaway/core/errors/app_exceptions.dart';
import 'package:runaway/core/errors/error_handler.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';
import 'package:runaway/core/helper/services/logging_service.dart';
import 'package:runaway/core/router/router.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:runaway/core/styles/theme.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/core/utils/injections/service_locator.dart';
import 'package:runaway/core/helper/services/app_initialization_service.dart';
import 'package:runaway/core/helper/services/conversion_service.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/core/helper/services/notification_service.dart';
import 'package:runaway/core/helper/services/route_data_sync_wrapper.dart';
import 'package:runaway/core/helper/services/session_manager.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_data_listener.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/credits/data/services/iap_service.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/l10n/app_localizations.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import 'features/home/presentation/blocs/route_parameters_bloc.dart';
import 'features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';

void main() async {
  // 🆕 Capture des erreurs Dart avant l'initialisation Flutter
  runZonedGuarded(() async {
    LogConfig.logInfo('🚀 Démarrage Trailix...');

    // === INITIALISATION FLUTTER ===
    SentryWidgetsFlutterBinding.ensureInitialized();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    // === CONFIGURATION DES ORIENTATIONS ===
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown
    ]);

    try {
      // Initialisation parallèle des services critiques
      await _initializeCriticalServices();

      // Initialisation du monitoring (avant tout le reste)
      await _initializeMonitoring();

      // Initialisation parallèle des services secondaires  
      await _initializeSecondaryServices();

      // Finalisation
      await _finalizeInitialization();

      LogConfig.logSuccess('🚀 Trailix initialisé avec succès');
      
      runApp(const Trailix());
      
    } catch (error, stackTrace) {
      // Gestion des erreurs critiques d'initialisation
      await _handleCriticalError(error, stackTrace);
    }
  }, (error, stackTrace) async {
    // Zone guard pour capturer toutes les erreurs non gérées
    await _handleUnhandledError(error, stackTrace);
  });
}

// ===== PHASE D'INITIALISATION =====

/// Services critiques en parallèle
Future<void> _initializeCriticalServices() async {
  LogConfig.logInfo('🚀 Phase 1: Services critiques...');
  
  try {
    await Future.wait([
      _testSecureStorage(),
      // Configuration et environnement
      _loadEnvironmentConfig(),
      // Storage local pour HydratedBloc
      _initializeHydratedStorage(),
      // ConnectivityService dès le début
      _initializeConnectivityServiceEarly(),
    ]);
    
    LogConfig.logSuccess('✅ Services critiques OK');

  } catch (e) {
    throw ConfigurationException(
      'Erreur lors du chargement de la configuration',
      code: 'CONFIG_LOAD_ERROR',
      originalError: e,
    );
  }
}

/// Initialisation du monitoring
Future<void> _initializeMonitoring() async {  
  try {
    // Initialiser le service principal de monitoring
    await MonitoringService.instance.initialize();
    
    // 🆕 Configurer le BlocObserver amélioré MAINTENANT
    Bloc.observer = MonitoringService.instance.blocObserver;
    
    // Log de succès
    LoggingService.instance.info(
      'MainApp',
      'Monitoring initialisé avec succès',
      data: {
        'crash_reporting': SecureConfig.isCrashReportingEnabled,
        'performance_monitoring': SecureConfig.isPerformanceMonitoringEnabled,
        'environment': SecureConfig.sentryEnvironment,
      },
    );
    
    LogConfig.logDebug('Monitoring initialisé');
    
  } catch (e) {
    LogConfig.logWarning('Monitoring échoué: $e');
    
    // Non critique, on continue
    ErrorHandler.instance.handleSilentError(
      e,
      contextInfo: 'Monitoring Initialization',
    );
  }
}

/// Services secondaires en parallèle
Future<void> _initializeSecondaryServices() async {
  LogConfig.logInfo('🚀 Phase 2: Services secondaires...');
  
  try {    
    // Services avec gestion d'erreur non-bloquante
    await Future.wait([
      // ✅ D'abord Supabase, puis les services qui en dépendent
      _initializeSupabase().catchError((e) {
        LogConfig.logWarning('⚠️ Supabase: $e');
        return null;
      }),
      // Services externes (après Supabase)
      _initializeIAP().catchError((e) {
        LogConfig.logWarning('⚠️ Monitoring: $e');
        return null;
      }),
      _initializeSessionMonitoring().catchError((e) {
        LogConfig.logWarning('⚠️ Monitoring: $e');
        return null;
      }),
      // Services de notification
      _initializeNotificationServices().catchError((e) {
        LogConfig.logWarning('⚠️ Monitoring: $e');
        return null;
      }),
    ]);
    
    LogConfig.logSuccess('✅ Services secondaires OK');

  } catch (e) {
    LogConfig.logWarning('⚠️ Certains services secondaires ont échoué: $e');
  }
}

/// Finalisation et DI
Future<void> _finalizeInitialization() async {
  LogConfig.logInfo('🚀 Phase 3: Finalisation...');
  
  try {
    await Future.wait([
      // Configuration Mapbox
      _configureMapbox().catchError((e) {
        LogConfig.logWarning('⚠️ Mapbox: $e');
        return null;
      }),
      // Initialisation des services app
      AppInitializationService.initialize(),
      // Injection de dépendances
      ServiceLocator.init(),
      // Services de conversion
      _initializeConversionService().catchError((e) {
        LogConfig.logWarning('⚠️ Conversion: $e');
        return null;
      }),
    ]);
    
    LogConfig.logSuccess('✅ Finalisation OK');
    
  } catch (e) {
    LogConfig.logWarning('⚠️ Erreurs non-critiques en finalisation: $e');

    await ErrorHandler.instance.handleError(
      e,
      contextInfo: 'Application Initialization',
      config: const ErrorDisplayConfig(
        type: ErrorDisplayType.dialog,
        showDetails: true,
      ),
    );
  }
}

// ===== SERVICES INDIVIDUELS =====

/// Gère les erreurs critiques d'initialisation
Future<void> _handleCriticalError(dynamic error, StackTrace stackTrace) async {
  LogConfig.logError('❌ ERREUR CRITIQUE D\'INITIALISATION: $error');
  print('Stack trace: $stackTrace');
  
  try {
    // Tentative de log via le service de monitoring
    await MonitoringService.instance.captureError(
      error,
      stackTrace,
      context: 'Critical Initialization Error',
    );
  } catch (e) {
    LogConfig.logError('❌ Impossible de logger l\'erreur critique: $e');
  }
  
  // Lancement de l'app d'erreur
  runApp(ErrorApp(error: error.toString()));
}

/// Gère les erreurs non gérées
Future<void> _handleUnhandledError(dynamic error, StackTrace stackTrace) async {
  LogConfig.logError('❌ ERREUR NON GÉRÉE: $error');
  
  try {
    // Log de l'erreur
    await MonitoringService.instance.captureError(
      error,
      stackTrace,
      context: 'Unhandled Error',
    );
    
    // Gestion via ErrorHandler si disponible
    await ErrorHandler.instance.handleError(
      error,
      contextInfo: 'Unhandled Application Error',
      config: const ErrorDisplayConfig(
        type: ErrorDisplayType.dialog,
        showDetails: true,
      ),
    );
  } catch (e) {
    LogConfig.logError('❌ Erreur lors de la gestion d\'erreur non gérée: $e');
  }
}

Future<void> _loadEnvironmentConfig() async {
  final operationId = MonitoringService.instance.trackOperation(
    'load_environment_config',
    description: 'Chargement configuration environnement',
  );
  
  try {
    await dotenv.load(fileName: ".env");
    SecureConfig.validateConfiguration();
    LogConfig.logDebug('Config initialisé');
    
    MonitoringService.instance.finishOperation(operationId, success: true);
  } catch (e) {
    LogConfig.logError('Config échoué: $e');
    MonitoringService.instance.finishOperation(
      operationId, 
      success: false, 
      errorMessage: e.toString(),
    );
    rethrow;
  }
}

Future<void> _testSecureStorage() async {
  try {        
    final isHealthy = await SecureConfig.checkSecureStorageHealth();
    
    if (!isHealthy) {
      await SecureConfig.forceKeychainCleanup();
    }
  } catch (e) {
    LogConfig.logError('❌ Erreur de stockage sécurisé: $e');
  }
}

Future<void> _initializeHydratedStorage() async {
  final operationId = MonitoringService.instance.trackOperation(
    'initialize_hydrated_storage',
    description: 'Initialisation stockage local persistant',
  );
  
  try {
    final directory = await getApplicationDocumentsDirectory();
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(directory.path),
    );
    LogConfig.logDebug('HydratedBloc initialisé');
    
    MonitoringService.instance.finishOperation(operationId, success: true);
  } catch (e) {
    LogConfig.logError('Erreur HydratedStorage: $e');
    
    throw StorageException(
      'Impossible d\'initialiser le stockage persistant',
      code: 'HYDRATED_STORAGE_ERROR',
      originalError: e,
    );
  }
}

Future<void> _initializeSupabase() async {
  final operationId = MonitoringService.instance.trackOperation(
    'initialize_supabase',
    description: 'Connexion à Supabase',
    data: {
      'url': SecureConfig.supabaseUrl,
      'environment': SecureConfig.sentryEnvironment,
    },
  );
  
  try {
    await Supabase.initialize(
      url: SecureConfig.supabaseUrl,
      anonKey: SecureConfig.supabaseAnonKey,
      debug: false,
    );
    LogConfig.logDebug('Supabase initialisé');
    
    // Maintenant vérifier les tables de monitoring
    await MonitoringService.instance.checkSupabaseTablesLater();
    
    MonitoringService.instance.finishOperation(operationId, success: true);
  } catch (e) {
    LogConfig.logError('Erreur Supabase: $e');
    MonitoringService.instance.finishOperation(
      operationId, 
      success: false, 
      errorMessage: e.toString(),
    );
    rethrow;
  }
}

Future<void> _initializeConnectivityServiceEarly() async {
  try {
    await ConnectivityService.instance.initialize();
    LogConfig.logDebug('Connectivité initialisée');
    
    LoggingService.instance.info(
      'ConnectivityService',
      'Service de connectivité initialisé',
    );
  } catch (e) {
    LogConfig.logError('ConnectivityService échoué: $e');
    
    // Critique pour le fonctionnement
    throw NetworkException(
      'Impossible d\'initialiser la connectivité',
      code: 'CONNECTIVITY_INIT_ERROR',
      originalError: e,
    );
  }
}

Future<void> _initializeSessionMonitoring() async {
  try {
    SessionManager.instance.startSessionMonitoring();
    LogConfig.logDebug('Session monitoring démarré');
    
    LoggingService.instance.info(
      'SessionManager',
      'Session monitoring démarré avec succès',
    );
  } catch (e) {
    LogConfig.logWarning('Session monitoring échoué: $e');
    
    LoggingService.instance.warning(
      'SessionManager',
      'Erreur démarrage session monitoring',
      data: {'error': e.toString()},
    );
  }
}

Future<void> _initializeIAP() async {
  try {
    await IAPService.initialize();
    LogConfig.logDebug('IAP initialisé');
    
    LoggingService.instance.info(
      'IAPService',
      'Service d\'achat intégré initialisé',
    );
  } catch (e) {
    LogConfig.logWarning('IAP échoué: $e');
    
    ErrorHandler.instance.handleSilentError(
      e,
      contextInfo: 'IAP Initialization',
    );
  }
}

Future<void> _initializeNotificationServices() async {
  try {
    await NotificationService.instance.initialize();
    LogConfig.logDebug('Notifications initialisées');
    
    LoggingService.instance.info(
      'NotificationService',
      'Service de notifications initialisé',
    );
  } catch (e) {
    LogConfig.logWarning('Notifications échouées: $e');
    
    ErrorHandler.instance.handleSilentError(
      e,
      contextInfo: 'Notification Service Initialization',
    );
  }
}

Future<void> _configureMapbox() async {
  try {
    MapboxOptions.setAccessToken(SecureConfig.mapboxToken);
    LogConfig.logDebug('Mapbox configuré');
    
    LoggingService.instance.info(
      'MapboxService',
      'Token Mapbox configuré avec succès',
    );
  } catch (e) {
    LogConfig.logWarning('Mapbox échoué: $e');
    
    ErrorHandler.instance.handleSilentError(
      e,
      contextInfo: 'Mapbox Configuration',
    );
  }
}

Future<void> _initializeConversionService() async {
  try {
    await ConversionService.instance.initializeSession();
    LogConfig.logDebug('ConversionService initialisé');
    
    LoggingService.instance.info(
      'ConversionService',
      'Service de conversion initialisé',
    );
  } catch (e) {
    LogConfig.logWarning('ConversionService échoué: $e');
    
    ErrorHandler.instance.handleSilentError(
      e,
      contextInfo: 'Conversion Service Initialization',
    );
  }
}

// ===== APP PRINCIAPLE =====

class Trailix extends StatefulWidget {
  const Trailix({super.key});

  @override
  State<Trailix> createState() => _TrailixState();
}

class _TrailixState extends State<Trailix> with WidgetsBindingObserver {
  StreamSubscription<SessionEvent>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupSessionListener();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }


  /// Configure l'écoute des événements de session
  void _setupSessionListener() {
    try {
      _sessionSubscription = SessionManager.instance.sessionEvents.listen(
        (event) => _handleSessionEvent(event),
        onError: (error) async {
          ErrorHandler.instance.handleSilentError(
            error,
            contextInfo: 'Session Event Stream',
          );
        },
      );
    } catch (e) {
      ErrorHandler.instance.handleSilentError(
        e,
        contextInfo: 'Session Listener Setup',
      );
    }
  }

  /// Gère les événements de session
  void _handleSessionEvent(SessionEvent event) {
    // Gestion des événements de session selon vos besoins
    LogConfig.logInfo('📡 Événement de session: ${event.reason}');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    try {
      switch (state) {
        case AppLifecycleState.resumed:
          _handleAppResumed();
          break;
        case AppLifecycleState.paused:
          _handleAppPaused();
          break;
        case AppLifecycleState.detached:
          _handleAppDetached();
          break;
        default:
          break;
      }
    } catch (e) {
      ErrorHandler.instance.handleSilentError(
        e,
        contextInfo: 'App Lifecycle Change',
      );
    }
  }

  void _handleAppResumed() {
    LogConfig.logInfo('📱 App resumed');
    // Vérification de la connectivité, refresh des tokens, etc.
  }

  void _handleAppPaused() {
    LogConfig.logInfo('📱 App paused');
    // Sauvegarde des données, nettoyage, etc.
  }

  void _handleAppDetached() {
    LogConfig.logInfo('📱 App detached');
    // Nettoyage final
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
        BlocProvider<ConnectivityCubit>.value(value: sl<ConnectivityCubit>()),
        
        // Factory pour les blocs qui peuvent avoir plusieurs instances
        BlocProvider<RouteParametersBloc>(create: (_) => sl<RouteParametersBloc>()),
        BlocProvider<RouteGenerationBloc>(create: (_) => sl<RouteGenerationBloc>()),
      ],
      child: AuthDataListener(
        child: RouteDataSyncWrapper(
          child: BlocBuilder<LocaleBloc, LocaleState>(
            // Éviter les rebuilds inutiles pour locale
            buildWhen: (previous, current) => previous.locale != current.locale,
            builder: (context, localeState) {
              return BlocBuilder<ThemeBloc, ThemeState>(
                // Éviter les rebuilds inutiles pour theme
                buildWhen: (previous, current) => previous.themeMode != current.themeMode,
                builder: (context, themeState) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: MaterialApp.router(
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
                        // Global error boundary pour l'UI
                        return _AppErrorBoundary(
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaler: TextScaler.linear(1.0),
                            ),
                            child: child ?? Container(),
                          ),
                        );
                      },
                    ),
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

/// Widget de gestion d'erreurs globale pour l'UI
class _AppErrorBoundary extends StatelessWidget {
  final Widget child;
  
  const _AppErrorBoundary({required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

// ===== APPLICATION D'ERREUR CRITIQUE =====

class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trailix - Erreur',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Erreur d\'initialisation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'L\'application n\'a pas pu démarrer correctement. Veuillez redémarrer l\'application.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Détails techniques:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    // Tentative de redémarrage
                    SystemNavigator.pop();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Redémarrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}