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

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String? emailValidator(String? v) => v != null && v.contains('@') ? null : context.l10n.emailInvalid;

  String? passwordValidator(String? v) => (v?.length ?? 0) >= 6 ? null : context.l10n.passwordMinLength;
  
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is ProfileIncomplete) {
          // ✔ inscription réussie ⇒ on passe à l’écran d’accueil
          context.go('/onboarding');
        } else if (authState is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authState.message)),
          );
        }
      },
      child: Stack(
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
                    LabelDivider(
                      label: context.l10n.orDivider,
                    ),
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
                    AuthTextField(
                      hint: context.l10n.confirmPasswordHint,
                      obscureText: true,
                      validator: (v) =>v == _passwordController.text ? null : context.l10n.passwordsDontMatchError,
                      controller: _confirmPasswordController,
                    ),
                    15.h,
                    _buildSignUpButton(
                      onTap: () {
                        if (_formKey.currentState!.validate()) {
                          context.authBloc.add(
                            SignUpBasicRequested(
                              email: _emailController.text.trim(),
                              password: _passwordController.text, 
                            ),
                          );
                        }
                      },
                    ),
                    25.h,
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: context.l10n.haveAccount,
                            style: context.bodySmall?.copyWith(
                              fontSize: 15,
                              color: context.adaptiveTextPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: ' ${context.l10n.logIn}',
                            style: context.bodySmall?.copyWith(
                              fontSize: 15,
                              color: context.adaptivePrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: TapGestureRecognizer()..onTap = () => context.pushReplacement("/login"),
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
                onTap: () => context.pop(),
                child: Icon(
                  HugeIcons.solidRoundedCancelCircle,
                  color: context.adaptiveTextPrimary,
                  size: 25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpInfo() {
    return Column(
      children: [
        Text(
          context.l10n.createAccount,
          style: context.bodyLarge?.copyWith(
            color: context.adaptiveTextPrimary,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        10.h,
        Text(
          context.l10n.createAccountSubtitle,
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

  Widget _buildSignUpButton({required Function()? onTap}) {
    return SizedBox(
      width: double.infinity,
      child: SquircleContainer(
        onTap: onTap,
        height: 60,
        color: context.adaptivePrimary,
        radius: 30,
        padding: EdgeInsets.symmetric(
          horizontal: 15.0,
          vertical: 5.0,
        ),
        child: Center(
          child: Text(
            context.l10n.continueForms,
            style: context.bodySmall?.copyWith(
              color: Colors.white,
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

  void _handleGoogleSignIn() {
    context.authBloc.add(GoogleSignInRequested());
  }

  void _handleAppleSignIn() {
    context.authBloc.add(AppleSignInRequested());
  }
}



