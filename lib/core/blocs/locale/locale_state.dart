part of 'locale_bloc.dart';

class LocaleState {
  final Locale locale;
  final bool isLoading;
  final String? error;

  const LocaleState({
    this.locale = const Locale('en'),
    this.isLoading = false,
    this.error,
  });

  LocaleState copyWith({
    Locale? locale,
    bool? isLoading,
    String? error,
  }) {
    return LocaleState(
      locale: locale ?? this.locale,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocaleState &&
        other.locale == locale &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(locale, isLoading, error);

  @override
  String toString() {
    return 'LocaleState(locale: $locale, isLoading: $isLoading, error: $error)';
  }
}