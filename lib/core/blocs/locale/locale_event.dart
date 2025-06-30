part of 'locale_bloc.dart';

abstract class LocaleEvent {
  const LocaleEvent();
}

/// Événement pour initialiser la langue au démarrage de l'app
class LocaleInitialized extends LocaleEvent {
  const LocaleInitialized();
}

/// Événement pour changer la langue
class LocaleChanged extends LocaleEvent {
  final Locale locale;

  const LocaleChanged(this.locale);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocaleChanged && other.locale == locale;
  }

  @override
  int get hashCode => locale.hashCode;

  @override
  String toString() => 'LocaleChanged(locale: $locale)';
}