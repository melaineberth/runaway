// lib/core/widgets/generation_limit_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_event.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
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
                  'Générations gratuites',
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
                  onTap: onLogin ?? () => _showLoginOptions(context),
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
                        'Créer un compte',
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
      title: capability.type == GenerationType.guest 
        ? 'Générations gratuites épuisées'
        : 'Crédits épuisés', 
      subtitle: capability.upgradeMessage ?? 'Impossible de générer plus de parcours', 
      validLabel: "Créer un compte gratuit",
      onValid: onLogin ?? () => _showLoginOptions(context),
      cancelLabel: "Debug",
      onCancel: onDebug,
    );

    if (!showBackground) return container;

    return container;
  }

  /// Affiche les options de connexion
  void _showLoginOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LoginOptionsModal(),
    );
  }
}

/// Modal pour les options de connexion
class LoginOptionsModal extends StatelessWidget {
  const LoginOptionsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return SquircleContainer(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      color: context.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            HugeIcons.strokeRoundedUserAdd01,
            size: 48,
            color: context.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Rejoignez Runaway',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez un compte pour débloquer plus de générations et sauvegarder vos parcours',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              return Column(
                children: [
                  SquircleBtn(
                    onTap: () {
                      Navigator.pop(context);
                      context.authBloc.add(GoogleSignInRequested());
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Vous pouvez ajouter l'icône Google ici
                        const Icon(Icons.g_translate, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Continuer avec Google',
                          style: TextStyle(
                            color: context.colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SquircleBtn(
                    onTap: () {
                      Navigator.pop(context);
                      context.authBloc.add(AppleSignInRequested());
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.apple,
                          color: context.colorScheme.surface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Continuer avec Apple',
                          style: TextStyle(
                            color: context.colorScheme.surface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Plus tard',
              style: TextStyle(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}