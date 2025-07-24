import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';

class PasswordResetCodeDialog extends StatefulWidget {
  final String email;
  
  const PasswordResetCodeDialog({
    super.key,
    required this.email,
  });

  @override
  State<PasswordResetCodeDialog> createState() => _PasswordResetCodeDialogState();
}

class _PasswordResetCodeDialogState extends State<PasswordResetCodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? codeValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez saisir le code de réinitialisation';
    }
    if (value.trim().length != 6) {
      return 'Le code doit contenir exactement 6 chiffres';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Le code doit contenir uniquement des chiffres';
    }
    return null;
  }

  String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.requiredPassword;
    }
    if (value.length < 8) {
      return context.l10n.passwordTooShort;
    }
    return null;
  }

  String? confirmPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.requiredPassword;
    }
    if (value != _passwordController.text) {
      return context.l10n.passwordsDontMatchError;
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final code = _codeController.text.trim();
    final newPassword = _passwordController.text;

    context.authBloc.add(
      ResetPasswordWithOTPRequested(
        email: widget.email,
        otp: code,
        newPassword: newPassword,
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null) {
        _codeController.text = clipboardData!.text!;
      }
    } catch (e) {
      // Ignore clipboard errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Vérifiez vos emails et copiez le code de réinitialisation envoyé à ${widget.email}',
                style: context.theme.textTheme.bodyMedium?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Champ code avec bouton coller
              Row(
                children: [
                  Expanded(
                    child: AuthTextField(
                      controller: _codeController,
                      hint: 'Code à 6 chiffres',
                      validator: codeValidator,
                      keyboardType: TextInputType.number,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.paste),
                    tooltip: 'Coller',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Nouveau mot de passe
              AuthTextField(
                controller: _passwordController,
                hint: context.l10n.passwordHint,
                obscureText: true,
                validator: passwordValidator,
              ),
              const SizedBox(height: 16),
              
              // Confirmation mot de passe
              AuthTextField(
                controller: _confirmPasswordController,
                hint: context.l10n.confirmPasswordHint,
                obscureText: true,
                validator: confirmPasswordValidator,
              ),
              const SizedBox(height: 24),
              
              // Bouton de validation
              SquircleBtn(
                onTap: _handleSubmit,
                child: Text(context.l10n.continueForms),
              ),
            ],
          ),
        ),
      ),
    );
  }
}