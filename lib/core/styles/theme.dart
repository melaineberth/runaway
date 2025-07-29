import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      surface: isDark ? AppColorsDark.surface : AppColors.surface,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      onError: Colors.white,
    ),
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        height: 1.2,
        color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColorsDark.background : AppColors.background,
      foregroundColor: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
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
    // Ajout des thèmes additionnels pour une meilleure cohérence
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppColorsDark.primary : AppColors.primary,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: isDark ? AppColorsDark.surface : AppColors.surface,
      selectedItemColor: isDark ? AppColorsDark.primary : AppColors.primary,
      unselectedItemColor: isDark ? AppColorsDark.textSecondary : AppColors.textSecondary,
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? Colors.white12 : Colors.black12,
      thickness: 1,
    ),
    iconTheme: IconThemeData(
      color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
    ),
  );
}