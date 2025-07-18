import 'package:flutter/material.dart';
import 'package:runaway/core/styles/colors.dart';
import 'package:runaway/core/helper/services/session_manager.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
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
    final maxPadding = [
      left,
      top,
      right,
      bottom,
    ].reduce((a, b) => a > b ? a : b);
    return innerRadius + maxPadding;
  }

  /// Calcule le radius interne basé sur le radius externe et le padding
  double calculateInnerRadius(double outerRadius) {
    final maxPadding = [
      left,
      top,
      right,
      bottom,
    ].reduce((a, b) => a > b ? a : b);
    return (outerRadius - maxPadding).clamp(0.0, double.infinity);
  }
}

extension L10nExtension on BuildContext {
  /// Utilisation : `context.l10n.helloWorld`
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension ThemeExtension on BuildContext {
  /// Accès rapide au thème actuel
  ThemeData get theme => Theme.of(this);

  /// Accès rapide au ColorScheme
  ColorScheme get colorScheme => theme.colorScheme;

  /// Vérifie si on est en mode sombre
  bool get isDarkMode => theme.brightness == Brightness.dark;

  /// Couleurs adaptatives selon le thème
  Color get adaptiveTextPrimary =>
      isDarkMode ? AppColorsDark.textPrimary : AppColors.textPrimary;
  Color get adaptiveTextSecondary =>
      isDarkMode ? AppColorsDark.textSecondary : AppColors.textSecondary;
  Color get adaptiveBackground =>
      isDarkMode ? AppColorsDark.background : AppColors.background;
  Color get adaptiveSurface =>
      isDarkMode ? AppColorsDark.surface : AppColors.surface;
  Color get adaptivePrimary =>
      isDarkMode ? AppColorsDark.primary : AppColors.primary;

  /// Couleurs avec opacité adaptative
  Color get adaptiveWhite => isDarkMode ? Colors.white : Colors.black;
  Color get adaptiveBlack => isDarkMode ? Colors.black : Colors.white;
  Color get adaptiveBorder => isDarkMode ? Colors.white12 : Colors.black12;
  Color get adaptiveDisabled => isDarkMode ? Colors.white38 : Colors.black38;
}

extension SessionValidation on Object {
  /// Vérifie que la session est valide avant d'exécuter une action critique
  Future<T> withValidSession<T>(Future<T> Function() action) async {
    if (!SessionManager.instance.isSessionValid()) {
      throw Exception('Session invalide ou expirée');
    }
    return await action();
  }
}

extension SurfaceTypeL10n on SurfaceType {
  /// Renvoie la chaîne localisée pour *cette* valeur de enum.
  String label(BuildContext context) {
    final l10n = context.l10n; // ou `content.l10n` dans ton widget
    switch (this) {
      case SurfaceType.asphalt:
        return l10n.asphaltSurfaceTitle; // clé ARB : "statusPending"
      case SurfaceType.mixed:
        return l10n.mixedSurfaceTitle;
      case SurfaceType.natural:
        return l10n.naturalSurfaceTitle;
    }
  }
}

extension DifficultyLevelL10n on DifficultyLevel {
  /// Renvoie la chaîne localisée pour *cette* valeur de enum.
  String label(BuildContext context) {
    final l10n = context.l10n; // ou `content.l10n` dans ton widget
    switch (this) {
      case DifficultyLevel.easy:
        return l10n.easyDifficultyLevel; // clé ARB : "statusPending"
      case DifficultyLevel.moderate:
        return l10n.moderateDifficultyLevel;
      case DifficultyLevel.hard:
        return l10n.hardDifficultyLevel;
      case DifficultyLevel.expert:
        return l10n.expertDifficultyLevel;
    }
  }
}
