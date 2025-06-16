import 'package:flutter/material.dart';

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

String? emailValidator(String? v) => v != null && v.contains('@') ? null : 'Adresse e-mail invalide';

String? passwordValidator(String? v) => (v?.length ?? 0) >= 6 ? null : 'Au moins 6 caractères';
