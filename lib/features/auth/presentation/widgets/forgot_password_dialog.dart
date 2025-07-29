import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/connectivity_helper.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/widgets/list_header.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/screens/password_reset_success_screen.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:runaway/features/auth/presentation/widgets/password_strength_indicator.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

enum ForgotPasswordStep {
  email,
  code,
  newPassword,
}

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Variables pour l'indicateur de force
  bool _showPasswordStrength = false;
  
  ForgotPasswordStep _currentStep = ForgotPasswordStep.email;
  String? _email;
  String? _verifiedCode;

  // Ajouter ces variables d'état en haut de la classe _ForgotPasswordDialogState
  bool _codeVerifying = false;
  String? _codeError;
  bool _showRetryOption = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      _showPasswordStrength = _passwordController.text.isNotEmpty;
    });
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

  String? codeValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.codeRequired;
    }
    if (value.length != 6 || !RegExp(r'^\d{6}$').hasMatch(value)) {
      return context.l10n.codeMustBe6Digits;
    }
    return null;
  }

  // 🆕 Modifier la validation du mot de passe pour inclure toutes les exigences
  String? passwordValidator(String? v) {
    if (v == null || v.isEmpty) {
      return context.l10n.requiredPassword;
    }
    
    if (v.length < 8) {
      return context.l10n.requiredCountCharacters(8);
    }
    
    if (!v.contains(RegExp(r'[A-Z]'))) {
      return context.l10n.requiredCapitalLetter;
    }
    
    if (!v.contains(RegExp(r'[a-z]'))) {
      return context.l10n.requiredMinusculeLetter;
    }
    
    if (!v.contains(RegExp(r'[0-9]'))) {
      return context.l10n.requiredDigit;
    }
    
    if (!v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return context.l10n.requiredSymbol;
    }
    
    return null;
  }

  void _handleSubmit() {
    // Vérifier la connexion avant la connexion Apple
    if (!ConnectivityHelper.checkConnectionAndShowModal(context)) {
      return;
    }
    
    if (!(_formKey.currentState?.validate() ?? false)) return;

    switch (_currentStep) {
      case ForgotPasswordStep.email:
        _sendResetCode();
        break;
      case ForgotPasswordStep.code:
        _verifyCode();
        break;
      case ForgotPasswordStep.newPassword:
        _resetPassword();
        break;
    }
  }

  void _sendResetCode() {
    final email = _emailController.text.trim();
    _email = email;
    context.read<AuthBloc>().add(ForgotPasswordRequested(email: email));
  }

  void _verifyCode() {
    final code = _codeController.text.trim();
    
    // Validation locale d'abord
    if (code.isEmpty) {
      setState(() {
        _codeError = context.l10n.codeRequired;
      });
      return;
    }
    
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _codeError = context.l10n.codeMustBe6Digits;
      });
      return;
    }
    
    setState(() {
      _codeError = null;
      _codeVerifying = true;
    });
    
    context.read<AuthBloc>().add(
      VerifyPasswordResetCodeRequested(email: _email!, code: code)
    );
  }

  void _resetPassword() {
    final newPassword = _passwordController.text.trim();
    context.read<AuthBloc>().add(
      ResetPasswordRequested(
        email: _email!,
        code: _verifiedCode!,
        newPassword: newPassword,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is PasswordResetCodeSent) {
          setState(() {
            _currentStep = ForgotPasswordStep.code;
            _codeVerifying = false;
            _showRetryOption = false; // Reset option retry
          });
        } else if (state is PasswordResetCodeVerified) {
          setState(() {
            _currentStep = ForgotPasswordStep.newPassword;
            _verifiedCode = state.verifiedCode;
            _codeVerifying = false;
            _showRetryOption = false;
          });
        } else if (state is PasswordResetSuccess) {
          context.pop();

          showModalSheet(
            context: context, 
            backgroundColor: Colors.transparent,
            child: PasswordResetSuccessScreen(),
          );
        } else if (state is AuthError) {
          setState(() {
            _codeVerifying = false;
            // 🆕 Afficher l'option retry si le code est expiré
            _showRetryOption = state.message.contains('expiré') || state.message.contains('expired');
          });
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              isWarning: true,
              title: state.message,
            ),
          );
        }
      },
      child: ModalSheet(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                _buildCurrentStepContent(),
                20.h,
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    String subtitle;

    switch (_currentStep) {
      case ForgotPasswordStep.email:
        title = context.l10n.forgotPassword;
        subtitle = context.l10n.enterEmailToReset;
        break;
      case ForgotPasswordStep.code:
        title = context.l10n.enterVerificationCode;
        subtitle = context.l10n.verificationCodeSentTo(_email ?? '');
        break;
      case ForgotPasswordStep.newPassword:
        title = context.l10n.enterNewPassword;
        subtitle = context.l10n.createNewPassword;
        break;
    }

    return ListHeader(
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case ForgotPasswordStep.email:
        return AuthTextField(
          hint: context.l10n.emailHint,
          validator: emailValidator,
          controller: _emailController,
        );
      case ForgotPasswordStep.code:
        return Column(
          children: [
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: context.bodyMedium?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                hintStyle: context.bodyMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 8,
                  color: context.adaptiveTextSecondary.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: context.adaptiveTextSecondary.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.adaptivePrimary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.colorScheme.error,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                // Effacer l'erreur quand l'utilisateur tape
                if (_codeError != null) {
                  setState(() {
                    _codeError = null;
                  });
                }
              },
            ),
            if (_codeVerifying) ...[
              8.h,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.adaptivePrimary,
                      ),
                    ),
                  ),
                  8.w,
                  Text(
                    context.l10n.verfyPasswordInProgress,
                    style: context.bodySmall?.copyWith(
                      color: context.adaptiveTextSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                
              ),
            ],
            10.h,
            // 🆕 Option pour redemander un code si expiré
            if (_showRetryOption) ...[
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentStep = ForgotPasswordStep.email;
                    _showRetryOption = false;
                    _codeController.clear();
                  });
                },
                child: Text(
                  context.l10n.requestNewCode,
                  style: context.bodySmall?.copyWith(
                    color: context.adaptivePrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              5.h,
            ],
          ],
        );
      case ForgotPasswordStep.newPassword:
        return AuthTextField(
          hint: context.l10n.passwordHint,
          obscureText: true,
          validator: passwordValidator,
          controller: _passwordController,
          bottom: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: (_passwordController.text.isNotEmpty)
            ? PasswordStrengthIndicator(
                password: _passwordController.text,
                isVisible: _showPasswordStrength,
              )
            : null
          ),
        );
    }
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        
        String buttonText;
        switch (_currentStep) {
          case ForgotPasswordStep.email:
            buttonText = context.l10n.sendResetCode;
            break;
          case ForgotPasswordStep.code:
            buttonText = context.l10n.verify;
            break;
          case ForgotPasswordStep.newPassword:
            buttonText = context.l10n.updatePassword;
            break;
        }
        
        return SquircleBtn(
          isPrimary: true,
          isLoading: isLoading,
          onTap: isLoading ? null : _handleSubmit,
          label: buttonText,
        );
      },
    );
  }
}