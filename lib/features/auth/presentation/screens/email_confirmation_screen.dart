import 'package:flutter/material.dart';
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

  void _resendEmail() {
    if (_canResend && !_isResending) {
      setState(() {
        _isResending = true;
      });
      
      context.authBloc.add(ResendConfirmationRequested(email: widget.email));
    }
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
                40.h,
                _buildResendButton(),
                12.h,
                _buildBackToLoginButton(),
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

  Widget _buildResendButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        
        return SquircleBtn(
          isPrimary: true,
          isLoading: isLoading,
          onTap: (_canResend && !isLoading) ? _resendEmail : null,
          label: _canResend 
            ? context.l10n.resendCode
            : context.l10n.resendCodeInDelay(_cooldownSeconds),
        );
      },
    );
  }

  Widget _buildBackToLoginButton() {
    return SquircleBtn(
      isPrimary: false,
      onTap: () => context.go('/login'),
      label: context.l10n.loginBack,
    );
  }
}