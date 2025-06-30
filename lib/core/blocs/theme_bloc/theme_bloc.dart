import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:runaway/core/services/theme_service.dart';

part 'theme_event.dart';
part 'theme_state.dart';

enum AppThemeMode {
  auto,
  light,
  dark,
}

extension AppThemeModeExtension on AppThemeMode {
  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemeMode.auto:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}

class ThemeBloc extends HydratedBloc<ThemeEvent, ThemeState> {
  final ThemeService _themeService;

  ThemeBloc({ThemeService? themeService})
      : _themeService = themeService ?? ThemeService(),
        super(const ThemeState()) {
    on<ThemeInitialized>(_onThemeInitialized);
    on<ThemeChanged>(_onThemeChanged);
  }

  Future<void> _onThemeInitialized(
    ThemeInitialized event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));
      
      final savedThemeMode = await _themeService.getSavedThemeMode();
      
      emit(state.copyWith(
        themeMode: savedThemeMode,
        isLoading: false,
      ));
      
      print('✅ Theme initialisé: ${savedThemeMode.name}');
    } catch (e) {
      print('❌ Erreur initialisation theme: $e');
      emit(state.copyWith(
        themeMode: AppThemeMode.dark,
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onThemeChanged(
    ThemeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, error: null));
      
      await _themeService.saveThemeMode(event.themeMode);
      
      emit(state.copyWith(
        themeMode: event.themeMode,
        isLoading: false,
      ));
      
      print('✅ Theme changé vers: ${event.themeMode.name}');
    } catch (e) {
      print('❌ Erreur changement theme: $e');
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  @override
  ThemeState? fromJson(Map<String, dynamic> json) {
    try {
      return ThemeState.fromJson(json);
    } catch (e) {
      print('❌ Erreur hydratation theme: $e');
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(ThemeState state) {
    try {
      return state.toJson();
    } catch (e) {
      print('❌ Erreur sérialisation theme: $e');
      return null;
    }
  }
}