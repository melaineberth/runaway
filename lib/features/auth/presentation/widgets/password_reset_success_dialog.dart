import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:hugeicons/hugeicons.dart';

class PasswordResetSuccessDialog extends StatelessWidget {
  const PasswordResetSuccessDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône de succès
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                HugeIcons.strokeRoundedCheckmarkCircle02,
                size: 40,
                color: context.theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Message de succès
            Text(
              context.l10n.passwordResetSuccessDesc,
              style: context.theme.textTheme.bodyMedium?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Bouton pour fermer
            SquircleBtn(
              onTap: () => Navigator.of(context).pop(),
              child: Text(context.l10n.continueForms),
            ),
          ],
        ),
      ),
    );
  }
}