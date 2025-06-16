import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';

/// Wrapper pour les pages qui nécessitent une authentification
/// Affiche automatiquement la modal AskRegistration si l'utilisateur n'est pas connecté
class ProtectedRouteWrapper extends StatefulWidget {
  final Widget child;
  final bool showModalOnUnauth;

  const ProtectedRouteWrapper({
    super.key,
    required this.child,
    this.showModalOnUnauth = true,
  });

  @override
  State<ProtectedRouteWrapper> createState() => _ProtectedRouteWrapperState();
}

class _ProtectedRouteWrapperState extends State<ProtectedRouteWrapper> {
  bool _modalShown = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, authState) {
        // FIX: Seulement afficher la modal pour les utilisateurs vraiment non connectés
        // ProfileIncomplete sera géré par le router vers /onboarding
        if (widget.showModalOnUnauth && authState is Unauthenticated) {
          if (!_modalShown) {
            _modalShown = true;
            print('🔒 Affichage modal AskRegistration - utilisateur non connecté');
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showModalBottomSheet(
                  context: context,
                  useRootNavigator: true,
                  enableDrag: false,
                  isDismissible: false,
                  isScrollControlled: true,
                  builder: (modalCtx) {
                    return AskRegistration();
                  },
                ).whenComplete(() {
                  // Réinitialiser le flag quand la modal se ferme
                  if (mounted) {
                    setState(() {
                      _modalShown = false;
                    });
                  }
                });
              }
            });
          }
        } else if (authState is Authenticated && _modalShown) {
          // L'utilisateur s'est connecté, fermer la modal si elle est ouverte
          _modalShown = false;
          Navigator.of(context, rootNavigator: true).pop();
        } else if (authState is ProfileIncomplete && _modalShown) {
          // FIX: Si ProfileIncomplete et modal ouverte, la fermer car le router va rediriger vers onboarding
          _modalShown = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
      builder: (context, authState) {
        // Toujours afficher l'enfant, la modal se superpose
        return widget.child;
      },
    );
  }
}