// Fichier : lib/bloc/auth_event.dart
import 'dart:io';

import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class SignUpBasicRequested extends AuthEvent {
  final String email, password;
  SignUpBasicRequested({required this.email, required this.password});
}

class CompleteProfileRequested extends AuthEvent {
  final String fullName, username;
  final File? avatar;
  CompleteProfileRequested({
    required this.fullName,
    required this.username,
    this.avatar,
  });
}

class LogInRequested extends AuthEvent {
  final String email, password;
  LogInRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class LogOutRequested extends AuthEvent {}

class GoogleSignInRequested extends AuthEvent {}

class AppleSignInRequested extends AuthEvent {}

class UpdateProfileRequested extends AuthEvent {
  final String? fullName;
  final String? username;
  final File? avatar;
  
  UpdateProfileRequested({
    this.fullName,
    this.username,
    this.avatar,
  });
  
  @override
  List<Object?> get props => [fullName, username, avatar];
}

class DeleteAccountRequested extends AuthEvent {}

class NotificationSettingsToggleRequested extends AuthEvent {
  final bool enabled;
  
  NotificationSettingsToggleRequested({required this.enabled});
  
  @override
  List<Object?> get props => [enabled];
}