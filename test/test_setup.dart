// test/test_setup.dart - Version simplifiée
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/features/auth/data/repositories/auth_repository.dart';
import 'package:runaway/features/home/data/services/map_state_service.dart';

/// Configuration ultra-simplifiée pour les tests
class TestSetup {
  static bool _isInitialized = false;
  static Directory? _tempDir;

  /// Initialise les services nécessaires pour les tests
  static Future<void> initialize() async {
    if (_isInitialized) return;

    TestWidgetsFlutterBinding.ensureInitialized();

    try {
      // 1. Initialiser dotenv en mémoire
      _initializeDotenvInMemory();

      // 2. Initialiser HydratedStorage
      await _initializeHydratedStorage();

      // 3. Initialiser Supabase (basic)
      _initializeSupabaseBasic();

      // 4. Configurer GetIt (basic)
      _setupGetItBasic();

      _isInitialized = true;
      LogConfig.logInfo('✅ Test setup initialisé avec succès');

    } catch (e) {
      LogConfig.logError('❌ Erreur initialisation tests: $e');
      rethrow;
    }
  }

  /// Nettoie les ressources après les tests
  static Future<void> cleanup() async {
    try {
      if (GetIt.instance.isRegistered<AppDataBloc>()) {
        await GetIt.instance.reset();
      }

      if (_tempDir != null) {
        await _tempDir!.delete(recursive: true);
        _tempDir = null;
      }

      _isInitialized = false;
    } catch (e) {
      // Ignorer les erreurs de cleanup
    }
  }

  /// Initialise dotenv directement en mémoire
  static void _initializeDotenvInMemory() {
    dotenv.env.clear();
    dotenv.env.addAll({
      'MAPBOX_TOKEN': 'pk.test_token_for_tests_only',
      'SUPABASE_URL': 'https://test.supabase.co',
      'SUPABASE_ANON_KEY': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlc3QiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTY0NzY4NzI2MCwiZXhwIjoxOTYzMjYzMjYwfQ.test_signature',
      'WEB_CLIENT_ID_DEV': 'test.apps.googleusercontent.com',
      'IOS_CLIENT_ID_DEV': 'test.apps.googleusercontent.com',
      'SENTRY_DSN_DEV': 'https://test@sentry.io/test',
      'SENTRY_ENVIRONMENT_DEV': 'test',
      'ENABLE_CRASH_REPORTING': 'false',
      'ENABLE_PERFORMANCE_MONITORING': 'false',
      'LOG_LEVEL_DEV': 'debug',
      'ENVIRONMENT': 'test',
    });
  }

  /// Initialise HydratedStorage pour les tests
  static Future<void> _initializeHydratedStorage() async {
    _tempDir = await Directory.systemTemp.createTemp('trailix_test_');
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(_tempDir!.path),
    );
  }

  /// Initialise Supabase de manière basique
  static void _initializeSupabaseBasic() {
    try {
      Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlc3QiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTY0NzY4NzI2MCwiZXhwIjoxOTYzMjYzMjYwfQ.test_signature',
        debug: false,
      );
    } catch (e) {
      // Ignorer les erreurs d'initialisation Supabase en mode test
    }
  }

  /// Configure GetIt de manière basique
  static void _setupGetItBasic() {
    final sl = GetIt.instance;

    if (sl.isRegistered<AppDataBloc>()) {
      return; // Déjà configuré
    }

    try {
      // Services basiques seulement
      sl.registerLazySingleton<RoutesRepository>(() => RoutesRepository());
      sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
      sl.registerLazySingleton<MapStateService>(() => MapStateService());

      // Blocs basiques
      sl.registerLazySingleton<NotificationBloc>(() => NotificationBloc());
      sl.registerLazySingleton<LocaleBloc>(() => LocaleBloc());
      sl.registerLazySingleton<ThemeBloc>(() => ThemeBloc());

    } catch (e) {
      // Ignorer les erreurs de setup GetIt en mode test
    }
  }

  /// Obtient une instance configurée pour les tests
  static T getTestInstance<T extends Object>() {
    if (!_isInitialized) {
      throw StateError('TestSetup non initialisé. Appelez TestSetup.initialize() d\'abord.');
    }
    return GetIt.instance<T>();
  }

  /// Vérifie si le setup est initialisé
  static bool get isInitialized => _isInitialized;
}