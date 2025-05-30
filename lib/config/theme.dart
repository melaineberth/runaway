import 'package:flutter/material.dart';
import 'colors.dart';

ThemeData getAppTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: isDark ? AppColorsDark.background : AppColors.background,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColorsDark.primary : AppColors.primary,
      secondary: isDark ? AppColorsDark.secondary : AppColors.secondary,
      background: isDark ? AppColorsDark.background : AppColors.background,
      surface: isDark ? AppColorsDark.surface : AppColors.surface,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      onSurface: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      onError: Colors.white,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColorsDark.surface : AppColors.surface,
      foregroundColor: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: isDark ? AppColorsDark.surface : AppColors.surface,
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: isDark ? AppColorsDark.primary : AppColors.primary,
      textTheme: ButtonTextTheme.primary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}
