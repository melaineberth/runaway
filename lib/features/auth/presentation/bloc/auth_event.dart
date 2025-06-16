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
  final String fullName, username, phone;
  final File? avatar;
  CompleteProfileRequested({
    required this.fullName,
    required this.username,
    required this.phone,
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
