import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_state.dart';
import 'package:runaway/features/credits/presentation/widgets/insufficient_credits_modal.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class CreditsUtils {
  /// Vérifie les crédits et affiche une modal si insuffisants
  static Future<bool> checkAndUseCredits({
    required BuildContext context,
    required int requiredCredits,
    required String action,
    String? routeGenerationId,
    Map<String, dynamic>? metadata,
  }) async {
    final creditsBloc = context.read<CreditsBloc>();
    
    // Vérifier d'abord si l'utilisateur a assez de crédits
    final hasEnough = await creditsBloc.hasEnoughCredits(requiredCredits);
    
    if (!hasEnough) {
      // Récupérer les crédits actuels pour la modal
      final currentCredits = creditsBloc.getCurrentCredits();

      if (context.mounted) {
        if (currentCredits != null) {
          _showInsufficientCreditsModal(
            context: context,
            availableCredits: currentCredits.availableCredits,
            requiredCredits: requiredCredits,
            action: action,
          );
        }
      }
      
      return false;
    }
    
    return true;
  }

  /// Affiche la modal de crédits insuffisants
  static void _showInsufficientCreditsModal({
    required BuildContext context,
    required int availableCredits,
    required int requiredCredits,
    required String action,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InsufficientCreditsModal(
        availableCredits: availableCredits,
        requiredCredits: requiredCredits,
        action: action,
      ),
    );
  }

  /// Écoute les changements d'état des crédits et affiche des messages
  static void setupCreditsListener(BuildContext context) {
    context.read<CreditsBloc>().stream.listen((state) {
      if (state is CreditUsageSuccess) {
        if (context.mounted) {
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              title: state.message,
            ),
          );
        }
      } else if (state is CreditPurchaseSuccess) {
        if (context.mounted) {
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              title: state.message,
            ),
          );
        }
      } else if (state is CreditsError && state.currentCredits == null) {
        if (context.mounted) {
          showTopSnackBar(
            Overlay.of(context),
            TopSnackBar(
              isError: true,
              title: state.message,
            ),
          );
        }
      }
    });
  }

  /// Format d'affichage des crédits
  static String formatCredits(int credits) {
    return '$credits crédit${credits > 1 ? 's' : ''}';
  }

  /// Couleur selon le nombre de crédits
  static Color getCreditsColor(int credits) {
    if (credits == 0) return Colors.red;
    if (credits <= 3) return Colors.orange;
    if (credits <= 10) return Colors.amber;
    return Colors.green;
  }

  /// Icône selon le nombre de crédits
  static IconData getCreditsIcon(int credits) {
    if (credits == 0) return Icons.star_border_rounded;
    if (credits <= 3) return Icons.star_half_rounded;
    return Icons.star_rounded;
  }
}