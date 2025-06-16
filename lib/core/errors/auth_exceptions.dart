// lib/features/auth/data/exceptions/auth_exceptions.dart

import 'package:runaway/core/errors/auth_exceptions.dart';

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
    final errorMessage = error.toString().toLowerCase();
    
    // Erreurs de connexion
    if (errorMessage.contains('invalid login credentials') ||
        errorMessage.contains('invalid email or password')) {
      return LoginException(
        'Email ou mot de passe incorrect',
        code: 'INVALID_CREDENTIALS',
        originalError: error,
      );
    }
    
    if (errorMessage.contains('email not confirmed')) {
      return LoginException(
        'Veuillez confirmer votre email avant de vous connecter',
        code: 'EMAIL_NOT_CONFIRMED',
        originalError: error,
      );
    }
    
    // Erreurs d'inscription
    if (errorMessage.contains('user already registered')) {
      return SignUpException(
        'Un compte existe déjà avec cet email',
        code: 'USER_ALREADY_EXISTS',
        originalError: error,
      );
    }
    
    if (errorMessage.contains('password')) {
      return SignUpException(
        'Le mot de passe ne respecte pas les exigences de sécurité',
        code: 'WEAK_PASSWORD',
        originalError: error,
      );
    }
    
    if (errorMessage.contains('email')) {
      return SignUpException(
        'Format d\'email invalide',
        code: 'INVALID_EMAIL',
        originalError: error,
      );
    }
    
    // Erreurs de session
    if (errorMessage.contains('jwt') || 
        errorMessage.contains('token') ||
        errorMessage.contains('session')) {
      return SessionException(
        'Session expirée. Veuillez vous reconnecter',
        code: 'SESSION_EXPIRED',
        originalError: error,
      );
    }
    
    // Erreurs de profil
    if (errorMessage.contains('profile') ||
        errorMessage.contains('user not found')) {
      return ProfileException(
        'Erreur lors de la gestion du profil utilisateur',
        code: 'PROFILE_ERROR',
        originalError: error,
      );
    }
    
    // Erreurs réseau
    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout')) {
      return NetworkException(
        'Problème de connexion. Vérifiez votre connexion internet',
        code: 'NETWORK_ERROR',
        originalError: error,
      );
    }
    
    // Erreur générique
    return AuthException(
      'Une erreur d\'authentification s\'est produite',
      code: 'UNKNOWN_AUTH_ERROR',
      originalError: error,
    );
  }
  
  /// Convertit une exception en message utilisateur friendly
  static String getErrorMessage(AppException exception) {
    switch (exception.code) {
      case 'INVALID_CREDENTIALS':
        return 'Email ou mot de passe incorrect';
      case 'EMAIL_NOT_CONFIRMED':
        return 'Veuillez confirmer votre email avant de vous connecter';
      case 'USER_ALREADY_EXISTS':
        return 'Un compte existe déjà avec cet email';
      case 'WEAK_PASSWORD':
        return 'Le mot de passe doit contenir au moins 6 caractères';
      case 'INVALID_EMAIL':
        return 'Format d\'email invalide';
      case 'SESSION_EXPIRED':
        return 'Session expirée. Veuillez vous reconnecter';
      case 'PROFILE_ERROR':
        return 'Erreur lors de la sauvegarde du profil';
      case 'NETWORK_ERROR':
        return 'Problème de connexion internet';
      default:
        return exception.message;
    }
  }
}