import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class PasswordResetSuccessScreen extends StatefulWidget {
  const PasswordResetSuccessScreen({super.key});

  @override
  State<PasswordResetSuccessScreen> createState() => _PasswordResetSuccessScreenState();
}

class _PasswordResetSuccessScreenState extends State<PasswordResetSuccessScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [          
          // Icône de succès
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: SquircleContainer(
                  width: 100,
                  height: 100,
                  radius: 60.0,
                  isGlow: true,
                  color: Colors.green,
                  child: Icon(
                    HugeIcons.solidRoundedCheckmarkCircle01,
                    size: 50,
                    color: context.adaptiveBackground,
                  ),
                ),
              );
            }
          ),
          
          20.h,
          
          // Titre
          Text(
            context.l10n.passwordResetSuccess,
            style: context.bodyMedium?.copyWith(
              fontSize: 22,
              color: context.adaptiveTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          
          12.h,
          
          // Description
          Text(
            context.l10n.passwordResetSuccessDesc,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),

          40.h,
                    
          // Bouton de connexion
          SquircleBtn(
            isPrimary: true,
            label: context.l10n.logIn,
            onTap: () {
              context.pop();
            },
          ),          
        ],
      ),
    );
  }
}