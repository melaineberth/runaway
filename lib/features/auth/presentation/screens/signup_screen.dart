import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/label_divider.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onSwitchToLogin;
  final bool isLoading;

  const SignupScreen({
    super.key,
    required this.onSwitchToLogin,
    required this.isLoading,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? emailValidator(String? v) => v != null && v.contains('@') ? null : context.l10n.emailInvalid;
  String? passwordValidator(String? v) => (v?.length ?? 0) >= 6 ? null : context.l10n.passwordMinLength;
  
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          _buildSignUpInfo(),
          40.h,
          _buildSocialButtons(),
          30.h,
          LabelDivider(
            label: context.l10n.orDivider,
          ),
          30.h,
          AuthTextField(
            hint: context.l10n.emailHint,
            validator: emailValidator,
            controller: _emailController,
            enabled: !widget.isLoading,
          ),
          10.h,
          AuthTextField(
            hint: context.l10n.passwordHint,
            obscureText: true,
            validator: passwordValidator,
            controller: _passwordController,
            enabled: !widget.isLoading,
          ),
          10.h,
          AuthTextField(
            hint: context.l10n.confirmPasswordHint,
            obscureText: true,
            validator: (v) => v == _passwordController.text ? null : context.l10n.passwordsDontMatchError,
            controller: _confirmPasswordController,
            enabled: !widget.isLoading,
          ),
          10.h,
          _buildSignUpButton(),
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
                  recognizer: TapGestureRecognizer()..onTap = widget.onSwitchToLogin,
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
        ],
      ),
    );
  }

  Widget _buildSignUpInfo() {
    return Column(
      children: [
        Text(
          context.l10n.createAccountTitle,
          style: context.bodyMedium?.copyWith(
            fontSize: 22,
            color: context.adaptiveTextPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        12.h,
        Text(
          context.l10n.createAccountSubtitle,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextSecondary,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return SquircleBtn(
      isPrimary: true,
      isLoading: widget.isLoading,
      onTap: widget.isLoading ? null : _handleSignUp,
      label: context.l10n.continueForms,
    );
  }

  Widget _buildSocialButtons() {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: SquircleBtn(
              isPrimary: true,
              isLoading: widget.isLoading,
              onTap: widget.isLoading ? null : _handleAppleSignIn,
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
          Expanded(
            child: SquircleBtn(
              isPrimary: true,
              isLoading: widget.isLoading,
              onTap: widget.isLoading ? null : _handleGoogleSignIn,
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
    );
  }

  void _handleSignUp() {
    if (_formKey.currentState!.validate()) {
      context.authBloc.add(
        SignUpBasicRequested(
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