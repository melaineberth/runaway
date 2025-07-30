import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:runaway/core/errors/app_exceptions.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/logging_service.dart';
import 'package:runaway/core/router/router.dart';

/// Service centralisé pour la gestion des erreurs
class ErrorService {
  static ErrorService? _instance;
  static ErrorService get instance => _instance ??= ErrorService._();
  
  ErrorService._();

  /// Convertit une exception brute en AppException typée avec message localisé
  AppException handleError(dynamic error, {BuildContext? context}) {
    context ??= rootNavigatorKey.currentContext;
    
    // Log de l'erreur pour le debugging
    LogConfig.logError('ErrorService.handleError: $error');
    
    try {
      // Si c'est déjà une AppException, on la retourne
      if (error is AppException) {
        _logAppException(error);
        return error;
      }

      // Conversion selon le type d'erreur
      final appException = _convertToAppException(error, context);
      _logAppException(appException);
      
      return appException;
      
    } catch (e) {
      LogConfig.logError('Erreur lors du traitement de l\'erreur: $e');
      
      // Fallback en cas d'erreur dans la gestion d'erreur
      return UnknownException(
        context?.l10n.unknownError ?? 'Erreur inconnue',
        code: 'ERROR_HANDLING_FAILED',
        originalError: error,
      );
    }
  }

  /// Convertit une erreur brute en AppException appropriée
  AppException _convertToAppException(dynamic error, BuildContext? context) {
    // === ERREURS HTTP ===
    if (error is http.Response) {
      return _handleHttpError(error, context);
    }

    // === ERREURS SUPABASE ===
    if (error is supabase.AuthException) {
      return _handleSupabaseAuthError(error, context);
    }

    if (error is supabase.PostgrestException) {
      return _handleSupabasePostgrestError(error, context);
    }

    if (error is supabase.StorageException) {
      return _handleSupabaseStorageError(error, context);
    }

    if (error is supabase.FunctionException) {
      return _handleSupabaseFunctionsError(error, context);
    }

    // === ERREURS RÉSEAU ===
    if (error is SocketException) {
      return NetworkException(
        context?.l10n.noInternetConnection ?? 'Pas de connexion internet',
        code: 'NO_INTERNET',
        originalError: error,
      );
    }

    if (error is TimeoutException) {
      return TimeoutException(
        context?.l10n.timeoutError ?? 'Délai d\'attente dépassé',
        code: 'TIMEOUT',
        originalError: error,
      );
    }

    // === ERREURS DE FORMAT ===
    if (error is FormatException) {
      return DataFormatException(
        context?.l10n.invalidServerResponse ?? 'Réponse serveur invalide',
        code: 'INVALID_FORMAT',
        originalError: error,
      );
    }

    // === ERREURS DE FICHIER ===
    if (error is FileSystemException) {
      return FileException(
        context?.l10n.fileAccessError ?? 'Erreur d\'accès au fichier',
        code: 'FILE_ACCESS_ERROR',
        originalError: error,
      );
    }

    // === AUTRES ERREURS ===
    return UnknownException(
      context?.l10n.unknownError ?? 'Erreur inconnue',
      code: 'UNKNOWN_ERROR',
      originalError: error,
    );
  }

  /// Gère les erreurs HTTP
  AppException _handleHttpError(http.Response response, BuildContext? context) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      
      switch (response.statusCode) {
        case 400:
          return _handleValidationError(data, context);
        case 401:
          return AuthException(
            context?.l10n.invalidCredentials ?? 'Identifiants invalides',
            code: 'UNAUTHORIZED',
          );
        case 403:
          return PermissionException(
            context?.l10n.accessDenied ?? 'Accès refusé',
            code: 'FORBIDDEN',
          );
        case 404:
          return ServerException(
            context?.l10n.resourceNotFound ?? 'Ressource non trouvée',
            404,
            code: 'NOT_FOUND',
          );
        case 408:
          return TimeoutException(
            context?.l10n.timeoutError ?? 'Délai d\'attente dépassé',
            code: 'REQUEST_TIMEOUT',
          );
        case 429:
          return RateLimitException(
            context?.l10n.tooManyRequests ?? 'Trop de requêtes, veuillez patienter',
            code: 'RATE_LIMIT',
          );
        case 500:
          return ServerException(
            context?.l10n.internalServerError ?? 'Erreur serveur interne',
            500,
            code: 'INTERNAL_SERVER_ERROR',
          );
        case 502:
          return ServerException(
            context?.l10n.badGateway ?? 'Passerelle défaillante',
            502,
            code: 'BAD_GATEWAY',
          );
        case 503:
          return ServiceUnavailableException(
            context?.l10n.serviceUnavailable ?? 'Service temporairement indisponible',
            code: 'SERVICE_UNAVAILABLE',
          );
        case 504:
          return TimeoutException(
            context?.l10n.gatewayTimeout ?? 'Délai d\'attente de la passerelle',
            code: 'GATEWAY_TIMEOUT',
          );
        default:
          return ServerException(
            data?['error'] ?? context?.l10n.serverErrorCode(response.statusCode) ?? 'Erreur serveur',
            response.statusCode,
            code: 'HTTP_${response.statusCode}',
          );
      }
    } catch (e) {
      return ServerException(
        context?.l10n.serverErrorCode(response.statusCode) ?? 'Erreur serveur',
        response.statusCode,
        code: 'HTTP_${response.statusCode}',
        originalError: e,
      );
    }
  }

  /// Gère les erreurs de validation
  AppException _handleValidationError(Map<String, dynamic>? data, BuildContext? context) {
    if (data?['details'] != null) {
      final details = data!['details'] as List;
      final errors = details.map((e) => ValidationError(
        field: e['field'] ?? 'unknown',
        message: e['message'] ?? context?.l10n.validationError ?? 'Erreur de validation',
        code: e['code'],
      )).toList();
      
      return ValidationException(errors, code: 'VALIDATION_ERROR');
    }
    
    return ValidationException([
      ValidationError(
        field: 'general',
        message: data?['error'] ?? context?.l10n.invalidRequest ?? 'Requête invalide',
      ),
    ], code: 'VALIDATION_ERROR');
  }

  /// Gère les erreurs d'authentification Supabase
  AppException _handleSupabaseAuthError(supabase.AuthException error, BuildContext? context) {
    switch (error.message.toLowerCase()) {
      case 'invalid login credentials':
        return LoginException(
          context?.l10n.invalidCredentials ?? 'Identifiants invalides',
          code: 'INVALID_CREDENTIALS',
          originalError: error,
        );
      case 'email not confirmed':
        return AuthException(
          context?.l10n.notConfirmedEmail ?? 'Email non confirmé',
          code: 'EMAIL_NOT_CONFIRMED',
          originalError: error,
        );
      case 'signup disabled':
        return SignUpException(
          context?.l10n.signupDisabled ?? 'Inscription désactivée',
          code: 'SIGNUP_DISABLED',
          originalError: error,
        );
      case 'user not found':
        return AuthException(
          context?.l10n.userNotFound ?? 'Utilisateur non trouvé',
          code: 'USER_NOT_FOUND',
          originalError: error,
        );
      case 'invalid refresh token':
      case 'refresh token not found':
        return TokenException(
          context?.l10n.sessionExpired ?? 'Session expirée',
          code: 'TOKEN_EXPIRED',
          originalError: error,
        );
      default:
        return AuthException(
          context?.l10n.authenticationError ?? 'Erreur d\'authentification',
          code: 'AUTH_ERROR',
          originalError: error,
        );
    }
  }

  /// Gère les erreurs Postgrest (base de données)
  AppException _handleSupabasePostgrestError(supabase.PostgrestException error, BuildContext? context) {
    if (error.code == '23505') { // Contrainte unique violée
      return ValidationException([
        ValidationError(
          field: 'duplicate',
          message: context?.l10n.duplicateEntry ?? 'Entrée dupliquée',
        ),
      ], code: 'DUPLICATE_ENTRY');
    }

    return DatabaseException(
      context?.l10n.databaseError ?? 'Erreur de base de données',
      code: error.code,
      originalError: error,
    );
  }

  /// Gère les erreurs de stockage Supabase
  AppException _handleSupabaseStorageError(supabase.StorageException error, BuildContext? context) {
    return StorageException(
      context?.l10n.storageError ?? 'Erreur de stockage',
      code: error.statusCode,
      originalError: error,
    );
  }

  /// Gère les erreurs des fonctions Edge Supabase
  AppException _handleSupabaseFunctionsError(supabase.FunctionException error, BuildContext? context) {
    return ServerException(
      context?.l10n.serverFunctionError ?? 'Erreur de fonction serveur',
      error.status,
      code: 'FUNCTION_ERROR',
      originalError: error,
    );
  }

  /// Log une AppException de manière structurée
  void _logAppException(AppException exception) {
    LoggingService.instance.error(
      'ErrorService',
      'Exception traitée: ${exception.runtimeType}',
      data: exception.toJson(),
    );
  }

  /// Obtient un message d'erreur localisé pour une exception
  String getLocalizedMessage(AppException exception, BuildContext? context) {
    context ??= rootNavigatorKey.currentContext;
    
    // Pour les exceptions avec codes spécifiques, on peut avoir des messages plus précis
    if (exception.code != null && context != null) {
      final specificMessage = _getSpecificLocalizedMessage(exception.code!, context);
      if (specificMessage != null) {
        return specificMessage;
      }
    }

    return exception.message;
  }

  /// Obtient des messages spécifiques selon le code d'erreur
  String? _getSpecificLocalizedMessage(String code, BuildContext context) {
    switch (code) {
      case 'NO_INTERNET':
        return context.l10n.noInternetConnection;
      case 'TIMEOUT':
        return context.l10n.timeoutError;
      case 'SERVICE_UNAVAILABLE':
        return context.l10n.serviceUnavailable;
      case 'INVALID_CREDENTIALS':
        return context.l10n.invalidCredentials;
      case 'EMAIL_NOT_CONFIRMED':
        return context.l10n.notConfirmedEmail;
      case 'SESSION_EXPIRED':
        return context.l10n.sessionExpired;
      case 'ROUTE_GENERATION_FAILED':
        return context.l10n.routeGenerationFailed;
      case 'LOCATION_DISABLED':
        return context.l10n.locationServicesDisabled;
      case 'LOCATION_DENIED':
        return context.l10n.locationPermissionDenied;
      case 'INSUFFICIENT_CREDITS':
        return context.l10n.insufficientCredits;
      case 'PURCHASE_FAILED':
        return context.l10n.purchaseFailed;
      default:
        return null;
    }
  }
}