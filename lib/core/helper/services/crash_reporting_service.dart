import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:runaway/core/helper/config/log_config.dart';

/// Service principal de crash reporting utilisant Sentry
class CrashReportingService {
  static CrashReportingService? _instance;
  static CrashReportingService get instance => _instance ??= CrashReportingService._();
  
  CrashReportingService._();

  bool _isInitialized = false;
  String? _userId;
  Map<String, dynamic> _userContext = {};

  /// Initialise Sentry avec la configuration sécurisée
  Future<void> initialize() async {
    if (_isInitialized) {
      LogConfig.logInfo('CrashReportingService déjà initialisé');
      return;
    }

    try {
      // Vérifier si le crash reporting est activé
      if (!SecureConfig.isCrashReportingEnabled) {
        LogConfig.logInfo('ℹ️ Crash reporting désactivé via configuration');
        return;
      }

      print('🚨 Initialisation Sentry...');

      await SentryFlutter.init(
        (options) {
          options.dsn = SecureConfig.sentryDsn;
          options.environment = SecureConfig.sentryEnvironment;
          options.release = SecureConfig.sentryRelease;
          
          // Configuration de l'échantillonnage
          options.sampleRate = SecureConfig.sentrySampleRate;
          options.tracesSampleRate = SecureConfig.sentryTracesSampleRate;
          
          // Configuration du debug
          options.debug = !SecureConfig.kIsProduction;
          
          // Attachements automatiques
          options.attachThreads = true;
          options.attachStacktrace = true;
          options.attachViewHierarchy = true;
          
          // Configuration des breadcrumbs
          options.maxBreadcrumbs = 100;
          options.enableAutoSessionTracking = true;
          
          // Performance monitoring si activé
          if (SecureConfig.isPerformanceMonitoringEnabled) {
            options.enableAutoPerformanceTracing = true;
            options.enableMemoryPressureBreadcrumbs = true;
            options.autoInitializeNativeSdk = true;
          }
          
          // Filtres pour éviter les erreurs non critiques
          options.beforeSend = _beforeSendFilter;
          options.beforeBreadcrumb = _beforeBreadcrumbFilter;
        },
      );

      // Configurer le contexte de l'appareil
      await _configureDeviceContext();

      _isInitialized = true;
      LogConfig.logInfo('Sentry initialisé avec succès');
      
      // Log de test si développement
      if (!SecureConfig.kIsProduction) {
        addBreadcrumb('CrashReportingService', 'Service initialisé');
      }

    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur initialisation Sentry: $e');
      print('Stack trace: $stackTrace');
      // Ne pas faire échouer l'app si Sentry n'arrive pas à s'initialiser
    }
  }

  /// Configure l'utilisateur connecté
  Future<void> setUser({
    required String userId,
    String? email,
    String? username,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isInitialized) return;

    try {
      _userId = userId;
      _userContext = {
        'id': userId,
        if (email != null) 'email': email,
        if (username != null) 'username': username,
        ...?additionalData,
      };

      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(
          id: userId,
          email: email,
          username: username,
          data: additionalData,
        ));
      });

      addBreadcrumb('User', 'Utilisateur configuré: $username');
      LogConfig.logInfo('👤 Utilisateur Sentry configuré: $userId');
    } catch (e) {
      LogConfig.logError('❌ Erreur configuration utilisateur Sentry: $e');
    }
  }

  /// Supprime les informations utilisateur (déconnexion)
  Future<void> clearUser() async {
    if (!_isInitialized) return;

    try {
      _userId = null;
      _userContext.clear();

      await Sentry.configureScope((scope) {
        scope.removeTag("user");
      });

      addBreadcrumb('User', 'Utilisateur déconnecté');
      LogConfig.logInfo('👤 Utilisateur Sentry supprimé');
    } catch (e) {
      LogConfig.logError('❌ Erreur suppression utilisateur Sentry: $e');
    }
  }

  /// Capture une exception avec contexte
  Future<void> captureException(
    dynamic exception,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? extra,
    SentryLevel level = SentryLevel.error,
  }) async {
    if (!_isInitialized) {
      LogConfig.logInfo('CrashReportingService non initialisé, exception ignorée: $exception');
      return;
    }

    try {
      await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (context != null) {
            scope.setTag('context', context);
          }
          
          if (extra != null) {
            for (final entry in extra.entries) {
              scope.setExtra(entry.key, entry.value);
            }
          }
          
          scope.level = level;
        },
      );

      // Log local si développement
      if (!SecureConfig.kIsProduction) {
        print('🚨 Exception capturée: $exception');
        if (context != null) print('   Contexte: $context');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur capture exception Sentry: $e');
    }
  }

  /// Capture un message avec niveau
  Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? extra,
    String? context,
  }) async {
    if (!_isInitialized) return;

    try {
      await Sentry.captureMessage(
        message,
        level: level,
        withScope: (scope) {
          if (context != null) {
            scope.setTag('context', context);
          }
          
          if (extra != null) {
            for (final entry in extra.entries) {
              scope.setExtra(entry.key, entry.value);
            }
          }
        },
      );
    } catch (e) {
      LogConfig.logError('❌ Erreur capture message Sentry: $e');
    }
  }

  /// Ajoute un breadcrumb pour tracer les actions utilisateur
  void addBreadcrumb(
    String category,
    String message, {
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
  }) {
    if (!_isInitialized) return;

    try {
      Sentry.addBreadcrumb(Breadcrumb(
        category: category,
        message: message,
        data: data,
        level: level,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      LogConfig.logError('❌ Erreur ajout breadcrumb: $e');
    }
  }

  /// Démarre une transaction de performance
  ISentrySpan? startTransaction(
    String name,
    String operation, {
    Map<String, dynamic>? data,
    bool bindToScope = true, // pour lier les erreurs capturées
  }) {
    if (!_isInitialized || !SecureConfig.isPerformanceMonitoringEnabled) {
      return null;
    }

    try {
      // Reprend la span courante s’il en existe déjà une (ex. instrumentation auto)
      final span = Sentry.getSpan() ??
          Sentry.startTransaction(
            name,
            operation,
            bindToScope: bindToScope,
          );

      // Ajoute des metadata optionnelles
      data?.forEach(span.setData);

      // Vous pouvez aussi retourner `span as SentryTransaction?`
      return span;
    } catch (e) {
      LogConfig.logError('❌ Erreur démarrage transaction: $e');
      return null;
    }
  }

  /// Configure le contexte de l'appareil
  Future<void> _configureDeviceContext() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      await Sentry.configureScope((scope) {
        // Informations de l'app
        scope.setTag('app_name', packageInfo.appName);
        scope.setTag('app_version', packageInfo.version);
        scope.setTag('build_number', packageInfo.buildNumber);
        scope.setTag('package_name', packageInfo.packageName);

        // Informations de l'environnement
        scope.setTag('environment', SecureConfig.sentryEnvironment);
        scope.setTag('is_production', SecureConfig.kIsProduction.toString());
        scope.setTag('platform', Platform.operatingSystem);

        // Informations spécifiques à la plateforme
        if (Platform.isAndroid) {
          _configureAndroidContext(deviceInfo, scope);
        } else if (Platform.isIOS) {
          _configureIOSContext(deviceInfo, scope);
        }
      });
    } catch (e) {
      LogConfig.logError('❌ Erreur configuration contexte appareil: $e');
    }
  }

  Future<void> _configureAndroidContext(DeviceInfoPlugin deviceInfo, Scope scope) async {
    try {
      final androidInfo = await deviceInfo.androidInfo;
      scope.setTag('device_model', androidInfo.model);
      scope.setTag('device_manufacturer', androidInfo.manufacturer);
      scope.setTag('android_version', androidInfo.version.release);
      scope.setTag('android_sdk', androidInfo.version.sdkInt.toString());
    } catch (e) {
      LogConfig.logError('❌ Erreur contexte Android: $e');
    }
  }

  Future<void> _configureIOSContext(DeviceInfoPlugin deviceInfo, Scope scope) async {
    try {
      final iosInfo = await deviceInfo.iosInfo;
      scope.setTag('device_model', iosInfo.model);
      scope.setTag('device_name', iosInfo.name);
      scope.setTag('ios_version', iosInfo.systemVersion);
      scope.setTag('is_physical_device', iosInfo.isPhysicalDevice.toString());
    } catch (e) {
      LogConfig.logError('❌ Erreur contexte iOS: $e');
    }
  }

  /// Filtre pour éviter les erreurs non critiques
  SentryEvent? _beforeSendFilter(SentryEvent event, Hint hint) {
    // Filtrer certaines erreurs non critiques
    final exception = event.throwable;
    if (exception != null) {
      final exceptionString = exception.toString().toLowerCase();
      
      // Ignorer les erreurs réseau temporaires
      if (exceptionString.contains('timeout') ||
          exceptionString.contains('network') ||
          exceptionString.contains('connection')) {
        return null;
      }
      
      // Ignorer les erreurs de permission non critiques
      if (exceptionString.contains('permission denied') &&
          !exceptionString.contains('camera') &&
          !exceptionString.contains('location')) {
        return null;
      }
    }

    return event;
  }

  /// Filtre pour les breadcrumbs
  Breadcrumb? _beforeBreadcrumbFilter(Breadcrumb? breadcrumb, Hint hint) {
    if (breadcrumb == null) return null; // Sûreté supplémentaire

    // Limiter certains types de breadcrumbs en production
    if (SecureConfig.kIsProduction) {
      // Ne garder que l’HTTP et la navigation
      if (breadcrumb.category == 'http' ||
          breadcrumb.category == 'navigation') {
        return breadcrumb;
      }
      return null; // On jette le reste
    }

    return breadcrumb; // En debug on garde tout
  }

  /// Ferme le service
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await Sentry.close();
      _isInitialized = false;
      LogConfig.logInfo('CrashReportingService fermé');
    } catch (e) {
      LogConfig.logError('❌ Erreur fermeture Sentry: $e');
    }
  }
}