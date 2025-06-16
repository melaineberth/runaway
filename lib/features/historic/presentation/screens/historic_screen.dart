import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/features/account/presentation/screens/account_screen.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import '../widgets/historic_card.dart';

class HistoricScreen extends StatelessWidget {  
  const HistoricScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final List<HistoricCard> data = [];

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
                  "Historique",
                  style: context.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              body: data.isNotEmpty ? BlurryPage(
                padding: EdgeInsets.all(20.0),
                children: List.generate(
                  data.length, 
                  (index) => Padding(
                    padding: EdgeInsets.only(bottom: index >= data.length ? 0 : 15.0),
                    child: data[index],
                  ),
                ),
              ) : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Historique',
                      style: context.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Aucun parcours dans votre historique',
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