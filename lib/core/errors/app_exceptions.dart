/// Exception de base pour toute l'application
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final Map<String, dynamic>? data;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
    this.data,
  });

  @override
  String toString() => message;

  /// Convertit l'exception en Map pour le logging
  Map<String, dynamic> toJson() {
    return {
      'type': runtimeType.toString(),
      'message': message,
      'code': code,
      'originalError': originalError?.toString(),
      'data': data,
    };
  }
}

// ===== EXCEPTIONS RÉSEAU =====

/// Exception de connectivité réseau
class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de timeout
class TimeoutException extends AppException {
  const TimeoutException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de connectivité (pas d'internet)
class ConnectivityException extends AppException {
  const ConnectivityException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

// ===== EXCEPTIONS SERVEUR =====

/// Exception serveur générique
class ServerException extends AppException {
  final int statusCode;

  const ServerException(
    super.message,
    this.statusCode, {
    super.code,
    super.originalError,
    super.data,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['statusCode'] = statusCode;
    return json;
  }
}

/// Exception de service indisponible
class ServiceUnavailableException extends AppException {
  const ServiceUnavailableException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de limite de débit (rate limiting)
class RateLimitException extends AppException {
  final Duration? retryAfter;

  const RateLimitException(
    super.message, {
    this.retryAfter,
    super.code,
    super.originalError,
    super.data,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (retryAfter != null) {
      json['retryAfter'] = retryAfter!.inSeconds;
    }
    return json;
  }
}

// ===== EXCEPTIONS DE VALIDATION =====

/// Erreur de validation individuelle
class ValidationError {
  final String field;
  final String message;
  final String? code;

  const ValidationError({
    required this.field,
    required this.message,
    this.code,
  });

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'message': message,
      'code': code,
    };
  }
}

/// Exception de validation avec erreurs multiples
class ValidationException extends AppException {
  final List<ValidationError> errors;

  const ValidationException(
    this.errors, {
    super.code,
    super.originalError,
    super.data,
  }) : super('Erreurs de validation');

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['errors'] = errors.map((e) => e.toJson()).toList();
    return json;
  }
}

// ===== EXCEPTIONS AUTHENTIFICATION =====

/// Exception d'authentification de base
class AuthException extends AppException {
  const AuthException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de connexion
class LoginException extends AuthException {
  const LoginException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception d'inscription
class SignUpException extends AuthException {
  const SignUpException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception pour les annulations utilisateur
class UserCanceledException extends AuthException {
  const UserCanceledException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de session expirée
class SessionException extends AuthException {
  const SessionException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de token invalide
class TokenException extends AuthException {
  const TokenException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de permissions
class PermissionException extends AuthException {
  const PermissionException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de profil utilisateur
class ProfileException extends AuthException {
  const ProfileException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

// ===== EXCEPTIONS MÉTIER =====

/// Exception de génération de parcours
class RouteGenerationException extends AppException {
  const RouteGenerationException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de localisation
class LocationException extends AppException {
  const LocationException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de géolocalisation
class GeolocationException extends AppException {
  const GeolocationException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de crédits
class CreditException extends AppException {
  const CreditException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception d'achat intégré (IAP)
class IAPException extends AppException {
  const IAPException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de validation d'achat
class PurchaseValidationException extends AppException {
  const PurchaseValidationException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

// ===== EXCEPTIONS STOCKAGE =====

/// Exception de stockage local
class StorageException extends AppException {
  const StorageException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de cache
class CacheException extends AppException {
  const CacheException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de base de données
class DatabaseException extends AppException {
  const DatabaseException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

// ===== EXCEPTIONS PLATEFORME =====

/// Exception de notification
class NotificationException extends AppException {
  const NotificationException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de partage
class ShareException extends AppException {
  const ShareException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de fichier
class FileException extends AppException {
  const FileException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de format de données
class DataFormatException extends AppException {
  const DataFormatException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

// ===== EXCEPTIONS CONFIGURATION =====

/// Exception de configuration
class ConfigurationException extends AppException {
  const ConfigurationException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception de service indisponible
class ServiceException extends AppException {
  const ServiceException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}

/// Exception inconnue/inattendue
class UnknownException extends AppException {
  const UnknownException(
    super.message, {
    super.code,
    super.originalError,
    super.data,
  });
}