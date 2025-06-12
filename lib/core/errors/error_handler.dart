import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:runaway/core/errors/api_exceptions.dart';

class ErrorHandler {
  static AppException handleHttpError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      
      switch (response.statusCode) {
        case 400:
          // Erreur de validation
          if (data['details'] != null) {
            final errors = (data['details'] as List)
                .map((e) => ValidationError(
                    field: e['field'] ?? 'unknown',
                    message: e['message'] ?? 'Erreur inconnue'))
                .toList();
            return ValidationException(errors);
          }
          return ValidationException([ValidationError(
              field: 'general', 
              message: data['error'] ?? 'Requête invalide')]);
              
        case 503:
          return RouteGenerationException(
              'Service temporairement indisponible. Réessayez dans quelques minutes.',
              code: 'SERVICE_UNAVAILABLE');
              
        case 408:
          return NetworkException(
              'Délai d\'attente dépassé. Vérifiez votre connexion.',
              code: 'TIMEOUT');
              
        default:
          return ServerException(
              data['error'] ?? 'Erreur serveur inattendue', 
              response.statusCode);
      }
    } catch (e) {
      return ServerException(
          'Erreur serveur (${response.statusCode})', 
          response.statusCode);
    }
  }
  
  static AppException handleNetworkError(dynamic error) {
    if (error is SocketException) {
      return NetworkException(
          'Pas de connexion internet. Vérifiez votre réseau.',
          code: 'NO_INTERNET');
    }
    
    if (error is TimeoutException) {
      return NetworkException(
          'Délai d\'attente dépassé. Réessayez.',
          code: 'TIMEOUT');
    }
    
    if (error is FormatException) {
      return ServerException(
          'Réponse serveur invalide', 500);
    }
    
    return NetworkException(
        'Erreur de connexion: ${error.toString()}',
        originalError: error);
  }
}
