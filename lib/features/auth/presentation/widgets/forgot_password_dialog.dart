import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as su;
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
      return context.l10n.requiredEmail;
    }
    if (!value.contains('@')) {
      return context.l10n.emailInvalid;
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    try {
      // Appeler la fonction RPC pour vérifier l'éligibilité
      final response = await su.Supabase.instance.client
          .rpc('check_password_reset_eligibility', params: {
        'user_email': email,
      });

      if (mounted) {
        final result = response as Map<String, dynamic>;
        final userExists = result['user_exists'] as bool;
        final canResetPassword = result['can_reset_password'] as bool;

        if (!userExists) {
          // Utilisateur non trouvé
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              isWarning: true,
              title: context.l10n.notEmailFound,
            ),
          );
        } else if (!canResetPassword) {
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              isWarning: true,
              title: context.l10n.resetPasswordImpossible,
            ),
          );
        } else {
          // L'utilisateur peut réinitialiser son mot de passe
          
        }
      }
    } catch (e, stack) {
      // En cas d'erreur réseau ou autre
      debugPrint('Erreur lors de la vérification du profil : $e\n$stack');
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            isError: true,
            title: context.l10n.genericErrorRetry,
          ),
        );
      }
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
              title: context.l10n.resetEmail(state.email),
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
                  context.l10n.forgotPassword,
                  style: context.bodyMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                16.h,
                Text(
                  context.l10n.receiveResetLink,
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
                            label: context.l10n.cancel,
                          ),
                        ),
                        8.w,
                        Expanded(
                          child: SquircleBtn(
                            isPrimary: true,
                            isLoading: isLoading,
                            onTap: isLoading ? null : _handleSubmit,
                            label: context.l10n.send,
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