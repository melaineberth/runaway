// lib/core/helper/services/deep_link_service.dart
import 'package:flutter/material.dart';
import 'package:runaway/core/helper/config/log_config.dart';

class DeepLinkService {
  static const DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  const DeepLinkService._internal();

  static const String _scheme = 'trailix';

  /// Traite les deep links entrants
  static void handleDeepLink(String link, BuildContext context) {
    try {
      final uri = Uri.parse(link);
      
      if (uri.scheme != _scheme) {
        LogConfig.logWarning('Deep link avec scheme non reconnu: ${uri.scheme}');
        return;
      }
      
      LogConfig.logInfo('Deep link reçu: ${uri.path}');
      
      switch (uri.path) {
        case '/auth/password-reset-success':
          _handlePasswordResetSuccess(context);
          break;
        default:
          LogConfig.logWarning('Deep link non géré: ${uri.path}');
      }
    } catch (e) {
      LogConfig.logError('Erreur traitement deep link: $e');
    }
  }
  
  /// Gère le succès du reset password
  static void _handlePasswordResetSuccess(BuildContext context) {
    // Naviguer vers l'écran de succès
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/password-reset-success',
      (route) => false,
    );
  }
}