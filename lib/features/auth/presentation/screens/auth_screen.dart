import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/extensions/monitoring_extensions.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/utils/injections/service_locator.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
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
  late String _screenLoadId;
  int initialIndex = 0;

  @override
  void initState() {
    super.initState();
    _screenLoadId = context.trackScreenLoad('auth_screen');

    initialIndex = widget.initialIndex;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.finishScreenLoad(_screenLoadId);
    });
  }

  void showEmailSignIn({required bool isLoading}) {
    showModalSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      child: LoginScreen(
        isLoading: isLoading, 
      )
    );
  }

  void showEmailSignUp({required bool isLoading}) {
    showModalSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      child: SignupScreen(
        isLoading: isLoading, 
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MonitoredScreen(
      screenName: 'auth',
      child: BlocListener<AuthBloc, AuthState>(
        // Optimiser l'écoute des états d'auth
        listenWhen: (previous, current) =>
          current is Authenticated ||
          current is ProfileIncomplete ||
          current is EmailConfirmationRequired ||
          current is PasswordResetSent ||
          current is AuthError,
          
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
                title: context.l10n.resetEmail(authState.email),
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
        child: SizedBox(
          height: MediaQuery.of(context).size.height / 1.1,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  onPressed: () => context.pop(), 
                  icon: Icon(
                    HugeIcons.solidRoundedCancelCircle,
                    color: context.adaptiveDisabled.withValues(alpha: 0.2),
                    size: 28,
                  ),
                ),
              ],
            ),
            body: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                final isLoading = authState is AuthLoading;
                
                return BlocBuilder<ThemeBloc, ThemeState>(
                  // ✅ Éviter les rebuilds inutiles pour theme
                  buildWhen: (previous, current) => previous.themeMode != current.themeMode,
                  builder: (context, themeState) {
                    return Column(
                      children: [
                        Expanded(
                          child: Image.asset(
                            themeState.themeMode == AppThemeMode.dark ? "assets/img/onboard_black.png" : "assets/img/onboard_white.png",
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            20.0,
                            20.0,
                            20.0,
                            Platform.isAndroid ? MediaQuery.of(context).padding.bottom + 20.0 : 20.0,
                          ),
                          child: SquircleContainer(
                            gradient: false,
                            padding: EdgeInsets.all(20.0),
                            color: context.adaptiveDisabled.withValues(alpha: 0.05),
                            radius: 100.0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildAuthInfo(),
                    
                                40.h,
                    
                                _buildSocialButtons(isLoading: isLoading),          
                      
                                50.h,
                                
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: initialIndex == 0 
                                          ? context.l10n.haveAccount 
                                          : context.l10n.createAccountQuestion,
                                        style: context.bodySmall?.copyWith(
                                          fontSize: 15,
                                          color: context.adaptiveTextPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      TextSpan(
                                        text: initialIndex == 0  
                                          ? ' ${context.l10n.logIn}'
                                          : ' ${context.l10n.signUp}',
                                        style: context.bodySmall?.copyWith(
                                          fontSize: 15,
                                          color: context.adaptivePrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          setState(() {
                                            if (initialIndex == 1) {
                                              initialIndex = 0; // <= CORRECT
                                            } else {
                                              initialIndex = 1; // <= CORRECT
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                );              
              },
            ),
          ),
        )
      ),
    );
  }

  Widget _buildAuthInfo() {
    return Column(
      children: [
        Text(
          initialIndex == 0 
            ? context.l10n.createAccountTitle 
            : context.l10n.loginGreetingTitle,
          style: context.bodyMedium?.copyWith(
            fontSize: 22,
            color: context.adaptiveTextPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        12.h,
        Text(
          initialIndex == 0 
            ? context.l10n.createAccountSubtitle 
            : context.l10n.loginGreetingSubtitle,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextSecondary,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSocialButtons({required bool isLoading}) {
    return Column(
      children: [
        SquircleBtn(
          isPrimary: true,
          isLoading: isLoading,
          onTap: isLoading 
            ? null : initialIndex == 0 
              ? () => showEmailSignUp(isLoading: isLoading) 
              : () => showEmailSignIn(isLoading: isLoading),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                HugeIcons.solidRoundedMail02,
                color: Colors.white,
              ),
              5.w,
              Text(
                context.l10n.continueWithEmail,
                style: context.bodySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        8.h,
        Row(
          children: [
            if (!Platform.isAndroid) ...[
              Expanded(
                child: SquircleBtn(
                  isPrimary: true,
                  isLoading: isLoading,
                  onTap: isLoading ? null : _handleAppleSignIn,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        HugeIcons.solidSharpApple,
                        color: Colors.white,
                      ),
                      5.w,
                      Text(
                        context.l10n.apple,
                        style: context.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              8.w,
            ],
            
            Expanded(
              child: SquircleBtn(
                isPrimary: true,
                isLoading: isLoading,
                onTap: isLoading ? null : _handleGoogleSignIn,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      HugeIcons.solidSharpGoogle,
                      color: Colors.white,
                    ),
                    5.w,
                    Text(
                      context.l10n.google,
                      style: context.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleGoogleSignIn() {
    context.authBloc.add(GoogleSignInRequested());
  }

  void _handleAppleSignIn() {
    context.authBloc.add(AppleSignInRequested());
  }
}