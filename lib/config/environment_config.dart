import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  static String get apiBaseUrl {
    final String? baseUrl = dotenv.env['API_BASE_URL'];
    
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('API_BASE_URL must be configured in .env file');
    }
    
    // Validation de l'URL
    if (!Uri.tryParse(baseUrl)!.isAbsolute) {
      throw Exception('API_BASE_URL must be a valid absolute URL');
    }
    
    return baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  }
  
  static Duration get apiTimeout => Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '30') ?? 30,
  );
  
  static bool get isProduction => dotenv.env['ENVIRONMENT'] == 'production';
  static bool get isDevelopment => dotenv.env['ENVIRONMENT'] == 'development';
  
  static void validate() {
    try {
      apiBaseUrl; // Déclenche la validation
      print('✅ Configuration environment');
    } catch (e) {
      print('❌ Erreur configuration: $e');
      rethrow;
    }
  }
}