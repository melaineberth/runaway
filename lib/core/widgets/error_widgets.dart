import 'package:flutter/material.dart';
import 'package:runaway/core/errors/app_exceptions.dart';
import 'package:runaway/core/errors/error_service.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';

/// Widget pour afficher une erreur dans une card
class ErrorCard extends StatelessWidget {
  final AppException exception;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showDetails;
  final bool canRetry;

  const ErrorCard({
    super.key,
    required this.exception,
    this.onRetry,
    this.onDismiss,
    this.showDetails = false,
    this.canRetry = true,
  });

  @override
  Widget build(BuildContext context) {
    final message = ErrorService.instance.getLocalizedMessage(exception, context);
    
    return Card(
      margin: const EdgeInsets.all(16),
      color: context.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _getErrorIcon(),
                  color: context.colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.errorDialogTitle,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: context.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close),
                    color: context.colorScheme.error,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onErrorContainer,
              ),
            ),
            if (showDetails && exception.code != null) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.errorCode(exception.code!),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onErrorContainer.withOpacity(0.7),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canRetry && onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: Text(context.l10n.retryAction),
                  ),
                if (onDismiss != null)
                  TextButton(
                    onPressed: onDismiss,
                    child: Text(context.l10n.closeAction),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    if (exception is NetworkException || exception is ConnectivityException) {
      return Icons.wifi_off;
    }
    if (exception is TimeoutException) {
      return Icons.timer;
    }
    if (exception is AuthException) {
      return Icons.lock;
    }
    if (exception is ValidationException) {
      return Icons.warning;
    }
    if (exception is RouteGenerationException) {
      return Icons.route;
    }
    if (exception is LocationException) {
      return Icons.location_off;
    }
    return Icons.error;
  }
}

/// Widget compact pour afficher une erreur en banner
class ErrorBanner extends StatelessWidget {
  final AppException exception;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool canRetry;

  const ErrorBanner({
    super.key,
    required this.exception,
    this.onRetry,
    this.onDismiss,
    this.canRetry = true,
  });

  @override
  Widget build(BuildContext context) {
    final message = ErrorService.instance.getLocalizedMessage(exception, context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colorScheme.errorContainer,
        border: Border(
          left: BorderSide(
            color: context.colorScheme.error,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: context.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (canRetry && onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(
                context.l10n.retryAction,
                style: context.textTheme.bodySmall,
              ),
            ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              iconSize: 20,
              color: context.colorScheme.error,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}

/// Page d'erreur complète pour les erreurs critiques
class ErrorScreen extends StatelessWidget {
  final AppException exception;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;
  final bool showDetails;

  const ErrorScreen({
    super.key,
    required this.exception,
    this.onRetry,
    this.onGoHome,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final message = ErrorService.instance.getLocalizedMessage(exception, context);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getErrorIcon(),
                size: 80,
                color: context.colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.errorDialogTitle,
                style: context.textTheme.headlineMedium?.copyWith(
                  color: context.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: context.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (showDetails && exception.code != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.technicalDetails,
                        style: context.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.errorCode(exception.code!),
                        style: context.textTheme.bodySmall,
                      ),
                      Text(
                        context.l10n.errorTime(
                          TimeOfDay.now().format(context),
                        ),
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (onRetry != null)
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.retryAction),
                    ),
                  if (onGoHome != null)
                    OutlinedButton.icon(
                      onPressed: onGoHome,
                      icon: const Icon(Icons.home),
                      label: Text('Accueil'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    if (exception is NetworkException || exception is ConnectivityException) {
      return Icons.cloud_off;
    }
    if (exception is TimeoutException) {
      return Icons.timer_off;
    }
    if (exception is AuthException) {
      return Icons.lock_open;
    }
    if (exception is ServerException) {
      return Icons.dns;
    }
    return Icons.error_outline;
  }
}

/// SnackBar pour les erreurs légères
class ErrorSnackBar {
  static void show(
    BuildContext context,
    AppException exception, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    final message = ErrorService.instance.getLocalizedMessage(exception, context);
    
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
                message,
                style: TextStyle(color: context.colorScheme.onError),
              ),
            ),
          ],
        ),
        backgroundColor: context.colorScheme.error,
        duration: duration,
        action: onRetry != null
          ? SnackBarAction(
              label: context.l10n.retryAction,
              textColor: context.colorScheme.onError,
              onPressed: onRetry,
            )
          : null,
      ),
    );
  }
}

/// Dialog pour les erreurs importantes
class ErrorDialog extends StatelessWidget {
  final AppException exception;
  final VoidCallback? onRetry;
  final bool showDetails;
  final bool barrierDismissible;

  const ErrorDialog({
    super.key,
    required this.exception,
    this.onRetry,
    this.showDetails = false,
    this.barrierDismissible = true,
  });

  static Future<void> show(
    BuildContext context,
    AppException exception, {
    VoidCallback? onRetry,
    bool showDetails = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => ErrorDialog(
        exception: exception,
        onRetry: onRetry,
        showDetails: showDetails,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = ErrorService.instance.getLocalizedMessage(exception, context);
    
    return AlertDialog(
      icon: Icon(
        Icons.error_outline,
        color: context.colorScheme.error,
        size: 32,
      ),
      title: Text(context.l10n.errorDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (showDetails && exception.code != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.errorCode(exception.code!),
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry!();
            },
            child: Text(context.l10n.retryAction),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.closeAction),
        ),
      ],
    );
  }
}