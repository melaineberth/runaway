// Fichier : lib/bloc/auth_event.dart
import 'dart:io';

import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class GetUsernameSuggestionRequested extends AuthEvent {}

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

class VerifyOTPRequested extends AuthEvent {
  final String email;
  final String otp;
  
  VerifyOTPRequested({required this.email, required this.otp});
  
  @override
  List<Object?> get props => [email, otp];
}

class ForgotPasswordRequested extends AuthEvent {
  final String email;
  
  ForgotPasswordRequested({required this.email});
  
  @override
  List<Object?> get props => [email];
}

class VerifyPasswordResetCodeRequested extends AuthEvent {
  final String email;
  final String code;
  
  VerifyPasswordResetCodeRequested({required this.email, required this.code});
  
  @override
  List<Object?> get props => [email, code];
}

class ResetPasswordRequested extends AuthEvent {
  final String email;
  final String code;
  final String newPassword;
  
  ResetPasswordRequested({required this.email, required this.code, required this.newPassword});
  
  @override
  List<Object?> get props => [email, code, newPassword];
}