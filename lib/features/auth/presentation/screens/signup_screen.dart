import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:runaway/features/auth/presentation/widgets/password_strength_indicator.dart';

class SignupScreen extends StatefulWidget {
  final bool isLoading;
  final bool passwordStrength;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final String? Function(String?)? emailValidator;
  final String? Function(String?)? passwordValidator;

  const SignupScreen({
    super.key,
    required this.isLoading,
    required this.passwordStrength,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.emailValidator,
    required this.passwordValidator,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {

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
                // 🆕 Ajouter l'indicateur de force
                PasswordStrengthIndicator(
                  password: widget.passwordController.text,
                  isVisible: widget.passwordStrength,
                ),
                10.h,
                AuthTextField(
                  hint: context.l10n.confirmPasswordHint,
                  obscureText: true,
                  validator: (v) => v == widget.passwordController.text 
                      ? null 
                      : context.l10n.passwordsDontMatchError,
                  controller: widget.confirmPasswordController,
                  enabled: !widget.isLoading,
                ),
              ],
            ),
            10.h,
        
            _buildSignUpButton(isLoading: widget.isLoading),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSignUpButton({required bool isLoading}) {
    return SquircleBtn(
      isPrimary: true,
      isLoading: isLoading,
      onTap: isLoading ? null : _handleSignUp,
      label: context.l10n.continueForms,
    );
  }

  void _handleSignUp() {
    if (widget.formKey.currentState!.validate()) {
      context.authBloc.add(
        SignUpBasicRequested(
          email: widget.emailController.text.trim(),
          password: widget.passwordController.text, 
        ),
      );
    }
  }
}