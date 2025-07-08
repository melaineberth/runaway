import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/credits/presentation/screens/credit_plans_screen.dart';

/// Modal affiché quand l'utilisateur n'a pas assez de crédits
class InsufficientCreditsModal extends StatelessWidget {
  final int availableCredits;
  final int requiredCredits;
  final String action;

  const InsufficientCreditsModal({
    super.key,
    required this.availableCredits,
    required this.requiredCredits,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star_border_rounded,
              size: 32,
              color: Colors.amber[600],
            ),
          ),
          
          16.h,
          
          // Titre
          Text(
            context.l10n.insufficientCreditsTitle,
            style: context.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.adaptiveTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          
          8.h,
          
          // Description
          Text(
            context.l10n.insufficientCreditsDescription(
              requiredCredits,
              action,
              availableCredits,
            ),
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          
          24.h,
          
          // Boutons
          Column(
            children: [
              // Bouton principal - Acheter des crédits
              SizedBox(
                width: double.infinity,
                child: SquircleContainer(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CreditPlansScreen(),
                      ),
                    );
                  },
                  height: 52,
                  color: context.adaptivePrimary,
                  radius: 26.0,
                  child: Center(
                    child: Text(
                      context.l10n.buyCredits,
                      style: context.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              
              12.h,
              
              // Bouton secondaire - Annuler
              SizedBox(
                width: double.infinity,
                child: SquircleContainer(
                  onTap: () => Navigator.of(context).pop(),
                  height: 52,
                  color: context.adaptiveSurface,
                  radius: 26.0,
                  child: Center(
                    child: Text(
                      context.l10n.cancel,
                      style: context.bodySmall?.copyWith(
                        color: context.adaptiveTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Espace pour le safe area
          MediaQuery.of(context).padding.bottom.h,
        ],
      ),
    );
  }
}
