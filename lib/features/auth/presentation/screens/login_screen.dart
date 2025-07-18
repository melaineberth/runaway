import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:runaway/features/auth/presentation/widgets/forgot_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  final bool isLoading;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? Function(String?)? emailValidator;
  final String? Function(String?)? passwordValidator;

  const LoginScreen({
    super.key,
    required this.isLoading,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.emailValidator,
    required this.passwordValidator,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  void _showForgotPasswordDialog() {
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: ForgotPasswordDialog(),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                AuthTextField(
                  hint: context.l10n.emailHint,
                  validator: widget.emailValidator,
                  controller: widget.emailController,
                  enabled: !widget.isLoading,
                ),
                10.h,
                AuthTextField(
                  hint: context.l10n.passwordHint,
                  obscureText: true,
                  validator: widget.passwordValidator,
                  controller: widget.passwordController,
                  enabled: !widget.isLoading,
                ),
                10.h,
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
            10.h,
        
            _buildSignInButton(isLoading: widget.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInButton({required bool isLoading}) {
    return SquircleBtn(
      isPrimary: true,
      isLoading: isLoading,
      onTap: isLoading ? null : _handleSignIn,
      label: context.l10n.continueForms,
    );
  }

  void _handleSignIn() {
    if (widget.formKey.currentState!.validate()) {
      context.authBloc.add(
        LogInRequested(
          email: widget.emailController.text.trim(),
          password: widget.passwordController.text,
        ),
      );
    }
  }
}
