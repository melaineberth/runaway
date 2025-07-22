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

/// Helper pour convertir les erreurs Supabase en exceptions typées
class AuthExceptionHandler {
  static AppException handleSupabaseError(dynamic error) {
    final context = rootNavigatorKey.currentContext!;
    final errorMessage = error.toString().toLowerCase();
    
    // Erreurs de connexion
    if (errorMessage.contains('invalid login credentials') ||
        errorMessage.contains('invalid email or password')) {
      return LoginException(
       context.l10n.invalidCredentials,
        code: 'INVALID_CREDENTIALS',
        originalError: error,
      );
    }

    // 🆕 Gestion des annulations utilisateur
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

    // 🆕 Erreurs de mot de passe faible - gestion plus spécifique
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

    if (errorMessage.contains('email not confirmed') ||
        errorMessage.contains('email address not confirmed') ||
        errorMessage.contains('confirm your email')) {
      return AuthException(
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
    
    if (errorMessage.contains('email not confirmed')) {
      return LoginException(
        context.l10n.confirmEmailBeforeLogin,
        code: 'EMAIL_NOT_CONFIRMED',
        originalError: error,
      );
    }
    
    // Erreurs d'inscription
    if (errorMessage.contains('user already registered')) {
      return SignUpException(
        context.l10n.emailAlreadyUsed,
        code: 'USER_ALREADY_EXISTS',
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
    
    // Erreurs de profil
    if (errorMessage.contains('profile') ||
        errorMessage.contains('user not found')) {
      return ProfileException(
        context.l10n.profileManagementError,
        code: 'PROFILE_ERROR',
        originalError: error,
      );
    }
    
    // Erreurs réseau
    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout')) {
      return NetworkException(
        context.l10n.connectionProblem,
        code: 'NETWORK_ERROR',
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