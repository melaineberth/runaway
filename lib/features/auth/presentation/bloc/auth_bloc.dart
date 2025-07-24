import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/helper/extensions/monitoring_extensions.dart';
import 'package:runaway/core/helper/services/app_data_initialization_service.dart';
import 'package:runaway/core/helper/services/cache_service.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/core/router/router.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/utils/injections/service_locator.dart';
import 'package:runaway/features/auth/data/repositories/auth_repository.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:runaway/core/helper/config/log_config.dart';
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

    on<ResendConfirmationRequested>(_onResendConfirmation);
    on<VerifyOTPRequested>(_onVerifyOTP);
    on<ForgotPasswordRequested>(_onForgotPassword);
    on<ResetPasswordWithOTPRequested>(_onResetPasswordWithOTP);

    // handlers internes
    on<_InternalProfileLoaded>(_onInternalProfileLoaded);
    on<_InternalProfileIncomplete>((e, emit) => emit(ProfileIncomplete(e.user)));
    on<_InternalLoggedOut>((e, emit) => emit(Unauthenticated()));

    // FIX: Nouvelle logique pour le stream listener
    _sub = _repo.authChangesStream.listen((data) async {
      try {
        final user = data.session?.user;
        if (user == null) return add(_InternalLoggedOut());
        
        // FIX: Utiliser skipCleanup pour éviter le nettoyage automatique
        final p = await _repo.getProfile(user.id, skipCleanup: true);
        
        if (p == null) {
          // Pas de profil trouvé - vérifier si c'est un compte vraiment corrompu
          final isCorrupted = await _repo.isCorruptedAccount(user.id);
          
          if (isCorrupted) {
            LogConfig.logInfo('🧹 Compte corrompu détecté - nettoyage');
            await _repo.cleanupCorruptedAccount();
            add(_InternalLoggedOut());
          } else {
            LogConfig.logInfo('Nouveau compte sans profil - OK pour onboarding');
            add(_InternalProfileIncomplete(user));
          }
        } else {
          // FIX: Utiliser la méthode isComplete pour vérifier
          if (!p.isComplete) {
            LogConfig.logInfo('Profil trouvé mais incomplet');
            add(_InternalProfileIncomplete(user));
          } else {
            LogConfig.logInfo('Profil complet trouvé');
            add(_InternalProfileLoaded(p));
          }
        }

        // 🆕 Tracking des changements d'état d'auth
        MonitoringService.instance.recordMetric(
          'auth_state_change',
          1,
          tags: {
            'new_state': data.runtimeType.toString(),
            'has_user': (data is Authenticated).toString(),
          },
        );
        
        // 🆕 Configurer l'utilisateur dans le monitoring
        if (data is Authenticated) {
          MonitoringService.instance.setUser(
            userId: data.session!.user.id,
            email: data.session!.user.email,
            username: data.session!.user.userMetadata?['username'],
            additionalData: {
              'provider': data.session!.user.appMetadata['provider'] ?? 'unknown',
              'created_at': data.session!.user.createdAt,
            },
          );
        } else {
          MonitoringService.instance.clearUser();
        }
      } catch (e, stackTrace) {
        captureError(e, stackTrace, extra: {
          'context': 'auth_state_stream',
          'auth_state': data.runtimeType.toString(),
        });
      }
    });
  }

  /// 🆕 Gère le changement de session utilisateur
  Future<void> _handleUserSessionChange(String newUserId) async {
    try {
      LogConfig.logInfo('👤 Vérification changement utilisateur...');
      
      final cacheService = CacheService.instance;
      final hasUserChanged = await cacheService.hasUserChanged(newUserId);
      
      if (hasUserChanged) {
        LogConfig.logInfo('👤 Changement d\'utilisateur détecté - nettoyage en cours...');
        
        // Nettoyer le CreditsBloc AVANT le cache
        try {
          _creditsBloc?.add(const CreditsReset());
          LogConfig.logInfo('💳 CreditsBloc reseté pour nouvel utilisateur');
          
          // Attendre un peu pour que le reset soit traité
          await Future.delayed(Duration(milliseconds: 100));
        } catch (e) {
          LogConfig.logError('❌ Erreur reset CreditsBloc: $e');
        }
        
        // Notifier AppDataBloc du changement AVANT le nettoyage
        try {
          final appDataBloc = sl.get<AppDataBloc>();
          appDataBloc.add(UserSessionChangedInAppData(newUserId: newUserId));
          LogConfig.logInfo('📊 AppDataBloc notifié du changement utilisateur');
          
          // Attendre que AppDataBloc traite l'événement
          await Future.delayed(Duration(milliseconds: 150));
        } catch (e) {
          LogConfig.logError('❌ Erreur notification AppDataBloc: $e');
        }
        
        // Forcer le nettoyage complet du cache
        await cacheService.forceCompleteClearing();
        LogConfig.logInfo('🧹 Cache complètement nettoyé pour nouvel utilisateur');
        
        // Confirmer le changement d'utilisateur APRÈS le nettoyage
        await cacheService.confirmUserChange(newUserId);
        LogConfig.logInfo('✅ Changement d\'utilisateur confirmé');
        
        // Déclencher le pré-chargement avec un délai plus long
        try {
          final appDataBloc = sl.get<AppDataBloc>();
          // Attendre que le nettoyage soit complètement terminé
          Future.delayed(Duration(milliseconds: 500), () {
            appDataBloc.add(const AppDataPreloadRequested());
          });
          LogConfig.logInfo('🚀 Pré-chargement programmé pour nouvel utilisateur');
        } catch (e) {
          LogConfig.logError('❌ Erreur programmation pré-chargement: $e');
        }
      } else {
        LogConfig.logInfo('👤 Même utilisateur - pas de nettoyage nécessaire');
        
        // Même utilisateur, mais confirmer quand même (pour les premiers connexions)
        try {
          await cacheService.confirmUserChange(newUserId);
        } catch (e) {
          LogConfig.logError('❌ Erreur confirmation utilisateur: $e');
        }
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur gestion changement utilisateur: $e');
      
      // En cas d'erreur, forcer quand même un nettoyage minimal
      try {
        final cacheService = CacheService.instance;
        await cacheService.invalidateCreditsCache();
        await cacheService.confirmUserChange(newUserId);
        LogConfig.logInfo('🆘 Nettoyage minimal effectué après erreur');
      } catch (e2) {
        LogConfig.logError('❌ Erreur nettoyage minimal: $e2');
      }
    }
  }

  Future<void> _onInternalProfileLoaded(
    _InternalProfileLoaded event,
    Emitter<AuthState> emit,
  ) async {
    // Vérifier le changement d'utilisateur AVANT d'émettre l'état
    await _handleUserSessionChange(event.profile.id);
    
    // Attendre un petit délai pour s'assurer que le nettoyage est terminé
    await Future.delayed(Duration(milliseconds: 200));
    
    emit(Authenticated(event.profile));
    
    // Déclencher le pré-chargement des données
    if (AppDataInitializationService.isInitialized) {
      // Délai supplémentaire pour le pré-chargement
      Future.delayed(Duration(milliseconds: 300), () {
        AppDataInitializationService.startDataPreloading();
      });
    }

    // EN MODE DEBUG : Diagnostic automatique après connexion
    if (kDebugMode) {
      Future.delayed(Duration(seconds: 2), () async {
        try {
          final context = rootNavigatorKey.currentContext!;
          if (context != null) {
            await context.diagnoseCacheState();
            LogConfig.logInfo('🔍 Diagnostic automatique effectué après connexion');
          }
        } catch (e) {
          LogConfig.logError('❌ Erreur diagnostic automatique: $e');
        }
      });
    }
    
    LogConfig.logInfo('Utilisateur authentifié: ${event.profile.username}');
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
      LogConfig.logInfo('📝 Début mise à jour profil');

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
          LogConfig.logInfo('Erreur vidage cache ancien avatar: $e');
        }
      }
      
      // 🆕 Remettre l'état Authenticated immédiatement
      LogConfig.logInfo('Profil mis à jour avec succès');
      emit(Authenticated(updatedProfile!));
      
    } catch (err) {
      LogConfig.logError('❌ Erreur mise à jour profil: $err');
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
      LogConfig.logInfo('🗑️ Suppression du compte demandée...');

      // 🆕 1. Nettoyer explicitement TOUS les blocs avant la suppression
      try {
        _creditsBloc?.add(const CreditsReset());
        LogConfig.logInfo('💳 CreditsBloc reseté avant suppression');
      } catch (e) {
        LogConfig.logError('❌ Erreur reset CreditsBloc avant suppression: $e');
      }

      // 🆕 2. Nettoyer le monitoring
      try {
        MonitoringService.instance.clearUser();
        LogConfig.logInfo('📊 Données monitoring nettoyées avant suppression');
      } catch (e) {
        LogConfig.logError('❌ Erreur nettoyage monitoring avant suppression: $e');
      }
      
      // Utiliser la méthode existante du repository
      await _repo.deleteAccount();
      
      LogConfig.logInfo('Compte supprimé avec succès');
            
    } catch (e) {
      LogConfig.logError('❌ Erreur suppression compte: $e');

      // 🆕 En cas d'erreur, forcer le nettoyage quand même
      try {
        _creditsBloc?.add(const CreditsReset());
        MonitoringService.instance.clearUser();
        LogConfig.logInfo('🔒 Nettoyage forcé après erreur suppression');
      } catch (cleanupError) {
        LogConfig.logError('❌ Erreur nettoyage forcé après suppression: $cleanupError');
      }
      
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
      
      LogConfig.logInfo('Profil complété avec succès: ${p.username}');
      emit(Authenticated(p));
    } catch (err) {
      LogConfig.logError('❌ Erreur complétion profil: $err');
      emit(AuthError(err.toString()));
    }
  }

  Future<void> _onSignUpBasic(SignUpBasicRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _repo.signUpWithEmail(email: e.email, password: e.password);
      if (user == null) {
        return emit(AuthError('Échec de création de compte'));
      }

      LogConfig.logInfo('Inscription réussie pour: ${user.email}');
      print('📧 Email confirmé: ${user.emailConfirmedAt != null}');
      
      // Toujours rediriger vers la confirmation d'email si configuré dans Supabase
      // Supabase n'aura pas emailConfirmedAt si la confirmation est requise
      if (user.emailConfirmedAt == null) {
        print('📧 Email de confirmation requis pour: ${e.email}');
        emit(EmailConfirmationRequired(e.email));
      } else {
        LogConfig.logInfo('Inscription réussie, transition vers ProfileIncomplete');
        emit(ProfileIncomplete(user));
      }
    } catch (err) {
      LogConfig.logError('❌ Erreur inscription: $err');
      emit(AuthError(err.toString()));
    }
  }

  Future<void> _onLogin(LogInRequested e, Emitter<AuthState> emit) async {
    trackEvent(e, data: {
      'has_email': e.email != null,
    });

    final operationId = MonitoringService.instance.trackOperation(
      'user_login',
      description: 'Connexion utilisateur',
      data: {
        'has_email': e.email != null,
      },
    );

    try {
      emit(AuthLoading());
      
      final p = await _repo.signInWithEmail(email: e.email, password: e.password);
      
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
        MonitoringService.instance.finishOperation(operationId, success: true);

        // 🆕 Métrique business - nouvel utilisateur connecté
        MonitoringService.instance.recordMetric(
          'user_login_success',
          1,
          tags: {
            'is_new_user': 'false', // À déterminer selon votre logique
          },
        );
      }
    } catch (err, stackTrace) {
      captureError(err, stackTrace, event: e, state: state, extra: {
        'operation_id': operationId,
      });

      emit(AuthError(err.toString()));

      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: err.toString(),
      );
      
      // Métrique d'échec
      MonitoringService.instance.recordMetric(
        'user_login_failure',
        1,
        tags: {
          'error_type': err.runtimeType.toString(),
        },
      );
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
          LogConfig.logInfo('Connexion Google réussie mais pas de profil');
          emit(ProfileIncomplete(user));
        } else {
          emit(AuthError('Connexion Google échouée'));
        }
      } else {
        LogConfig.logInfo('Connexion Google réussie: ${profile.email}');
        emit(Authenticated(profile));
      }
    } catch (err) {
      LogConfig.logError('❌ Erreur Google Sign-In: $err');
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
          LogConfig.logInfo('Connexion Apple réussie mais pas de profil');
          emit(ProfileIncomplete(user));
        } else {
          emit(AuthError('Connexion Apple échouée'));
        }
      } else {
        LogConfig.logInfo('Connexion Apple réussie: ${profile.email}');
        emit(Authenticated(profile));
      }
    } catch (err) {
      LogConfig.logError('❌ Erreur Apple Sign-In: $err');
      emit(AuthError(err.toString()));
    }
  }

  // Ajouter cette méthode publique dans AuthBloc
  Future<String> getUsernameSuggestion() async {
    try {
      final suggestion = await _repo.suggestUsernameFromSocialData();
      LogConfig.logInfo('📝 Suggestion username reçue du repository: $suggestion');
      return suggestion;
    } catch (e) {
      LogConfig.logInfo('Erreur récupération suggestion username: $e');
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
      LogConfig.logInfo('📝 Infos sociales reçues du repository: $socialInfo');
      return socialInfo;
    } catch (e) {
      LogConfig.logInfo('Erreur récupération infos sociales: $e');
      // Fallback local
      try {
        final user = supabase.Supabase.instance.client.auth.currentUser;
        if (user == null) return {};
        
        return {
          'fullName': null, // Pas d'infos disponibles en cas d'erreur
          'email': user.email,
        };
      } catch (e2) {
        LogConfig.logInfo('Erreur fallback infos sociales: $e2');
        return {};
      }
    }
  }

  Future<void> _onLogout(LogOutRequested e, Emitter<AuthState> emit) async {
    trackEvent(e);

    final operationId = MonitoringService.instance.trackOperation(
      'user_logout',
      description: 'Déconnexion utilisateur',
    );

    try {
      emit(AuthLoading());

      // 🆕 1. Nettoyer explicitement les données via le CreditsBloc si disponible
      try {
        _creditsBloc?.add(const CreditsReset());
        LogConfig.logInfo('💳 CreditsBloc reseté');
      } catch (e) {
        LogConfig.logError('❌ Erreur reset CreditsBloc: $e');
      }

      // 🆕 2. Nettoyer les données de monitoring avant déconnexion
      try {
        MonitoringService.instance.clearUser();
        LogConfig.logInfo('📊 Données monitoring nettoyées');
      } catch (e) {
        LogConfig.logError('❌ Erreur nettoyage monitoring: $e');
      }

      await _repo.signOut();

      emit(Unauthenticated());

      MonitoringService.instance.finishOperation(operationId, success: true);
      
      LogConfig.logInfo('✅ Déconnexion complète réussie');
    } catch (err, stackTrace) {
      captureError(err, stackTrace, event: e, state: state);
      
      MonitoringService.instance.finishOperation(
        operationId,
        success: false,
        errorMessage: err.toString(),
      );

      // 🆕 En cas d'erreur, forcer le nettoyage et l'état déconnecté
      try {
        _creditsBloc?.add(const CreditsReset());
        MonitoringService.instance.clearUser();
        LogConfig.logInfo('🔒 Nettoyage forcé en cas d\'erreur de déconnexion');
      } catch (cleanupError) {
        LogConfig.logError('❌ Erreur nettoyage forcé: $cleanupError');
      }
      
      // Forcer l'état déconnecté même en cas d'erreur
      emit(Unauthenticated());
      
      LogConfig.logError('❌ Erreur déconnexion mais état forcé à déconnecté: $err');
    }
  }

  Future<void> _onVerifyOTP(VerifyOTPRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _repo.verifyOTP(email: e.email, otp: e.otp);
      if (user == null) {
        return emit(AuthError('Code invalide ou expiré'));
      }

      LogConfig.logInfo('✅ OTP vérifié pour: ${user.email}');
      
      // Email confirmé, passer à la complétion du profil
      emit(ProfileIncomplete(user));
    } catch (err) {
      LogConfig.logError('❌ Erreur vérification OTP: $err');
      // Rester sur l'écran de confirmation avec l'erreur
      emit(AuthError(err.toString()));
      
      // Retourner à l'état de confirmation après l'erreur
      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) emit(EmailConfirmationRequired(e.email));
      });
    }
  }

  Future<void> _onForgotPassword(
    ForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // Envoi du mail de reset via votre repo Supabase
      await _repo.resetPassword(email: event.email);

      // Succès → on passe à l'état de saisie du code OTP
      emit(PasswordResetCodeSent(event.email));

    } on supabase.AuthApiException catch (apiErr) {
      // Si Supabase renvoie une erreur de type AuthApiException
      final msg = apiErr.message.contains('invalid')
          ? 'Adresse e-mail invalide ou non enregistrée.'
          : apiErr.message;

      LogConfig.logError('❌ Erreur réinitialisation mot de passe: $apiErr');
      emit(AuthError(msg));

      // Puis on revient à Unauthenticated pour permettre une nouvelle tentative
      await Future.delayed(const Duration(seconds: 2));
      if (!isClosed) {
        emit(Unauthenticated());
      }
    } catch (err, stack) {
      // Erreur réseau, autre…
      LogConfig.logError('❌ Erreur mot de passe oublié: $err\n$stack');
      emit(AuthError('Une erreur est survenue. Veuillez réessayer.'));

      await Future.delayed(const Duration(seconds: 2));
      if (!isClosed) {
        emit(Unauthenticated());
      }
    }
  }

  Future<void> _onResetPasswordWithOTP(
    ResetPasswordWithOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _repo.resetPasswordWithOTP(
        email: event.email,
        otp: event.otp,
        newPassword: event.newPassword,
      );

      LogConfig.logInfo('✅ Mot de passe réinitialisé avec succès');
      
      // Émission de l'état de succès
      emit(PasswordResetSuccess());

      // Retour à l'état non authentifié après 3 secondes
      await Future.delayed(const Duration(seconds: 3));
      if (!isClosed) {
        emit(Unauthenticated());
      }

    } catch (err) {
      LogConfig.logError('❌ Erreur réinitialisation avec OTP: $err');
      
      // Retourner à l'écran de saisie du code avec l'erreur
      emit(AuthError(err.toString()));
      
      await Future.delayed(const Duration(seconds: 2));
      if (!isClosed) {
        emit(PasswordResetCodeSent(event.email));
      }
    }
  }

  Future<void> _onResendConfirmation(ResendConfirmationRequested e, Emitter<AuthState> emit) async {
    // Ne pas émettre AuthLoading pour éviter de bloquer l'UI
    try {
      await _repo.resendConfirmationEmail(email: e.email);
      LogConfig.logInfo('Email de confirmation renvoyé avec succès');
      // Rester sur EmailConfirmationRequired pour maintenir l'écran
      emit(EmailConfirmationRequired(e.email));
    } catch (err) {
      LogConfig.logError('❌ Erreur renvoi confirmation: $err');
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