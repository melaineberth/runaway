import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/l10n/app_localizations.dart';

  final _channel = const MethodChannel('corner_radius');

  Future<double> getDeviceCornerRadius() async {
    if (kDebugMode) debugPrint('[CR] ▶︎ Demande du rayon…');

    // 1️⃣ plateforme non prise en charge
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (kDebugMode) debugPrint('[CR] ⛔️ Desktop / Web – retourne 0');
      return 0;
    }

    try {
      final radius = await _channel.invokeMethod<double>('getCornerRadius');

      if (kDebugMode) {
        debugPrint('[CR] ✔︎ Réponse native = ${radius ?? 'null'}');
      }

      return radius ?? 0;
    } on PlatformException catch (e, s) {
      if (kDebugMode) {
        debugPrint('[CR] 💥 PlatformException : ${e.message}');
        debugPrint('[CR] Stack :\n$s');
      }
      return 0;
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('[CR] 🔥 Erreur inconnue : $e');
        debugPrint('[CR] Stack :\n$s');
      }
      return 0;
    }
  }

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

void showModalSheet({required BuildContext context, required Widget child, Color backgroundColor = Colors.black}) {
    showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      context: context,
      backgroundColor: backgroundColor,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (modalCtx) {
        return child;
      },
    );
  }

  String generateAutoRouteName(RouteParameters p, double distanceKm) {
  final now        = DateTime.now();
  final timeString = '${now.hour.toString().padLeft(2, '0')}:'
                     '${now.minute.toString().padLeft(2, '0')}';
  final dateString = '${now.day}/${now.month}';
  return '${p.activityType.title} '
         '${distanceKm.toStringAsFixed(0)}km - $timeString ($dateString)';
}

extension ThemeExtension on BuildContext {
  /// Accès rapide au thème actuel
  ThemeData get theme => Theme.of(this);
  
  /// Accès rapide au ColorScheme
  ColorScheme get colorScheme => theme.colorScheme;
  
  /// Vérifie si on est en mode sombre
  bool get isDarkMode => theme.brightness == Brightness.dark;
  
  /// Couleurs adaptatives selon le thème
  Color get adaptiveTextPrimary => isDarkMode ? AppColorsDark.textPrimary : AppColors.textPrimary;
  Color get adaptiveTextSecondary => isDarkMode ? AppColorsDark.textSecondary : AppColors.textSecondary;
  Color get adaptiveBackground => isDarkMode ? AppColorsDark.background : AppColors.background;
  Color get adaptiveSurface => isDarkMode ? AppColorsDark.surface : AppColors.surface;
  Color get adaptivePrimary => isDarkMode ? AppColorsDark.primary : AppColors.primary;
  
  /// Couleurs avec opacité adaptative
  Color get adaptiveWhite => isDarkMode ? Colors.white : Colors.black;
  Color get adaptiveBlack => isDarkMode ? Colors.black : Colors.white;
  Color get adaptiveBorder => isDarkMode ? Colors.white12 : Colors.black12;
  Color get adaptiveDisabled => isDarkMode ? Colors.white38 : Colors.black38;
}