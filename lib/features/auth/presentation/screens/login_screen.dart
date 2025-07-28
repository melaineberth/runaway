import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/list_header.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
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
                  title: context.l10n.logIn,
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
      onTap: isLoading ? null : _handleSignIn,
      label: context.l10n.continueForms,
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
}
