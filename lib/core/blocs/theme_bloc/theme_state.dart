part of 'theme_bloc.dart';

class ThemeState {
  final AppThemeMode themeMode;
  final bool isLoading;
  final String? error;

  const ThemeState({
    this.themeMode = AppThemeMode.dark,
    this.isLoading = false,
    this.error,
  });

  ThemeState copyWith({
    AppThemeMode? themeMode,
    bool? isLoading,
    String? error,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.name,
      'isLoading': isLoading,
      'error': error,
    };
  }

  factory ThemeState.fromJson(Map<String, dynamic> json) {
    return ThemeState(
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == json['themeMode'],
        orElse: () => AppThemeMode.dark,
      ),
      isLoading: json['isLoading'] ?? false,
      error: json['error'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeState &&
        other.themeMode == themeMode &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => themeMode.hashCode ^ isLoading.hashCode ^ error.hashCode;

  @override
  String toString() {
    return 'ThemeState(themeMode: $themeMode, isLoading: $isLoading, error: $error)';
  }
}