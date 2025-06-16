// lib/bloc/auth_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/features/auth/data/repositories/auth_repository.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  late final StreamSubscription _sub;

  AuthBloc(this._repo) : super(AuthInitial()) {
    on<AppStarted>(_onStart);
    on<SignUpBasicRequested>(_onSignUpBasic);
    on<CompleteProfileRequested>(_onCompleteProfile);
    on<LogInRequested>(_onLogin);
    on<LogOutRequested>(_onLogout);

    // handlers internes
    on<_InternalProfileLoaded>((e, emit) => emit(Authenticated(e.profile)));
    on<_InternalProfileIncomplete>((e, emit) => emit(ProfileIncomplete(e.user))); // ★
    on<_InternalLoggedOut>((e, emit) => emit(Unauthenticated()));

    // écoute des sessions Supabase
    _sub = _repo.authChangesStream.listen((data) async {
      final user = data.session?.user;
      if (user == null) return add(_InternalLoggedOut());

      final p = await _repo.getProfile(user.id);
      if (p == null || p.username!.isEmpty) {
        add(_InternalProfileIncomplete(user));
      } else {
        add(_InternalProfileLoaded(p));
      }
    });
  }

  Future<void> _onStart(AppStarted e, Emitter<AuthState> emit) async {
    final user = supabase.Supabase.instance.client.auth.currentUser;
    if (user == null) return emit(Unauthenticated());
    final p = await _repo.getProfile(user.id);
    emit(p == null ? Unauthenticated() : Authenticated(p));
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
        phone: e.phone,
        avatar: e.avatar,
      );
      if (p == null) return emit(AuthError('Impossible de sauvegarder'));
      emit(Authenticated(p));
    } catch (err) {
      emit(AuthError(err.toString()));
    }
  }

  Future<void> _onSignUpBasic(SignUpBasicRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user =
          await _repo.signUpBasic(email: e.email, password: e.password);
      if (user == null) {
        return emit(AuthError('Échec de création de compte'));
      }
      emit(ProfileIncomplete(user));               //  ← ICI
    } catch (err) {
      emit(AuthError(err.toString()));
    }
  }

  Future<void> _onLogin(LogInRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final p = await _repo.logIn(email: e.email, password: e.password);
      emit(p == null ? Unauthenticated() : Authenticated(p));
    } catch (err) {
      emit(AuthError(err.toString()));
    }
  }

  Future<void> _onLogout(LogOutRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _repo.logOut();
    emit(Unauthenticated());
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
