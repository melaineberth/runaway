part of 'theme_bloc.dart';

abstract class ThemeEvent {
  const ThemeEvent();
}

/// Événement pour initialiser le thème au démarrage de l'app
class ThemeInitialized extends ThemeEvent {
  const ThemeInitialized();
}

/// Événement pour changer le thème
class ThemeChanged extends ThemeEvent {
  final AppThemeMode themeMode;

  const ThemeChanged(this.themeMode);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeChanged && other.themeMode == themeMode;
  }

  @override
  int get hashCode => themeMode.hashCode;

  @override
  String toString() => 'ThemeChanged(themeMode: $themeMode)';
}