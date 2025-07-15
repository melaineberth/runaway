import 'dart:async';

import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:runaway/core/services/logging_service.dart';
import 'package:runaway/core/services/monitoring_service.dart';
import 'package:runaway/features/route_generator/data/validation/route_parameters_validator.dart';
import 'route_parameters_event.dart';
import 'route_parameters_state.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';

class RouteParametersBloc extends HydratedBloc<RouteParametersEvent, RouteParametersState> {
  // Cache de validation pour éviter les recalculs
  ValidationResult? _lastValidationResult;
  RouteParameters? _lastValidatedParameters;
  
  // Debounce pour la validation en temps réel
  Timer? _validationTimer;
  static const Duration _validationDelay = Duration(milliseconds: 300);
  
  RouteParametersBloc({
    required double startLongitude,
    required double startLatitude,
  }) : super(RouteParametersState(
    parameters: RouteParameters(
      activityType: ActivityType.running,
      terrainType: TerrainType.mixed,
      urbanDensity: UrbanDensity.mixed,
      distanceKm: 5.0,
      elevationGain: 0.0,
      startLongitude: 0.0,
      startLatitude: 0.0,
      isLoop: true,
      avoidTraffic: true,
      preferScenic: false,
    ),
  )) {
    on<ActivityTypeChanged>(_onActivityTypeChanged);
    on<TerrainTypeChanged>(_onTerrainTypeChanged);
    on<UrbanDensityChanged>(_onUrbanDensityChanged);
    on<DistanceChanged>(_onDistanceChanged);
    on<ElevationGainChanged>(_onElevationGainChanged);
    on<StartLocationUpdated>(_onStartLocationUpdated);
    on<PresetApplied>(_onPresetApplied);
    on<FavoriteAdded>(_onFavoriteAdded);
    on<FavoriteRemoved>(_onFavoriteRemoved);
    on<FavoriteApplied>(_onFavoriteApplied);
    on<RouteParametersUndoRequested>(_onUndo);
    on<RouteParametersRedoRequested>(_onRedo);
    on<LoopToggled>(_onLoopToggled);
    on<AvoidTrafficToggled>(_onAvoidTrafficToggled);
    on<PreferScenicToggled>(_onPreferScenicToggled);

    // 🆕 AJOUTER : Gestionnaire pour l'événement ParametersValidated
    on<ParametersValidated>(_onParametersValidated);
    on<ValidationRequested>(_onValidationRequested);
    on<QuickValidationRequested>(_onQuickValidationRequested);
    on<ValidationHelpRequested>(_onValidationHelpRequested);
  }

  Future<void> _onActivityTypeChanged(
    ActivityTypeChanged event, 
    Emitter<RouteParametersState> emit
  ) async {
    LoggingService.instance.info(
      'RouteParametersBloc',
      'Changement type d\'activité',
      data: {'from': state.parameters.activityType.name, 'to': event.activityType.name},
    );

    final newParameters = state.parameters.copyWith(
      activityType: event.activityType,
    );

    // Auto-ajustement de la distance si nécessaire
    final adjustedParameters = _autoAdjustParametersForActivity(newParameters, event.activityType);
    
    final newState = _addToHistory(state, adjustedParameters);
    emit(newState);
    
    // Validation automatique différée
    _scheduleValidation(adjustedParameters);
    
    // Tracking analytique
    MonitoringService.instance.recordMetric(
      'activity_type_changed',
      1,
      tags: {
        'new_type': event.activityType.name,
        'auto_adjusted': (adjustedParameters != newParameters).toString(),
      },
    );
  }

  Future<void> _onDistanceChanged(
    DistanceChanged event, 
    Emitter<RouteParametersState> emit
  ) async {
    final newParameters = state.parameters.copyWith(distanceKm: event.distanceKm);
    final newState = _addToHistory(state, newParameters);
    emit(newState);
    
    // Validation en temps réel pour la distance
    _scheduleValidation(newParameters);
  }

  Future<void> _onElevationGainChanged(
    ElevationGainChanged event, 
    Emitter<RouteParametersState> emit
  ) async {
    final newParameters = state.parameters.copyWith(elevationGain: event.elevationGain);
    final newState = _addToHistory(state, newParameters);
    emit(newState);
    
    _scheduleValidation(newParameters);
  }

  Future<void> _onTerrainTypeChanged(
    TerrainTypeChanged event, 
    Emitter<RouteParametersState> emit
  ) async {
    final newParameters = state.parameters.copyWith(terrainType: event.terrainType);
    final newState = _addToHistory(state, newParameters);
    emit(newState);
    
    _scheduleValidation(newParameters);
  }

  Future<void> _onUrbanDensityChanged(
    UrbanDensityChanged event, 
    Emitter<RouteParametersState> emit
  ) async {
    final newParameters = state.parameters.copyWith(urbanDensity: event.urbanDensity);
    final newState = _addToHistory(state, newParameters);
    emit(newState);
    
    _scheduleValidation(newParameters);
  }

  Future<void> _onStartLocationUpdated(
    StartLocationUpdated event, 
    Emitter<RouteParametersState> emit
  ) async {
    final newParameters = state.parameters.copyWith(
      startLatitude: event.latitude,
      startLongitude: event.longitude,
    );
    
    emit(state.copyWith(parameters: newParameters));
    
    // Validation immédiate pour la position
    _performImmediateValidation(newParameters, emit);
  }

  void _onPresetApplied(
    PresetApplied event,
    Emitter<RouteParametersState> emit,
  ) {
    RouteParameters preset;
    
    switch (event.presetType) {
      case 'beginner':
        preset = RouteParameters.beginnerPreset(
          startLongitude: state.parameters.startLongitude,
          startLatitude: state.parameters.startLatitude,
        );
        break;
      case 'intermediate':
        preset = RouteParameters.intermediatePreset(
          startLongitude: state.parameters.startLongitude,
          startLatitude: state.parameters.startLatitude,
        );
        break;
      case 'advanced':
        preset = RouteParameters.advancedPreset(
          startLongitude: state.parameters.startLongitude,
          startLatitude: state.parameters.startLatitude,
        );
        break;
      default:
        return;
    }

    _updateParameters(emit, preset);
  }

  void _onFavoriteAdded(
    FavoriteAdded event,
    Emitter<RouteParametersState> emit,
  ) {
    final newFavorites = List<RouteParameters>.from(state.favorites)
      ..add(state.parameters.copyWith());
    
    emit(state.copyWith(favorites: newFavorites));
  }

  void _onFavoriteRemoved(
    FavoriteRemoved event,
    Emitter<RouteParametersState> emit,
  ) {
    if (event.index >= 0 && event.index < state.favorites.length) {
      final newFavorites = List<RouteParameters>.from(state.favorites)
        ..removeAt(event.index);
      
      emit(state.copyWith(favorites: newFavorites));
    }
  }

  void _onFavoriteApplied(
    FavoriteApplied event,
    Emitter<RouteParametersState> emit,
  ) {
    if (event.index >= 0 && event.index < state.favorites.length) {
      _updateParameters(
        emit,
        state.favorites[event.index].copyWith(
          startLongitude: state.parameters.startLongitude,
          startLatitude: state.parameters.startLatitude,
        ),
      );
    }
  }

  void _onUndo(
    RouteParametersUndoRequested event,
    Emitter<RouteParametersState> emit,
  ) {
    if (state.canUndo) {
      final newIndex = state.historyIndex - 1;
      emit(state.copyWith(
        parameters: state.history[newIndex].copyWith(),
        historyIndex: newIndex,
      ));
    }
  }

  void _onRedo(
    RouteParametersRedoRequested event,
    Emitter<RouteParametersState> emit,
  ) {
    if (state.canRedo) {
      final newIndex = state.historyIndex + 1;
      emit(state.copyWith(
        parameters: state.history[newIndex].copyWith(),
        historyIndex: newIndex,
      ));
    }
  }

  Future<void> _onLoopToggled(
    LoopToggled event, 
    Emitter<RouteParametersState> emit
  ) async {
    final newParameters = state.parameters.copyWith(isLoop: event.isLoop);
    final newState = _addToHistory(state, newParameters);
    emit(newState);
    
    _scheduleValidation(newParameters);
  }

  void _onAvoidTrafficToggled(
    AvoidTrafficToggled event,
    Emitter<RouteParametersState> emit,
  ) {
    final newParameters = state.parameters.copyWith(avoidTraffic: event.avoidTraffic);
    final newState = _addToHistory(state, newParameters);
    emit(newState);
    
    _scheduleValidation(newParameters);
  }

  void _onPreferScenicToggled(
    PreferScenicToggled event,
    Emitter<RouteParametersState> emit,
  ) {
    final newParameters = state.parameters.copyWith(preferScenic: event.preferScenic);
    final newState = _addToHistory(state, newParameters);
    emit(newState);
    
    _scheduleValidation(newParameters);
  }

  Future<void> _onParametersValidated(
    ParametersValidated event, 
    Emitter<RouteParametersState> emit
  ) async {
    _cacheValidationResult(event.parameters, event.validationResult);
    
    emit(state.copyWith(
      validationResult: event.validationResult,
      errorMessage: event.validationResult.hasErrors ? event.validationResult.firstErrorMessage : null,
    ));
  }

  Future<void> _onValidationRequested(
    ValidationRequested event, 
    Emitter<RouteParametersState> emit
  ) async {
    LoggingService.instance.info('RouteParametersBloc', 'Validation complète demandée');
    
    final validationResult = RouteParametersValidator.validate(state.parameters);
    _cacheValidationResult(state.parameters, validationResult);
    
    emit(state.copyWith(
      validationResult: validationResult,
      errorMessage: validationResult.hasErrors ? validationResult.firstErrorMessage : null,
    ));
    
    MonitoringService.instance.recordMetric(
      'full_validation_performed',
      1,
      tags: {
        'is_valid': validationResult.isValid.toString(),
        'error_count': validationResult.errors.length.toString(),
        'warning_count': validationResult.warnings.length.toString(),
      },
    );
  }

  Future<void> _onQuickValidationRequested(
    QuickValidationRequested event, 
    Emitter<RouteParametersState> emit
  ) async {
    final isValid = RouteParametersValidator.isQuickValid(state.parameters);
    
    if (!isValid) {
      // Si la validation rapide échoue, faire une validation complète
      add(const ValidationRequested());
    } else {
      // Effacer les erreurs précédentes si la validation rapide passe
      emit(state.copyWith(errorMessage: null));
    }
  }

  Future<void> _onValidationHelpRequested(
    ValidationHelpRequested event, 
    Emitter<RouteParametersState> emit
  ) async {
    final helpMessage = RouteParametersValidator.getHelpMessage(event.field, state.parameters);
    
    // Vous pouvez stocker le message d'aide dans l'état si nécessaire
    // Pour l'instant, on log juste le message
    LoggingService.instance.info(
      'RouteParametersBloc',
      'Aide demandée pour ${event.field}: $helpMessage',
    );
  }

  void _updateParameters(
    Emitter<RouteParametersState> emit,
    RouteParameters newParams,
  ) {
    List<RouteParameters> newHistory = List.from(state.history);
    
    // Supprimer l'historique après la position actuelle
    if (state.historyIndex < state.history.length - 1) {
      newHistory = newHistory.sublist(0, state.historyIndex + 1);
    }
    
    newHistory.add(newParams.copyWith());
    int newIndex = newHistory.length - 1;
    
    // Limiter la taille de l'historique
    if (newHistory.length > 20) {
      newHistory.removeAt(0);
      newIndex--;
    }

    emit(state.copyWith(
      parameters: newParams,
      history: newHistory,
      historyIndex: newIndex,
      errorMessage: null,
    ));
  }

  // === MÉTHODES UTILITAIRES ===

  /// Auto-ajuste les paramètres selon l'activité
  RouteParameters _autoAdjustParametersForActivity(
    RouteParameters parameters, 
    ActivityType newActivity
  ) {
    var adjusted = parameters;
    
    // Ajuster la distance si elle dépasse les limites
    if (parameters.distanceKm < newActivity.minDistance) {
      adjusted = adjusted.copyWith(distanceKm: newActivity.minDistance);
      LoggingService.instance.info(
        'RouteParametersBloc',
        'Distance auto-ajustée au minimum',
        data: {'new_distance': newActivity.minDistance.toString()},
      );
    } else if (parameters.distanceKm > newActivity.maxDistance) {
      adjusted = adjusted.copyWith(distanceKm: newActivity.maxDistance);
      LoggingService.instance.info(
        'RouteParametersBloc',
        'Distance auto-ajustée au maximum',
        data: {'new_distance': newActivity.maxDistance.toString()},
      );
    }
    
    // Ajuster le terrain selon l'activité
    if (newActivity == ActivityType.cycling && parameters.terrainType == TerrainType.hilly) {
      // Suggérer un terrain plus adapté au vélo
      adjusted = adjusted.copyWith(terrainType: TerrainType.mixed);
    }
    
    return adjusted;
  }

  /// Ajoute les paramètres à l'historique
  RouteParametersState _addToHistory(RouteParametersState currentState, RouteParameters newParameters) {
    final newHistory = currentState.history.take(currentState.historyIndex + 1).toList()
      ..add(newParameters);
    
    // Limiter la taille de l'historique
    if (newHistory.length > 50) {
      newHistory.removeAt(0);
    }
    
    return currentState.copyWith(
      parameters: newParameters,
      history: newHistory,
      historyIndex: newHistory.length - 1,
      errorMessage: null,
    );
  }

  /// Programme une validation différée
  void _scheduleValidation(RouteParameters parameters) {
    _validationTimer?.cancel();
    _validationTimer = Timer(_validationDelay, () {
      if (!isClosed) {
        add(ParametersValidated(
          parameters: parameters,
          validationResult: RouteParametersValidator.validate(parameters),
        ));
      }
    });
  }

  // Effectue une validation immédiate
  void _performImmediateValidation(RouteParameters parameters, Emitter<RouteParametersState> emit) {
    final validationResult = RouteParametersValidator.validate(parameters);
    _cacheValidationResult(parameters, validationResult);
    
    emit(state.copyWith(
      validationResult: validationResult,
      errorMessage: validationResult.hasErrors ? validationResult.firstErrorMessage : null,
    ));
  }
  
  /// Cache le résultat de validation
  void _cacheValidationResult(RouteParameters parameters, ValidationResult result) {
    _lastValidatedParameters = parameters;
    _lastValidationResult = result;
  }

  String? validateParameters() {
    if (!state.parameters.isValid) {
      if (state.parameters.distanceKm < state.parameters.activityType.minDistance) {
        return 'La distance minimale pour ${state.parameters.activityType.title} est ${state.parameters.activityType.minDistance} km';
      }
      if (state.parameters.distanceKm > state.parameters.activityType.maxDistance) {
        return 'La distance maximale pour ${state.parameters.activityType.title} est ${state.parameters.activityType.maxDistance} km';
      }
    }
    return null;
  }

  @override
  RouteParametersState? fromJson(Map<String, dynamic> json) {
    try {
      return RouteParametersState.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(RouteParametersState state) {
    try {
      return state.toJson();
    } catch (e) {
      return null;
    }
  }
}