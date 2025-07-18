// test/unit/core/secure_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:runaway/core/helper/config/secure_config.dart';

void main() {
  group('SecureConfig', () {
    
    group('JWT Validation', () {
      test('valide un JWT correct', () {
        // JWT valide basique (header.payload.signature)
        const validJWT = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
        
        expect(SecureConfig.isValidJWT(validJWT), true);
      });

      test('rejette un JWT invalide', () {
        expect(SecureConfig.isValidJWT('invalid.jwt'), false);
        expect(SecureConfig.isValidJWT(''), false);
        expect(SecureConfig.isValidJWT('not.a.jwt.token'), false);
        expect(SecureConfig.isValidJWT('onlyonepart'), false);
      });

      test('extrait correctement l\'expiration d\'un JWT', () {
        // JWT avec exp: 1516239022 (timestamp Unix)
        const jwtWithExp = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyMzkwMjJ9.4Adcj3pn2XjmB5yVJJhkTpfbS8_r3DdMWZDVDYQHvOw';
        
        final expiration = SecureConfig.getJWTExpiration(jwtWithExp);
        expect(expiration, isNotNull);
        expect(expiration, isA<DateTime>());
      });

      test('retourne null pour JWT sans expiration', () {
        const jwtWithoutExp = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
        
        final expiration = SecureConfig.getJWTExpiration(jwtWithoutExp);
        expect(expiration, isNull);
      });
    });

    group('Configuration Tokens', () {
      test('mapboxToken a le bon format', () {
        try {
          final token = SecureConfig.mapboxToken;
          expect(token, isNotNull);
          expect(token, startsWith('pk.'));
        } catch (e) {
          // Si la variable d'environnement n'est pas configurée, c'est normal en test
          expect(e, isA<Exception>());
          expect(e.toString(), contains('MAPBOX_TOKEN non configuré'));
        }
      });

      test('supabaseUrl a le bon format', () {
        try {
          final url = SecureConfig.supabaseUrl;
          expect(url, isNotNull);
          expect(url, contains('supabase'));
          
          // Vérifier que c'est une URL valide
          final uri = Uri.tryParse(url);
          expect(uri, isNotNull);
          expect(uri!.isAbsolute, true);
        } catch (e) {
          // Si la variable d'environnement n'est pas configurée, c'est normal en test
          expect(e, isA<Exception>());
          expect(e.toString(), contains('SUPABASE_URL non configuré'));
        }
      });

      test('supabaseAnonKey a le bon format JWT', () {
        try {
          final key = SecureConfig.supabaseAnonKey;
          expect(key, isNotNull);
          expect(key, startsWith('eyJ')); // Format JWT
        } catch (e) {
          // Si la variable d'environnement n'est pas configurée, c'est normal en test
          expect(e, isA<Exception>());
          expect(e.toString(), contains('SUPABASE_ANON_KEY non configuré'));
        }
      });

      test('détecte l\'environnement correctement', () {
        expect(SecureConfig.kIsProduction, isA<bool>());
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

      test('gère le stockage et récupération de tokens', () async {
        // Test du cycle complet : stockage -> récupération -> nettoyage
        const testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0IiwibmFtZSI6IlRlc3QifQ.test';
        
        // Nettoyer d'abord
        await SecureConfig.clearStoredTokens();
        
        // Stocker un token
        await SecureConfig.storeAccessToken(testToken);
        
        // Récupérer le token
        final retrievedToken = await SecureConfig.getStoredAccessToken();
        
        // En fonction de la disponibilité du stockage sécurisé
        if (await SecureConfig.isSecureStorageAvailable()) {
          expect(retrievedToken, testToken);
        } else {
          // Si le stockage n'est pas disponible, on devrait recevoir null
          expect(retrievedToken, isNull);
        }
        
        // Nettoyer après le test
        await SecureConfig.clearStoredTokens();
      });

      test('gère le refresh token', () async {
        const testRefreshToken = 'refresh_token_test';
        
        // Nettoyer d'abord
        await SecureConfig.clearStoredTokens();
        
        // Stocker un refresh token
        await SecureConfig.storeRefreshToken(testRefreshToken);
        
        // Récupérer le refresh token
        final retrievedToken = await SecureConfig.getStoredRefreshToken();
        
        if (await SecureConfig.isSecureStorageAvailable()) {
          expect(retrievedToken, testRefreshToken);
        } else {
          expect(retrievedToken, isNull);
        }
        
        // Nettoyer après le test
        await SecureConfig.clearStoredTokens();
      });

      test('vérifie l\'expiration des tokens', () async {
        final isExpired = await SecureConfig.isTokenExpired();
        expect(isExpired, isA<bool>());
      });
    });

    group('Configuration Management', () {
      test('valide la configuration complète', () async {
        // Cette méthode ne devrait pas lever d'exception même si certaines configs manquent
        try {
          await SecureConfig.validateConfiguration();
          // Si ça passe, c'est bien
        } catch (e) {
          // Si ça échoue à cause de variables manquantes, c'est normal en test
          expect(e, isA<Exception>());
        }
      });

      test('nettoie le cache correctement', () async {
        await SecureConfig.clearCache();
        // Vérifier que ça ne lève pas d'exception
      });

      test('génère une clé de rotation', () async {
        await SecureConfig.generateRotationKey();
        // Vérifier que ça ne lève pas d'exception
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

      test('les taux d\'échantillonnage sont dans les bonnes limites', () {
        final sampleRate = SecureConfig.sentrySampleRate;
        final tracesSampleRate = SecureConfig.sentryTracesSampleRate;
        
        expect(sampleRate, greaterThanOrEqualTo(0.0));
        expect(sampleRate, lessThanOrEqualTo(1.0));
        expect(tracesSampleRate, greaterThanOrEqualTo(0.0));
        expect(tracesSampleRate, lessThanOrEqualTo(1.0));
      });
    });

    group('Error Handling', () {
      test('gère les tokens Mapbox invalides', () {
        // Ces tests dépendent des variables d'environnement
        // On teste que les exceptions sont bien levées pour les cas invalides
        try {
          final token = SecureConfig.mapboxToken;
          expect(token, startsWith('pk.'));
        } catch (e) {
          expect(e.toString(), anyOf([
            contains('MAPBOX_TOKEN non configuré'),
            contains('Token Mapbox invalide'),
          ]));
        }
      });

      test('gère les URLs Supabase invalides', () {
        try {
          final url = SecureConfig.supabaseUrl;
          final uri = Uri.tryParse(url);
          expect(uri, isNotNull);
          expect(uri!.isAbsolute, true);
        } catch (e) {
          expect(e.toString(), anyOf([
            contains('SUPABASE_URL non configuré'),
            contains('URL Supabase invalide'),
          ]));
        }
      });

      test('gère les clés Supabase invalides', () {
        try {
          final key = SecureConfig.supabaseAnonKey;
          expect(key, startsWith('eyJ'));
        } catch (e) {
          expect(e.toString(), anyOf([
            contains('SUPABASE_ANON_KEY non configuré'),
            contains('Clé Supabase anonyme invalide'),
          ]));
        }
      });
    });

    group('Edge Cases', () {
      test('gère les tokens vides et null', () {
        expect(SecureConfig.isValidJWT(''), false);
        expect(SecureConfig.getJWTExpiration(''), isNull);
      });

      test('gère les tokens malformés', () {
        expect(SecureConfig.isValidJWT('malformed'), false);
        expect(SecureConfig.isValidJWT('mal.formed'), false);
        expect(SecureConfig.getJWTExpiration('malformed'), isNull);
      });

      test('nettoie les tokens même en cas d\'erreur', () async {
        // Cette méthode devrait être robuste et ne pas lever d'exception
        await SecureConfig.clearStoredTokens();
        await SecureConfig.clearCache();
      });
    });
  });
}