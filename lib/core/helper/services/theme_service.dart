import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runaway/core/helper/config/log_config.dart';

class ThemeService {
  static const String _themeKey = 'selected_theme_mode';

  /// Sauvegarde le mode de thème sélectionné
  Future<void> saveThemeMode(AppThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeMode.name);
    LogConfig.logInfo('💾 Theme sauvegardé: ${themeMode.name}');
  }

  /// Récupère le mode de thème sauvegardé ou retourne le défaut
  Future<AppThemeMode> getSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    
    if (savedTheme != null) {
      try {
        final themeMode = AppThemeMode.values.firstWhere(
          (mode) => mode.name == savedTheme,
        );
        LogConfig.logInfo('📱 Theme récupéré: ${themeMode.name}');
        return themeMode;
      } catch (e) {
        LogConfig.logInfo('Theme invalide sauvegardé: $savedTheme, utilisation du défaut');
      }
    }
    
    LogConfig.logInfo('📱 Utilisation du theme par défaut: auto');
    return AppThemeMode.auto;
  }

  /// Efface la préférence de thème sauvegardée
  Future<void> clearSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeKey);
    LogConfig.logInfo('🗑️ Préférence de theme effacée');
  }
}