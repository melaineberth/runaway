// lib/core/widgets/generation_limit_widget.dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/route_generator/presentation/blocs/extensions/route_generation_bloc_extensions.dart';

/// Widget qui affiche les limitations de génération et encourage l'achat/connexion
class GenerationLimitWidget extends StatelessWidget {
  final GenerationCapability capability;
  final VoidCallback? onDebug;
  final VoidCallback? onLogin;
  final bool showBackground;
  final EdgeInsetsGeometry? padding;

  const GenerationLimitWidget({
    super.key,
    required this.capability,
    this.onDebug,
    this.onLogin,
    this.showBackground = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (capability.canGenerate && capability.type == GenerationType.authenticated) {
      // Utilisateur connecté avec crédits - affichage discret
      return _buildCreditsDisplay(context);
    }

    if (capability.canGenerate && capability.type == GenerationType.guest) {
      // Utilisateur guest avec générations restantes - encouragement doux
      return _buildGuestEncouragement(context);
    }

    if (!capability.canGenerate) {
      // Limitation atteinte - appel à l'action fort
      return _buildLimitReached(context);
    }

    return const SizedBox.shrink();
  }

  /// Affichage discret du nombre de crédits
  Widget _buildCreditsDisplay(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            HugeIcons.strokeRoundedCoins01,
            size: 16,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            capability.displayMessage,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Encouragement pour les utilisateurs guests
  Widget _buildGuestEncouragement(BuildContext context) {
    final container = SquircleContainer(
      padding: const EdgeInsets.all(16),
      color: context.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedGift,
                size: 20,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.freeGenerations,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            capability.displayMessage,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SquircleBtn(
                  onTap: onLogin ?? () => showAuthModal(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        HugeIcons.strokeRoundedUserAdd01,
                        size: 16,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.createAccount,
                        style: TextStyle(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!showBackground) return container;

    return Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: container,
    );
  }

  /// Affichage quand la limite est atteinte
  Widget _buildLimitReached(BuildContext context) {
    final container = ModalDialog(
      activeCancel: false,
      title: capability.type == GenerationType.guest 
        ? context.l10n.exhaustedFreeGenerations
        : context.l10n.exhaustedCredits, 
      subtitle: context.l10n.authForMoreGenerations, 
      validLabel: context.l10n.createFreeAccount,
      onValid: onLogin ?? () => showAuthModal(context),
    );

    if (!showBackground) return container;

    return container;
  }
}