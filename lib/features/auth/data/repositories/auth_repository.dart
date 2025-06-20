// lib/features/auth/data/repositories/auth_repository.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:runaway/core/errors/auth_exceptions.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Configuration Google Sign-In
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

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
      
      // 1. Déconnecter d'abord si déjà connecté
      await _googleSignIn.signOut();
      
      // 2. Initier la connexion Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ Connexion Google annulée par l\'utilisateur');
        throw AuthException('Connexion Google annulée');
      }
      
      // 3. Obtenir les détails d'authentification
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null) {
        throw AuthException('Impossible d\'obtenir le token Google');
      }
      
      print('✅ Token Google obtenu');
      
      // 4. Connexion avec Supabase
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken!,
      );
      
      if (response.user == null) {
        throw AuthException('Échec de la connexion avec Supabase');
      }
      
      print('✅ Connexion Supabase réussie: ${response.user!.email}');
      
      // 5. Créer ou récupérer le profil
      final profile = await _createOrGetSocialProfile(
        user: response.user!,
        displayName: googleUser.displayName,
        photoUrl: googleUser.photoUrl,
        provider: 'google',
      );
      
      return profile;
      
    } catch (e) {
      print('❌ Erreur Google Sign-In: $e');
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
      
      // 4. Connexion avec Supabase
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
        nonce: rawNonce,
      );
      
      if (response.user == null) {
        throw AuthException('Échec de la connexion avec Supabase');
      }
      
      print('✅ Connexion Supabase réussie: ${response.user!.email}');
      
      // 5. Créer le nom d'affichage à partir des informations Apple
      String? displayName;
      if (credential.givenName != null || credential.familyName != null) {
        displayName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
        if (displayName.isEmpty) displayName = null;
      }
      
      // 6. Créer ou récupérer le profil
      final profile = await _createOrGetSocialProfile(
        user: response.user!,
        displayName: displayName,
        photoUrl: null, // Apple ne fournit pas de photo de profil
        provider: 'apple',
      );
      
      return profile;
      
    } catch (e) {
      print('❌ Erreur Apple Sign-In: $e');
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  /* ───────── HELPER POUR PROFILS SOCIAUX ───────── */
  Future<Profile?> _createOrGetSocialProfile({
    required User user,
    String? displayName,
    String? photoUrl,
    required String provider,
  }) async {
    try {
      // 1. Vérifier si le profil existe déjà
      final existingProfile = await getProfile(user.id, skipCleanup: true);
      if (existingProfile != null && existingProfile.isComplete) {
        print('✅ Profil existant trouvé: ${existingProfile.username}');
        return existingProfile;
      }
      
      // 2. Créer un nouveau profil pour les connexions sociales
      String? fullName = displayName;
      String? username;
      String? avatarUrl = photoUrl;
      
      // Générer un nom d'utilisateur unique basé sur l'email ou le nom
      if (fullName != null && fullName.isNotEmpty) {
        username = await _generateUniqueUsername(fullName);
      } else if (user.email != null) {
        final emailUsername = user.email!.split('@').first;
        username = await _generateUniqueUsername(emailUsername);
      } else {
        username = await _generateUniqueUsername('user');
      }
      
      // Si pas de nom complet, utiliser l'email comme base
      if (fullName == null || fullName.isEmpty) {
        fullName = user.email?.split('@').first ?? 'Utilisateur';
      }
      
      print('👤 Création profil social: $fullName (@$username)');
      
      // 3. Sauvegarder le profil
      final data = await _supabase
          .from('profiles')
          .upsert({
            'id': user.id,
            'email': user.email!,
            'full_name': fullName,
            'username': username,
            'avatar_url': avatarUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .maybeSingle();

      if (data == null) {
        throw ProfileException('Impossible de créer le profil social');
      }

      final profile = Profile.fromJson(data);
      print('✅ Profil social créé: ${profile.username}');
      return profile;
      
    } catch (e) {
      print('❌ Erreur création profil social: $e');
      if (e is AuthException) {
        rethrow;
      }
      throw AuthExceptionHandler.handleSupabaseError(e);
    }
  }

  /* ───────── HELPER POUR GÉNÉRER USERNAME UNIQUE ───────── */
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
      
      String? avatarUrl;
      
      // Upload de l'avatar si fourni (mais ne pas faire échouer si ça rate)
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


      // Récupérer l'email depuis l'utilisateur actuel AVANT l'upsert
      final currentUser = _supabase.auth.currentUser;
      if (currentUser?.email == null) {
        throw ProfileException('Impossible de récupérer l\'email utilisateur');
      }

      // Sauvegarder le profil (FIX: inclure l'email qui est NOT NULL)
      final data = await _supabase
          .from('profiles')
          .upsert({
            'id': userId,
            'email': currentUser!.email!, // FIX: Ajouter l'email obligatoire
            'full_name': fullName.trim(),
            'username': username.trim().toLowerCase(),
            'avatar_url': avatarUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .maybeSingle();

      if (data == null) {
        print('❌ Aucune donnée retournée après upsert profil');
        throw ProfileException('Impossible de sauvegarder le profil');
      }

      // FIX: L'email est déjà inclus dans les données retournées
      final profile = Profile.fromJson(data);

      print('✅ Profil complété: ${profile.username}');
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
          updates['avatar_url'] = _supabase.storage.from('profile').getPublicUrl(filePath);
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
}