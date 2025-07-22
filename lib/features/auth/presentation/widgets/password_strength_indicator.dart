import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/features/auth/data/utils/password_validator.dart';

enum PasswordStrength {
  weak,
  fair,
  good,
  strong
}

class PasswordStrengthData {
  final PasswordStrength strength;
  final double score;
  final List<String> missingRequirements;
  final String message;

  PasswordStrengthData({
    required this.strength,
    required this.score,
    required this.missingRequirements,
    required this.message,
  });
}

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool isVisible;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.isVisible = true,
  });

  PasswordStrengthData _calculateStrength(BuildContext context, String password) {
    if (password.isEmpty) {
      return PasswordStrengthData(
        strength: PasswordStrength.weak,
        score: 0.0,
        missingRequirements: PasswordValidator.getMissingRequirements(context, ''),
        message: context.l10n.enterPassword,
      );
    }

    final missingRequirements = PasswordValidator.getMissingRequirements(context, password);
    final validRequirements = 5 - missingRequirements.length;
    
    // Calcul du score final
    final double finalScore = validRequirements / 5.0;
    PasswordStrength strength;
    String message;

    if (validRequirements <= 1) {
      strength = PasswordStrength.weak;
      message = context.l10n.passwordVeryWeak;
    } else if (validRequirements <= 2) {
      strength = PasswordStrength.weak;
      message = context.l10n.passwordWeak;
    } else if (validRequirements <= 3) {
      strength = PasswordStrength.fair;
      message = context.l10n.passwordFair;
    } else if (validRequirements <= 4) {
      strength = PasswordStrength.good;
      message = context.l10n.passwordGood;
    } else {
      strength = PasswordStrength.strong;
      message = context.l10n.passwordStrong;
    }

    return PasswordStrengthData(
      strength: strength,
      score: finalScore,
      missingRequirements: missingRequirements,
      message: message,
    );
  }

  Color _getStrengthColor(PasswordStrength strength, BuildContext context) {
    switch (strength) {
      case PasswordStrength.weak:
        return Colors.red;
      case PasswordStrength.fair:
        return Colors.orange;
      case PasswordStrength.good:
        return Colors.blue;
      case PasswordStrength.strong:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final strengthData = _calculateStrength(context, password);
    final strengthColor = _getStrengthColor(strengthData.strength, context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: password.isEmpty ? 0.0 : 1.0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            8.h,
            // Barre de force
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: context.adaptiveDisabled.withValues(alpha: 0.2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: strengthData.score,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: strengthColor,
                        ),
                      ),
                    ),
                  ),
                ),
                8.w,
                Text(
                  strengthData.message,
                  style: context.bodySmall?.copyWith(
                    fontSize: 12,
                    color: strengthColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            // Exigences manquantes
            if (strengthData.missingRequirements.isNotEmpty) ...[
              6.h,
              ...strengthData.missingRequirements.map(
                (requirement) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 4,
                        color: context.adaptiveTextSecondary,
                      ),
                      6.w,
                      Text(
                        requirement,
                        style: context.bodySmall?.copyWith(
                          fontSize: 11,
                          color: context.adaptiveTextSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}