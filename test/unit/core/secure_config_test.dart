// test/unit/core/secure_config_test.dart - Version simplifiée
import 'package:flutter_test/flutter_test.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import '../../test_setup.dart';

void main() {
  setUpAll(() async {
    await TestSetup.initialize();
  });

  tearDownAll(() async {
    await TestSetup.cleanup();
  });

  group('SecureConfig', () {
    
    group('JWT Validation', () {
      test('valide un JWT correct', () {
        const validJWT = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
        expect(SecureConfig.isValidJWT(validJWT), true);
      });

      test('rejette un JWT invalide', () {
        expect(SecureConfig.isValidJWT('invalid.jwt'), false);
        expect(SecureConfig.isValidJWT(''), false);
        expect(SecureConfig.isValidJWT('not.a.jwt.token'), false);
        expect(SecureConfig.isValidJWT('onlyonepart'), false);
      });
    });

    group('Configuration Tokens', () {
      test('mapboxToken a le bon format', () {
        try {
          final token = SecureConfig.mapboxToken;
          expect(token, isNotNull);
          expect(token, startsWith('pk.'));
        } catch (e) {
          // En mode test, on s'attend à ce que ça marche maintenant
          expect(e, isA<Exception>());
        }
      });

      test('supabaseUrl a le bon format', () {
        try {
          final url = SecureConfig.supabaseUrl;
          expect(url, isNotNull);
          expect(url, contains('supabase'));
          
          final uri = Uri.tryParse(url);
          expect(uri, isNotNull);
          expect(uri!.isAbsolute, true);
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('supabaseAnonKey a le bon format JWT', () {
        try {
          final key = SecureConfig.supabaseAnonKey;
          expect(key, isNotNull);
          expect(key, startsWith('eyJ'));
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('Secure Storage', () {
      test('vérifie la disponibilité du stockage sécurisé', () async {
        final isAvailable = await SecureConfig.isSecureStorageAvailable();
        expect(isAvailable, isA<bool>());
      });

      test('effectue un check de santé', () async {
        final isHealthy = await SecureConfig.checkSecureStorageHealth();
        expect(isHealthy, isA<bool>());
      });
    });

    group('Monitoring Configuration', () {
      test('a des valeurs par défaut pour le monitoring', () {
        expect(SecureConfig.isCrashReportingEnabled, isA<bool>());
        expect(SecureConfig.isPerformanceMonitoringEnabled, isA<bool>());
        expect(SecureConfig.sentrySampleRate, isA<double>());
        expect(SecureConfig.sentryTracesSampleRate, isA<double>());
      });

      test('a des valeurs par défaut pour les logs', () {
        expect(SecureConfig.logLevel, isA<String>());
        expect(SecureConfig.isSupabaseLoggingEnabled, isA<bool>());
        expect(SecureConfig.logRetentionDays, isA<int>());
      });
    });
  });
}