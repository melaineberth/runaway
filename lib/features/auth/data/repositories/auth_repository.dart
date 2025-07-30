import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/errors/auth_exceptions.dart';
import 'package:runaway/core/helper/config/secure_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/cache_service.dart';
import 'package:runaway/core/helper/services/device_fingerprint_service.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/core/router/router.dart';
import 'package:runaway/core/utils/injections/service_locator.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:runaway/core/helper/config/log_config.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Variables statiques pour stocker temporairement les infos Apple/Google
  static String? _tempAppleFullName;
  static String? _tempGoogleFullName;

  User? get currentUser => _supabase.auth.currentUser;

  // ---------- stream Auth (session) ----------
  Stream<AuthState> get authChangesStream => _supabase.auth.onAuthStateChange;

  /// 🔒 Stocke les tokens d'une session de façon sécurisée
  Future<void> _storeSessionTokensSecurely(Session session) async {
    try {
      // 🆕 FORCER l'affichage avec print pour diagnostic
      print('🔒 DEBUT STOCKAGE TOKENS SESSION');
      
      // Vérifier d'abord l'état du stockage sécurisé
      final isStorageHealthy = await SecureConfig.checkSecureStorageHealth();
      print('🔒 SANTE STOCKAGE SECURISE: $isStorageHealthy');
      
      await SecureConfig.storeAccessToken(session.accessToken);
      print('🔒 ACCESS TOKEN TRAITE');
      
      if (session.refreshToken != null) {
        await SecureConfig.storeRefreshToken(session.refreshToken!);
        print('🔒 REFRESH TOKEN TRAITE');
      }

      // Stocker aussi le profil en cache si disponible
      if (session.user != null) {
        try {
          final profile = await getProfile(session.user.id);
          if (profile != null) {
            final cacheService = CacheService.instance;
            await cacheService.storeUserSession(session.user.id, profile.toJson());
            LogConfig.logInfo('💾 Session utilisateur mise en cache lors du stockage tokens');
          }
        } catch (e) {
          // Ne pas faire échouer le stockage des tokens si le cache échoue
          LogConfig.logError('⚠️ Erreur cache session lors stockage tokens: $e');
        }
      }
      
      print('🔒 TOKENS SESSION STOCKES AVEC SUCCES');
      LogConfig.logInfo('🔒 Tokens session stockés de façon sécurisée');
    } catch (e) {
      print('⚠️ ERREUR STOCKAGE SECURISE: $e');
      LogConfig.logWarning('⚠️ Stockage sécurisé échoué (continuons): $e');
      // Ne pas faire échouer l'auth si le stockage sécurisé échoue
    }
  }

  /// 🔒 Valide un token JWT avant utilisation
  bool _validateTokenBeforeUse(String token) {
    try {
      // Validation du format JWT
      if (!SecureConfig.isValidJWT(token)) {
        LogConfig.logWarning('⚠️ Token JWT invalide détecté');
        return false;
      }

      // Vérification de l'expiration
      final expiry = SecureConfig.getJWTExpiration(token);
      if (expiry != null) {
        final now = DateTime.now();
        if (now.isAfter(expiry)) {
          LogConfig.logWarning('⚠️ Token JWT expiré détecté (exp: $expiry, now: $now)');
          return false;
        }
        
        // Log pour debug - temps restant
        final timeLeft = expiry.difference(now);
        LogConfig.logInfo('✅ Token valide, expire dans: ${timeLeft.inMinutes} minutes');
      } else {
        LogConfig.logInfo('✅ Token valide (pas d\'expiration détectée)');
      }

      return true;
    } catch (e) {
      LogConfig.logWarning('⚠️ Erreur validation token: $e');
      // Pour les tokens Apple, être plus permissif en cas d'erreur de validation
      // car Apple peut avoir des spécificités non standards
      LogConfig.logInfo('🍎 Autorisation token Apple malgré erreur validation');
      return true; // En cas d'erreur, laisser passer (comme avant)
    }
  }

  /// 🔒 Vérifie et refresh automatiquement si nécessaire
  Future<bool> _ensureValidSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return false;

      // Vérifier le token stocké si disponible
      try {
        final storedToken = await SecureConfig.getStoredAccessToken();
        if (storedToken != null && !_validateTokenBeforeUse(storedToken)) {
          LogConfig.logInfo('🔄 Token invalide, tentative de refresh...');
          
          try {
            await _supabase.auth.refreshSession();
            final newSession = _supabase.auth.currentSession;
            if (newSession != null) {
              await _storeSessionTokensSecurely(newSession);
              return true;
            }
          } catch (refreshError) {
            LogConfig.logWarning('⚠️ Refresh automatique échoué: $refreshError');
            // Continuer même si le refresh échoue
          }
        }

        // Vérifier l'expiration du stockage sécurisé
        final isExpired = await SecureConfig.isTokenExpired();
        if (isExpired) {
          LogConfig.logInfo('🔄 Token proche expiration, refresh préventif...');
          
          try {
            await _supabase.auth.refreshSession();
            final newSession = _supabase.auth.currentSession;
            if (newSession != null) {
              await _storeSessionTokensSecurely(newSession);
            }
          } catch (refreshError) {
            LogConfig.logWarning('⚠️ Refresh préventif échoué: $refreshError');
            // Continuer même si le refresh échoue
          }
        }
      } catch (storageError) {
        LogConfig.logWarning('⚠️ Erreur stockage sécurisé: $storageError');
        // Continuer même si le stockage sécurisé ne fonctionne pas
      }

      return true;
    } catch (e) {
      LogConfig.logWarning('⚠️ Erreur validation session: $e');
      return true; // Continuer même en cas d'erreur
    }
  }

  /* ───────── 1) CRÉATION DE COMPTE (ÉTAPE 1) ───────── */
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    
    final operationId = MonitoringService.instance.trackApiRequest(
      'auth.signUp',
      'POST',
      headers: {'Content-Type': 'application/json'},
      body: {'email': email},
    );

    try {
      LogConfig.logInfo('📧 Début inscription email: $email');

      // Générer l'empreinte de l'appareil AVANT l'inscription
      Map<String, String> deviceFingerprint = {};
      try {
        deviceFingerprint = await DeviceFingerprintService.instance.generateDeviceFingerprint();
        LogConfig.logInfo('📱 Empreinte appareil générée: ${deviceFingerprint['device_fingerprint']?.substring(0, 8)}...');
      } catch (e) {
        LogConfig.logError('⚠️ Erreur génération empreinte: $e');
      }
      
      final resp = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: deviceFingerprint.isNotEmpty ? {
          'device_fingerprint': deviceFingerprint['device_fingerprint'],
          'device_model': deviceFingerprint['device_model'],
          'device_manufacturer': deviceFingerprint['device_manufacturer'],
          'platform': deviceFingerprint['platform'],
          'signup_timestamp': DateTime.now().toIso8601String(),
          'signup_method': 'email',
        } : {
          'signup_timestamp': DateTime.now().toIso8601String(),
          'signup_method': 'email',
        },
      );
      
      if (resp.user != null) {
        LogConfig.logInfo('Inscription réussie pour: ${resp.user!.email}');

        // 🔒 Stocker les tokens si session créée
        if (resp.session != null) {
          await _storeSessionTokensSecurely(resp.session!);
        }

        MonitoringService.instance.finishApiRequest(
          operationId,
          statusCode: 200,
          responseSize: resp.toString().length,
        );

        // Métrique business - nouveau compte créé
        MonitoringService.instance.recordMetric(
          'user_registration',
          1,
          tags: {
            'source': 'email',
            'has_device_fingerprint': deviceFingerprint.isNotEmpty.toString(),
            'platform': deviceFingerprint['platform'] ?? 'unknown',
          },
        );

        return resp.user;
      } else {
        LogConfig.logError('❌ Inscription échouée: aucun utilisateur retourné');
        throw SignUpException('Impossible de créer le compte');
      }
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur inscription: $e');

      MonitoringService.instance.finishApiRequest(
        operationId,
        statusCode: 400,
        errorMessage: e.toString(),
      );

      MonitoringService.instance.captureError(e, stackTrace, context: 'AuthRepository.signUp');

      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  /* ───────── GOOGLE SIGN-IN ───────── */
  Future<Profile?> signInWithGoogle() async {
    final operationId = MonitoringService.instance.trackApiRequest(
      'auth.signInWithGoogle',
      'POST',
      headers: {'Content-Type': 'application/json'},
      body: {'provider': 'google'},
    );

    try {
      LogConfig.logInfo('🌐 Début connexion Google');

      final webClientId = SecureConfig.googleWebClientId;
      final iosClientId = SecureConfig.googleIosClientId;

      // 🆕 Générer l'empreinte de l'appareil AVANT la connexion Google
      Map<String, String> deviceFingerprint = {};
      try {
        deviceFingerprint = await DeviceFingerprintService.instance.generateDeviceFingerprint();
        LogConfig.logInfo('📱 Empreinte appareil générée: ${deviceFingerprint['device_fingerprint']?.substring(0, 8)}...');
      } catch (e) {
        LogConfig.logError('⚠️ Erreur génération empreinte: $e');
      }

      // 1. Configuration Google Sign-In
      await GoogleSignIn().signOut(); // Nettoyer session précédente
      
      // 2. Initier la connexion Google
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      final googleAuth = await googleUser!.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw 'No Access Token found.';
      }
      if (idToken == null) {
        throw 'No ID Token found.';
      }

      // 🔒 Valider les tokens Google avant usage
      if (!_validateTokenBeforeUse(idToken)) {
        throw AuthException('Token Google invalide');
      }
      
      LogConfig.logInfo('Utilisateur Google obtenu: ${googleUser.email}');

      // 3. Stocker temporairement les informations Google
      _tempGoogleFullName = googleUser.displayName;
      if (_tempGoogleFullName != null) {
        LogConfig.logInfo('📝 Nom Google stocké temporairement: $_tempGoogleFullName');
      }
            
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw AuthException('Tokens Google manquants');
      }
      
      LogConfig.logInfo('Tokens Google obtenus');
      
      // 4. Connexion avec Supabase
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken!,
      );
      
      if (response.user == null) {
        throw AuthException('Échec de la connexion avec Supabase');
      }

      final user = response.user!;
      LogConfig.logInfo('Connexion Google réussie: ${user.email}');

      // 🆕 4. Mettre à jour les métadonnées utilisateur avec l'empreinte d'appareil si c'est un nouveau compte
      if (deviceFingerprint.isNotEmpty) {
        try {
          final userCreatedAt = DateTime.parse(user.createdAt);
          final now = DateTime.now();
          final isNewUser = userCreatedAt.isAfter(now.subtract(Duration(seconds: 10)));
          
          if (isNewUser) {
            LogConfig.logInfo('📱 Nouveau compte Google - ajout empreinte avec vérification');
            
            await _supabase.auth.updateUser(
              UserAttributes(
                data: deviceFingerprint.isNotEmpty ? {
                  'device_fingerprint': deviceFingerprint['device_fingerprint'],
                  'device_model': deviceFingerprint['device_model'],
                  'device_manufacturer': deviceFingerprint['device_manufacturer'],
                  'platform': deviceFingerprint['platform'],
                  'signup_timestamp': DateTime.now().toIso8601String(),
                  'signup_method': 'google',
                } : {
                  'signup_timestamp': DateTime.now().toIso8601String(),
                  'signup_method': 'google',
                },
              ),
            );
            
            LogConfig.logInfo('✅ Métadonnées Google ajoutées');            
          }
        } catch (e) {
          LogConfig.logError('⚠️ Erreur ajout métadonnées Google: $e');
        }
      }

      // 🔒 Stocker les tokens Supabase de façon sécurisée
      if (response.session != null) {
        await _storeSessionTokensSecurely(response.session!);
      }
      
      LogConfig.logInfo('Connexion Supabase réussie: ${response.user!.email}');
      
      // 5. Vérifier si un profil existe déjà (nouveau comportement)
      final existingProfile = await getProfile(response.user!.id, skipCleanup: true);

      // 🆕 Monitoring de succès
      MonitoringService.instance.finishApiRequest(
        operationId,
        statusCode: 200,
        responseSize: response.toString().length,
      );

      if (existingProfile != null && existingProfile.isComplete) {
        LogConfig.logInfo('Profil Google existant trouvé: ${existingProfile.username}');

        // 🆕 Métrique business - utilisateur existant
        MonitoringService.instance.recordMetric(
          'user_google_signin',
          1,
          tags: {
            'success': 'true',
            'has_device_fingerprint': deviceFingerprint.isNotEmpty.toString(),
            'platform': deviceFingerprint['platform'] ?? 'unknown',
          },
        );

        // Nettoyer les données temporaires
        _tempGoogleFullName = null;
        return existingProfile;
      }

      // 🆕 Métrique business - nouvel utilisateur
      MonitoringService.instance.recordMetric(
        'user_registration',
        1,
        tags: {
          'source': 'google',
          'needs_onboarding': 'true',
        },
      );
      
      // 6. Pour les nouveaux utilisateurs, retourner null pour forcer l'onboarding
      LogConfig.logInfo('📝 Nouveau compte Google - sera dirigé vers l\'onboarding');
      return null;
      
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur Google Sign-In: $e');

      // 🆕 Monitoring d'erreur
      MonitoringService.instance.finishApiRequest(
        operationId,
        statusCode: 400,
        errorMessage: e.toString(),
      );

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'AuthRepository.signInWithGoogle',
        extra: {
          'provider': 'google',
          'step': _determineGoogleErrorStep(e),
        },
      );

      // 🆕 Métrique d'échec
      MonitoringService.instance.recordMetric(
        'user_login_failure',
        1,
        tags: {
          'method': 'google',
          'error_type': e.runtimeType.toString(),
          'error_category': _categorizeAuthError(e),
        },
      );

      // Nettoyer en cas d'erreur
      _tempGoogleFullName = null;
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  /* ───────── APPLE SIGN-IN ───────── */
  Future<Profile?> signInWithApple() async {
    final operationId = MonitoringService.instance.trackApiRequest(
      'auth.signInWithApple',
      'POST',
      headers: {'Content-Type': 'application/json'},
      body: {'provider': 'apple'},
    );

    try {
      LogConfig.logInfo('🍎 Début connexion Apple');
      
      // 1. Vérifier la disponibilité d'Apple Sign-In
      if (!await SignInWithApple.isAvailable()) {
        throw AuthException('Apple Sign-In non disponible sur cet appareil');
      }

      // 🆕 2. Générer l'empreinte de l'appareil AVANT la connexion Apple
      Map<String, String> deviceFingerprint = {};
      try {
        deviceFingerprint = await DeviceFingerprintService.instance.generateDeviceFingerprint();
        LogConfig.logInfo('📱 Empreinte appareil générée: ${deviceFingerprint['device_fingerprint']?.substring(0, 8)}...');
      } catch (e) {
        LogConfig.logError('⚠️ Erreur génération empreinte: $e');
      }

      // ← Nettoie la session Supabase et les tokens locaux
      await _supabase.auth.signOut();
      await SecureConfig.clearStoredTokens();
      
      // 3. Générer un nonce sécurisé
      final rawNonce = _generateNonce();
      final state = _generateNonce();  // recommandé aussi pour le paramètre state
      final hashedNonce = sha256ofString(rawNonce);
      
      // 4. Initier la connexion Apple
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
        state: state,
      );

      // 🔒 Valider le token Apple
      if (credential.identityToken != null && 
          !_validateTokenBeforeUse(credential.identityToken!)) {
        throw AuthException('Token Apple invalide');
      }
      
      LogConfig.logInfo('Credentials Apple obtenus');

      // 4. Stocker temporairement les informations de nom Apple
      if (credential.givenName != null || credential.familyName != null) {
        final fullName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
        if (fullName.isNotEmpty) {
          _tempAppleFullName = fullName;
          LogConfig.logInfo('📝 Nom Apple stocké temporairement: $fullName');
        } else {
          _tempAppleFullName = null;
        }
      } else {
        _tempAppleFullName = null;
        LogConfig.logInfo('Aucun nom fourni par Apple');
      }
      
      // 5. Connexion avec Supabase
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
        nonce: rawNonce,
      );
      
      if (response.user == null) {
        throw AuthException('Échec de la connexion avec Supabase');
      }

      final user = response.user!;
      LogConfig.logInfo('Connexion Apple réussie: ${user.email}');

      // 🆕 7. Mettre à jour les métadonnées utilisateur avec l'empreinte d'appareil si c'est un nouveau compte
      if (deviceFingerprint.isNotEmpty) {
        try {
          final userCreatedAt = DateTime.parse(user.createdAt);
          final now = DateTime.now();
          final isNewUser = userCreatedAt.isAfter(now.subtract(Duration(seconds: 10)));
          
          if (isNewUser) {
            LogConfig.logInfo('📱 Nouveau compte Apple - ajout empreinte avec vérification');
            
            await _supabase.auth.updateUser(
              UserAttributes(
                data: deviceFingerprint.isNotEmpty ? {
                  'device_fingerprint': deviceFingerprint['device_fingerprint'],
                  'device_model': deviceFingerprint['device_model'],
                  'device_manufacturer': deviceFingerprint['device_manufacturer'],
                  'platform': deviceFingerprint['platform'],
                  'signup_timestamp': DateTime.now().toIso8601String(),
                  'signup_method': 'apple',
                } : {
                  'signup_timestamp': DateTime.now().toIso8601String(),
                  'signup_method': 'apple',
                },
              ),
            );
            
            LogConfig.logInfo('✅ Métadonnées Apple ajoutées');            
          }
        } catch (e) {
          LogConfig.logError('⚠️ Erreur ajout métadonnées Apple: $e');
        }
      }

      // 🔒 Stocker les tokens Supabase de façon sécurisée
      if (response.session != null) {
        await _storeSessionTokensSecurely(response.session!);
      }
      
      LogConfig.logInfo('Connexion Supabase réussie: ${response.user!.email}');
      
      // 6. Vérifier si un profil existe déjà
      final existingProfile = await getProfile(response.user!.id, skipCleanup: true);

      // 🆕 Monitoring de succès
      MonitoringService.instance.finishApiRequest(
        operationId,
        statusCode: 200,
        responseSize: response.toString().length,
      );

      if (existingProfile != null && existingProfile.isComplete) {
        LogConfig.logInfo('Profil Apple existant trouvé: ${existingProfile.username}');

        // 🆕 Métrique business - utilisateur existant avec info appareil
        MonitoringService.instance.recordMetric(
          'user_login_success',
          1,
          tags: {
            'method': 'apple',
            'is_returning_user': 'true',
            'has_device_fingerprint': deviceFingerprint.isNotEmpty.toString(),
            'platform': deviceFingerprint['platform'] ?? 'unknown',
          },
        );

        // Nettoyer les données temporaires
        _tempAppleFullName = null;
        return existingProfile;
      }

      // 🆕 Métrique business - nouvel utilisateur
      MonitoringService.instance.recordMetric(
        'user_registration',
        1,
        tags: {
          'source': 'apple',
          'needs_onboarding': 'true',
          'has_name': (_tempAppleFullName != null).toString(),
          'has_device_fingerprint': deviceFingerprint.isNotEmpty.toString(),
          'platform': deviceFingerprint['platform'] ?? 'unknown',
        },
      );
      
      // 7. Pour les nouveaux utilisateurs, retourner null pour forcer l'onboarding
      LogConfig.logInfo('📝 Nouveau compte Apple - sera dirigé vers l\'onboarding');
      return null;
      
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur Apple Sign-In: $e');

      // 🆕 Monitoring d'erreur
      MonitoringService.instance.finishApiRequest(
        operationId,
        statusCode: 400,
        errorMessage: e.toString(),
      );

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'AuthRepository.signInWithApple',
        extra: {
          'provider': 'apple',
          'step': _determineAppleErrorStep(e),
          'has_identity_token': currentUser != null,
        },
      );

      // 🆕 Métrique d'échec
      MonitoringService.instance.recordMetric(
        'user_login_failure',
        1,
        tags: {
          'method': 'apple',
          'error_type': e.runtimeType.toString(),
          'error_category': _categorizeAuthError(e),
        },
      );

      // Nettoyer en cas d'erreur
      _tempAppleFullName = null;
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  /* ───────── HELPER POUR GÉNÉRER NONCE ───────── */
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /* ───────── 2) COMPLÉMENT DE PROFIL (ÉTAPE 2) ───────── */
  Future<Profile?> completeProfile({
    required String userId,
    required String fullName,
    required String username,
    File? avatar,
  }) async {
    final operationId = MonitoringService.instance.trackOperation(
      'complete_profile',
      description: 'Complétion du profil utilisateur',
      data: {
        'user_id': userId,
        'has_avatar': avatar != null,
        'username_length': username.length,
        'full_name_length': fullName.length,
      },
    );

    try {
      // 🔒 Vérifier que la session est valide avant de continuer
      final isSessionValid = await _ensureValidSession();
      if (!isSessionValid) {
        throw AuthException('Session invalide, reconnexion requise');
      }

      LogConfig.logInfo('👤 Complétion du profil pour: $userId');

      // 1. Vérifier si le nom d'utilisateur est disponible
      if (!await isUsernameAvailable(username)) {
        throw AuthException('Ce nom d\'utilisateur n\'est pas disponible');
      }
      
      String? avatarUrl;
      
      // 2. Upload de l'avatar si fourni
      if (avatar != null) {
        try {
          // Structure : userId/profile_picture/profile_picture.extension
          final extension = p.extension(avatar.path);
          final filePath = '$userId/profile_picture/profile_picture$extension';
          
          print('📸 Upload avatar: $filePath');
          
          await _supabase.storage.from('profile').upload(
            filePath, 
            avatar,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true, // Écraser si existe déjà
            ),
          );
          
          avatarUrl = _supabase.storage.from('profile').getPublicUrl(filePath);
          LogConfig.logInfo('Avatar uploadé: $avatarUrl');
        } catch (e) {
          LogConfig.logInfo('Erreur upload avatar (continuez sans avatar): $e');
          avatarUrl = null;
        }
      }

      // 3. Validation anti-abus des crédits
      try {
        LogConfig.logInfo('🔍 Validation finale anti-abus des crédits pour: $userId');
        
        final validationResult = await _supabase
            .rpc('validate_user_credits', params: {'p_user_id': userId});
        
        if (validationResult != null) {
          if (validationResult['credits_removed'] == true) {
            LogConfig.logWarning('⚠️ Crédits retirés pour abus détecté: $userId');
          } else if (validationResult['credits_validated'] == true) {
            LogConfig.logInfo('✅ Crédits validés: $userId (${validationResult['credits_count']} crédits)');
          }
        }
        
        // 🆕 AJOUT: Si l'appareil n'était pas encore enregistré, l'enregistrer maintenant
        try {
          final currentUser = _supabase.auth.currentUser;
          final deviceFingerprint = currentUser?.userMetadata?['device_fingerprint'] as String?;
          
          if (deviceFingerprint != null && deviceFingerprint.isNotEmpty) {
            // Vérifier si l'appareil est déjà enregistré
            final existingRegistration = await _supabase
                .from('device_registrations')
                .select('id')
                .eq('device_fingerprint', deviceFingerprint)
                .eq('email', currentUser!.email!)
                .maybeSingle();
            
            if (existingRegistration == null) {
              LogConfig.logInfo('📝 Enregistrement appareil lors de completeProfile (rattrapage)...');
              
              final registerResult = await _supabase.rpc('register_device_after_otp', params: {
                'p_user_id': userId,
              });
              
              LogConfig.logInfo('✅ Enregistrement rattrapage: $registerResult');
            } else {
              LogConfig.logInfo('✅ Appareil déjà enregistré');
            }
          }
        } catch (e) {
          LogConfig.logWarning('⚠️ Erreur vérification/enregistrement appareil: $e');
        }
      } catch (e) {
        LogConfig.logError('⚠️ Erreur validation crédits (continuant): $e');
        // On continue même si la validation échoue
      }

      // 4. Récupérer l'email depuis l'utilisateur connecté
      final user = _supabase.auth.currentUser;
      if (user?.email == null) {
        throw AuthException('Utilisateur non connecté ou email manquant');
      }

      final initialColor = math.Random().nextInt(Colors.primaries.length);
      final userColor = HSLColor.fromColor(Colors.primaries[initialColor])
          .withLightness(0.8)
          .toColor();

      // Convertir en format Flutter-friendly (ex: 0xFF2196F3)
      final colorHex = '0x${userColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

      // 5. Sauvegarder le profil complet
      final data = await _supabase
        .from('profiles')
        .upsert({
          'id': userId,
          'email': user!.email!, // Utiliser l'email de l'utilisateur connecté
          'full_name': fullName,
          'username': username,
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
          'color': colorHex,
        })
        .select()
        .maybeSingle();

      if (data == null) {
        throw ProfileException('Impossible de sauvegarder le profil');
      }

      final profile = Profile.fromJson(data);
      LogConfig.logInfo('Profil complété: ${profile.username}');

      // Vérifier et forcer l'enregistrement de l'appareil après création du profil
      try {
        LogConfig.logInfo('🔍 Vérification appareil après création profil...');
        await _forceDeviceCheck(userId);
      } catch (e) {
        LogConfig.logWarning('⚠️ Erreur vérification appareil post-profil: $e');
        // Ne pas faire échouer la création du profil pour ça
      }

      // Monitoring de succès
      MonitoringService.instance.finishOperation(
        operationId,
        success: true,
        data: {
          'username': username,
          'has_avatar': avatarUrl != null,
          'avatar_upload_success': avatar != null ? avatarUrl != null : null,
        },
      );

      // Métrique business - profil complété
      MonitoringService.instance.recordMetric(
        'profile_completed',
        1,
        tags: {
          'has_avatar': (avatarUrl != null).toString(),
          'username_source': _determineUsernameSource(username),
          'provider': _determineSignupProvider(user),
        },
      );

      // 6. Informer si l'avatar n'a pas pu être uploadé
      if (avatar != null && avatarUrl == null) {
        // On peut retourner le profil mais signaler que l'avatar a échoué
        // L'UI pourra afficher un avertissement
        LogConfig.logInfo('Profil créé mais avatar non uploadé');
      }

      return profile;
      
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur complétion profil: $e');

      // Monitoring d'erreur
      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: e.toString(),
      );

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'AuthRepository.completeProfile',
        extra: {
          'user_id': userId,
          'username': username,
          'has_avatar': avatar != null,
        },
      );

      if (e is AuthException) {
        rethrow;
      }
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  // ---------- connexion ----------
  Future<Profile?> signInWithEmail({
    required String email,
    required String password,
  }) async {

    final operationId = MonitoringService.instance.trackApiRequest(
      'auth.signInWithPassword',
      'POST',
      headers: {'Content-Type': 'application/json'},
      body: {'email': email, 'method': "email"},
    );

    try {
      print('🔑 Tentative de connexion: $email');
      
      final resp = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      
      final user = resp.user;
      if (user == null) {
        LogConfig.logError('❌ Connexion échouée: aucun utilisateur retourné');
        throw LoginException('Connexion échouée');
      }

      // 🔒 Stocker les tokens de façon sécurisée
      if (resp.session != null) {
        await _storeSessionTokensSecurely(resp.session!);
      }
      
      LogConfig.logInfo('Connexion réussie: ${resp.user!.email}');

      // Vérifier si un profil existe
      final existingProfile = await getProfile(resp.user!.id, skipCleanup: true);

      MonitoringService.instance.finishApiRequest(
        operationId,
        statusCode: 200,
        responseSize: resp.toString().length,
      );

      if (existingProfile != null && existingProfile.isComplete) {
        LogConfig.logInfo('Profil existant trouvé: ${existingProfile.username}');

        MonitoringService.instance.recordMetric(
          'user_login_success',
          1,
          tags: {
            'method': 'email',
            'is_returning_user': 'true',
          },
        );

        return existingProfile;
      }

      // Nouveau utilisateur nécessite un profil
      MonitoringService.instance.recordMetric(
        'user_registration',
        1,
        tags: {
          'source': 'email',
          'needs_onboarding': 'true',
        },
      );

      return null; // Indique qu'il faut compléter le profil
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur connexion: $e');

      MonitoringService.instance.finishApiRequest(
        operationId,
        statusCode: 400,
        errorMessage: e.toString(),
      );

      MonitoringService.instance.captureError(
        e,
        stackTrace,
        context: 'AuthRepository.signIn',
        extra: {
          'method': "email",
          'has_email': email != null,
        },
      );

      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  // ---------- lecture profile ----------
  Future<Profile?> getProfile(String id, {bool skipCleanup = false}) async {
    try {
      LogConfig.logInfo('👤 Récupération profil: $id');
      
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle()
          .timeout(Duration(seconds: 10)); // Timeout pour éviter l'attente infinie
      
      if (data == null) {
        LogConfig.logInfo('Aucun profil trouvé pour: $id');
        
        // Ne nettoyer que si explicitement demandé
        // Cela permet aux nouveaux utilisateurs d'avoir une chance de compléter leur profil
        if (!skipCleanup) {
          LogConfig.logInfo('ℹ️ Profil non trouvé mais pas de nettoyage automatique');
        }
        return null;
      }
      
      // L'email est maintenant directement dans les données de la DB
      final profile = Profile.fromJson(data);
      
      LogConfig.logInfo('Profil récupéré: ${profile.username}');
      return profile;
    } catch (e) {
      LogConfig.logError('❌ Erreur récupération profil: $e');

      // Si c'est un timeout ou problème réseau, ne pas retourner null
      // pour permettre l'utilisation du cache
      if (e.toString().contains('timeout') || 
          e.toString().contains('network') ||
          e.toString().contains('connection')) {
        LogConfig.logInfo('🌐 Problème réseau détecté, utilisation du cache possible');
        throw NetworkException('Problème de réseau lors de la récupération du profil');
      }

      return null;
    }
  }

  // ---------- déconnexion ----------
  Future<void> signOut() async {
    try {
      LogConfig.logInfo('🚪 Début déconnexion...');
      
      // 1. Nettoyage complet du cache AVANT la déconnexion
      await _clearAllUserData();

      // 2. Déconnexion Supabase
      await _supabase.auth.signOut();

      // 3. Nettoyage supplémentaire APRÈS la déconnexion
      await _clearAllUserData();
      
      LogConfig.logInfo('✅ Déconnexion réussie');
    } catch (e) {
      LogConfig.logError('❌ Erreur déconnexion: $e');
      
      // En cas d'erreur, forcer quand même le nettoyage
      await _clearAllUserData();
      
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  /// 🆕 Nettoyage complet de toutes les données utilisateur
  Future<void> _clearAllUserData() async {
    try {
      LogConfig.logInfo('🧹 Nettoyage complet des données utilisateur...');
      
      // Vider le cache des crédits en premier
      await _invalidateCreditsCache();
      
      // Vider le cache général via CacheService
      try {
        final cacheService = CacheService.instance;
        await cacheService.invalidateCreditsCache(); // Double sécurité
        await cacheService.clear();
        LogConfig.logInfo('🧹 Cache général vidé');
      } catch (e) {
        LogConfig.logError('❌ Erreur vidage cache général: $e');
      }
      
      //  Nettoyer les données AppDataBloc
      try {
        final appDataBloc = sl.get<AppDataBloc>();
        appDataBloc.add(const AppDataClearRequested());
        LogConfig.logInfo('🧹 AppDataBloc nettoyé');
        
        //  Attendre que le nettoyage soit traité
        await Future.delayed(Duration(milliseconds: 200));
      } catch (e) {
        LogConfig.logError('❌ Erreur nettoyage AppDataBloc: $e');
      }
      
      //  Nettoyer les données CreditsBloc si disponible
      try {
        final creditsBloc = sl.isRegistered<CreditsBloc>() ? sl.get<CreditsBloc>() : null;
        if (creditsBloc != null) {
          creditsBloc.add(const CreditsReset());
          LogConfig.logInfo('🧹 CreditsBloc nettoyé');
          
          // Attendre que le reset soit traité
          await Future.delayed(Duration(milliseconds: 100));
        }
      } catch (e) {
        LogConfig.logError('❌ Erreur nettoyage CreditsBloc: $e');
      }
      
      LogConfig.logInfo('✅ Nettoyage complet des données terminé');
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage données utilisateur: $e');
    }
  }

  // ---------- vérification du nom d'utilisateur ----------
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final result = await _supabase
          .from('profiles')
          .select('id')
          .eq('username', username.trim().toLowerCase())
          .maybeSingle();
      
      return result == null; // Disponible si aucun résultat
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification username: $e');
      // En cas d'erreur, considérer comme non disponible par sécurité
      return false;
    }
  }

  // ---------- mise à jour du profil ----------
  Future<Profile?> updateProfile({
    required String userId,
    String? fullName,
    String? username,
    String? phone,
    File? avatar,
  }) async {
    try {
      LogConfig.logInfo('📝 Mise à jour profil: $userId');
      
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (fullName != null) updates['full_name'] = fullName.trim();
      if (username != null) {
        // Vérifier la disponibilité du nom d'utilisateur
        final isAvailable = await isUsernameAvailable(username);
        if (!isAvailable) {
          throw ProfileException('Ce nom d\'utilisateur est déjà pris');
        }
        updates['username'] = username.trim().toLowerCase();
      }
      if (phone != null) updates['phone'] = phone.trim();
      
      // Upload nouvel avatar si fourni
      if (avatar != null) {
        try {
          final filePath = 'profile/$userId${p.extension(avatar.path)}';
          await _supabase.storage.from('profile').upload(
            filePath, 
            avatar,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );
          
          // 🔧 FIX: Ajouter un timestamp pour forcer le cache-busting
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final baseUrl = _supabase.storage.from('profile').getPublicUrl(filePath);
          updates['avatar_url'] = '$baseUrl?v=$timestamp';
          
        } catch (e) {
          LogConfig.logInfo('Erreur upload nouvel avatar: $e');
          // Continuer sans mettre à jour l'avatar
        }
      }
      
      final data = await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .maybeSingle();
      
      if (data == null) {
        throw ProfileException('Impossible de mettre à jour le profil');
      }
      
      // FIX: L'email est maintenant directement dans les données retournées
      final profile = Profile.fromJson(data);
      
      LogConfig.logInfo('Profil mis à jour: ${profile.username}');

      // 🆕 Métrique de mise à jour profil
      MonitoringService.instance.recordMetric(
        'profile_updated',
        1,
        tags: {
          'fields_updated': [
            if (fullName != null) 'full_name',
            if (avatar != null) 'avatar_url',
          ].length.toString(),
        },
      );

      return profile;
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur mise à jour profil: $e');
      if (e is AuthException) {
        MonitoringService.instance.captureError(
          e,
          stackTrace,
          context: 'AuthRepository.updateProfile',
          extra: {
            'user_id': userId,
            'updated_fields_count': [
              if (fullName != null) 'full_name',
              if (avatar != null) 'avatar_url',
            ].length,
          },
        );

        rethrow;
      }
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  // ---------- vérification et nettoyage d'état ----------
  Future<bool> hasCompleteProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('username, full_name')
          .eq('id', userId)
          .maybeSingle();
      
      if (data == null) return false;
      
      final username = data['username'] as String?;
      final fullName = data['full_name'] as String?;
      
      return username != null && 
             username.isNotEmpty && 
             fullName != null && 
             fullName.isNotEmpty;
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification profil: $e');
      return false;
    }
  }

  /// Nettoie un compte corrompu (authentifié dans Supabase mais sans profil complet)
  Future<void> cleanupCorruptedAccount() async {
    try {
      final user = currentUser;
      if (user == null) return;
      
      LogConfig.logInfo('🧹 Nettoyage compte corrompu: ${user.email}');
      
      // Supprimer le profil partiel s'il existe
      await _supabase
          .from('profiles')
          .delete()
          .eq('id', user.id);
      
      // Déconnecter l'utilisateur
      await signOut();
      
      LogConfig.logInfo('Compte corrompu nettoyé');
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage compte: $e');
      // Forcer la déconnexion même en cas d'erreur
      try {
        await signOut();
      } catch (logoutError) {
        LogConfig.logError('❌ Erreur déconnexion forcée: $logoutError');
      }
    }
  }

  // ---------- Nouvelle méthode pour vérifier si un compte est vraiment corrompu ----------
  Future<bool> isCorruptedAccount(String userId) async {
    try {
      final user = currentUser;
      if (user == null) return false;
      
      // FIX: createdAt est déjà une DateTime, pas besoin de parser
      final createdAtString = user.createdAt;
      final createdAt = DateTime.parse(createdAtString);
      final now = DateTime.now();
      final accountAge = now.difference(createdAt);
      
      print('🕐 Âge du compte: ${accountAge.inHours}h');
      
      // Si le compte existe depuis plus de 24h sans profil, c'est probablement corrompu
      if (accountAge.inHours > 24) {
        final hasProfile = await hasCompleteProfile(userId);
        print('📋 Profil complet: $hasProfile');
        return !hasProfile;
      }
      
      return false; // Compte récent sans profil = normal
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification corruption: $e');
      return false;
    }
  }

  // ---------- suppression du compte ----------
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) throw AuthException('Aucun utilisateur connecté');

      LogConfig.logInfo('🗑️ Début suppression du compte: ${user.email}');

      // 1. Supprimer les données utilisateur dans Supabase
      await _supabase
        .from('credit_transactions')
        .delete()
        .eq('user_id', user.id);

      LogConfig.logInfo('Profil supprimé de la base credit_transactions');

      await _supabase
        .from('user_credits')
        .delete()
        .eq('user_id', user.id);

      LogConfig.logInfo('Profil supprimé de la base user_credits');

      await _supabase
        .from('user_routes')
        .delete()
        .eq('user_id', user.id);

      LogConfig.logInfo('Profil supprimé de la base user_routes');

      await _supabase
        .from('profiles')
        .delete()
        .eq('id', user.id);

      LogConfig.logInfo('Profil supprimé de la base de données profiles');

      // 🆕 2. Nettoyer TOUTES les données locales avant la déconnexion finale
      try {
        ServiceLocator.clearUserData();
        LogConfig.logInfo('🗑️ Données utilisateur nettoyées via ServiceLocator');
      } catch (e) {
        LogConfig.logError('❌ Erreur nettoyage données ServiceLocator: $e');
      }
      
      // 🆕 3. Nettoyer le cache des images
      try {
        await CachedNetworkImage.evictFromCache('');
        LogConfig.logInfo('🖼️ Cache images nettoyé');
      } catch (e) {
        LogConfig.logError('❌ Erreur nettoyage cache images: $e');
      }
      
      // 🆕 4. Nettoyer TOUTES les préférences (suppression = nettoyage complet)
      try {
        await _clearAllUserData();
        LogConfig.logInfo('📱 Toutes les données locales nettoyées');
      } catch (e) {
        LogConfig.logError('❌ Erreur nettoyage données locales: $e');
      }

      // 5. Nettoyer les tokens stockés
      await SecureConfig.clearStoredTokens();

      // 6. Déconnexion Supabase
      await _supabase.auth.signOut();
      
      // 7. Suppression Supabase User avec une instance dédiée admin
      final adminClient = SupabaseClient(
        SecureConfig.supabaseUrl,
        SecureConfig.supabaseServiceRoleKey,
      );

      await adminClient.auth.admin.deleteUser(user.id);

      LogConfig.logInfo('✅ Compte Supabase supprimé via adminClient');
    } catch (e) {
      LogConfig.logError('❌ Erreur suppression compte: $e');
      
      // 🔒 En cas d'erreur, nettoyer quand même les données locales
      try {
        ServiceLocator.clearUserData();
        await SecureConfig.clearStoredTokens();
        await _clearAllUserData();
        // Forcer la déconnexion même si la suppression a échoué
        await _supabase.auth.signOut();
      } catch (cleanupError) {
        LogConfig.logError('❌ Erreur nettoyage forcé après échec: $cleanupError');
      }
      
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  /// Vérifie l'éligibilité au reset de mot de passe
  Future<Map<String, dynamic>> checkPasswordResetEligibility(String email) async {
    try {
      final response = await _supabase.rpc('check_password_reset_eligibility', params: {
        'user_email': email,
      });
      
      return Map<String, dynamic>.from(response);
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification éligibilité: $e');
      throw AuthException('Erreur lors de la vérification');
    }
  }

  /// Envoie un code de réinitialisation par email
  Future<void> sendPasswordResetCode(String email) async {
    try {
      // Utiliser Supabase pour envoyer un email avec un code OTP
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: null, // Pas de redirection, on utilise le code OTP
      );
      
      LogConfig.logInfo('📧 Code de réinitialisation envoyé à: $email');
    } catch (e) {
      LogConfig.logError('❌ Erreur envoi code: $e');
      throw AuthException('Impossible d\'envoyer le code');
    }
  }

  /// Vérifie un code de réinitialisation de mot de passe
  Future<bool> verifyPasswordResetCode(String email, String code) async {
    try {
      LogConfig.logInfo('🔍 Vérification code pour: $email');
      
      // Validation préliminaire
      if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
        LogConfig.logWarning('⚠️ Format de code invalide');
        return false;
      }
      
      // Vérifier le code OTP de récupération avec Supabase
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.recovery,
        email: email.trim(),
        token: code.trim(),
      );
      
      // Si la vérification réussit, garder la session active pour la prochaine étape
      if (response.user != null && response.session != null) {
        LogConfig.logInfo('✅ Code valide pour: $email - session active pour reset');
        return true;
      }
      
      LogConfig.logWarning('⚠️ Code invalide pour: $email');
      return false;
      
    } on AuthException catch (e) {
      LogConfig.logError('❌ Erreur Auth Supabase: $e');
      
      // Assurez-vous qu'aucune session n'est active en cas d'erreur
      try {
        await _supabase.auth.signOut();
      } catch (signOutError) {
        // Ignorer les erreurs de déconnexion
      }
      
      // Ne pas lever d'exception pour les codes invalides, juste retourner false
      if (e.message.toLowerCase().contains('invalid') || 
          e.message.toLowerCase().contains('expired') ||
          e.message.toLowerCase().contains('not_found')) {
        return false;
      }
      
      // Pour les autres erreurs Auth, lever une exception avec un message clair
      throw AuthException(_parseSupabaseError(e));
      
    } catch (e) {
      LogConfig.logError('❌ Erreur générale vérification code: $e');
      
      // Assurez-vous qu'aucune session n'est active en cas d'erreur
      try {
        await _supabase.auth.signOut();
      } catch (signOutError) {
        // Ignorer les erreurs de déconnexion
      }
      
      // Pour les erreurs réseau ou autres, lever une exception
      throw AuthException(_parseSupabaseError(e));
    }
  }

  /// Réinitialise le mot de passe (sans re-vérifier le code)
  Future<void> resetPasswordWithCode(String email, String code, String newPassword) async {
    try {
      LogConfig.logInfo('🔄 Réinitialisation mot de passe pour: $email');
      
      // Validation du mot de passe avant tentative
      if (newPassword.length < 8) {
        throw AuthException('Le mot de passe doit contenir au moins 8 caractères');
      }
      
      // Vérifier qu'une session active existe (du à la vérification précédente)
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw AuthException('Session expirée. Veuillez recommencer le processus');
      }
      
      LogConfig.logInfo('✅ Session active trouvée, mise à jour du mot de passe...');
      
      // Mettre à jour le mot de passe directement (le token a déjà été vérifié)
      final updateResponse = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      if (updateResponse.user == null) {
        throw AuthException('Impossible de mettre à jour le mot de passe');
      }
      
      LogConfig.logInfo('✅ Mot de passe mis à jour pour: $email');
      
      // Déconnecter l'utilisateur pour qu'il se reconnecte avec le nouveau mot de passe
      await _supabase.auth.signOut();
      
      LogConfig.logInfo('🔒 Utilisateur déconnecté après changement de mot de passe');
      
    } on AuthException catch (e) {
      LogConfig.logError('❌ Erreur Auth lors de la réinitialisation: $e');
      
      // Ne pas nettoyer la session si c'est juste un problème de mot de passe identique
      if (!e.message.toLowerCase().contains('same_password') && 
          !e.message.toLowerCase().contains('même mot de passe')) {
        try {
          await _supabase.auth.signOut();
        } catch (signOutError) {
          // Ignorer les erreurs de déconnexion
        }
      }
      
      throw AuthException(_parseSupabaseError(e));
      
    } catch (e) {
      LogConfig.logError('❌ Erreur générale réinitialisation: $e');
      
      // Ne pas nettoyer la session si c'est juste un problème de mot de passe identique
      final errorString = e.toString().toLowerCase();
      if (!errorString.contains('same_password') && 
          !errorString.contains('même mot de passe')) {
        try {
          await _supabase.auth.signOut();
        } catch (signOutError) {
          // Ignorer les erreurs de déconnexion
        }
      }
      
      throw AuthException(_parseSupabaseError(e));
    }
  }

  /* ───────── HELPER POUR GÉNÉRER USERNAME UNIQUE (réutilisé si nécessaire) ───────── */
  Future<String> _generateUniqueUsername(String baseName) async {
    // Nettoyer le nom de base
    String cleanBase = baseName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .substring(0, min(baseName.length, 15));
    
    if (cleanBase.isEmpty) {
      cleanBase = 'user';
    }
    
    // Essayer le nom de base d'abord
    if (await isUsernameAvailable(cleanBase)) {
      return cleanBase;
    }
    
    // Ajouter des nombres jusqu'à trouver un nom disponible
    for (int i = 1; i <= 999; i++) {
      final candidate = '$cleanBase$i';
      if (await isUsernameAvailable(candidate)) {
        return candidate;
      }
    }
    
    // Fallback avec timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return '${cleanBase}_${timestamp.substring(timestamp.length - 6)}';
  }

  /* ───────── HELPER POUR SUGGÉRER UN USERNAME DEPUIS LES DONNÉES SOCIALES ───────── */
  Map<String, String?> getSocialUserInfo() {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {};
      
      String? suggestedFullName;
      
      // 1. D'abord, vérifier les données temporaires Apple/Google
      if (_tempAppleFullName != null && _tempAppleFullName!.isNotEmpty) {
        suggestedFullName = _tempAppleFullName;
        LogConfig.logInfo('📝 Récupération nom Apple temporaire: $suggestedFullName');
      } else if (_tempGoogleFullName != null && _tempGoogleFullName!.isNotEmpty) {
        suggestedFullName = _tempGoogleFullName;
        LogConfig.logInfo('📝 Récupération nom Google temporaire: $suggestedFullName');
      }
      // 2. Sinon, essayer les métadonnées
      else {
        final userMetadata = user.userMetadata;
        if (userMetadata != null) {
          if (userMetadata.containsKey('full_name')) {
            suggestedFullName = userMetadata['full_name'] as String?;
          } else if (userMetadata.containsKey('name')) {
            suggestedFullName = userMetadata['name'] as String?;
          }
        }
      }
      
      // 3. AMÉLIORATION : Fallback intelligent sur l'email
      if ((suggestedFullName == null || suggestedFullName.isEmpty) && user.email != null) {
        final emailPart = user.email!.split('@').first;
        
        // Si l'email contient un point (prénom.nom), traiter intelligemment
        if (emailPart.contains('.')) {
          final parts = emailPart.split('.');
          if (parts.length >= 2) {
            // Capitaliser chaque partie et joindre avec espace
            final firstName = _capitalizeFirst(parts[0]);
            final lastName = _capitalizeFirst(parts[1]);
            suggestedFullName = '$firstName $lastName';
            LogConfig.logInfo('📝 Nom formaté depuis email: $suggestedFullName');
          } else {
            // Un seul mot avec point à la fin
            suggestedFullName = _capitalizeFirst(emailPart.replaceAll('.', ''));
          }
        } else {
          // Pas de point, juste capitaliser
          suggestedFullName = _capitalizeFirst(emailPart);
        }
        
        LogConfig.logInfo('📝 Fallback nom depuis email: $suggestedFullName');
      }
      
      return {
        'fullName': suggestedFullName?.trim(),
        'email': user.email,
      };
    } catch (e) {
      LogConfig.logInfo('Erreur récupération infos sociales: $e');
      return {};
    }
  }

  /* ───────── HELPER POUR CAPITALISER ───────── */
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /* ───────── GÉNÉRATION USERNAME INTELLIGENTE ───────── */
  Future<String> suggestUsernameFromSocialData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 'user';
      
      String baseName = 'user';
      
      // 1. D'abord, vérifier les données temporaires Apple/Google
      if (_tempAppleFullName != null && _tempAppleFullName!.isNotEmpty) {
        baseName = _tempAppleFullName!;
        LogConfig.logInfo('📝 Utilisation nom Apple temporaire: $baseName');
      } else if (_tempGoogleFullName != null && _tempGoogleFullName!.isNotEmpty) {
        baseName = _tempGoogleFullName!;
        LogConfig.logInfo('📝 Utilisation nom Google temporaire: $baseName');
      }
      // 2. Sinon, essayer les métadonnées utilisateur
      else {
        final userMetadata = user.userMetadata;
        if (userMetadata != null) {
          if (userMetadata.containsKey('full_name')) {
            baseName = userMetadata['full_name'] as String? ?? baseName;
          } else if (userMetadata.containsKey('name')) {
            baseName = userMetadata['name'] as String? ?? baseName;
          }
        }
      }
      
      // 3. AMÉLIORATION : Fallback intelligent sur l'email
      if (baseName == 'user' && user.email != null) {
        final emailPart = user.email!.split('@').first;
        baseName = emailPart;
        LogConfig.logInfo('📝 Utilisation email comme base: $baseName');
      }
      
      // 4. Générer username unique et nettoyer les données temporaires après usage
      final result = await _generateUniqueUsernameFromEmail(baseName, user.email);
      
      // Nettoyer les données temporaires après utilisation
      _tempAppleFullName = null;
      _tempGoogleFullName = null;
      
      return result;
    } catch (e) {
      LogConfig.logInfo('Erreur suggestion username: $e');
      // Nettoyer en cas d'erreur
      _tempAppleFullName = null;
      _tempGoogleFullName = null;
      return await _generateUniqueUsername('user');
    }
  }

  /* ───────── GÉNÉRATION USERNAME INTELLIGENT DEPUIS EMAIL ───────── */
  Future<String> _generateUniqueUsernameFromEmail(String baseName, String? email) async {
    try {
      // Si on a un email avec point (prénom.nom), utiliser la logique intelligente
      if (email != null) {
        final emailPart = email.split('@').first;
        
        if (emailPart.contains('.')) {
          final parts = emailPart.split('.');
          if (parts.length >= 2) {
            final firstName = parts[0].toLowerCase();
            final lastName = parts[1].toLowerCase();
            
            // Prendre le prénom + 5 premières lettres du nom de famille
            final lastNamePart = lastName.length > 5 ? lastName.substring(0, 5) : lastName;
            final suggestedUsername = '$firstName$lastNamePart';
            
            LogConfig.logInfo('📝 Username intelligent généré: $suggestedUsername ($firstName + $lastNamePart)');
            
            // Nettoyer et vérifier la disponibilité
            String cleanUsername = suggestedUsername
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]'), '');
            
            if (cleanUsername.length > 15) {
              cleanUsername = cleanUsername.substring(0, 15);
            }
            
            // Essayer le nom suggéré d'abord
            if (await isUsernameAvailable(cleanUsername)) {
              return cleanUsername;
            }
            
            // Si pas disponible, ajouter des nombres
            for (int i = 1; i <= 999; i++) {
              final candidate = '$cleanUsername$i';
              if (await isUsernameAvailable(candidate)) {
                return candidate;
              }
            }
          }
        }
      }
      
      // Fallback sur la méthode classique si pas d'email avec point
      return await _generateUniqueUsername(baseName);
      
    } catch (e) {
      LogConfig.logInfo('Erreur génération username depuis email: $e');
      return await _generateUniqueUsername(baseName);
    }
  }

  /// Détermine à quelle étape l'erreur Google est survenue
  String _determineGoogleErrorStep(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('access token') || errorString.contains('id token')) {
      return 'google_tokens';
    } else if (errorString.contains('supabase') || errorString.contains('signin')) {
      return 'supabase_auth';
    } else if (errorString.contains('google')) {
      return 'google_signin';
    }
    return 'unknown';
  }

  /// Détermine à quelle étape l'erreur Apple est survenue
  String _determineAppleErrorStep(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('available') || errorString.contains('not supported')) {
      return 'apple_availability';
    } else if (errorString.contains('credential') || errorString.contains('identity')) {
      return 'apple_credentials';
    } else if (errorString.contains('supabase') || errorString.contains('signin')) {
      return 'supabase_auth';
    }
    return 'unknown';
  }

  /// Catégorise les erreurs d'authentification
  String _categorizeAuthError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('network') || errorString.contains('timeout')) {
      return 'network';
    } else if (errorString.contains('cancelled') || errorString.contains('cancel')) {
      return 'user_cancelled';
    } else if (errorString.contains('available') || errorString.contains('supported')) {
      return 'not_supported';
    } else if (errorString.contains('token') || errorString.contains('credential')) {
      return 'token_error';
    }
    return 'unknown';
  }

  /// Détermine la source du username (généré, saisi, etc.)
  String _determineUsernameSource(String username) {
    if (username.contains(RegExp(r'\d+$'))) {
      return 'generated_with_number';
    } else if (username.length < 6) {
      return 'short_custom';
    } else if (username.contains('.') || username.contains('_')) {
      return 'custom_with_separator';
    }
    return 'custom';
  }

  /// Détermine le provider d'inscription depuis les métadonnées utilisateur
  String _determineSignupProvider(User user) {
    try {
      final appMetadata = user.appMetadata;
      if (appMetadata != null && appMetadata.containsKey('provider')) {
        return appMetadata['provider'] as String? ?? 'unknown';
      }
      
      // Fallback sur l'email
      if (user.email?.contains('@') == true) {
        return 'email';
      }
      
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Force la vérification des crédits après ajout de métadonnées d'appareil
  Future<void> _forceDeviceCheck(String userId) async {
    try {
      LogConfig.logInfo('🔍 Force vérification appareil pour: $userId');
      
      // Attendre que les métadonnées soient bien enregistrées
      await Future.delayed(Duration(seconds: 2));
      
      // 1. D'abord récupérer les métadonnées utilisateur
      final user = _supabase.auth.currentUser;
      if (user?.userMetadata == null) {
        LogConfig.logWarning('⚠️ Pas de métadonnées utilisateur disponibles');
        return;
      }
      
      final deviceFingerprint = user!.userMetadata!['device_fingerprint'] as String?;
      
      if (deviceFingerprint != null && deviceFingerprint.isNotEmpty) {
        LogConfig.logInfo('📱 Device fingerprint trouvé: ${deviceFingerprint.substring(0, 8)}...');
        
        // 2. Vérifier l'état actuel avec debug_device_data
        try {
          final debugResult = await _supabase.rpc('debug_device_data', params: {
            'p_user_id': userId,
          });
          
          if (debugResult != null && debugResult.isNotEmpty) {
            final userData = debugResult.first;
            final deviceRegsCount = userData['device_registrations_count'] ?? 0;
            final currentCredits = userData['current_credits'] ?? 0;
            
            LogConfig.logInfo('📊 État utilisateur: registrations=$deviceRegsCount, credits=$currentCredits');
            
            // 3. Si pas d'enregistrement d'appareil, forcer l'enregistrement
            if (deviceRegsCount == 0) {
              LogConfig.logInfo('🔧 Forcer enregistrement car aucun trouvé...');
              
              final registerResult = await _supabase.rpc('register_device_fingerprint', params: {
                'p_user_id': userId,
                'p_device_fingerprint': deviceFingerprint,
                'p_force': true, // Forcer l'enregistrement
              });
              
              LogConfig.logInfo('✅ Enregistrement forcé: $registerResult');
            } else {
              LogConfig.logInfo('✅ Appareil déjà enregistré');
            }
            
            // 4. Vérification finale avec force_check_user_device
            final finalCheck = await _supabase.rpc('force_check_user_device', params: {
              'p_user_id': userId,
            });
            
            LogConfig.logInfo('🔍 Vérification finale: $finalCheck');
            
          } else {
            LogConfig.logWarning('⚠️ Aucun résultat de debug_device_data');
          }
        } catch (e) {
          LogConfig.logError('❌ Erreur vérification/enregistrement: $e');
          
          // En cas d'erreur, essayer quand même d'enregistrer
          try {
            await _supabase.rpc('register_device_fingerprint', params: {
              'p_user_id': userId,
              'p_device_fingerprint': deviceFingerprint,
              'p_force': true,
            });
            LogConfig.logInfo('✅ Enregistrement de secours réussi');
          } catch (fallbackError) {
            LogConfig.logError('❌ Échec enregistrement de secours: $fallbackError');
          }
        }
      } else {
        LogConfig.logWarning('⚠️ Aucun device fingerprint dans les métadonnées');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur générale _forceDeviceCheck: $e');
    }
  }

  /// Diagnostique l'état d'un utilisateur pour le debugging
  Future<Map<String, dynamic>?> debugUserState(String userId) async {
    try {
      final debugResult = await _supabase.rpc('debug_device_data', params: {
        'p_user_id': userId,
      });
      
      if (debugResult != null && debugResult.isNotEmpty) {
        return Map<String, dynamic>.from(debugResult.first);
      }
      return null;
    } catch (e) {
      LogConfig.logError('❌ Erreur debug utilisateur: $e');
      return null;
    }
  }

  // Invalidation du cache des crédits
  Future<void> _invalidateCreditsCache() async {
    try {
      LogConfig.logInfo('💳 Invalidation cache crédits...');
      
      final cacheService = CacheService.instance;
      await cacheService.invalidateCreditsCache();
      
      // Supprimer aussi les préférences partagées liées aux crédits
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = prefs.getKeys().where((key) => 
        key.contains('credit') || 
        key.contains('user_id') || 
        key.contains('last_user') ||
        key.startsWith('last_')
      ).toList();
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      LogConfig.logInfo('💳 Cache crédits invalidé (${keysToRemove.length} clés supprimées)');
    } catch (e) {
      LogConfig.logError('❌ Erreur invalidation cache crédits: $e');
    }
  }

  /* ───────── VÉRIFICATION OTP EMAIL ───────── */
  Future<User?> verifyOTP({required String email, required String otp}) async {
    try {
      print('🔍 Vérification OTP pour: $email');
      
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: email.trim(),
        token: otp.trim(),
      );
      
      if (response.user == null) {
        throw AuthException('Échec de la vérification OTP');
      }

      final user = response.user!;
      
      // 🔒 Stocker les tokens si session créée
      if (response.session != null) {
        await _storeSessionTokensSecurely(response.session!);
      }

      // 🆕 CRUCIAL: Générer et mettre à jour les métadonnées d'appareil après vérification OTP
      try {
        final deviceFingerprint = await DeviceFingerprintService.instance.generateDeviceFingerprint();
        
        if (deviceFingerprint.isNotEmpty) {
          LogConfig.logInfo('📱 Mise à jour métadonnées après OTP: ${deviceFingerprint['device_fingerprint']?.substring(0, 8)}...');
          
          await _supabase.auth.updateUser(
            UserAttributes(
              data: {
                'device_fingerprint': deviceFingerprint['device_fingerprint'],
                'device_model': deviceFingerprint['device_model'],
                'device_manufacturer': deviceFingerprint['device_manufacturer'],
                'platform': deviceFingerprint['platform'],
                'otp_verified_timestamp': DateTime.now().toIso8601String(),
              },
            ),
          );
          
          LogConfig.logInfo('✅ Métadonnées appareil mises à jour après vérification OTP');
          
          // 🆕 NOUVEAU: Enregistrer l'appareil dans device_registrations après OTP
          try {
            LogConfig.logInfo('📝 Enregistrement appareil après vérification OTP...');
            
            final registerResult = await _supabase.rpc('register_device_after_otp', params: {
              'p_user_id': user.id,
            });
            
            if (registerResult != null) {
              LogConfig.logInfo('✅ Résultat enregistrement après OTP: $registerResult');
              
              if (registerResult['device_registered'] == true) {
                final creditsGranted = registerResult['credits_granted'] == true;
                LogConfig.logInfo('🎯 Appareil enregistré après OTP - crédits accordés: $creditsGranted');
              }
            }
          } catch (e) {
            LogConfig.logWarning('⚠️ Erreur enregistrement appareil après OTP: $e');
            // Ne pas faire échouer la vérification OTP pour autant
          }
        }
      } catch (e) {
        LogConfig.logWarning('⚠️ Erreur mise à jour métadonnées post-OTP: $e');
        // Continuer même si ça échoue
      }
      
      LogConfig.logInfo('✅ OTP vérifié avec succès pour: ${user.email}');
      return user;
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification OTP: $e');
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  /// Vérifie si un email est déjà utilisé en consultant la table des profils
  Future<bool> isEmailAlreadyUsed(String email) async {
    try {
      LogConfig.logInfo('🔍 Vérification existence email: $email');
      
      // Rechercher dans la table des profils si l'email existe déjà
      final response = await _supabase
          .from('profiles')
          .select('email')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle()
          .timeout(Duration(seconds: 5));
      
      final exists = response != null;
      LogConfig.logInfo('📧 Email $email ${exists ? 'existe déjà' : 'disponible'}');
      
      return exists;
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification email: $e');
      
      // En cas d'erreur, on laisse l'inscription se faire pour ne pas bloquer l'utilisateur
      return false;
    }
  }

  /// Helper pour analyser et formater les erreurs Supabase
  String _parseSupabaseError(dynamic error) {
    final errorString = error.toLowerCase();

    final context = rootNavigatorKey.currentContext!;
    
    // Erreurs spécifiques avec codes
    if (errorString.contains('same_password') || error == 'SAME_PASSWORD') {
      return context.l10n.passwordMustBeDifferent;
    } else if (errorString.contains('password_too_short') || error == 'PASSWORD_TOO_SHORT') {
      return context.l10n.passwordTooShort;
    } else if (errorString.contains('session_expired') || error == 'SESSION_EXPIRED') {
      return context.l10n.expiredSession;
    } else if (errorString.contains('update_password_failed') || error == 'UPDATE_PASSWORD_FAILED') {
      return 'Impossible de mettre à jour le mot de passe';
    }
    
    // Erreurs Supabase standard
    if (errorString.contains('email_already_exists') || errorString.contains('user_already_exists')) {
      return context.l10n.emailAlreadyUsed;
    } else if (errorString.contains('invalid_credentials')) {
      return context.l10n.invalidCredentials;
    } else if (errorString.contains('email_not_found') || errorString.contains('user_not_found')) {
      return context.l10n.notEmailFound;
    } else if (errorString.contains('email_not_confirmed')) {
      return context.l10n.confirmEmailBeforeLogin;
    } else if (errorString.contains('invalid_password') || errorString.contains('weak_password')) {
      return context.l10n.passwordTooSimple;
    } else if (errorString.contains('too_many_requests')) {
      return 'Trop de tentatives. Veuillez patienter avant de réessayer';
    } else if (errorString.contains('otp_expired') || errorString.contains('token_expired')) {
      return 'Code expiré. Demandez un nouveau code de réinitialisation';
    } else if (errorString.contains('invalid_token') || errorString.contains('token_not_found')) {
      return context.l10n.invalidCode;
    } else if (errorString.contains('network') || errorString.contains('timeout')) {
      return context.l10n.connectionProblem;
    }
    
    return context.l10n.authenticationError;
  }
}