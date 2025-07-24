import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class EmailConfirmationScreen extends StatefulWidget {
  final String email;
  
  const EmailConfirmationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailConfirmationScreen> createState() => _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  bool _canResend = false; // Commencer par false
  int _cooldownSeconds = 30; // Commencer avec 30 secondes
  bool _isResending = false;

  // 🆕 Controllers pour OTP
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  String? _otpError;

  @override
  void initState() {
    super.initState();
    // Démarrer le timer automatiquement dès l'arrivée sur l'écran
    _startCooldown();
  }

  void _startCooldown() {
    setState(() {
      _canResend = false;
      _cooldownSeconds = 30;
    });
    _countdown();
  }

  void _countdown() {
    if (_cooldownSeconds > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _cooldownSeconds--;
          });
          _countdown();
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    }
  }

  // void _resendEmail() {
  //   if (_canResend && !_isResending) {
  //     setState(() {
  //       _isResending = true;
  //     });
      
  //     context.authBloc.add(ResendConfirmationRequested(email: widget.email));
  //   }
  // }

  // Validation et vérification OTP
  void _verifyOTP() {
    final otp = _otpController.text.trim();
    
    // Validation
    if (otp.isEmpty) {
      setState(() {
        _otpError = context.l10n.codeRequired;
      });
      return;
    }
    
    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() {
        _otpError = context.l10n.codeMustBe6Digits;
      });
      return;
    }
    
    setState(() {
      _otpError = null;
    });
    
    // Déclencher la vérification
    context.authBloc.add(VerifyOTPRequested(email: widget.email, otp: otp));
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is ProfileIncomplete) {
          // Email confirmé, aller vers l'onboarding
          context.go('/onboarding');
        } else if (state is Authenticated) {
          // Connexion complète
          context.go('/home');
        } else if (state is EmailConfirmationRequired) {
          // Email renvoyé avec succès
          if (_isResending) {
            setState(() {
              _isResending = false;
            });

            showTopSnackBar(
              Overlay.of(context),
              TopSnackBar(
                title: context.l10n.successEmailSentBack,
              ),
            );
            
            // Redémarrer le timer
            _startCooldown();
          }
        } else if (state is AuthError) {
          if (_isResending) {
            setState(() {
              _isResending = false;
            });
          }

          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              isError: true,
              title: state.message,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: context.adaptiveBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/login'),
                      icon: Icon(HugeIcons.strokeStandardArrowLeft02),
                    ),
                  ],
                ),
                const Spacer(),
                _buildEmailIcon(),
                32.h,
                _buildTitle(),
                16.h,
                _buildSubtitle(),
                32.h,
                _buildOTPField(),
                16.h,
                _buildVerifyButton(),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: context.adaptivePrimary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        HugeIcons.strokeRoundedMail01,
        size: 40,
        color: context.adaptivePrimary,
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      context.l10n.checkEmail,
      style: context.bodyMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: context.adaptiveTextPrimary,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle() {
    return Text(
      context.l10n.successSentConfirmationLink(widget.email),
      style: context.bodySmall?.copyWith(
        color: context.adaptiveTextSecondary,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  // Champ de saisie OTP
  Widget _buildOTPField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.enterVerificationCode,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        8.h,
        TextField(
          controller: _otpController,
          focusNode: _otpFocusNode,
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
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.colorScheme.error,
                width: 2,
              ),
            ),
            errorText: _otpError,
          ),
          onChanged: (value) {
            if (_otpError != null) {
              setState(() {
                _otpError = null;
              });
            }
            // Auto-vérification quand 6 chiffres sont saisis
            if (value.length == 6) {
              _verifyOTP();
            }
          },
        ),
      ],
    );
  }

  // Bouton de vérification
  Widget _buildVerifyButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final hasValidCode = _otpController.text.length == 6;
        
        return SquircleBtn(
          isPrimary: true,
          isLoading: isLoading,
          onTap: (hasValidCode && !isLoading) ? _verifyOTP : null,
          label: context.l10n.verify,
        );
      },
    );
  }
}