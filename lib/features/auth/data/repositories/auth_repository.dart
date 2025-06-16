// lib/features/auth/data/repositories/auth_repository.dart

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:runaway/core/errors/auth_exceptions.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

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
          // FIX: Continuer SANS avatar plutôt que d'échouer
          // L'utilisateur peut ajouter son avatar plus tard
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
  // FIX: Ne plus nettoyer automatiquement les comptes
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
  /// FIX: Maintenant appelée explicitement seulement quand nécessaire
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