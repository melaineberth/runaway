import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/helper/services/locale_service.dart';

part 'locale_event.dart';
part 'locale_state.dart';

class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  final LocaleService _localeService;

  LocaleBloc({LocaleService? localeService})
      : _localeService = localeService ?? LocaleService(),
        super(const LocaleState()) {
    on<LocaleInitialized>(_onLocaleInitialized);
    on<LocaleChanged>(_onLocaleChanged);
  }

  Future<void> _onLocaleInitialized(
    LocaleInitialized event,
    Emitter<LocaleState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));
      
      final savedLocale = await _localeService.getSavedLocale();
      
      emit(state.copyWith(
        locale: savedLocale,
        isLoading: false,
      ));
      
      print('✅ Locale initialisée: ${savedLocale.languageCode}');
    } catch (e) {
      print('❌ Erreur initialisation locale: $e');
      emit(state.copyWith(
        locale: const Locale('en'),
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLocaleChanged(
    LocaleChanged event,
    Emitter<LocaleState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, error: null));
      
      await _localeService.saveLocale(event.locale);
      
      emit(state.copyWith(
        locale: event.locale,
        isLoading: false,
      ));
      
      print('✅ Langue changée vers: ${event.locale.languageCode}');
    } catch (e) {
      print('❌ Erreur changement langue: $e');
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }
}