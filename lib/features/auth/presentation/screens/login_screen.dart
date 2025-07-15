import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/label_divider.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:runaway/features/auth/presentation/widgets/forgot_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onSwitchToSignup;
  final bool isLoading;

  const LoginScreen({
    super.key,
    required this.onSwitchToSignup,
    required this.isLoading,
  });

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

  void _showForgotPasswordDialog() {
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: ForgotPasswordDialog(),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        _buildSignInInfo(),
        40.h,
        _buildSocialButtons(),
        30.h,
        LabelDivider(),
        30.h,
        Form(
          key: _formKey,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                20.h,
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: widget.isLoading ? null : _showForgotPasswordDialog,
                    child: Text(
                      context.l10n.forgotPassword,
                      style: context.bodySmall?.copyWith(
                        fontSize: 14,
                        color: context.adaptiveTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        20.h,
        _buildSignInButton(),
        const Spacer(),
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
                recognizer: TapGestureRecognizer()..onTap = widget.onSwitchToSignup,
              ),
            ],
          ),
        ),
        10.h,
      ],
    );
  }

  Widget _buildSignInInfo() {
    return Column(
      children: [
        Text(
          context.l10n.loginGreetingTitle,
          style: context.bodyMedium?.copyWith(
            fontSize: 22,
            color: context.adaptiveTextPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        12.h,
        Text(
          context.l10n.loginGreetingSubtitle,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextSecondary,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSignInButton() {
    return SquircleBtn(
      isPrimary: true,
      isLoading: widget.isLoading,
      onTap: widget.isLoading ? null : _handleSignIn,
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
