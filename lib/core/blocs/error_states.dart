import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/errors/app_exceptions.dart';
import 'package:runaway/core/errors/error_handler.dart';
import 'package:runaway/core/errors/error_service.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/services/logging_service.dart';

/// État d'erreur de base pour tous les BLoCs
class ErrorState {
  final AppException exception;
  final DateTime timestamp;
  final String? contextInfo;
  final bool canRetry;
  final VoidCallback? retryAction;

  const ErrorState({
    required this.exception,
    required this.timestamp,
    this.contextInfo,
    this.canRetry = true,
    this.retryAction,
  });

  /// Obtient un message d'erreur localisé
  String getLocalizedMessage(BuildContext context) {
    return ErrorService.instance.getLocalizedMessage(exception, context);
  }

  /// Détermine si l'erreur est critique
  bool get isCritical {
    return exception is AuthException ||
           exception is ServerException && (exception as ServerException).statusCode >= 500 ||
           exception is ConfigurationException;
  }

  /// Détermine si l'erreur est liée au réseau
  bool get isNetworkRelated {
    return exception is NetworkException ||
           exception is TimeoutException ||
           exception is ConnectivityException;
  }

  /// Détermine si l'erreur nécessite une action utilisateur
  bool get requiresUserAction {
    return exception is ValidationException ||
           exception is PermissionException ||
           exception is AuthException;
  }
}

// ===== ÉTATS D'ERREUR SPÉCIFIQUES =====

/// État d'erreur pour la génération de parcours
class RouteGenerationError extends ErrorState {
  final dynamic parameters;
  final int? retryAttempt;

  RouteGenerationError({
    required super.exception,
    required this.parameters,
    super.contextInfo,
    super.canRetry = true,
    super.retryAction,
    this.retryAttempt,
  }) : super(timestamp: DateTime.now());

  /// Crée un état d'erreur spécifique pour la génération
  factory RouteGenerationError.create({
    required AppException exception,
    required dynamic parameters,
    VoidCallback? onRetry,
    int? retryAttempt,
  }) {
    final canRetry = _shouldAllowRetry(exception);
    
    return RouteGenerationError(
      exception: exception,
      parameters: parameters,
      canRetry: canRetry,
      retryAction: canRetry ? onRetry : null,
      retryAttempt: retryAttempt,
      contextInfo: 'Route Generation',
    );
  }

  static bool _shouldAllowRetry(AppException exception) {
    // Pas de retry pour les erreurs de validation et d'auth
    if (exception is ValidationException ||
        exception is AuthException ||
        exception is PermissionException ||
        exception is CreditException) {
      return false;
    }
    return true;
  }
}

/// État d'erreur pour l'authentification
class AuthError extends ErrorState {
  final String? userId;
  final Map<String, dynamic>? authContext;

  AuthError({
    required super.exception,
    this.userId,
    this.authContext,
    super.contextInfo,
    super.canRetry = false, // Auth errors généralement non retriables
  }) : super(timestamp: DateTime.now());

  /// Crée un état d'erreur d'authentification
  factory AuthError.create({
    required AppException exception,
    String? userId,
    Map<String, dynamic>? authContext,
  }) {
    return AuthError(
      exception: exception,
      userId: userId,
      authContext: authContext,
      contextInfo: 'Authentication',
    );
  }
}

/// État d'erreur pour les crédits/IAP
class CreditsError extends ErrorState {
  final String? transactionId;
  final String? productId;
  final int? currentCredits;

  CreditsError({
    required super.exception,
    this.transactionId,
    this.productId,
    this.currentCredits,
    super.contextInfo,
    super.canRetry = true,
    super.retryAction,
  }) : super(timestamp: DateTime.now());

  /// Crée un état d'erreur de crédits
  factory CreditsError.create({
    required AppException exception,
    String? transactionId,
    String? productId,
    int? currentCredits,
    VoidCallback? onRetry,
  }) {
    final canRetry = exception is! ValidationException &&
                     exception is! AuthException;
    
    return CreditsError(
      exception: exception,
      transactionId: transactionId,
      productId: productId,
      currentCredits: currentCredits,
      canRetry: canRetry,
      retryAction: canRetry ? onRetry : null,
      contextInfo: 'Credits/IAP',
    );
  }
}

/// État d'erreur pour la connectivité
class ConnectivityError extends ErrorState {
  final bool isOffline;
  final bool isSlowConnection;
  final DateTime? lastConnectedAt;

  ConnectivityError({
    required super.exception,
    required this.isOffline,
    required this.isSlowConnection,
    this.lastConnectedAt,
    super.contextInfo,
    super.canRetry = true,
    super.retryAction,
  }) : super(timestamp: DateTime.now());

  /// Crée un état d'erreur de connectivité
  factory ConnectivityError.create({
    required AppException exception,
    required bool isOffline,
    required bool isSlowConnection,
    DateTime? lastConnectedAt,
    VoidCallback? onRetry,
  }) {
    return ConnectivityError(
      exception: exception,
      isOffline: isOffline,
      isSlowConnection: isSlowConnection,
      lastConnectedAt: lastConnectedAt,
      canRetry: true,
      retryAction: onRetry,
      contextInfo: 'Connectivity',
    );
  }
}

/// État d'erreur pour les notifications
class NotificationError extends ErrorState {
  final String? notificationType;
  final bool permissionRequired;

  NotificationError({
    required super.exception,
    this.notificationType,
    this.permissionRequired = false,
    super.contextInfo,
    super.canRetry = false, // Notification errors généralement non retriables
  }) : super(timestamp: DateTime.now());

  /// Crée un état d'erreur de notification
  factory NotificationError.create({
    required AppException exception,
    String? notificationType,
    bool permissionRequired = false,
  }) {
    return NotificationError(
      exception: exception,
      notificationType: notificationType,
      permissionRequired: permissionRequired,
      contextInfo: 'Notifications',
    );
  }
}

/// État d'erreur pour le stockage/cache
class StorageError extends ErrorState {
  final String? storageType;
  final String? operation;
  final int? dataSize;

  StorageError({
    required super.exception,
    this.storageType,
    this.operation,
    this.dataSize,
    super.contextInfo,
    super.canRetry = true,
    super.retryAction,
  }) : super(timestamp: DateTime.now());

  /// Crée un état d'erreur de stockage
  factory StorageError.create({
    required AppException exception,
    String? storageType,
    String? operation,
    int? dataSize,
    VoidCallback? onRetry,
  }) {
    return StorageError(
      exception: exception,
      storageType: storageType,
      operation: operation,
      dataSize: dataSize,
      canRetry: true,
      retryAction: onRetry,
      contextInfo: 'Storage',
    );
  }
}

/// État d'erreur pour la localisation
class LocationError extends ErrorState {
  final bool permissionDenied;
  final bool serviceDisabled;
  final bool permanentlyDenied;

  LocationError({
    required super.exception,
    this.permissionDenied = false,
    this.serviceDisabled = false,
    this.permanentlyDenied = false,
    super.contextInfo,
    super.canRetry = false,
  }) : super(timestamp: DateTime.now());

  /// Crée un état d'erreur de localisation
  factory LocationError.create({
    required AppException exception,
    bool permissionDenied = false,
    bool serviceDisabled = false,
    bool permanentlyDenied = false,
  }) {
    return LocationError(
      exception: exception,
      permissionDenied: permissionDenied,
      serviceDisabled: serviceDisabled,
      permanentlyDenied: permanentlyDenied,
      contextInfo: 'Location',
    );
  }

  /// Détermine si l'utilisateur peut résoudre l'erreur
  bool get canBeResolvedByUser {
    return !permanentlyDenied && (permissionDenied || serviceDisabled);
  }
}

// ===== MIXIN POUR GESTION D'ERREURS DANS LES BLOCS =====

/// Mixin pour ajouter la gestion d'erreurs standardisée aux BLoCs
mixin ErrorHandlingMixin<Event, State> on Bloc<Event, State> {
  
  /// Gère une erreur et émet l'état approprié
  Future<void> handleError(
    dynamic error, {
    required Emitter<State> emit,
    String? contextInfo,
    VoidCallback? onRetry,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Conversion en AppException
      final appException = ErrorService.instance.handleError(error);
      
      // Log de l'erreur
      LoggingService.instance.error(
        runtimeType.toString(),
        'Erreur dans ${contextInfo ?? 'BLoC'}',
        data: {
          'exception': appException.toJson(),
          'contextInfo': contextInfo,
          'additionalData': additionalData,
        },
      );

      // Émission de l'état d'erreur approprié
      final errorState = _createErrorState(appException, contextInfo, onRetry);
      if (errorState is State) {
        emit(state);
      }

      // Gestion UI via ErrorHandler
      await ErrorHandler.instance.handleError(
        appException,
        contextInfo: contextInfo,
        config: _getErrorDisplayConfig(appException),
      );

    } catch (e) {
      // Fallback en cas d'erreur dans la gestion d'erreur
      LogConfig.logError('Erreur dans ErrorHandlingMixin: $e');
    }
  }

  /// Crée l'état d'erreur approprié selon le type
  ErrorState _createErrorState(
    AppException exception,
    String? contextInfo,
    VoidCallback? onRetry,
  ) {
    switch (contextInfo?.toLowerCase()) {
      case 'authentication':
      case 'auth':
        return AuthError.create(exception: exception);
      case 'credits':
      case 'iap':
        return CreditsError.create(
          exception: exception,
          onRetry: onRetry,
        );
      case 'connectivity':
      case 'network':
        return ConnectivityError.create(
          exception: exception,
          isOffline: true, 
          isSlowConnection: false,
          onRetry: onRetry,
        );
      case 'location':
        return LocationError.create(exception: exception);
      case 'storage':
        return StorageError.create(
          exception: exception,
          onRetry: onRetry,
        );
      case 'route generation':
        return RouteGenerationError.create(
          exception: exception,
          parameters: {},
          onRetry: onRetry,
        );
      default:
        return ErrorState(
          exception: exception,
          timestamp: DateTime.now(),
          contextInfo: contextInfo,
          canRetry: onRetry != null,
          retryAction: onRetry,
        );
    }
  }

  /// Détermine la configuration d'affichage selon le type d'erreur
  ErrorDisplayConfig _getErrorDisplayConfig(AppException exception) {
    if (exception is AuthException) {
      return const ErrorDisplayConfig(
        type: ErrorDisplayType.dialog,
        showDetails: false,
      );
    }

    if (exception is NetworkException || exception is TimeoutException) {
      return const ErrorDisplayConfig(
        type: ErrorDisplayType.snackBar,
        canRetry: true,
        duration: Duration(seconds: 5),
      );
    }

    if (exception is ValidationException) {
      return const ErrorDisplayConfig(
        type: ErrorDisplayType.banner,
        showDetails: true,
        canRetry: false,
      );
    }

    if (exception is PermissionException || exception is LocationException) {
      return const ErrorDisplayConfig(
        type: ErrorDisplayType.dialog,
        showDetails: true,
        canRetry: false,
      );
    }

    // Configuration par défaut
    return const ErrorDisplayConfig(
      type: ErrorDisplayType.snackBar,
      canRetry: true,
    );
  }

  /// Gère les erreurs silencieuses (log seulement)
  void handleSilentError(
    dynamic error, {
    String? contextInfo,
    Map<String, dynamic>? additionalData,
  }) {
    try {
      final appException = ErrorService.instance.handleError(error);
      
      LoggingService.instance.error(
        runtimeType.toString(),
        'Erreur silencieuse dans ${contextInfo ?? 'BLoC'}',
        data: {
          'exception': appException.toJson(),
          'contextInfo': contextInfo,
          'additionalData': additionalData,
        },
      );

      // Monitoring seulement, pas d'affichage
      ErrorHandler.instance.handleSilentError(
        appException,
        contextInfo: contextInfo,
      );

    } catch (e) {
      LogConfig.logError('Erreur dans handleSilentError: $e');
    }
  }
}