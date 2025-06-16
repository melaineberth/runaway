import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
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
                    LabelDivider(),
                    20.h,
                    AuthTextField(
                      hint: "Email adress",
                      validator: emailValidator,
                      controller: _emailController,
                    ),
                    15.h,
                    AuthTextField(
                      hint: "Password",
                      obscureText: true,
                      validator: passwordValidator,
                      controller: _passwordController,
                    ),
                    15.h,
                    AuthTextField(
                      hint: "Confirm password",
                      obscureText: true,
                      validator: (v) =>v == _passwordController.text ? null : 'Les mots de passe ne correspondent pas',
                      controller: _confirmPasswordController,
                    ),
                    15.h,
                    _buildSignUpButton(
                      onTap: () {
                        if (_formKey.currentState!.validate()) {
                          context.read<AuthBloc>().add(
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
                            text: 'Have an account?',
                            style: context.bodySmall?.copyWith(
                              fontSize: 15,
                              color: Colors.white54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: ' Log in',
                            style: context.bodySmall?.copyWith(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: TapGestureRecognizer()..onTap = () => context.pushReplacement("/login"),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "Terms of Service | Privacy Policy", 
                      style: context.bodySmall?.copyWith(
                        fontSize: 15,
                        color: Colors.white24,
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
                  color: Colors.white,
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
          "Create an account",
          style: context.bodyLarge?.copyWith(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        10.h,
        Text(
          "To create an account provide details verify email and set a password.",
          style: context.bodyMedium?.copyWith(
            color: Colors.white,
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
      child: Expanded(
        child: SquircleContainer(
          onTap: onTap,
          height: 60,
          color: AppColors.primary,
          radius: 30,
          padding: EdgeInsets.symmetric(
            horizontal: 15.0,
            vertical: 5.0,
          ),
          child: Center(
            child: Text(
              "Continue",
              style: context.bodySmall?.copyWith(
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton() {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: SquircleContainer(
              height: 60,
              color: AppColors.primary,
              radius: 30,
              padding: EdgeInsets.symmetric(
                horizontal: 15.0,
                vertical: 5.0,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(HugeIcons.solidSharpApple),
                    5.w,
                    Text(
                      "Apple",
                      style: context.bodySmall?.copyWith(
                        color: Colors.black,
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
              height: 60,
              color: AppColors.primary,
              radius: 30,
              padding: EdgeInsets.symmetric(
                horizontal: 15.0,
                vertical: 5.0,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(HugeIcons.solidSharpGoogle),
                    5.w,
                    Text(
                      "Google",
                      style: context.bodySmall?.copyWith(
                        color: Colors.black,
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
  }
}



