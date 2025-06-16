import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';

class ActivityScreen extends StatelessWidget {  
  const ActivityScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {    
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is Unauthenticated) {
          // L'utilisateur s'est déconnecté, rediriger vers l'accueil
          context.go('/home');
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (_, authState) {
          if (authState is Authenticated) {
            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                forceMaterialTransparency: true,
                backgroundColor: Colors.transparent,
                title: Text(
                  "Activité",
                  style: context.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 64,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Page Activité',
                      style: context.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Contenu de la page activité à implémenter',
                      style: context.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          
          return AskRegistration();
        }
      ),
    );
  }
}