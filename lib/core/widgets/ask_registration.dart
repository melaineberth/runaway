import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/features/auth/presentation/screens/login_screen.dart';
import 'package:runaway/features/auth/presentation/screens/signup_screen.dart';

class AskRegistration extends StatefulWidget {
  const AskRegistration({super.key});

  @override
  State<AskRegistration> createState() => _AskRegistrationState();
}

class _AskRegistrationState extends State<AskRegistration> {
  void _showAuthModal({required Widget child}) {
    showModalSheet(
      context: context, 
      child: child,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          context.l10n.restrictedAccessTitle,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 100.0, 20.0, 20.0),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: Image.asset("assets/img/lock.png"),
                ),
                20.h,
                Column(
                  children: [
                    Text(
                      context.l10n.notLoggedIn,
                      style: context.bodyLarge?.copyWith(
                        color: context.adaptiveTextPrimary,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    10.h,
                    Text(
                      context.l10n.loginOrCreateAccountHint,
                      style: context.bodyMedium?.copyWith(
                        color: context.adaptiveTextSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 17,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: kBottomNavigationBarHeight * 2.5,
            child: Column(
              children: [
                _buildAuthButton(
                  label: context.l10n.logIn,
                  onPressed: () => _showAuthModal(child: LoginScreen()),
                ),
                12.h,
                _buildAuthButton(
                  isBorder: true,
                  label: context.l10n.createAccount,
                  onPressed: () => _showAuthModal(child: SignupScreen()),
                ),
                20.h,
                Text.rich(
                  TextSpan(
                    text: context.l10n.needHelp,
                    style: context.bodySmall?.copyWith(
                      color: context.adaptiveTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    children: <InlineSpan>[
                      TextSpan(
                        text: context.l10n.contactUs,
                        style: context.bodySmall?.copyWith(
                          color: context.adaptivePrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = () => print('Tap Here onTap'),
                      )
                    ]
                  )
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButton({required String label, required Function() onPressed, bool isBorder = false}) {
    return SizedBox(
      width: double.infinity,
      child: IconBtn(
        label: label,
        backgroundColor: isBorder ? Colors.transparent : context.adaptivePrimary,
        labelColor: isBorder ? context.adaptivePrimary : Colors.white,
        onPressed: onPressed,
        border: isBorder ? Border.all(
          color: context.adaptivePrimary,
          width: 2.5,
        ) : null,
      ),
    );
  }
}