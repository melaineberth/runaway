// lib/core/widgets/loading_overlay.dart
import 'package:flutter/material.dart';
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

  static const Duration _kDefaultMinDisplay = Duration(milliseconds: 5000);
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
      return;
    }

    _shownAt = DateTime.now();
    _isHideScheduled = false;

    _entry = OverlayEntry(
      builder: (_) => FullScreenLoader(loadingType: loadingType),
    );

    final overlayState = Overlay.of(context, rootOverlay: true);
    overlayState.insert(_entry!);
    
    print('🔄 LoadingOverlay affiché à ${DateTime.now()} (minimum ${_minDisplay.inSeconds}s)');
  }

  void hide({VoidCallback? onHidden}) {
    if (_entry == null) return;

    final elapsed = DateTime.now().difference(_shownAt!);
    final remaining = _minDisplay - elapsed;

    print('🕐 Tentative masquage - Écoulé: ${elapsed.inMilliseconds}ms, Minimum: ${_minDisplay.inMilliseconds}ms, Restant: ${remaining.inMilliseconds}ms');

    if (remaining.isNegative || remaining == Duration.zero) {
      print('✅ Temps minimum respecté - Masquage immédiat');
      _remove(onHidden);
    } else if (!_isHideScheduled) {
      print('⏰ Temps minimum non atteint - Programmation masquage dans ${remaining.inMilliseconds}ms');
      _isHideScheduled = true;
      Future.delayed(remaining, () {
        print('🎯 Masquage programmé exécuté');
        _remove(onHidden);
      });
    } else {
      print('📅 Masquage déjà programmé');
    }
  }

  void _remove(VoidCallback? onHidden) {
    if (_entry != null) {
      _entry!.remove();
      _entry = null;
      _shownAt = null;
      _isHideScheduled = false;
      _currentLoadingType = null;
      
      print('❌ LoadingOverlay masqué à ${DateTime.now()}');
      
      if (onHidden != null) {
        print('📞 Exécution callback onHidden');
        onHidden();
      }
    }
  }

  void _updateMessage(LoadingType? loadingType) {
    if (_entry == null) return;
    
    if (_currentLoadingType != loadingType) {
      _currentLoadingType = loadingType;
      _entry!.markNeedsBuild();
      print('🔄 Type de chargement mis à jour: $loadingType');
    }
  }

  bool get isVisible => _entry != null;
}