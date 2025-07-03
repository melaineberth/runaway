import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/label_divider.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? emailValidator(String? v) => v != null && v.contains('@') ? null : context.l10n.emailInvalid;

  String? passwordValidator(String? v) => (v?.length ?? 0) >= 6 ? null : context.l10n.passwordMinLength;
  
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
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final isLoading = authState is AuthLoading;
          
          return Stack(
            children: [
              Scaffold(
                resizeToAvoidBottomInset: false,
                body: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(),
                        _buildSignUpInfo(),
                        40.h,
                        _buildSocialButton(),
                        20.h,
                        LabelDivider(),
                        20.h,
                        AuthTextField(
                          hint: context.l10n.emailHint,
                          validator: emailValidator,
                          controller: _emailController,
                        ),
                        15.h,
                        AuthTextField(
                          hint: context.l10n.passwordHint,
                          obscureText: true,
                          validator: passwordValidator,
                          controller: _passwordController,
                        ),
                        15.h,
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            context.l10n.forgotPassword,
                            style: context.bodySmall?.copyWith(
                              fontSize: 14,
                              color: context.adaptiveTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        15.h,
                        _buildSignInButton(isLoading),
                        25.h,
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: context.l10n.createAccountQuestion,
                                style: context.bodySmall?.copyWith(
                                  fontSize: 15,
                                  color: context.adaptiveTextPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: ' ${context.l10n.signUp}',
                                style: context.bodySmall?.copyWith(
                                  fontSize: 15,
                                  color: context.adaptivePrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                recognizer: TapGestureRecognizer()..onTap = () => context.pushReplacement("/signup"),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          context.l10n.termsAndPrivacy, 
                          style: context.bodySmall?.copyWith(
                            fontSize: 15,
                            color: context.adaptiveTextSecondary,
                          ),
                        ),
                        15.h,
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                top: kToolbarHeight,
                right: 5,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: GestureDetector(
                    onTap: () {
                      if (!isLoading) {
                        context.pop();
                      }
                    },
                    child: Icon(
                      HugeIcons.solidRoundedCancelCircle,
                      color: context.adaptiveTextPrimary,
                      size: 25,
                    ),
                  ),
                ),
              ),

              // Overlay de chargement
              if (isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(context.adaptivePrimary),
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildSignUpInfo() {
    return Column(
      children: [
        Text(
          context.l10n.loginGreetingTitle,
          style: context.bodyLarge?.copyWith(
            color: context.adaptiveTextPrimary,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        10.h,
        Text(
          context.l10n.loginGreetingSubtitle,
          style: context.bodyMedium?.copyWith(
            color: context.adaptiveTextSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 17,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSignInButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: SquircleContainer(
        onTap: isLoading ? null : _handleSignIn,
        height: 60,
        color: context.adaptivePrimary,
        radius: 30,
        padding: EdgeInsets.symmetric(
          horizontal: 15.0,
          vertical: 5.0,
        ),
        child: Center(
          child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                context.l10n.continueForms,
                style: context.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildSocialButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isLoading = authState is AuthLoading;
        
        return SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: SquircleContainer(
                  onTap: isLoading ? null : _handleAppleSignIn,
                  height: 60,
                  color: isLoading ? context.adaptivePrimary.withValues(alpha: 0.5) : context.adaptivePrimary,
                  radius: 30,
                  padding: EdgeInsets.symmetric(
                    horizontal: 15.0,
                    vertical: 5.0,
                  ),
                  child: Center(
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
              ),
              10.w,
              Expanded(
                child: SquircleContainer(
                  onTap: isLoading ? null : _handleGoogleSignIn,
                  height: 60,
                  color: isLoading ? context.adaptivePrimary.withValues(alpha: 0.5) : context.adaptivePrimary,
                  radius: 30,
                  padding: EdgeInsets.symmetric(
                    horizontal: 15.0,
                    vertical: 5.0,
                  ),
                  child: Center(
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
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleSignIn() {
    if (_formKey.currentState!.validate()) {
      context.authBloc.add(
        LogInRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  void _handleGoogleSignIn() {
    context.authBloc.add(GoogleSignInRequested());
  }

  void _handleAppleSignIn() {
    context.authBloc.add(AppleSignInRequested());
  }
}