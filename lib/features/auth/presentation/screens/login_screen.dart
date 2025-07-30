import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/list_header.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/auth/data/services/auth_input_validator.dart';
import 'package:runaway/features/auth/data/services/brute_force_protection_service.dart';
import 'package:runaway/features/auth/data/services/security_logging_service.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:runaway/features/auth/presentation/widgets/forgot_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  final bool isLoading;

  const LoginScreen({
    super.key,
    required this.isLoading,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 🆕 Variables de sécurité
  bool _isAccountLocked = false;
  int _remainingLockoutMinutes = 0;
  int _remainingAttempts = 5;

  @override
  void initState() {
    super.initState();
    // 🆕 Vérifier l'état de sécurité au démarrage
    _checkSecurityStatus();
  }

  // 🆕 Vérification de l'état de sécurité
  Future<void> _checkSecurityStatus() async {
    final canAttempt = await BruteForceProtectionService.instance.canAttemptLogin();
    final lockoutMinutes = await BruteForceProtectionService.instance.getRemainingLockoutMinutes();
    final remainingAttempts = await BruteForceProtectionService.instance.getRemainingAttempts();
    
    if (mounted) {
      setState(() {
        _isAccountLocked = !canAttempt;
        _remainingLockoutMinutes = lockoutMinutes;
        _remainingAttempts = remainingAttempts;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog() {
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: ForgotPasswordDialog(),
    );
  }

  // 🆕 Validation d'email avec sécurité
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.requiredEmail;
    }
    
    final validationResult = AuthInputValidator.validateEmail(value);
    if (!validationResult.isValid) {
      // Logger l'entrée suspecte
      SecurityLoggingService.instance.logSuspiciousInput(
        inputType: 'email',
        reason: validationResult.errorMessage ?? 'format_invalid',
        email: value,
      );
      return validationResult.errorMessage;
    }
    
    return null;
  }

  // 🆕 Validation de mot de passe avec sécurité
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.requiredPassword;
    }
    
    final validationResult = AuthInputValidator.validatePassword(value);
    if (!validationResult.isValid) {
      // Logger l'entrée suspecte
      SecurityLoggingService.instance.logSuspiciousInput(
        inputType: 'password',
        reason: validationResult.errorMessage ?? 'format_invalid',
      );
      return validationResult.errorMessage;
    }
    
    return null;
  }
  
  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListHeader(
                  title: context.l10n.logIn,
                  subtitle: context.l10n.enterAuthDetails,
                ),

                // 🆕 Affichage des alertes de sécurité
                if (_isAccountLocked) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.red, size: 24),
                        8.h,
                        Text(
                          'Compte temporairement verrouillé',
                          style: context.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        4.h,
                        Text(
                          'Réessayez dans $_remainingLockoutMinutes minute${_remainingLockoutMinutes > 1 ? 's' : ''}',
                          style: context.bodySmall?.copyWith(
                            color: Colors.red.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  20.h,
                ] else if (_remainingAttempts < 5) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                        8.w,
                        Expanded(
                          child: Text(
                            'Attention: $_remainingAttempts tentative${_remainingAttempts > 1 ? 's' : ''} restante${_remainingAttempts > 1 ? 's' : ''}',
                            style: context.bodySmall?.copyWith(
                              color: Colors.orange.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  15.h,
                ],

                Column(
                  children: [
                    AuthTextField(
                      hint: context.l10n.emailHint,
                      validator: _validateEmail,
                      controller: _emailController,
                      enabled: !widget.isLoading && !_isAccountLocked,
                    ),

                    10.h,
                    
                    AuthTextField(
                      hint: context.l10n.passwordHint,
                      obscureText: true,
                      validator: _validatePassword,
                      controller: _passwordController,
                      enabled: !widget.isLoading && !_isAccountLocked,
                    ),

                    10.h,

                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: (widget.isLoading || _isAccountLocked) ? null : _showForgotPasswordDialog,
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
                20.h,
          
              _buildSignInButton(isLoading: widget.isLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton({required bool isLoading}) {
    return SquircleBtn(
      isPrimary: true,
      isLoading: isLoading,
      onTap: (isLoading || _isAccountLocked) ? null : _handleSignIn,
      label: context.l10n.continueForms,
    );
  }

  // Connexion avec sécurité
  Future<void> _handleSignIn() async {
    // Vérification de sécurité avant validation
    final canAttempt = await BruteForceProtectionService.instance.canAttemptLogin();
    if (!canAttempt) {
      await _checkSecurityStatus();
      return;
    }

    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      // Validation finale avec assainissement
      final emailValidation = AuthInputValidator.validateEmail(email);
      final passwordValidation = AuthInputValidator.validatePassword(password);
      
      if (!emailValidation.isValid || !passwordValidation.isValid) {
        SecurityLoggingService.instance.logSuspiciousInput(
          inputType: 'login_form',
          reason: 'validation_failed',
          email: email,
        );
        return;
      }

      // Logger la tentative de connexion
      SecurityLoggingService.instance.logLoginAttempt(
        email: emailValidation.sanitizedValue!,
        success: false, // Sera mis à jour par le bloc en cas de succès
        reason: 'attempt_started',
      );

      // Déclencher la connexion avec valeurs assainies
      if (mounted) {
        context.authBloc.add(
          LogInRequested(
            email: emailValidation.sanitizedValue!,
            password: passwordValidation.sanitizedValue!,
          ),
        );
      }
    }
  }
}
