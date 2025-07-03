import 'package:flutter/material.dart';
import 'package:runaway/core/services/conversion_service.dart';
import 'package:runaway/features/auth/presentation/widgets/conversion_prompt_modal.dart';

/// Helper class pour déclencher les événements de conversion
class ConversionTriggers {
  
  /// Déclenche quand une route est générée
  static Future<void> onRouteGenerated(BuildContext context) async {
    try {
      await ConversionService.instance.trackRouteGenerated();
      
      // Vérifier si on doit montrer un prompt contextuel
      final shouldShow = await ConversionService.instance.shouldShowConversionPrompt();
      if (shouldShow && context.mounted) {
        _scheduleContextualPrompt(context, 'route_generated');
      }
    } catch (e) {
      print('❌ Erreur ConversionTriggers.onRouteGenerated: $e');
    }
  }
  
  /// Déclenche quand une page d'activité est consultée
  static Future<void> onActivityViewed(BuildContext context) async {
    try {
      await ConversionService.instance.trackActivityView();
      
      // Vérifier si on doit montrer un prompt contextuel
      final shouldShow = await ConversionService.instance.shouldShowConversionPrompt();
      if (shouldShow && context.mounted) {
        _scheduleContextualPrompt(context, 'activity_viewed');
      }
    } catch (e) {
      print('❌ Erreur ConversionTriggers.onActivityViewed: $e');
    }
  }
  
  /// Déclenche pour des sessions longues d'utilisation
  static Future<void> onLongSession(BuildContext context) async {
    try {
      final shouldShow = await ConversionService.instance.shouldShowConversionPrompt();
      if (shouldShow && context.mounted) {
        _scheduleContextualPrompt(context, 'long_session');
      }
    } catch (e) {
      print('❌ Erreur ConversionTriggers.onLongSession: $e');
    }
  }
  
  /// Déclenche après plusieurs routes générées
  static Future<void> onMultipleRoutes(BuildContext context) async {
    try {
      final shouldShow = await ConversionService.instance.shouldShowConversionPrompt();
      if (shouldShow && context.mounted) {
        _scheduleContextualPrompt(context, 'multiple_routes');
      }
    } catch (e) {
      print('❌ Erreur ConversionTriggers.onMultipleRoutes: $e');
    }
  }
  
  /// Programme l'affichage d'un prompt contextuel avec délai
  static void _scheduleContextualPrompt(BuildContext context, String promptContext) {
    // Délai de 3-7 secondes pour ne pas interrompre l'utilisateur
    Future.delayed(const Duration(seconds: 5), () {
      if (context.mounted) {
        _showContextualPrompt(context, promptContext);
      }
    });
  }
  
  /// Affiche un prompt contextuel
  static Future<void> _showContextualPrompt(BuildContext context, String promptContext) async {
    try {
      await showModalBottomSheet<void>(
        useRootNavigator: true,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: false,
        context: context,
        backgroundColor: Colors.transparent,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        builder: (context) => ConversionPromptModal(context: promptContext),
      );
    } catch (e) {
      print('❌ Erreur affichage prompt contextuel: $e');
    }
  }
  
  /// Obtient les statistiques de debug
  static Future<Map<String, dynamic>> getDebugStats() async {
    return await ConversionService.instance.getDebugStats();
  }
}