import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/services/conversion_service.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/widgets/conversion_prompt_modal.dart';

/// Helper class pour déclencher les événements de conversion
class ConversionTriggers {
  
  /// Vérifie si l'utilisateur est connecté
  static bool _isUserAuthenticated(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is Authenticated;
  }
  
  /// Déclenche quand une route est générée
  static Future<void> onRouteGenerated(BuildContext context) async {
    // ✅ Ne pas déclencher si utilisateur connecté
    if (_isUserAuthenticated(context)) return;
    
    try {
      await ConversionService.instance.trackRouteGenerated();
      
      // Vérifier si on doit montrer un prompt contextuel
      final shouldShow = await ConversionService.instance.shouldShowConversionPrompt();
      if (shouldShow && context.mounted && !_isUserAuthenticated(context)) {
        _scheduleContextualPrompt(context, 'route_generated');
      }
    } catch (e) {
      print('❌ Erreur ConversionTriggers.onRouteGenerated: $e');
    }
  }
  
  /// Déclenche quand une page d'activité est consultée
  static Future<void> onActivityViewed(BuildContext context) async {
    // ✅ Ne pas déclencher si utilisateur connecté
    if (_isUserAuthenticated(context)) return;
    
    try {
      await ConversionService.instance.trackActivityView();
      
      // Vérifier si on doit montrer un prompt contextuel
      final shouldShow = await ConversionService.instance.shouldShowConversionPrompt();
      if (shouldShow && context.mounted && !_isUserAuthenticated(context)) {
        _scheduleContextualPrompt(context, 'activity_viewed');
      }
    } catch (e) {
      print('❌ Erreur ConversionTriggers.onActivityViewed: $e');
    }
  }
  
  /// Déclenche pour des sessions longues d'utilisation
  static Future<void> onLongSession(BuildContext context) async {
    // ✅ Ne pas déclencher si utilisateur connecté
    if (_isUserAuthenticated(context)) return;
    
    try {
      final shouldShow = await ConversionService.instance.shouldShowConversionPrompt();
      if (shouldShow && context.mounted && !_isUserAuthenticated(context)) {
        _scheduleContextualPrompt(context, 'long_session');
      }
    } catch (e) {
      print('❌ Erreur ConversionTriggers.onLongSession: $e');
    }
  }
  
  /// Déclenche après plusieurs routes générées
  static Future<void> onMultipleRoutes(BuildContext context) async {
    // ✅ Ne pas déclencher si utilisateur connecté
    if (_isUserAuthenticated(context)) return;
    
    try {
      final shouldShow = await ConversionService.instance.shouldShowConversionPrompt();
      if (shouldShow && context.mounted && !_isUserAuthenticated(context)) {
        _scheduleContextualPrompt(context, 'multiple_routes');
      }
    } catch (e) {
      print('❌ Erreur ConversionTriggers.onMultipleRoutes: $e');
    }
  }
  
  /// Programme l'affichage d'un prompt contextuel après un délai
  static void _scheduleContextualPrompt(BuildContext context, String promptType) {
    Future.delayed(const Duration(seconds: 3), () async {
      // ✅ Triple vérification avant affichage
      if (!context.mounted || _isUserAuthenticated(context)) {
        print('🚫 Prompt contextuel annulé - utilisateur connecté ou contexte invalide');
        return;
      }
      
      try {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: true,
          enableDrag: true,
          builder: (context) => ConversionPromptModal(context: promptType),
        );
      } catch (e) {
        print('❌ Erreur affichage prompt contextuel: $e');
      }
    });
  }
}