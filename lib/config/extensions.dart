import 'package:flutter/material.dart';
import 'package:runaway/l10n/app_localizations.dart';

extension SpacingExtension on num {
  SizedBox get h => SizedBox(height: toDouble());
  SizedBox get w => SizedBox(width: toDouble());
}

extension TextStyleExtension on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;

  TextStyle? get displayLarge => textTheme.displayLarge;
  TextStyle? get displayMedium => textTheme.displayMedium;
  TextStyle? get displaySmall => textTheme.displaySmall;

  TextStyle? get headlineLarge => textTheme.headlineLarge;
  TextStyle? get headlineMedium => textTheme.headlineMedium;
  TextStyle? get headlineSmall => textTheme.headlineSmall;

  TextStyle? get titleLarge => textTheme.titleLarge;
  TextStyle? get titleMedium => textTheme.titleMedium;
  TextStyle? get titleSmall => textTheme.titleSmall;

  TextStyle? get bodyLarge => textTheme.bodyLarge;
  TextStyle? get bodyMedium => textTheme.bodyMedium;
  TextStyle? get bodySmall => textTheme.bodySmall;

  TextStyle? get labelLarge => textTheme.labelLarge;
  TextStyle? get labelMedium => textTheme.labelMedium;
  TextStyle? get labelSmall => textTheme.labelSmall;
}

extension OuterRadiusExt on double {
  double outerRadius(double padding) {
    assert(padding >= 0, 'Le padding doit être positif');
    return this + padding;
  }
}

extension SmartRadius on EdgeInsets {
  /// Calcule le radius externe basé sur le radius interne et le padding
  double calculateOuterRadius(double innerRadius) {
    // Prend la valeur maximale du padding pour le calcul
    final maxPadding = [left, top, right, bottom].reduce((a, b) => a > b ? a : b);
    return innerRadius + maxPadding;
  }
  
  /// Calcule le radius interne basé sur le radius externe et le padding
  double calculateInnerRadius(double outerRadius) {
    final maxPadding = [left, top, right, bottom].reduce((a, b) => a > b ? a : b);
    return (outerRadius - maxPadding).clamp(0.0, double.infinity);
  }
}

/// Accès rapide aux chaînes localisées :
extension L10nExtension on BuildContext {
  /// Utilisation : `context.l10n.helloWorld`
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

void showModalSheet({required BuildContext context, required Widget child}) {
    showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      context: context,
      backgroundColor: Colors.black,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (modalCtx) {
        return child;
      },
    );
  }