import 'dart:async';
import 'dart:math' as math;

import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:runaway/core/helper/services/logging_service.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
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
      elevationRange: const ElevationRange(min: 0, max: 100), // 🔧 Valeur sûre au lieu de 0
      difficulty: DifficultyLevel.moderate,
      maxInclinePercent: 12.0,
      preferredWaypoints: 3,
      avoidHighways: true,
      prioritizeParks: false,
      surfacePreference: 0.5,
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
    on<ElevationRangeChanged>(_onElevationRangeChanged);
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

    on<DifficultyChanged>(_onDifficultyChanged);
    on<MaxInclineChanged>(_onMaxInclineChanged);
    on<PreferredWaypointsChanged>(_onPreferredWaypointsChanged);
    on<AvoidHighwaysToggled>(_onAvoidHighwaysToggled);
    on<PrioritizeParksToggled>(_onPrioritizeParksToggled);
    on<SurfacePreferenceChanged>(_onSurfacePreferenceChanged);
    on<DifficultyPresetApplied>(_onDifficultyPresetApplied);

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

    // 🆕 UTILISER _adjustParametersForActivity ici
    final adjustedParameters = _adjustParametersForActivity(newParameters);
    
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

  void _onElevationRangeChanged(
    ElevationRangeChanged event,
    Emitter<RouteParametersState> emit,
  ) {
    final updatedParameters = state.parameters.copyWith(
      elevationRange: event.elevationRange,
    );
    
    final updatedState = _addToHistory(state, updatedParameters);
    emit(updatedState);
    
    // Validation différée pour UX fluide
    _scheduleValidation(updatedParameters);
    
    // Metrics
    MonitoringService.instance.recordMetric(
      'elevation_range_changed',
      1,
      tags: {
        'min': event.elevationRange.min,
        'max': event.elevationRange.max,
        'activity': updatedParameters.activityType.id,
      },
    );
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

  // 🆕 Handler pour le changement de difficulté
  void _onDifficultyChanged(
    DifficultyChanged event,
    Emitter<RouteParametersState> emit,
  ) {
    final updatedParameters = state.parameters.copyWith(
      difficulty: event.difficulty,
    );
    
    final updatedState = _addToHistory(state, updatedParameters);
    emit(updatedState);
    
    _scheduleValidation(updatedParameters);
    
    MonitoringService.instance.recordMetric(
      'difficulty_changed',
      1,
      tags: {
        'difficulty': event.difficulty.id,
        'level': event.difficulty.level,
      },
    );
  }

  // 🆕 Handler pour la pente maximale
  void _onMaxInclineChanged(
    MaxInclineChanged event,
    Emitter<RouteParametersState> emit,
  ) {
    final updatedParameters = state.parameters.copyWith(
      maxInclinePercent: event.maxInclinePercent,
    );
    
    final updatedState = _addToHistory(state, updatedParameters);
    emit(updatedState);
    
    _scheduleValidation(updatedParameters);
  }

  // 🆕 Handler pour les points d'intérêt
  void _onPreferredWaypointsChanged(
    PreferredWaypointsChanged event,
    Emitter<RouteParametersState> emit,
  ) {
    final updatedParameters = state.parameters.copyWith(
      preferredWaypoints: event.waypoints,
    );
    
    final updatedState = _addToHistory(state, updatedParameters);
    emit(updatedState);
    
    _scheduleValidation(updatedParameters);
  }

  // 🆕 Handler pour éviter les autoroutes
  void _onAvoidHighwaysToggled(
    AvoidHighwaysToggled event,
    Emitter<RouteParametersState> emit,
  ) {
    final updatedParameters = state.parameters.copyWith(
      avoidHighways: event.avoidHighways,
    );
    
    final updatedState = _addToHistory(state, updatedParameters);
    emit(updatedState);
    
    _performImmediateValidation(updatedParameters, emit);
  }

  // 🆕 Handler pour prioriser les parcs
  void _onPrioritizeParksToggled(
    PrioritizeParksToggled event,
    Emitter<RouteParametersState> emit,
  ) {
    final updatedParameters = state.parameters.copyWith(
      prioritizeParks: event.prioritizeParks,
    );
    
    final updatedState = _addToHistory(state, updatedParameters);
    emit(updatedState);
    
    _performImmediateValidation(updatedParameters, emit);
  }

  // 🆕 Handler pour la préférence de surface
  void _onSurfacePreferenceChanged(
    SurfacePreferenceChanged event,
    Emitter<RouteParametersState> emit,
  ) {
    final updatedParameters = state.parameters.copyWith(
      surfacePreference: event.surfacePreference,
    );
    
    final updatedState = _addToHistory(state, updatedParameters);
    emit(updatedState);
    
    _scheduleValidation(updatedParameters);
  }

  // 🆕 Handler pour appliquer un preset de difficulté
  void _onDifficultyPresetApplied(
    DifficultyPresetApplied event,
    Emitter<RouteParametersState> emit,
  ) {
    RouteParameters presetParameters;
    
    switch (event.difficulty) {
      case DifficultyLevel.easy:
        presetParameters = RouteParameters.beginnerPreset(
          startLongitude: event.startLongitude,
          startLatitude: event.startLatitude,
        );
        break;
      case DifficultyLevel.moderate:
        presetParameters = RouteParameters.intermediatePreset(
          startLongitude: event.startLongitude,
          startLatitude: event.startLatitude,
        );
        break;
      case DifficultyLevel.hard:
      case DifficultyLevel.expert:
        presetParameters = RouteParameters.advancedPreset(
          startLongitude: event.startLongitude,
          startLatitude: event.startLatitude,
        );
        break;
    }
    
    // Garde quelques paramètres actuels si pertinents
    final mergedParameters = presetParameters.copyWith(
      activityType: state.parameters.activityType, // Garde l'activité sélectionnée
      preferredStartTime: state.parameters.preferredStartTime,
    );
    
    final updatedState = _addToHistory(state, mergedParameters);
    emit(updatedState);
    
    _performImmediateValidation(mergedParameters, emit);
    
    MonitoringService.instance.recordMetric(
      'difficulty_preset_applied',
      1,
      tags: {
        'preset': event.difficulty.id,
        'activity': mergedParameters.activityType.id,
      },
    );
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

  RouteParameters _adjustParametersForActivity(RouteParameters parameters) {
    var adjusted = parameters;
    
    // Ajustements spécifiques par activité
    switch (parameters.activityType) {
      case ActivityType.walking:
        // Pour la marche : réduire la vitesse, accepter plus de pentes
        adjusted = adjusted.copyWith(
          maxInclinePercent: math.min(parameters.maxInclinePercent, 15.0),
          surfacePreference: math.max(parameters.surfacePreference, 0.3), // Plus de chemins naturels
        );
        break;
        
      case ActivityType.cycling:
        // Pour le vélo : limiter les pentes, préférer les routes
        adjusted = adjusted.copyWith(
          maxInclinePercent: math.min(parameters.maxInclinePercent, 12.0),
          surfacePreference: math.min(parameters.surfacePreference, 0.8), // Plus de routes
          avoidHighways: false, // Les cyclistes peuvent utiliser certaines routes principales
        );
        break;
        
      case ActivityType.running:
        // Pour la course : équilibré
        adjusted = adjusted.copyWith(
          maxInclinePercent: math.min(parameters.maxInclinePercent, 15.0),
        );
        break;
    }
    
    // Ajustement de la plage d'élévation selon le terrain
    if (parameters.terrainType == TerrainType.flat && parameters.elevationRange.max > 100) {
      adjusted = adjusted.copyWith(
        elevationRange: ElevationRange(
          min: 0,
          max: math.min(parameters.elevationRange.max, 100),
        ),
      );
    }
    
    return adjusted;
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