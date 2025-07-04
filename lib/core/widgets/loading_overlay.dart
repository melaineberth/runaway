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

  static const Duration _kDefaultMinDisplay = Duration(milliseconds: 600);
  Duration _minDisplay = _kDefaultMinDisplay;

  void show(
    BuildContext context,
    String message, {
    Duration minDisplay = _kDefaultMinDisplay,
  }) {
    _minDisplay = minDisplay;

    // Overlay déjà visible → on met à jour le contenu si besoin
    if (_entry != null) {
      _updateMessage(message);
      return;
    }

    _shownAt = DateTime.now();

    _entry = OverlayEntry(
      builder: (_) => FullScreenLoader(message: message),
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void hide() {
    if (_entry == null) return;

    final elapsed   = DateTime.now().difference(_shownAt!);
    final remaining = _minDisplay - elapsed;

    if (remaining.isNegative || remaining == Duration.zero) {
      _remove();
    } else if (!_isHideScheduled) {
      _isHideScheduled = true;
      Future.delayed(remaining, _remove);
    }
  }

  void _remove() {
    _entry?.remove();
    _entry            = null;
    _shownAt          = null;
    _isHideScheduled  = false;
  }

  void _updateMessage(String msg) {
    if (_entry == null) return;
    _entry!.markNeedsBuild();
  }
}
