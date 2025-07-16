import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/core/helper/services/app_data_initialization_service.dart';

/// Widget qui écoute les changements d'authentification et déclenche le pré-chargement
class AuthDataListener extends StatelessWidget {
  final Widget child;

  const AuthDataListener({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is Authenticated) {
          // Utilisateur connecté -> démarrer le pré-chargement
          print('🔐 Utilisateur authentifié, démarrage du pré-chargement...');
          AppDataInitializationService.startDataPreloading();
        } else if (authState is Unauthenticated) {
          // Utilisateur déconnecté -> nettoyer le cache
          print('🚪 Utilisateur déconnecté, nettoyage du cache...');
          AppDataInitializationService.clearDataCache();
        }
      },
      child: child,
    );
  }
}
