import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:runaway/core/errors/api_exceptions.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/router/router.dart';

class ErrorHandler {
  static AppException handleHttpError(http.Response response) {
    final context = rootNavigatorKey.currentContext!;
    
    try {
      final data = jsonDecode(response.body);
      
      switch (response.statusCode) {
        case 400:
          // Erreur de validation
          if (data['details'] != null) {
            final errors = (data['details'] as List)
                .map((e) => ValidationError(
                    field: e['field'] ?? 'unknown',
                    message: e['message'] ?? context.l10n.unknownError))
                .toList();
            return ValidationException(errors);
          }
          return ValidationException([ValidationError(
              field: 'general', 
              message: data['error'] ?? context.l10n.invalidRequest)]);
              
        case 503:
          return RouteGenerationException(
              context.l10n.serviceUnavailable,
              code: 'SERVICE_UNAVAILABLE');
              
        case 408:
          return NetworkException(
              context.l10n.timeoutError,
              code: 'TIMEOUT');
              
        default:
          return ServerException(
              data['error'] ?? context.l10n.unexpectedServerError, 
              response.statusCode);
      }
    } catch (e) {
      return ServerException(
        context.l10n.serverErrorCode(response.statusCode),
        response.statusCode);
    }
  }
  
  static AppException handleNetworkError(dynamic error) {
    final context = rootNavigatorKey.currentContext!;

    if (error is SocketException) {
      return NetworkException(
          context.l10n.networkException,
          code: 'NO_INTERNET');
    }
    
    if (error is TimeoutException) {
      return NetworkException(
          context.l10n.timeoutError,
          code: 'TIMEOUT');
    }
    
    if (error is FormatException) {
      return ServerException(
          context.l10n.invalidServerResponse, 500);
    }
    
    return NetworkException(
        context.l10n.connectionError,
        originalError: error);
  }
}
