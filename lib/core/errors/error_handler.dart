import 'dart:async';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:runaway/core/errors/app_exceptions.dart';
import 'package:runaway/core/errors/error_service.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/logging_service.dart';
import 'package:runaway/core/router/router.dart';
import 'package:runaway/core/widgets/error_widgets.dart';

/// Types d'affichage d'erreur
enum ErrorDisplayType {
  snackBar,
  dialog,
  banner,
  screen,
  none,
}

/// Configuration pour l'affichage d'une erreur
class ErrorDisplayConfig {
  final ErrorDisplayType type;
  final bool canRetry;
  final bool showDetails;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final Duration? duration;

  const ErrorDisplayConfig({
    this.type = ErrorDisplayType.snackBar,
    this.canRetry = true,
    this.showDetails = false,
    this.onRetry,
    this.onDismiss,
    this.duration,
  });
}

/// Gestionnaire d'erreurs global amélioré
class ErrorHandler {
  static ErrorHandler? _instance;
  static ErrorHandler get instance => _instance ??= ErrorHandler._();
  
  ErrorHandler._();

  /// Configuration par défaut selon le type d'exception
  ErrorDisplayConfig _getDefaultDisplayConfig(AppException exception) {
    // En production, pas de dialogs d'erreur - utiliser des SnackBar à la place
    if (!kDebugMode) {
      // En production, toutes les erreurs critiques deviennent des SnackBar
      if (exception is AuthException || 
          exception is ServerException && exception.statusCode >= 500) {
        return const ErrorDisplayConfig(
          type: ErrorDisplayType.snackBar,
          showDetails: false,
          duration: Duration(seconds: 6),
        );
      }

      // Erreurs de permissions aussi en SnackBar en production
      if (exception is PermissionException || exception is LocationException) {
        return const ErrorDisplayConfig(
          type: ErrorDisplayType.snackBar,
          canRetry: false,
          showDetails: false,
          duration: Duration(seconds: 5),
        );
      }
    } else {
      // En mode debug, garder le comportement original avec dialogs
      // Erreurs critiques -> Dialog ou Screen
      if (exception is AuthException || 
          exception is ServerException && exception.statusCode >= 500) {
        return const ErrorDisplayConfig(
          type: ErrorDisplayType.dialog,
          showDetails: true,
        );
      }

      // Erreurs de permissions -> Dialog
      if (exception is PermissionException || exception is LocationException) {
        return const ErrorDisplayConfig(
          type: ErrorDisplayType.dialog,
          canRetry: false,
          showDetails: true,
        );
      }
    }

    // Erreurs réseau -> SnackBar avec retry (même comportement debug/prod)
    if (exception is NetworkException || 
        exception is TimeoutException ||
        exception is ConnectivityException) {
      return const ErrorDisplayConfig(
        type: ErrorDisplayType.snackBar,
        canRetry: true,
        duration: Duration(seconds: 5),
      );
    }

    // Erreurs de validation -> Banner (même comportement debug/prod)
    if (exception is ValidationException) {
      return const ErrorDisplayConfig(
        type: ErrorDisplayType.banner,
        canRetry: false,
        showDetails: kDebugMode, // Détails seulement en debug
      );
    }

    // Par défaut -> SnackBar
    return const ErrorDisplayConfig(
      type: ErrorDisplayType.snackBar,
    );
  }

  /// Gère et affiche une erreur avec la configuration appropriée
  Future<void> handleError(
    dynamic error, {
    BuildContext? context,
    ErrorDisplayConfig? config,
    String? contextInfo,
  }) async {
    try {
      // Conversion en AppException
      final appException = ErrorService.instance.handleError(error, context: context);
      
      // Log de l'erreur avec contexte
      _logError(appException, contextInfo);
      
      // Configuration d'affichage
      final displayConfig = config ?? _getDefaultDisplayConfig(appException);
      
      // Affichage de l'erreur
      await _displayError(appException, displayConfig, context);
      
    } catch (e) {
      LogConfig.logError('Erreur dans ErrorHandler.handleError: $e');
      // Fallback critique
      if (context != null && context.mounted) {
        _showFallbackError(context);
      }
    }
  }

  /// Affiche une erreur selon la configuration
  Future<void> _displayError(
    AppException exception,
    ErrorDisplayConfig config,
    BuildContext? context,
  ) async {
    context ??= rootNavigatorKey.currentContext;
    if (context == null) return;

    switch (config.type) {
      case ErrorDisplayType.snackBar:
        ErrorSnackBar.show(
          context,
          exception,
          onRetry: config.canRetry ? config.onRetry : null,
          duration: config.duration ?? const Duration(seconds: 4),
        );
        break;

      case ErrorDisplayType.dialog:
        // Vérification kDebugMode avant d'afficher un dialog
        if (kDebugMode) {
          await ErrorDialog.show(
            context,
            exception,
            onRetry: config.canRetry ? config.onRetry : null,
            showDetails: config.showDetails,
          );
        } else {
          // En production, remplacer par une SnackBar
          ErrorSnackBar.show(
            context,
            exception,
            onRetry: config.canRetry ? config.onRetry : null,
            duration: const Duration(seconds: 5),
          );
        }
        break;

      case ErrorDisplayType.banner:
        // Pour les banners, on peut utiliser un overlay ou intégrer dans l'UI
        _showBannerError(context, exception, config);
        break;

      case ErrorDisplayType.screen:
        // Navigation vers une page d'erreur complète
        await _showErrorScreen(context, exception, config);
        break;

      case ErrorDisplayType.none:
        // Pas d'affichage, juste le log
        break;
    }
  }

  /// Affiche une erreur en banner via overlay
  void _showBannerError(
    BuildContext context,
    AppException exception,
    ErrorDisplayConfig config,
  ) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).viewPadding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ErrorBanner(
            exception: exception,
            onRetry: config.canRetry ? config.onRetry : null,
            onDismiss: () => overlayEntry.remove(),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-remove après délai
    Timer(config.duration ?? const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  /// Affiche une page d'erreur complète
  Future<void> _showErrorScreen(
    BuildContext context,
    AppException exception,
    ErrorDisplayConfig config,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ErrorScreen(
          exception: exception,
          onRetry: config.onRetry,
          showDetails: config.showDetails && kDebugMode, // Détails seulement en debug
        ),
      ),
    );
  }

  /// Log une erreur avec contexte
  void _logError(AppException exception, String? contextInfo) {
    LoggingService.instance.error(
      'ErrorHandler',
      'Erreur dans ${contextInfo ?? 'Application'}',
      data: {
        'exception': exception.toJson(),
        'context': contextInfo,
        'debug_mode': kDebugMode,
      },
    );
  }

  /// Fallback pour les erreurs critiques
  void _showFallbackError(BuildContext context) {
    if (!context.mounted) return;
    
    // En production, utiliser une SnackBar simple même pour les fallbacks
    if (!kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: context.colorScheme.onError,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.unknownError,
                  style: TextStyle(color: context.colorScheme.onError),
                ),
              ),
            ],
          ),
          backgroundColor: context.colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      // En debug, garder le dialog de fallback
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.errorDialogTitle),
          content: Text(context.l10n.unknownError),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.closeAction),
            ),
          ],
        ),
      );
    }
  }

  /// Gère spécifiquement les erreurs de génération de parcours
  Future<void> handleRouteGenerationError(
    dynamic error, {
    BuildContext? context,
    VoidCallback? onRetry,
    String? contextInfo,
  }) async {
    await handleError(
      error,
      context: context,
      config: ErrorDisplayConfig(
        type: kDebugMode ? ErrorDisplayType.dialog : ErrorDisplayType.snackBar,
        canRetry: true,
        onRetry: onRetry,
        showDetails: kDebugMode,
        duration: const Duration(seconds: 6),
      ),
      contextInfo: contextInfo ?? 'Route Generation',
    );
  }

  /// Gère spécifiquement les erreurs d'authentification
  Future<void> handleAuthError(
    dynamic error, {
    BuildContext? context,
    VoidCallback? onRetry,
    String? contextInfo,
  }) async {
    await handleError(
      error,
      context: context,
      config: ErrorDisplayConfig(
        type: kDebugMode ? ErrorDisplayType.dialog : ErrorDisplayType.snackBar,
        canRetry: false,
        showDetails: false,
        duration: const Duration(seconds: 5),
      ),
      contextInfo: contextInfo ?? 'Authentication',
    );
  }

  /// Gère spécifiquement les erreurs de connectivité
  Future<void> handleConnectivityError(
    dynamic error, {
    BuildContext? context,
    VoidCallback? onRetry,
    String? contextInfo,
  }) async {
    await handleError(
      error,
      context: context,
      config: ErrorDisplayConfig(
        type: ErrorDisplayType.snackBar,
        canRetry: true,
        onRetry: onRetry,
        duration: const Duration(seconds: 5),
      ),
      contextInfo: contextInfo ?? 'Connectivity',
    );
  }

  /// Gère spécifiquement les erreurs de validation
  Future<void> handleValidationError(
    ValidationException error, {
    BuildContext? context,
    String? contextInfo,
  }) async {
    await handleError(
      error,
      context: context,
      config: ErrorDisplayConfig(
        type: ErrorDisplayType.banner,
        canRetry: false,
        showDetails: kDebugMode,
      ),
      contextInfo: contextInfo ?? 'Validation',
    );
  }

  /// Gère les erreurs silencieuses (log seulement)
  void handleSilentError(
    dynamic error, {
    String? contextInfo,
  }) {
    final appException = ErrorService.instance.handleError(error);
    _logError(appException, contextInfo);
  }
}