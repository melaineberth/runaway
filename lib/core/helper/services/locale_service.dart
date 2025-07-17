import 'dart:ui';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static final LocaleService _instance = LocaleService._internal();
  factory LocaleService() => _instance;
  LocaleService._internal();

  static const String _localeKey = 'selected_locale';

  /// Langues supportées par l'application
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fr'),
    Locale('it'),
    Locale('es'),
  ];

  /// Obtient la langue sauvegardée ou celle du système par défaut
  Future<Locale> getSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocaleCode = prefs.getString(_localeKey);
      
      if (savedLocaleCode != null) {
        final locale = Locale(savedLocaleCode);
        if (isSupported(locale)) {
          return locale;
        }
      }
      
      // Retourne la langue du système si supportée, sinon anglais par défaut
      final systemLocale = PlatformDispatcher.instance.locale;
      return isSupported(systemLocale) ? systemLocale : const Locale('en');
    } catch (e) {
      LogConfig.logError('❌ Erreur lecture locale: $e');
      return const Locale('en');
    }
  }

  /// Sauvegarde la langue sélectionnée
  Future<void> saveLocale(Locale locale) async {
    try {
      if (!isSupported(locale)) {
        throw Exception('Locale non supportée: ${locale.languageCode}');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
      LogConfig.logSuccess('Locale sauvegardée: ${locale.languageCode}');
    } catch (e) {
      LogConfig.logError('❌ Erreur sauvegarde locale: $e');
      rethrow;
    }
  }

  /// Vérifie si une langue est supportée
  bool isSupported(Locale locale) {
    return supportedLocales.any((l) => l.languageCode == locale.languageCode);
  }

  /// Retourne le nom d'affichage d'une langue
  String getLanguageDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'Anglais';
      case 'fr':
        return 'Français';
      case 'it':
        return 'Italien';
      case 'es':
        return 'Espagnol';
      default:
        return locale.languageCode.toUpperCase();
    }
  }

  /// Retourne le nom d'affichage d'une langue dans sa propre langue
  String getLanguageNativeName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      case 'it':
        return 'Italiano';
      case 'es':
        return 'Español';
      default:
        return locale.languageCode.toUpperCase();
    }
  }
}