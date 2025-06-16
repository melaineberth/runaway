import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
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
    showModalBottomSheet(
      context: context, 
      useRootNavigator: true,
      enableDrag: false,
      isDismissible: false,
      isScrollControlled: true,
      builder: (modalCtx) {
        return child;
      },
    );    
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: kToolbarHeight * 3,
        automaticallyImplyLeading: false,
        title: Text(
          "Accès restreint",
          style: context.bodySmall?.copyWith(
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            context.pop();

            if (mounted) {
            context.pushReplacement('/home');
            }
          }, 
          icon: Icon(HugeIcons.solidStandardArrowLeft02),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
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
                  "Vous n'êtes pas connecté",
                  style: context.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                10.h,
                Text(
                  "Pour accéder à cette page, veuillez vous connecter ou créer un compte.",
                  style: context.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 17,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const Spacer(),
            Column(
              children: [
                _buildAuthButton(
                  label: "Se connecter",
                  onPressed: () => _showAuthModal(child: LoginScreen()),
                ),
                12.h,
                _buildAuthButton(
                  isBorder: true,
                  label: "Créer un compte",
                  onPressed: () => _showAuthModal(child: SignupScreen()),
                ),
                20.h,
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    "Besoin d'aide ? Contactez-nous.",
                    style: context.bodySmall?.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              ],
            ),
            40.h,
          ],
        ),
      ),
    );
  }

  Widget _buildAuthButton({required String label, required Function() onPressed, bool isBorder = false}) {
    return SizedBox(
      width: double.infinity,
      child: Expanded(
        child: IconBtn(
          label: label,
          backgroundColor: isBorder ? Colors.transparent : AppColors.primary,
          labelColor: isBorder ? AppColors.primary : Colors.black,
          onPressed: onPressed,
          border: isBorder ? Border.all(
            color: AppColors.primary,
            width: 2.5,
          ) : null,
        ),
      ),
    );
  }
}