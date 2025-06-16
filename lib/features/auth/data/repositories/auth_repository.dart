import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final resp = await _supabase.auth.signUp(email: email, password: password);
    return resp.user; // null si échec
  }

/* ───────── 2) COMPLÉMENT DE PROFIL (ÉTAPE 2) ───────── */
  Future<Profile?> completeProfile({
    required String userId,
    required String fullName,
    required String username,
    required String phone,
    File? avatar,
  }) async {
    String? avatarUrl;
    if (avatar != null) {
      final filePath = 'profile/$userId${p.extension(avatar.path)}';
      await _supabase.storage.from('profile').upload(filePath, avatar);
      avatarUrl = _supabase.storage.from('profile').getPublicUrl(filePath);
    }

    final data = await _supabase
        .from('profiles')
        .upsert({
          'id': userId,
          'full_name': fullName,
          'username': username,
          'phone': phone,
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .maybeSingle();

    return data == null ? null : Profile.fromJson(data);
  }

  // ---------- connexion ----------
  Future<Profile?> logIn({
    required String email,
    required String password,
  }) async {
    final resp = await _supabase.auth.signInWithPassword(email: email, password: password);
    final user = resp.user;
    if (user == null) return null;
    return getProfile(user.id);
  }

  // ---------- lecture profile ----------
  Future<Profile?> getProfile(String id) async {
    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data == null ? null : Profile.fromJson(data);
  }

  // ---------- déconnexion ----------
  Future<void> logOut() => _supabase.auth.signOut();
}
