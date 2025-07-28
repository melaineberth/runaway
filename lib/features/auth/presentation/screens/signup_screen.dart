import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/list_header.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:runaway/features/auth/presentation/widgets/password_strength_indicator.dart';

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

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {
      _showPasswordStrength = _passwordController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? emailValidator(String? v) => v != null && v.contains('@') ? null : context.l10n.emailInvalid;

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
              Column(
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
                    bottom: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: (_passwordController.text.isNotEmpty)
                      ? PasswordStrengthIndicator(
                          password: _passwordController.text,
                          isVisible: _showPasswordStrength,
                        )
                      : null
                  ),
                  ),
                  10.h,
                  AuthTextField(
                    hint: context.l10n.confirmPasswordHint,
                    obscureText: true,
                    validator: (v) => v == _passwordController.text 
                        ? null 
                        : context.l10n.passwordsDontMatchError,
                    controller: _confirmPasswordController,
                    enabled: !widget.isLoading,
                  ),
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
      onTap: isLoading ? null : _handleSignUp,
      label: context.l10n.continueForms,
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
}