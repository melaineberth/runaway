import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/extensions/monitoring_extensions.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/screens/login_screen.dart';
import 'package:runaway/features/auth/presentation/screens/signup_screen.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class AuthScreen extends StatefulWidget {
  final int initialIndex;
  
  const AuthScreen({super.key, this.initialIndex = 0});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late String _screenLoadId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _screenLoadId = context.trackScreenLoad('auth_screen');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.finishScreenLoad(_screenLoadId);
    });
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
    return MonitoredScreen(
      screenName: 'auth',
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, authState) {
          if (authState is Authenticated) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            context.go('/home');
          } else if (authState is ProfileIncomplete) {
            // Profil incomplet, aller vers l'onboarding
            context.go('/onboarding');
          } else if (authState is EmailConfirmationRequired) {
            // Email de confirmation requis
            context.go('/email-confirmation?email=${Uri.encodeComponent(authState.email)}');
          } else if (authState is PasswordResetSent) {
            // Mot de passe réinitialisé
            showTopSnackBar(
              Overlay.of(context),
              TopSnackBar(
                title: 'Email de réinitialisation envoyé à ${authState.email}',
              ),
            );
          } else if (authState is AuthError) {
            // Afficher l'erreur
            showTopSnackBar(
              Overlay.of(context),
              TopSnackBar(
                isError: true,
                title: authState.message,
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
                  
                  return PageView(
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
                  );
                },
              ),
            ),
            Positioned(
              right: 15,
              top: 15,
              child: IconBtn(
                backgroundColor: Colors.transparent,
                icon: HugeIcons.solidRoundedCancelCircle,
                iconColor: context.adaptiveDisabled.withValues(alpha: 0.2),
                onPressed: () => context.pop(),
              ),
            ),  
          ],
        ),
      ),
    );
  }
}