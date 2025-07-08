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
  
  // 🆕 Configuration Stripe
  static String get stripePublishableKey {
    final String? key = isProduction 
        ? dotenv.env['STRIPE_PUBLIC_KEY_TEST']
        : dotenv.env['STRIPE_PUBLIC_KEY_PROD'];
    
    if (key == null || key.isEmpty) {
      throw Exception('Stripe publishable key must be configured in .env file');
    }
    
    return key;
  }
  
  static String get stripeSecretKey {
    final String? key = isProduction 
        ? dotenv.env['STRIPE_PRIVATE_KEY_TEST']
        : dotenv.env['STRIPE_PRIVATE_KEY_PROD'];
    
    if (key == null || key.isEmpty) {
      throw Exception('Stripe secret key must be configured in .env file');
    }
    
    return key;
  }
  
  static String get merchantIdentifier {
    return dotenv.env['STRIPE_MERCHANT_IDENTIFIER'] ?? 'merchant.com.trailix.runaway';
  }
  
  static void validate() {
    try {
      apiBaseUrl; // Déclenche la validation
      stripePublishableKey; // 🆕 Validation Stripe
      stripeSecretKey; // 🆕 Validation Stripe
      print('✅ Configuration environment et Stripe validée');
    } catch (e) {
      print('❌ Erreur configuration: $e');
      rethrow;
    }
  }
}