// lib/core/services/permission_service.dart
import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';
import 'package:runaway/core/helper/services/logging_service.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';

/// Types de permissions gérées par l'application
enum AppPermission {
  location,
  camera,
  storage,
  notification,
  microphone,
  contacts,
}

/// Statut d'une permission avec détails
class AppPermissionStatus {
  final AppPermission permission;
  final bool isGranted;
  final bool isDenied;
  final bool isPermanentlyDenied;
  final bool isRestricted;
  final bool canRequest;
  final String displayName;
  final String description;
  final String rationaleMessage;

  AppPermissionStatus({
    required this.permission,
    required this.isGranted,
    required this.isDenied,
    required this.isPermanentlyDenied,
    required this.isRestricted,
    required this.canRequest,
    required this.displayName,
    required this.description,
    required this.rationaleMessage,
  });

  bool get needsAction => !isGranted && canRequest;
  bool get isBlocked => isPermanentlyDenied || isRestricted;
}

/// Résultat d'une demande de permission
class PermissionRequestResult {
  final AppPermission permission;
  final bool wasGranted;
  final bool wasDenied;
  final bool wasPermanentlyDenied;
  final String? errorMessage;

  PermissionRequestResult({
    required this.permission,
    required this.wasGranted,
    required this.wasDenied,
    required this.wasPermanentlyDenied,
    this.errorMessage,
  });
}

/// Service centralisé de gestion des permissions
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  static PermissionService get instance => _instance;
  
  PermissionService._internal();

  final Map<AppPermission, AppPermissionStatus> _permissionCache = {};
  final StreamController<Map<AppPermission, AppPermissionStatus>> _statusController = 
      StreamController<Map<AppPermission, AppPermissionStatus>>.broadcast();

  Stream<Map<AppPermission, AppPermissionStatus>> get statusStream => _statusController.stream;

  /// Initialise le service des permissions
  Future<void> initialize() async {
    try {
      LoggingService.instance.info('PermissionService', 'Initialisation du service des permissions');
      
      // Vérifier le statut initial de toutes les permissions
      await checkAllPermissions();
      
      MonitoringService.instance.recordMetric(
        'permission_service_initialized',
        1,
        tags: {'platform': Platform.operatingSystem},
      );
      
    } catch (e) {
      LoggingService.instance.error(
        'PermissionService',
        'Erreur lors de l\'initialisation',
        data: {'error': e.toString()},
      );
    }
  }

  /// Vérifie le statut de toutes les permissions
  Future<Map<AppPermission, AppPermissionStatus>> checkAllPermissions() async {
    try {
      final futures = AppPermission.values.map((permission) async {
        final status = await checkPermission(permission);
        _permissionCache[permission] = status;
        return MapEntry(permission, status);
      });

      final results = await Future.wait(futures);
      final statusMap = Map<AppPermission, AppPermissionStatus>.fromEntries(results);
      
      _statusController.add(statusMap);
      return statusMap;
      
    } catch (e) {
      LoggingService.instance.error(
        'PermissionService',
        'Erreur lors de la vérification des permissions',
        data: {'error': e.toString()},
      );
      return {};
    }
  }

  /// Vérifie le statut d'une permission spécifique
  Future<AppPermissionStatus> checkPermission(AppPermission appPermission) async {
    try {
      Permission? systemPermission = _getSystemPermission(appPermission);
      AppPermissionStatus status;

      if (appPermission == AppPermission.location) {
        // Gestion spéciale pour la géolocalisation avec Geolocator
        status = await _checkLocationPermission();
      } else if (systemPermission != null) {
        final systemStatus = await systemPermission.status;
        status = _convertPermissionStatus(appPermission, systemStatus);
      } else {
        // Permission non supportée sur cette plateforme
        status = _createUnsupportedStatus(appPermission);
      }

      _permissionCache[appPermission] = status;
      return status;

    } catch (e) {
      LoggingService.instance.error(
        'PermissionService',
        'Erreur vérification permission ${appPermission.name}',
        data: {'error': e.toString()},
      );

      return _createErrorStatus(appPermission, e.toString());
    }
  }

  /// Demande une permission spécifique
  Future<PermissionRequestResult> requestPermission(AppPermission appPermission) async {
    try {
      LoggingService.instance.info(
        'PermissionService',
        'Demande permission ${appPermission.name}',
      );

      // Vérifier d'abord le statut actuel
      final currentStatus = await checkPermission(appPermission);
      if (currentStatus.isGranted) {
        return PermissionRequestResult(
          permission: appPermission,
          wasGranted: true,
          wasDenied: false,
          wasPermanentlyDenied: false,
        );
      }

      if (currentStatus.isBlocked) {
        return PermissionRequestResult(
          permission: appPermission,
          wasGranted: false,
          wasDenied: true,
          wasPermanentlyDenied: true,
          errorMessage: 'Permission bloquée définitivement',
        );
      }

      // Demander la permission
      PermissionRequestResult result;
      if (appPermission == AppPermission.location) {
        result = await _requestLocationPermission();
      } else {
        result = await _requestSystemPermission(appPermission);
      }

      // Mettre à jour le cache
      await checkPermission(appPermission);
      
      // Enregistrer la métrique
      MonitoringService.instance.recordMetric(
        'permission_requested',
        1,
        tags: {
          'permission': appPermission.name,
          'granted': result.wasGranted.toString(),
          'platform': Platform.operatingSystem,
        },
      );

      return result;

    } catch (e) {
      LoggingService.instance.error(
        'PermissionService',
        'Erreur demande permission ${appPermission.name}',
        data: {'error': e.toString()},
      );

      return PermissionRequestResult(
        permission: appPermission,
        wasGranted: false,
        wasDenied: true,
        wasPermanentlyDenied: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Demande plusieurs permissions en une fois
  Future<Map<AppPermission, PermissionRequestResult>> requestMultiplePermissions(
    List<AppPermission> permissions,
  ) async {
    final results = <AppPermission, PermissionRequestResult>{};
    
    for (final permission in permissions) {
      results[permission] = await requestPermission(permission);
    }
    
    return results;
  }

  /// Ouvre les paramètres de l'application
  Future<bool> openAppSettings() async {
    try {
      LoggingService.instance.info('PermissionService', 'Ouverture paramètres app');
      
      final opened = await openAppSettings();
      
      MonitoringService.instance.recordMetric(
        'app_settings_opened',
        1,
        tags: {'success': opened.toString()},
      );
      
      return opened;
    } catch (e) {
      LoggingService.instance.error(
        'PermissionService',
        'Erreur ouverture paramètres',
        data: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Vérifie si une permission est accordée
  bool isPermissionGranted(AppPermission permission) {
    return _permissionCache[permission]?.isGranted ?? false;
  }

  /// Vérifie si une permission est définitivement refusée
  bool isPermissionPermanentlyDenied(AppPermission permission) {
    return _permissionCache[permission]?.isPermanentlyDenied ?? false;
  }

  /// Obtient le message de justification pour une permission
  String getRationaleMessage(AppPermission permission) {
    return _permissionCache[permission]?.rationaleMessage ?? '';
  }

  // === MÉTHODES PRIVÉES ===

  /// Gestion spéciale pour la géolocalisation
  Future<AppPermissionStatus> _checkLocationPermission() async {
    try {
      // Vérifier si le service est activé
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return AppPermissionStatus(
          permission: AppPermission.location,
          isGranted: false,
          isDenied: true,
          isPermanentlyDenied: false,
          isRestricted: true,
          canRequest: false,
          displayName: 'Localisation',
          description: 'Service de localisation désactivé',
          rationaleMessage: 'Activez le service de localisation dans les paramètres',
        );
      }

      // Vérifier la permission
      final permission = await geo.Geolocator.checkPermission();
      
      return AppPermissionStatus(
        permission: AppPermission.location,
        isGranted: permission == geo.LocationPermission.always || 
                   permission == geo.LocationPermission.whileInUse,
        isDenied: permission == geo.LocationPermission.denied,
        isPermanentlyDenied: permission == geo.LocationPermission.deniedForever,
        isRestricted: !serviceEnabled,
        canRequest: permission == geo.LocationPermission.denied,
        displayName: 'Localisation',
        description: 'Nécessaire pour générer des parcours adaptés à votre position',
        rationaleMessage: 'Trailix utilise votre position pour créer des parcours personnalisés près de chez vous.',
      );

    } catch (e) {
      return _createErrorStatus(AppPermission.location, e.toString());
    }
  }

  /// Demande la permission de géolocalisation
  Future<PermissionRequestResult> _requestLocationPermission() async {
    try {
      final permission = await geo.Geolocator.requestPermission();
      
      return PermissionRequestResult(
        permission: AppPermission.location,
        wasGranted: permission == geo.LocationPermission.always || 
                    permission == geo.LocationPermission.whileInUse,
        wasDenied: permission == geo.LocationPermission.denied,
        wasPermanentlyDenied: permission == geo.LocationPermission.deniedForever,
      );
    } catch (e) {
      return PermissionRequestResult(
        permission: AppPermission.location,
        wasGranted: false,
        wasDenied: true,
        wasPermanentlyDenied: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Demande une permission système via permission_handler
  Future<PermissionRequestResult> _requestSystemPermission(AppPermission appPermission) async {
    final systemPermission = _getSystemPermission(appPermission);
    if (systemPermission == null) {
      return PermissionRequestResult(
        permission: appPermission,
        wasGranted: false,
        wasDenied: true,
        wasPermanentlyDenied: false,
        errorMessage: 'Permission non supportée sur cette plateforme',
      );
    }

    final status = await systemPermission.request();
    
    return PermissionRequestResult(
      permission: appPermission,
      wasGranted: status.isGranted,
      wasDenied: status.isDenied,
      wasPermanentlyDenied: status.isPermanentlyDenied,
    );
  }

  /// Convertit une permission app vers permission système
  Permission? _getSystemPermission(AppPermission appPermission) {
    switch (appPermission) {
      case AppPermission.camera:
        return Permission.camera;
      case AppPermission.storage:
        return Platform.isAndroid ? Permission.storage : Permission.photos;
      case AppPermission.notification:
        return Permission.notification;
      case AppPermission.microphone:
        return Permission.microphone;
      case AppPermission.contacts:
        return Permission.contacts;
      case AppPermission.location:
        return null; // Géré spécialement avec Geolocator
    }
  }

  /// Convertit un statut système vers notre format
  AppPermissionStatus _convertPermissionStatus(AppPermission appPermission, PermissionStatus systemStatus) {
    return AppPermissionStatus(
      permission: appPermission,
      isGranted: systemStatus.isGranted,
      isDenied: systemStatus.isDenied,
      isPermanentlyDenied: systemStatus.isPermanentlyDenied,
      isRestricted: systemStatus.isRestricted,
      canRequest: !systemStatus.isPermanentlyDenied && !systemStatus.isRestricted,
      displayName: _getDisplayName(appPermission),
      description: _getDescription(appPermission),
      rationaleMessage: _getRationaleMessage(appPermission),
    );
  }

  /// Crée un statut pour permission non supportée
  AppPermissionStatus _createUnsupportedStatus(AppPermission appPermission) {
    return AppPermissionStatus(
      permission: appPermission,
      isGranted: false,
      isDenied: true,
      isPermanentlyDenied: false,
      isRestricted: true,
      canRequest: false,
      displayName: _getDisplayName(appPermission),
      description: 'Non supporté sur cette plateforme',
      rationaleMessage: '',
    );
  }

  /// Crée un statut d'erreur
  AppPermissionStatus _createErrorStatus(AppPermission appPermission, String error) {
    return AppPermissionStatus(
      permission: appPermission,
      isGranted: false,
      isDenied: true,
      isPermanentlyDenied: false,
      isRestricted: false,
      canRequest: false,
      displayName: _getDisplayName(appPermission),
      description: 'Erreur: $error',
      rationaleMessage: '',
    );
  }

  /// Nom d'affichage de la permission
  String _getDisplayName(AppPermission permission) {
    switch (permission) {
      case AppPermission.location:
        return 'Localisation';
      case AppPermission.camera:
        return 'Appareil photo';
      case AppPermission.storage:
        return 'Stockage';
      case AppPermission.notification:
        return 'Notifications';
      case AppPermission.microphone:
        return 'Microphone';
      case AppPermission.contacts:
        return 'Contacts';
    }
  }

  /// Description de la permission
  String _getDescription(AppPermission permission) {
    switch (permission) {
      case AppPermission.location:
        return 'Génération de parcours personnalisés';
      case AppPermission.camera:
        return 'Photos de vos parcours';
      case AppPermission.storage:
        return 'Sauvegarde des données de parcours';
      case AppPermission.notification:
        return 'Rappels et notifications importantes';
      case AppPermission.microphone:
        return 'Commandes vocales (fonctionnalité future)';
      case AppPermission.contacts:
        return 'Partage avec vos contacts (fonctionnalité future)';
    }
  }

  /// Message de justification
  String _getRationaleMessage(AppPermission permission) {
    switch (permission) {
      case AppPermission.location:
        return 'Trailix utilise votre position pour créer des parcours adaptés à votre environnement.';
      case AppPermission.camera:
        return 'Prenez des photos de vos parcours pour les partager et les mémoriser.';
      case AppPermission.storage:
        return 'Sauvegardez vos parcours et données d\'activité sur votre appareil.';
      case AppPermission.notification:
        return 'Recevez des rappels et des informations importantes sur vos activités.';
      case AppPermission.microphone:
        return 'Contrôlez l\'application avec des commandes vocales lors de vos activités.';
      case AppPermission.contacts:
        return 'Partagez facilement vos parcours avec vos amis et famille.';
    }
  }

  /// Nettoie les ressources
  void dispose() {
    _statusController.close();
  }
}