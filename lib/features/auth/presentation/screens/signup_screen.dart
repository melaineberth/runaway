import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/list_header.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/auth/data/services/auth_input_validator.dart';
import 'package:runaway/features/auth/data/services/brute_force_protection_service.dart';
import 'package:runaway/features/auth/data/services/security_logging_service.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:runaway/features/auth/presentation/widgets/password_strength_indicator.dart' hide PasswordStrength;

class SignupScreen extends StatefulWidget {
  final bool isLoading;

  const SignupScreen({
    super.key,
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

  // Variables pour l'indicateur de force
  bool _showPasswordStrength = false;
  PasswordStrength _passwordStrength = PasswordStrength.weak;
  bool _isAccountLocked = false;
  int _remainingLockoutMinutes = 0;

  @override
  void initState() {
    super.initState();
    // 🆕 Vérifier l'état de sécurité au démarrage
    _checkSecurityStatus();
    
    // 🆕 Écouter les changements de mot de passe pour la force
    _passwordController.addListener(_onPasswordChanged);
  }

  // 🆕 Vérification de l'état de sécurité
  Future<void> _checkSecurityStatus() async {
    final canAttempt = await BruteForceProtectionService.instance.canAttemptLogin();
    final lockoutMinutes = await BruteForceProtectionService.instance.getRemainingLockoutMinutes();
    
    if (mounted) {
      setState(() {
        _isAccountLocked = !canAttempt;
        _remainingLockoutMinutes = lockoutMinutes;
      });
    }
  }

  // 🆕 Gestion des changements de mot de passe
  void _onPasswordChanged() {
    final password = _passwordController.text;
    final strength = AuthInputValidator.evaluatePasswordStrength(password);
    
    setState(() {
      _showPasswordStrength = password.isNotEmpty;
      _passwordStrength = strength;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  // 🆕 Validation de confirmation de mot de passe
  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return context.l10n.passwordsDontMatchError;
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
                title: context.l10n.signUp,
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
                        'Inscription temporairement suspendue',
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
                    bottom: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _showPasswordStrength 
                      ? PasswordStrengthIndicator(
                          password: _passwordController.text,
                          isVisible: _showPasswordStrength,
                        )
                      : null,
                    ),
                  ),
                  10.h,
                  AuthTextField(
                    hint: context.l10n.confirmPasswordHint,
                    obscureText: true,
                    validator: _validateConfirmPassword,
                    controller: _confirmPasswordController,
                    enabled: !widget.isLoading && !_isAccountLocked,
                  ),

                  // 🆕 Conseils de sécurité pour le mot de passe
                  if (_showPasswordStrength) ...[
                    10.h,
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getPasswordStrengthColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _getPasswordStrengthColor().withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getPasswordStrengthIcon(),
                                color: _getPasswordStrengthColor(),
                                size: 16,
                              ),
                              8.w,
                              Text(
                                _getPasswordStrengthText(),
                                style: context.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: _getPasswordStrengthColor(),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (_passwordStrength == PasswordStrength.weak) ...[
                            4.h,
                            Text(
                              'Recommandations: 8+ caractères, majuscules, minuscules, chiffres et symboles',
                              style: context.bodySmall?.copyWith(
                                color: context.adaptiveTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              10.h,
          
              _buildSignUpButton(isLoading: widget.isLoading),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSignUpButton({required bool isLoading}) {
    return SquircleBtn(
      isPrimary: true,
      isLoading: isLoading,
      onTap: (isLoading || _isAccountLocked) ? null : _handleSignUp,
      label: context.l10n.continueForms,
    );
  }

  // 🆕 Gestion améliorée de l'inscription avec sécurité
  Future<void> _handleSignUp() async {
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
          inputType: 'signup_form',
          reason: 'validation_failed',
          email: email,
        );
        return;
      }

      // Logger la tentative d'inscription
      SecurityLoggingService.instance.logSignUpAttempt(
        email: emailValidation.sanitizedValue!,
        success: false, // Sera mis à jour par le bloc en cas de succès
        reason: 'attempt_started',
      );

      // Déclencher l'inscription avec valeurs assainies
      if (mounted) {
        context.authBloc.add(
          SignUpBasicRequested(
            email: emailValidation.sanitizedValue!,
            password: passwordValidation.sanitizedValue!,
          ),
        );
      }
    }
  }

  // 🆕 Helpers pour l'indicateur de force de mot de passe
  Color _getPasswordStrengthColor() {
    switch (_passwordStrength) {
      case PasswordStrength.weak:
        return Colors.red;
      case PasswordStrength.medium:
        return Colors.orange;
      case PasswordStrength.strong:
        return Colors.green;
    }
  }

  IconData _getPasswordStrengthIcon() {
    switch (_passwordStrength) {
      case PasswordStrength.weak:
        return Icons.security;
      case PasswordStrength.medium:
        return Icons.security_outlined;
      case PasswordStrength.strong:
        return Icons.verified_user;
    }
  }

  String _getPasswordStrengthText() {
    switch (_passwordStrength) {
      case PasswordStrength.weak:
        return 'Mot de passe faible';
      case PasswordStrength.medium:
        return 'Mot de passe moyen';
      case PasswordStrength.strong:
        return 'Mot de passe fort';
    }
  }
}