import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/services/app_data_initialization_service.dart';
import 'package:runaway/features/auth/data/repositories/auth_repository.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  final CreditsBloc? _creditsBloc; // 🆕 Injection optionnelle
  late final StreamSubscription _sub;

  AuthBloc({
    AuthRepository? authRepository,
    CreditsBloc? creditsBloc, // 🆕 Paramètre optionnel
  }) : _repo = authRepository ?? AuthRepository(),
       _creditsBloc = creditsBloc,
       super(AuthInitial()) {
    on<AppStarted>(_onStart);
    on<SignUpBasicRequested>(_onSignUpBasic);
    on<CompleteProfileRequested>(_onCompleteProfile);
    on<LogInRequested>(_onLogin);
    on<GoogleSignInRequested>(_onGoogleSignIn);
    on<AppleSignInRequested>(_onAppleSignIn);
    on<LogOutRequested>(_onLogout);
    on<UpdateProfileRequested>(_onUpdateProfile);
    on<DeleteAccountRequested>(_onDeleteAccount);
    on<NotificationSettingsToggleRequested>(_onNotificationSettingsToggle);

    on<ForgotPasswordRequested>(_onForgotPassword);
    on<ResendConfirmationRequested>(_onResendConfirmation);

    // handlers internes
    on<_InternalProfileLoaded>(_onInternalProfileLoaded);
    on<_InternalProfileIncomplete>((e, emit) => emit(ProfileIncomplete(e.user)));
    on<_InternalLoggedOut>((e, emit) => emit(Unauthenticated()));

    // FIX: Nouvelle logique pour le stream listener
    _sub = _repo.authChangesStream.listen((data) async {
      final user = data.session?.user;
      if (user == null) return add(_InternalLoggedOut());

      // FIX: Utiliser skipCleanup pour éviter le nettoyage automatique
      final p = await _repo.getProfile(user.id, skipCleanup: true);
      
      if (p == null) {
        // Pas de profil trouvé - vérifier si c'est un compte vraiment corrompu
        final isCorrupted = await _repo.isCorruptedAccount(user.id);
        
        if (isCorrupted) {
          print('🧹 Compte corrompu détecté - nettoyage');
          await _repo.cleanupCorruptedAccount();
          add(_InternalLoggedOut());
        } else {
          print('✅ Nouveau compte sans profil - OK pour onboarding');
          add(_InternalProfileIncomplete(user));
        }
      } else {
        // FIX: Utiliser la méthode isComplete pour vérifier
        if (!p.isComplete) {
          print('⚠️ Profil trouvé mais incomplet');
          add(_InternalProfileIncomplete(user));
        } else {
          print('✅ Profil complet trouvé');
          add(_InternalProfileLoaded(p));
        }
      }
    });
  }

  Future<void> _onInternalProfileLoaded(
    _InternalProfileLoaded event,
    Emitter<AuthState> emit,
  ) async {
    emit(Authenticated(event.profile));
    
    // 🆕 Déclencher le pré-chargement des données (qui inclut maintenant les crédits)
    if (AppDataInitializationService.isInitialized) {
      AppDataInitializationService.startDataPreloading();
    }
    
    print('✅ Utilisateur authentifié: ${event.profile.username}');
  }

  // Ajouter cette méthode dans la classe AuthBloc :
  Future<void> _onUpdateProfile(UpdateProfileRequested event, Emitter<AuthState> emit) async {
    if (state is! Authenticated) return;
    
    final currentState = state as Authenticated;
    emit(AuthLoading());

    final user = (state is ProfileIncomplete)
        ? (state as ProfileIncomplete).user
        : supabase.Supabase.instance.client.auth.currentUser;

    if (user == null) return emit(AuthError('Session expirée'));
    
    try {
      print('📝 Début mise à jour profil');

      // 🆕 Conserver l'état authenticated pendant la mise à jour
      emit(AuthLoading()); // État de chargement temporaire
      
      final updatedProfile = await _repo.updateProfile(
        userId: user.id,
        fullName: event.fullName,
        username: event.username,
        avatar: event.avatar,
      );

      // 🔧 FIX: Vider le cache de l'ancienne image si avatar changé
      if (event.avatar != null && currentState.profile.hasAvatar) {
        try {
          await CachedNetworkImage.evictFromCache(currentState.profile.avatarUrl!);
        } catch (e) {
          print('⚠️ Erreur vidage cache ancien avatar: $e');
        }
      }
      
      // 🆕 Remettre l'état Authenticated immédiatement
      print('✅ Profil mis à jour avec succès');
      emit(Authenticated(updatedProfile!));
      
    } catch (err) {
      print('❌ Erreur mise à jour profil: $err');
      emit(AuthError(err.toString()));
      // Retourner à l'état précédent après l'erreur
      Future.delayed(const Duration(seconds: 2), () {
        emit(Authenticated(currentState.profile));
      });
    }
  }

  Future<void> _onDeleteAccount(
    DeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! Authenticated) return;
    
    emit(AuthLoading());
    
    try {
      print('🗑️ Suppression du compte demandée...');
      
      // Utiliser la méthode existante du repository
      await _repo.deleteAccount();
      
      print('✅ Compte supprimé avec succès');
      
      // L'utilisateur sera automatiquement déconnecté par le stream listener
      // qui détectera que la session n'existe plus
      
    } catch (e) {
      print('❌ Erreur suppression compte: $e');
      
      // Retourner à l'état précédent en cas d'erreur
      final currentState = state;
      if (currentState is Authenticated) {
        emit(currentState);
      } else {
        emit(Unauthenticated());
      }
      
      // Propager l'erreur pour l'affichage dans l'UI
      emit(AuthError(
        e.toString(),
      ));
    }
  }

  Future<void> _onNotificationSettingsToggle(
    NotificationSettingsToggleRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Cette méthode est gérée par le NotificationBloc
    // On peut l'utiliser ici pour des actions supplémentaires si nécessaire
    print('🔔 Paramètres de notification modifiés: ${event.enabled}');
  }

  Future<void> _onStart(AppStarted e, Emitter<AuthState> emit) async {
    final user = supabase.Supabase.instance.client.auth.currentUser;
    if (user == null) return emit(Unauthenticated());
    
    // FIX: Utiliser skipCleanup au démarrage aussi
    final p = await _repo.getProfile(user.id, skipCleanup: true);
    
    if (p == null) {
      // Vérifier si c'est un compte corrompu avant de nettoyer
      final isCorrupted = await _repo.isCorruptedAccount(user.id);
      if (isCorrupted) {
        await _repo.cleanupCorruptedAccount();
        emit(Unauthenticated());
      } else {
        emit(ProfileIncomplete(user));
      }
    } else {
      emit(Authenticated(p));
    }
  }

  Future<void> _onCompleteProfile(CompleteProfileRequested e, Emitter<AuthState> emit) async {
    final user = (state is ProfileIncomplete)
        ? (state as ProfileIncomplete).user
        : supabase.Supabase.instance.client.auth.currentUser;

    if (user == null) return emit(AuthError('Session expirée'));

    emit(AuthLoading());
    try {
      final p = await _repo.completeProfile(
        userId: user.id,
        fullName: e.fullName,
        username: e.username,
        avatar: e.avatar,
      );
      if (p == null) return emit(AuthError('Impossible de sauvegarder'));
      
      print('✅ Profil complété avec succès: ${p.username}');
      emit(Authenticated(p));
    } catch (err) {
      print('❌ Erreur complétion profil: $err');
      emit(AuthError(err.toString()));
    }
  }

  Future<void> _onSignUpBasic(SignUpBasicRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _repo.signUpBasic(email: e.email, password: e.password);
      if (user == null) {
        return emit(AuthError('Échec de création de compte'));
      }

      print('✅ Inscription réussie pour: ${user.email}');
      print('📧 Email confirmé: ${user.emailConfirmedAt != null}');
      
      // Toujours rediriger vers la confirmation d'email si configuré dans Supabase
      // Supabase n'aura pas emailConfirmedAt si la confirmation est requise
      if (user.emailConfirmedAt == null) {
        print('📧 Email de confirmation requis pour: ${e.email}');
        emit(EmailConfirmationRequired(e.email));
      } else {
        print('✅ Inscription réussie, transition vers ProfileIncomplete');
        emit(ProfileIncomplete(user));
      }
    } catch (err) {
      print('❌ Erreur inscription: $err');
      emit(AuthError(err.toString()));
    }
  }

  Future<void> _onLogin(LogInRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final p = await _repo.logIn(email: e.email, password: e.password);
      
      if (p == null) {
        // Connexion réussie mais pas de profil - vérifier si corrompu
        final user = supabase.Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final isCorrupted = await _repo.isCorruptedAccount(user.id);
          if (isCorrupted) {
            await _repo.cleanupCorruptedAccount();
            emit(Unauthenticated());
          } else {
            emit(ProfileIncomplete(user));
          }
        } else {
          emit(Unauthenticated());
        }
      } else {
        emit(Authenticated(p));
      }
    } catch (err) {
      print('❌ Erreur connexion: $err');
      emit(AuthError(err.toString()));
    }
  }

  /* ───────── GOOGLE SIGN-IN HANDLER ───────── */
  Future<void> _onGoogleSignIn(GoogleSignInRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      print('🔑 Début Google Sign-In');
      
      final profile = await _repo.signInWithGoogle();
      
      if (profile == null) {
        // Connexion réussie mais pas de profil - rare mais possible
        final user = supabase.Supabase.instance.client.auth.currentUser;
        if (user != null) {
          print('⚠️ Connexion Google réussie mais pas de profil');
          emit(ProfileIncomplete(user));
        } else {
          emit(AuthError('Connexion Google échouée'));
        }
      } else {
        print('✅ Connexion Google réussie: ${profile.email}');
        emit(Authenticated(profile));
      }
    } catch (err) {
      print('❌ Erreur Google Sign-In: $err');
      emit(AuthError(err.toString()));
    }
  }

  /* ───────── APPLE SIGN-IN HANDLER ───────── */
  Future<void> _onAppleSignIn(AppleSignInRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      print('🔑 Début Apple Sign-In');
      
      final profile = await _repo.signInWithApple();
      
      if (profile == null) {
        // Connexion réussie mais pas de profil - rare mais possible
        final user = supabase.Supabase.instance.client.auth.currentUser;
        if (user != null) {
          print('⚠️ Connexion Apple réussie mais pas de profil');
          emit(ProfileIncomplete(user));
        } else {
          emit(AuthError('Connexion Apple échouée'));
        }
      } else {
        print('✅ Connexion Apple réussie: ${profile.email}');
        emit(Authenticated(profile));
      }
    } catch (err) {
      print('❌ Erreur Apple Sign-In: $err');
      emit(AuthError(err.toString()));
    }
  }

  // Ajouter cette méthode publique dans AuthBloc
  Future<String> getUsernameSuggestion() async {
    try {
      final suggestion = await _repo.suggestUsernameFromSocialData();
      print('📝 Suggestion username reçue du repository: $suggestion');
      return suggestion;
    } catch (e) {
      print('⚠️ Erreur récupération suggestion username: $e');
      // Fallback local en cas d'erreur
      final user = supabase.Supabase.instance.client.auth.currentUser;
      if (user?.email != null) {
        return user!.email!.split('@').first.toLowerCase();
      }
      return 'user';
    }
  }

  // Ajouter cette méthode publique dans AuthBloc pour obtenir les infos sociales
  Map<String, String?> getSocialUserInfo() {
    try {
      // Utiliser la méthode du repository qui gère les données temporaires
      final socialInfo = _repo.getSocialUserInfo();
      print('📝 Infos sociales reçues du repository: $socialInfo');
      return socialInfo;
    } catch (e) {
      print('⚠️ Erreur récupération infos sociales: $e');
      // Fallback local
      try {
        final user = supabase.Supabase.instance.client.auth.currentUser;
        if (user == null) return {};
        
        return {
          'fullName': null, // Pas d'infos disponibles en cas d'erreur
          'email': user.email,
        };
      } catch (e2) {
        print('⚠️ Erreur fallback infos sociales: $e2');
        return {};
      }
    }
  }

  Future<void> _onLogout(LogOutRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    // 🆕 Nettoyer le cache des crédits
    if (_creditsBloc != null) {
      _creditsBloc.add(const CreditsReset());
      try {
        final creditsRepo = CreditsRepository();
        await creditsRepo.clearCache();
      } catch (error) {
        print('⚠️ Erreur nettoyage cache crédits: $error');
      }
    }
    
    await _repo.logOut();
    emit(Unauthenticated());
  }

  Future<void> _onForgotPassword(ForgotPasswordRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _repo.resetPassword(email: e.email);
      emit(PasswordResetSent(e.email));
      
      // Retourner à l'état non authentifié après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (!isClosed) emit(Unauthenticated());
      });
    } catch (err) {
      print('❌ Erreur mot de passe oublié: $err');
      emit(AuthError(err.toString()));
      
      // Retourner à l'état précédent après l'erreur
      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) emit(Unauthenticated());
      });
    }
  }

  Future<void> _onResendConfirmation(ResendConfirmationRequested e, Emitter<AuthState> emit) async {
    // Ne pas émettre AuthLoading pour éviter de bloquer l'UI
    try {
      await _repo.resendConfirmationEmail(email: e.email);
      print('✅ Email de confirmation renvoyé avec succès');
      // Rester sur EmailConfirmationRequired pour maintenir l'écran
      emit(EmailConfirmationRequired(e.email));
    } catch (err) {
      print('❌ Erreur renvoi confirmation: $err');
      emit(AuthError(err.toString()));
      
      // Retourner à l'état précédent après l'erreur
      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) emit(EmailConfirmationRequired(e.email));
      });
    }
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}

class _InternalProfileIncomplete extends AuthEvent {
  final supabase.User user;
  _InternalProfileIncomplete(this.user);
}

class _InternalProfileLoaded extends AuthEvent {
  final Profile profile;
  _InternalProfileLoaded(this.profile);
}

class _InternalLoggedOut extends AuthEvent {}