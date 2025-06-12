abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException(this.message, {this.code, this.originalError});
  
  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.originalError});
}

class ValidationException extends AppException {
  final List<ValidationError> errors;
  
  ValidationException(this.errors) 
      : super('Erreurs de validation: ${errors.length} erreur(s)');
}

class ValidationError {
  final String field;
  final String message;
  
  ValidationError({required this.field, required this.message});
}

class ServerException extends AppException {
  final int statusCode;
  
  ServerException(super.message, this.statusCode, {super.code});
}

class RouteGenerationException extends AppException {
  RouteGenerationException(super.message, {super.code, super.originalError});
}