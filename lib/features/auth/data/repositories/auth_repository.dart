import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:runaway/config/secure_config.dart';
import 'package:runaway/core/errors/auth_exceptions.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Variables statiques pour stocker temporairement les infos Apple/Google
  static String? _tempAppleFullName;
  static String? _tempGoogleFullName;

  User? get currentUser => _supabase.auth.currentUser;

  // ---------- stream Auth (session) ----------
  Stream<AuthState> get authChangesStream => _supabase.auth.onAuthStateChange;

  /* ───────── 1) CRÉATION DE COMPTE (ÉTAPE 1) ───────── */
  Future<User?> signUpBasic({
    required String email,
    required String password,
  }) async {
    try {
      print('🔑 Tentative d\'inscription: $email');
      
      final resp = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
      );
      
      if (resp.user != null) {
        print('✅ Inscription réussie pour: ${resp.user!.email}');
        return resp.user;
      } else {
        print('❌ Inscription échouée: aucun utilisateur retourné');
        throw SignUpException('Impossible de créer le compte');
      }
    } catch (e) {
      print('❌ Erreur inscription: $e');
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  /* ───────── GOOGLE SIGN-IN ───────── */
  Future<Profile?> signInWithGoogle() async {
    try {
      print('🔑 Tentative de connexion Google');

      final webClientId = SecureConfig.googleWebClientId;
      final iosClientId = SecureConfig.googleIosClientId;
      
      // 1. Initier la connexion Google
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
      
      print('✅ Utilisateur Google obtenu: ${googleUser.email}');

      // 2. Stocker temporairement les informations Google
      _tempGoogleFullName = googleUser.displayName;
      if (_tempGoogleFullName != null) {
        print('📝 Nom Google stocké temporairement: $_tempGoogleFullName');
      }
            
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw AuthException('Tokens Google manquants');
      }
      
      print('✅ Tokens Google obtenus');
      
      // 3. Connexion avec Supabase
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken!,
      );
      
      if (response.user == null) {
        throw AuthException('Échec de la connexion avec Supabase');
      }
      
      print('✅ Connexion Supabase réussie: ${response.user!.email}');
      
      // 4. Vérifier si un profil existe déjà (nouveau comportement)
      final existingProfile = await getProfile(response.user!.id, skipCleanup: true);
      if (existingProfile != null && existingProfile.isComplete) {
        print('✅ Profil Google existant trouvé: ${existingProfile.username}');
        // Nettoyer les données temporaires
        _tempGoogleFullName = null;
        return existingProfile;
      }

      
      
      // 5. Pour les nouveaux utilisateurs, retourner null pour forcer l'onboarding
      print('📝 Nouveau compte Google - sera dirigé vers l\'onboarding');
      return null;
      
    } catch (e) {
      print('❌ Erreur Google Sign-In: $e');
      // Nettoyer en cas d'erreur
      _tempGoogleFullName = null;
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  /* ───────── APPLE SIGN-IN ───────── */
  Future<Profile?> signInWithApple() async {
    try {
      print('🔑 Tentative de connexion Apple');
      
      // 1. Vérifier la disponibilité d'Apple Sign-In
      if (!await SignInWithApple.isAvailable()) {
        throw AuthException('Apple Sign-In non disponible sur cet appareil');
      }
      
      // 2. Générer un nonce sécurisé
      final rawNonce = _generateNonce();
      final nonce = sha256.convert(utf8.encode(rawNonce)).toString();
      
      // 3. Initier la connexion Apple
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      
      print('✅ Credentials Apple obtenus');

      // 4. Stocker temporairement les informations de nom Apple
      if (credential.givenName != null || credential.familyName != null) {
        final fullName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
        if (fullName.isNotEmpty) {
          _tempAppleFullName = fullName;
          print('📝 Nom Apple stocké temporairement: $fullName');
        } else {
          _tempAppleFullName = null;
        }
      } else {
        _tempAppleFullName = null;
        print('⚠️ Aucun nom fourni par Apple');
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
      
      print('✅ Connexion Supabase réussie: ${response.user!.email}');
      
      // 6. Vérifier si un profil existe déjà
      final existingProfile = await getProfile(response.user!.id, skipCleanup: true);
      if (existingProfile != null && existingProfile.isComplete) {
        print('✅ Profil Apple existant trouvé: ${existingProfile.username}');
        // Nettoyer les données temporaires
        _tempAppleFullName = null;
        return existingProfile;
      }
      
      // 7. Pour les nouveaux utilisateurs, retourner null pour forcer l'onboarding
      print('📝 Nouveau compte Apple - sera dirigé vers l\'onboarding');
      return null;
      
    } catch (e) {
      print('❌ Erreur Apple Sign-In: $e');
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

  /* ───────── 2) COMPLÉMENT DE PROFIL (ÉTAPE 2) ───────── */
  Future<Profile?> completeProfile({
    required String userId,
    required String fullName,
    required String username,
    File? avatar,
  }) async {
    try {
      print('👤 Complétion du profil pour: $userId');

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
          print('✅ Avatar uploadé: $avatarUrl');
        } catch (e) {
          print('⚠️ Erreur upload avatar (continuez sans avatar): $e');
          avatarUrl = null;
        }
      }

      // 3. MODIFICATION : Récupérer l'email depuis l'utilisateur connecté
      final user = _supabase.auth.currentUser;
      if (user?.email == null) {
        throw AuthException('Utilisateur non connecté ou email manquant');
      }

      // 4. Sauvegarder le profil complet
      final data = await _supabase
          .from('profiles')
          .upsert({
            'id': userId,
            'email': user!.email!, // Utiliser l'email de l'utilisateur connecté
            'full_name': fullName,
            'username': username,
            'avatar_url': avatarUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .maybeSingle();

      if (data == null) {
        throw ProfileException('Impossible de sauvegarder le profil');
      }

      final profile = Profile.fromJson(data);
      print('✅ Profil complété: ${profile.username}');

      // 5. MODIFICATION : Informer si l'avatar n'a pas pu être uploadé
      if (avatar != null && avatarUrl == null) {
        // On peut retourner le profil mais signaler que l'avatar a échoué
        // L'UI pourra afficher un avertissement
        print('⚠️ Profil créé mais avatar non uploadé');
      }

      return profile;
      
    } catch (e) {
      print('❌ Erreur complétion profil: $e');
      if (e is AuthException) {
        rethrow;
      }
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  // ---------- connexion ----------
  Future<Profile?> logIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔑 Tentative de connexion: $email');
      
      final resp = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      
      final user = resp.user;
      if (user == null) {
        print('❌ Connexion échouée: aucun utilisateur retourné');
        throw LoginException('Connexion échouée');
      }
      
      print('✅ Connexion réussie: ${user.email}');
      
      // Récupérer le profil
      final profile = await getProfile(user.id);
      if (profile == null) {
        print('⚠️ Connexion réussie mais profil incomplet');
      } else {
        print('✅ Profil récupéré: ${profile.username}');
      }
      
      return profile;
    } catch (e) {
      print('❌ Erreur connexion: $e');
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  // ---------- lecture profile ----------
  Future<Profile?> getProfile(String id, {bool skipCleanup = false}) async {
    try {
      print('👤 Récupération profil: $id');
      
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      
      if (data == null) {
        print('⚠️ Aucun profil trouvé pour: $id');
        
        // FIX: Ne nettoyer que si explicitement demandé
        // Cela permet aux nouveaux utilisateurs d'avoir une chance de compléter leur profil
        if (!skipCleanup) {
          print('ℹ️ Profil non trouvé mais pas de nettoyage automatique');
        }
        return null;
      }
      
      // FIX: L'email est maintenant directement dans les données de la DB
      final profile = Profile.fromJson(data);
      
      print('✅ Profil récupéré: ${profile.username}');
      return profile;
    } catch (e) {
      print('❌ Erreur récupération profil: $e');
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  // ---------- déconnexion ----------
  Future<void> logOut() async {
    try {
      print('👋 Déconnexion...');
      await _supabase.auth.signOut();
      print('✅ Déconnexion réussie');
    } catch (e) {
      print('❌ Erreur déconnexion: $e');
      throw AuthExceptionHandler.handleSupabaseError(e);
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
      print('❌ Erreur vérification username: $e');
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
      print('📝 Mise à jour profil: $userId');
      
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
          print('⚠️ Erreur upload nouvel avatar: $e');
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
      
      print('✅ Profil mis à jour: ${profile.username}');
      return profile;
    } catch (e) {
      print('❌ Erreur mise à jour profil: $e');
      if (e is AuthException) {
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
      print('❌ Erreur vérification profil: $e');
      return false;
    }
  }

  /// Nettoie un compte corrompu (authentifié dans Supabase mais sans profil complet)
  Future<void> cleanupCorruptedAccount() async {
    try {
      final user = currentUser;
      if (user == null) return;
      
      print('🧹 Nettoyage compte corrompu: ${user.email}');
      
      // Supprimer le profil partiel s'il existe
      await _supabase
          .from('profiles')
          .delete()
          .eq('id', user.id);
      
      // Déconnecter l'utilisateur
      await logOut();
      
      print('✅ Compte corrompu nettoyé');
    } catch (e) {
      print('❌ Erreur nettoyage compte: $e');
      // Forcer la déconnexion même en cas d'erreur
      try {
        await logOut();
      } catch (logoutError) {
        print('❌ Erreur déconnexion forcée: $logoutError');
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
      print('❌ Erreur vérification corruption: $e');
      return false;
    }
  }

  // ---------- suppression du compte ----------
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw SessionException('Aucun utilisateur connecté');
      }
      
      print('🗑️ Suppression compte: ${user.id}');
      
      // Supprimer d'abord le profil
      await _supabase
          .from('profiles')
          .delete()
          .eq('id', user.id);
      
      // Supprimer l'avatar du storage si existe
      try {
        await _supabase.storage
            .from('profile')
            .remove(['profile/${user.id}']);
      } catch (e) {
        // Ignorer les erreurs de suppression de fichier
        print('⚠️ Erreur suppression avatar: $e');
      }
      
      // Note: La suppression de l'utilisateur auth doit être faite côté serveur
      // Pour l'instant, on se contente de supprimer le profil et déconnecter
      await logOut();
      
      print('✅ Compte supprimé');
    } catch (e) {
      print('❌ Erreur suppression compte: $e');
      throw AuthExceptionHandler.handleSupabaseError(e);
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
        print('📝 Récupération nom Apple temporaire: $suggestedFullName');
      } else if (_tempGoogleFullName != null && _tempGoogleFullName!.isNotEmpty) {
        suggestedFullName = _tempGoogleFullName;
        print('📝 Récupération nom Google temporaire: $suggestedFullName');
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
            print('📝 Nom formaté depuis email: $suggestedFullName');
          } else {
            // Un seul mot avec point à la fin
            suggestedFullName = _capitalizeFirst(emailPart.replaceAll('.', ''));
          }
        } else {
          // Pas de point, juste capitaliser
          suggestedFullName = _capitalizeFirst(emailPart);
        }
        
        print('📝 Fallback nom depuis email: $suggestedFullName');
      }
      
      return {
        'fullName': suggestedFullName?.trim(),
        'email': user.email,
      };
    } catch (e) {
      print('⚠️ Erreur récupération infos sociales: $e');
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
        print('📝 Utilisation nom Apple temporaire: $baseName');
      } else if (_tempGoogleFullName != null && _tempGoogleFullName!.isNotEmpty) {
        baseName = _tempGoogleFullName!;
        print('📝 Utilisation nom Google temporaire: $baseName');
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
        print('📝 Utilisation email comme base: $baseName');
      }
      
      // 4. Générer username unique et nettoyer les données temporaires après usage
      final result = await _generateUniqueUsernameFromEmail(baseName, user.email);
      
      // Nettoyer les données temporaires après utilisation
      _tempAppleFullName = null;
      _tempGoogleFullName = null;
      
      return result;
    } catch (e) {
      print('⚠️ Erreur suggestion username: $e');
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
            
            print('📝 Username intelligent généré: $suggestedUsername ($firstName + $lastNamePart)');
            
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
      print('⚠️ Erreur génération username depuis email: $e');
      return await _generateUniqueUsername(baseName);
    }
  }

  /* ───────── MOT DE PASSE OUBLIÉ ───────── */
  Future<void> resetPassword({required String email}) async {
    try {
      print('🔐 Demande de réinitialisation de mot de passe pour: $email');
      
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: '${SecureConfig.supabaseUrl}/auth/v1/verify?type=recovery',
      );
      
      print('✅ Email de réinitialisation envoyé');
    } catch (e) {
      print('❌ Erreur réinitialisation mot de passe: $e');
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  /* ───────── RENVOI EMAIL DE CONFIRMATION ───────── */
  Future<void> resendConfirmationEmail({required String email}) async {
    try {
      print('📧 Renvoi de l\'email de confirmation pour: $email');
      
      final response = await _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      
      print('✅ Email de confirmation renvoyé avec succès');
      print('📧 Response: ${response.toString()}');
    } catch (e) {
      print('❌ Erreur renvoi email de confirmation: $e');
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }
}