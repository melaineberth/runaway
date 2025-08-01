import 'dart:async';

import 'package:flutter/material.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/widgets/full_screen_loader.dart';

/// Service singleton – gère un unique OverlayEntry plein écran.
class LoadingOverlay {
  LoadingOverlay._();
  static final LoadingOverlay _i = LoadingOverlay._();
  factory LoadingOverlay() => _i;

  OverlayEntry? _entry;
  DateTime? _shownAt;
  bool _isHideScheduled = false;
  LoadingType? _currentLoadingType;
  Timer? _safetyTimer; // Timer de sécurité

  static const Duration _kDefaultMinDisplay = Duration(milliseconds: 5000);
  static const Duration _kMaxDisplay = Duration(seconds: 120); // Timeout de sécurité de 2 minutes
  Duration _minDisplay = _kDefaultMinDisplay;

  void show(
    BuildContext context, {
    Duration minDisplay = _kDefaultMinDisplay,
    LoadingType? loadingType,
  }) {
    _minDisplay = minDisplay;
    _currentLoadingType = loadingType;

    // Overlay déjà visible → on met à jour le contenu si besoin
    if (_entry != null) {
      _updateMessage(loadingType);
      // Redémarrer le timer de sécurité si on change de type
      _resetSafetyTimer();
      return;
    }

    _shownAt = DateTime.now();
    _isHideScheduled = false;

    _entry = OverlayEntry(
      builder: (_) => FullScreenLoader(loadingType: loadingType),
    );

    final overlayState = Overlay.of(context, rootOverlay: true);
    overlayState.insert(_entry!);

    // Démarrer un timer de sécurité pour éviter les loaders bloqués
    _startSafetyTimer();
    
    LogConfig.logInfo('🔄 LoadingOverlay affiché à ${DateTime.now()} (minimum ${_minDisplay.inSeconds}s)');
  }

  // Timer de sécurité pour forcer la fermeture après un délai maximum
  void _startSafetyTimer() {
    _safetyTimer?.cancel();
    _safetyTimer = Timer(_kMaxDisplay, () {
      if (_entry != null) {
        LogConfig.logWarning('⚠️ LoadingOverlay forcé à se fermer après ${_kMaxDisplay.inSeconds}s (sécurité)');
        _forceHide();
      }
    });
  }

  void _resetSafetyTimer() {
    _safetyTimer?.cancel();
    _startSafetyTimer();
  }

  void _forceHide() {
    LogConfig.logWarning('🚨 Fermeture forcée du LoadingOverlay (timeout de sécurité)');
    _remove(null);
  }

  void hide({VoidCallback? onHidden}) {
    if (_entry == null) return;

    // Annuler le timer de sécurité
    _safetyTimer?.cancel();

    final elapsed = DateTime.now().difference(_shownAt!);
    final remaining = _minDisplay - elapsed;

    LogConfig.logInfo('🕐 Tentative masquage - Écoulé: ${elapsed.inMilliseconds}ms, Minimum: ${_minDisplay.inMilliseconds}ms, Restant: ${remaining.inMilliseconds}ms');

    if (remaining.isNegative || remaining == Duration.zero) {
      LogConfig.logSuccess('✅ Temps minimum respecté - Masquage immédiat');
      _remove(onHidden);
    } else if (!_isHideScheduled) {
      LogConfig.logInfo('⏰ Temps minimum non atteint - Programmation masquage dans ${remaining.inMilliseconds}ms');
      _isHideScheduled = true;
      Future.delayed(remaining, () {
        LogConfig.logSuccess('🎯 Masquage programmé exécuté');
        _remove(onHidden);
      });
    } else {
      LogConfig.logInfo('📅 Masquage déjà programmé');
    }
  }

  void _remove(VoidCallback? onHidden) {
    if (_entry != null) {
      // Nettoyer le timer de sécurité
      _safetyTimer?.cancel();
      _safetyTimer = null;
      _entry!.remove();
      _entry = null;
      _shownAt = null;
      _isHideScheduled = false;
      _currentLoadingType = null;
      
      LogConfig.logInfo('❌ LoadingOverlay masqué à ${DateTime.now()}');
      
      if (onHidden != null) {
        LogConfig.logInfo('📞 Exécution callback onHidden');
        onHidden();
      }
    }
  }

  void _updateMessage(LoadingType? loadingType) {
    if (_entry == null) return;
    
    if (_currentLoadingType != loadingType) {
      _currentLoadingType = loadingType;
      _entry!.markNeedsBuild();
      LogConfig.logInfo('🔄 Type de chargement mis à jour: $loadingType');
    }
  }

  bool get isVisible => _entry != null;

  // Méthode pour vérifier si le loader est affiché depuis trop longtemps
  bool get isStuck {
    if (_entry == null || _shownAt == null) return false;
    final elapsed = DateTime.now().difference(_shownAt!);
    return elapsed > _kMaxDisplay;
  }

  // Méthode de debug pour diagnostiquer les problèmes
  void logStatus() {
    if (_entry == null) {
      LogConfig.logInfo('📊 LoadingOverlay: Non affiché');
    } else {
      final elapsed = DateTime.now().difference(_shownAt!);
      LogConfig.logInfo('📊 LoadingOverlay: Affiché depuis ${elapsed.inSeconds}s, Type: $_currentLoadingType, Planifié: $_isHideScheduled');
    }
  }
}