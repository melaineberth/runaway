import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';

class ModalDialog extends StatelessWidget {
  final String? imgPath;
  final String title;
  final String subtitle;
  final String validLabel;
  final String? cancelLabel;
  final bool activeCancel;
  final bool isDestructive;
  final bool isDismissible;
  final Function()? onValid;
  final Function()? onCancel;

  const ModalDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.validLabel,
    this.cancelLabel,
    this.imgPath,
    this.activeCancel = true,
    this.isDestructive = false,
    this.isDismissible = false,
    this.onValid,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModalSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imgPath != null) ...[
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Image.asset(imgPath!),
                ),
                30.h,
              ],
              Text(
                title,
                style: context.bodyMedium?.copyWith(
                  fontSize: 22,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              12.h,
              Text(
                subtitle,
                style: context.bodySmall?.copyWith(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              40.h,
              SquircleBtn(
                isDestructive: isDestructive,
                isPrimary: true,
                label: validLabel,
                onTap: onValid
              ),
              if (activeCancel) ...[
                10.h,
                SquircleBtn(
                  isGradient: false,
                  isDestructive: isDestructive,
                  label: cancelLabel ?? context.l10n.cancel,
                  onTap: onCancel ?? () {
                    HapticFeedback.mediumImpact();
                    context.pop();
                  },
                ),
              ]
            ],
          ),
        ),
        if (isDismissible)
        Positioned(
          right: 15,
          top: 15,
          child: IconBtn(
            backgroundColor: Colors.transparent,
            icon: HugeIcons.solidRoundedCancelCircle,
            iconColor: context.adaptiveDisabled.withValues(alpha: 0.2),
            onPressed: () {
              Navigator.pop(context);
              context.go('/home');
            },
          ),
        )
      ],
    );
  }
}