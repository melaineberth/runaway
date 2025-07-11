// lib/bloc/auth_state.dart
import 'package:equatable/equatable.dart';
import 'package:runaway/features/auth/domain/models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class Unauthenticated extends AuthState {}

class Authenticated extends AuthState {
  final Profile profile;
  Authenticated(this.profile);
  @override
  List<Object?> get props => [profile];
}

class ProfileIncomplete extends AuthState {
  final User user;               // encore brut, sans profil
  ProfileIncomplete(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

class PasswordResetSent extends AuthState {
  final String email;
  
  PasswordResetSent(this.email);
  
  @override
  List<Object> get props => [email];
}

class EmailConfirmationRequired extends AuthState {
  final String email;
  
  EmailConfirmationRequired(this.email);
  
  @override
  List<Object> get props => [email];
}