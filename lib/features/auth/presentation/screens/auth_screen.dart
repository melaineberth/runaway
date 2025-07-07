import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/screens/login_screen.dart';
import 'package:runaway/features/auth/presentation/screens/signup_screen.dart';

class AuthScreen extends StatefulWidget {
  final int initialIndex;
  
  const AuthScreen({super.key, this.initialIndex = 0});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchToLogin() {
    _pageController.jumpToPage(1);
  }

  void _switchToSignup() {
    _pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is Authenticated) {
          // Connexion réussie, fermer la modal et revenir à l'accueil
          context.pop();
        } else if (authState is ProfileIncomplete) {
          // Profil incomplet, aller vers l'onboarding
          context.go('/onboarding');
        } else if (authState is AuthError) {
          // Afficher l'erreur
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authState.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Stack(
        children: [
          ModalSheet(
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                final isLoading = authState is AuthLoading;
                
                return Stack(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height / 1.3,
                      child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                        children: [
                          SignupScreen(
                            onSwitchToLogin: _switchToLogin,
                            isLoading: isLoading,
                          ),
                          LoginScreen(
                            onSwitchToSignup: _switchToSignup,
                            isLoading: isLoading,
                          ),
                        ],
                      ),
                    ),                    
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: IconBtn(
              backgroundColor: Colors.transparent,
              icon: HugeIcons.solidRoundedCancelCircle,
              iconColor: context.adaptiveDisabled.withValues(alpha: 0.2),
              onPressed: () => context.pop(),
            ),  
          ),
        ],
      ),
    );
  }
}