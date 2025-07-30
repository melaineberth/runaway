import 'package:runaway/core/errors/auth_exceptions.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/router/router.dart';

export 'package:runaway/core/errors/api_exceptions.dart';

/// Exception d'authentification de base
class AuthException extends AppException {
  AuthException(super.message, {super.code, super.originalError});
}

/// Exception de connexion
class LoginException extends AuthException {
  LoginException(super.message, {super.code, super.originalError});
}

/// Exception d'inscription
class SignUpException extends AuthException {
  SignUpException(super.message, {super.code, super.originalError});
}

/// Exception pour les annulations utilisateur
class UserCanceledException extends AuthException {
  UserCanceledException(super.message, {super.code, super.originalError});
}

/// Exception de profil
class ProfileException extends AuthException {
  ProfileException(super.message, {super.code, super.originalError});
}

/// Exception de session
class SessionException extends AuthException {
  SessionException(super.message, {super.code, super.originalError});
}

/// Exception de token
class TokenException extends AuthException {
  TokenException(super.message, {super.code, super.originalError});
}

/// Exception de permissions
class PermissionException extends AuthException {
  PermissionException(super.message, {super.code, super.originalError});
}

class NetworkException implements Exception {
  final String message;
  final String? originalError;
  
  const NetworkException(
    this.message, {
    this.originalError,
  });

  @override
  String toString() {
    if (originalError != null) {
      return 'NetworkException: $message (Original: $originalError)';
    }
    return 'NetworkException: $message';
  }
}

/// Helper pour convertir les erreurs Supabase en exceptions typées
class AuthExceptionHandler {
  static Exception handleSupabaseError(dynamic error) {
    final context = rootNavigatorKey.currentContext!;
    final errorMessage = error.toString().toLowerCase();
    
    // Erreurs de connexion
    if (errorMessage.contains('invalid login credentials') ||
        errorMessage.contains('invalid email or password') ||
        errorMessage.contains('email not confirmed') && errorMessage.contains('invalid login')) {
      return LoginException(
       context.l10n.invalidCredentials,
        code: 'INVALID_CREDENTIALS',
        originalError: error,
      );
    }

    // Gestion des annulations utilisateur
    if (errorMessage.contains('canceled') || 
        errorMessage.contains('cancelled') ||
        errorMessage.contains('user canceled') ||
        errorMessage.contains('connexion google annulée') ||
        errorMessage.contains('authorizationerrorcode.canceled')) {
      return UserCanceledException(
        context.l10n.userCanceledConnection,
        code: 'USER_CANCELED',
        originalError: error,
      );
    }

    // Erreurs de mot de passe faible - gestion plus spécifique
    if (errorMessage.contains('password is too weak') ||
        errorMessage.contains('weak password') ||
        errorMessage.contains('password does not meet') ||
        errorMessage.contains('password must contain')) {
      return SignUpException(
        context.l10n.passwordMustRequired,
        code: 'WEAK_PASSWORD',
        originalError: error,
      );
    }
    
    // 🆕 Erreur de longueur de mot de passe
    if (errorMessage.contains('password should be at least') ||
        errorMessage.contains('password is too short')) {
      return SignUpException(
        context.l10n.passwordTooShort,
        code: 'PASSWORD_TOO_SHORT',
        originalError: error,
      );
    }

    // Email non confirmé spécifiquement
    if (errorMessage.contains('email not confirmed') ||
        errorMessage.contains('email_not_confirmed') ||
        errorMessage.contains('unconfirmed')) {
      return LoginException(
        context.l10n.notConfirmedEmail,
        code: 'EMAIL_NOT_CONFIRMED',
        originalError: error,
      );
    }
    
    // 🆕 Gestion des null checks pour Google
    if (errorMessage.contains('null check operator used on a null value')) {
      return UserCanceledException(
        context.l10n.userCanceledConnection,
        code: 'USER_CANCELED_NULL',
        originalError: error,
      );
    }
    
    // Erreurs de connexion existantes...
    if (errorMessage.contains('invalid login credentials') ||
        errorMessage.contains('invalid email or password')) {
      return LoginException(
        context.l10n.invalidCredentials,
        code: 'INVALID_CREDENTIALS',
        originalError: error,
      );
    }

    // Utilisateur non trouvé
    if (errorMessage.contains('user not found') ||
        errorMessage.contains('user does not exist')) {
      return LoginException(
        context.l10n.invalidCredentials, // On reste vague pour la sécurité
        code: 'USER_NOT_FOUND',
        originalError: error,
      );
    }
    
    if (errorMessage.contains('email not confirmed')) {
      return LoginException(
        context.l10n.confirmEmailBeforeLogin,
        code: 'EMAIL_NOT_CONFIRMED',
        originalError: error,
      );
    }
    
    // Erreurs liées aux emails déjà utilisés
    if (errorMessage.contains('user already registered') ||
        errorMessage.contains('email already exists') ||
        errorMessage.contains('duplicate key') ||
        errorMessage.contains('already registered')) {
      return SignUpException(
        context.l10n.emailAlreadyInUse,
        code: 'EMAIL_ALREADY_IN_USE',
        originalError: error,
      );
    }
    
    if (errorMessage.contains('password')) {
      return SignUpException(
        context.l10n.passwordTooSimple,
        code: 'WEAK_PASSWORD',
        originalError: error,
      );
    }
    
    if (errorMessage.contains('email')) {
      return SignUpException(
        context.l10n.emailInvalid,
        code: 'INVALID_EMAIL',
        originalError: error,
      );
    }
    
    // Erreurs de session - CORRECTION ICI
    if (errorMessage.contains('jwt') || 
        errorMessage.contains('token') ||
        errorMessage.contains('session')) {
      return SessionException(
        context.l10n.pleaseReconnect,
        code: 'SESSION_EXPIRED',
        originalError: error,
      );
    }

    if (errorMessage.contains('invalid refresh token') ||
        errorMessage.contains('refresh token not found') ||
        errorMessage.contains('jwt expired') ||
        errorMessage.contains('session expired')) {
      return SessionException(
        context.l10n.sessionExpired,
        code: 'SESSION_EXPIRED',
        originalError: error,
      );
    }

    // Erreurs de connexion réseau
    if (errorMessage.contains('failed host lookup') ||
        errorMessage.contains('network error') ||
        errorMessage.contains('connection timeout') ||
        errorMessage.contains('connection failed')) {
      return NetworkException(
        context.l10n.connectionProblem,
        originalError: error.toString(),
      );
    }

    // Erreurs de timeout
    if (errorMessage.contains('timeout') ||
        errorMessage.contains('timed out')) {
      return NetworkException(
        context.l10n.timeoutError,
        originalError: error.toString(),
      );
    }

    // Service temporairement indisponible
    if (errorMessage.contains('service unavailable') ||
        errorMessage.contains('503') ||
        errorMessage.contains('temporarily unavailable')) {
      return NetworkException(
        context.l10n.serviceUnavailable,
        originalError: error.toString(),
      );
    }

    // Inscription désactivée
    if (errorMessage.contains('signup disabled') ||
        errorMessage.contains('signups not allowed')) {
      return SignUpException(
        context.l10n.signupDisabled,
        code: 'SIGNUP_DISABLED',
        originalError: error,
      );
    }

    // Trop de tentatives de connexion
    if (errorMessage.contains('too many requests') ||
        errorMessage.contains('rate limit exceeded') ||
        errorMessage.contains('429')) {
      return LoginException(
        context.l10n.tooManyAttempts,
        code: 'TOO_MANY_ATTEMPTS',
        originalError: error,
      );
    }
    
    // Erreurs de profil
    if (errorMessage.contains('profile') ||
        errorMessage.contains('user not found')) {
      return ProfileException(
        context.l10n.profileManagementError,
        code: 'PROFILE_ERROR',
        originalError: error,
      );
    }
    
    // Erreur générique - OBLIGATOIRE
    return AuthException(
      context.l10n.authenticationError,
      code: 'UNKNOWN_AUTH_ERROR',
      originalError: error,
    );
  }
  
  /// Convertit une exception en message utilisateur friendly
  static String getErrorMessage(AppException exception) {
    final context = rootNavigatorKey.currentContext!;
    switch (exception.code) {
      case 'INVALID_CREDENTIALS':
        return context.l10n.invalidCredentials;
      case 'EMAIL_NOT_CONFIRMED':
        return context.l10n.confirmEmailBeforeLogin;
      case 'USER_ALREADY_EXISTS':
        return context.l10n.emailAlreadyUsed;
      case 'WEAK_PASSWORD':
        return context.l10n.passwordMustRequired;
      case 'INVALID_EMAIL':
        return context.l10n.emailInvalid;
      case 'SESSION_EXPIRED':
        return context.l10n.expiredSession;
      case 'PROFILE_ERROR':
        return context.l10n.savingProfileError;
      case 'NETWORK_ERROR':
        return context.l10n.connectionProblem;
      case 'PASSWORD_TOO_SHORT':
        return context.l10n.requiredCountCharacters(8);
      default:
        return exception.message;
    }
  }
}