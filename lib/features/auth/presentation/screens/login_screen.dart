import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/label_divider.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: false,
          body: Padding(
            padding: const EdgeInsets.all(20.0),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Forgot Password?",
                    style: context.bodySmall?.copyWith(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                15.h,
                _buildSignUpButton(),
                25.h,
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Create an account?',
                        style: context.bodySmall?.copyWith(
                          fontSize: 15,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: ' Sign up',
                        style: context.bodySmall?.copyWith(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = () => context.pushReplacement("/signup"),
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
    );
  }

  Widget _buildSignUpInfo() {
    return Column(
      children: [
        Text(
          "Hi there !",
          style: context.bodyLarge?.copyWith(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        10.h,
        Text(
          "Please enter required details.",
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

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      child: Expanded(
        child: SquircleContainer(
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