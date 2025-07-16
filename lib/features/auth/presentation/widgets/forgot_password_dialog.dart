import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email requis';
    }
    if (!value.contains('@')) {
      return 'Format d\'email invalide';
    }
    return null;
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.authBloc.add(ForgotPasswordRequested(email: _emailController.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is PasswordResetSent) {
          Navigator.of(context).pop();
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              title: 'Email de réinitialisation envoyé à ${state.email}',
            ),
          );
        } else if (state is AuthError) {
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              isError: true,
              title: state.message,
            ),
          );
        }
      },
      child: ModalSheet(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mot de passe oublié',
                  style: context.bodyMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                16.h,
                Text(
                  'Entrez votre adresse email pour recevoir un lien de réinitialisation',
                  style: context.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                24.h,
                AuthTextField(
                  hint: context.l10n.emailHint,
                  validator: emailValidator,
                  controller: _emailController,
                  enabled: true,
                ),
                8.h,
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return Row(
                      children: [
                        Expanded(
                          child: SquircleBtn(
                            isPrimary: false,
                            onTap: isLoading ? null : () => Navigator.of(context).pop(),
                            label: 'Annuler',
                          ),
                        ),
                        8.w,
                        Expanded(
                          child: SquircleBtn(
                            isPrimary: true,
                            isLoading: isLoading,
                            onTap: isLoading ? null : _handleSubmit,
                            label: 'Envoyer',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}