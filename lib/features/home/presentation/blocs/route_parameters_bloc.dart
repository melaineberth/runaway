import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'route_parameters_event.dart';
import 'route_parameters_state.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';

class RouteParametersBloc extends HydratedBloc<RouteParametersEvent, RouteParametersState> {
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
            startLongitude: startLongitude,
            startLatitude: startLatitude,
          ),
          history: [
            RouteParameters(
              activityType: ActivityType.running,
              terrainType: TerrainType.mixed,
              urbanDensity: UrbanDensity.mixed,
              distanceKm: 5.0,
              elevationGain: 0.0,
              startLongitude: startLongitude,
              startLatitude: startLatitude,
            ),
          ],
          historyIndex: 0,
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
  }

  void _onActivityTypeChanged(
    ActivityTypeChanged event,
    Emitter<RouteParametersState> emit,
  ) {
    final type = event.activityType;
    double newDistance = state.parameters.distanceKm;
    
    if (newDistance < type.minDistance) {
      newDistance = type.minDistance;
    } else if (newDistance > type.maxDistance) {
      newDistance = type.maxDistance;
    }

    _updateParameters(
      emit,
      state.parameters.copyWith(
        activityType: type,
        distanceKm: newDistance,
      ),
    );
  }

  void _onTerrainTypeChanged(
    TerrainTypeChanged event,
    Emitter<RouteParametersState> emit,
  ) {
    // ✅ CORRECTION : Ne plus forcer une élévation "suggérée"
    // Juste vérifier que l'élévation actuelle ne dépasse pas le nouveau maximum du terrain
    final maxElevation = state.parameters.distanceKm * event.terrainType.maxElevationGain;
    final currentElevation = state.parameters.elevationGain;
    final adjustedElevation = currentElevation > maxElevation ? maxElevation : currentElevation;
    
    _updateParameters(
      emit,
      state.parameters.copyWith(
        terrainType: event.terrainType,
        elevationGain: adjustedElevation, // ✅ Garde la valeur actuelle ou l'ajuste au max si nécessaire
      ),
    );
  }

  void _onUrbanDensityChanged(
    UrbanDensityChanged event,
    Emitter<RouteParametersState> emit,
  ) {
    _updateParameters(
      emit,
      state.parameters.copyWith(urbanDensity: event.urbanDensity),
    );
  }

  void _onDistanceChanged(
    DistanceChanged event,
    Emitter<RouteParametersState> emit,
  ) {
    final km = event.distanceKm;
    
    if (km < state.parameters.activityType.minDistance || 
        km > state.parameters.activityType.maxDistance) {
      emit(state.copyWith(
        errorMessage: 'Distance invalide pour ${state.parameters.activityType.title}',
      ));
      return;
    }
    
    // ✅ CORRECTION : Ne plus modifier automatiquement l'élévation
    // Juste vérifier que l'élévation actuelle ne dépasse pas le nouveau maximum
    final maxElevation = km * state.parameters.terrainType.maxElevationGain;
    final currentElevation = state.parameters.elevationGain;
    final adjustedElevation = currentElevation > maxElevation ? maxElevation : currentElevation;

    _updateParameters(
      emit,
      state.parameters.copyWith(
        distanceKm: km,
        elevationGain: adjustedElevation, // ✅ Garde la valeur actuelle ou l'ajuste au max si nécessaire
      ),
    );
  }

  void _onElevationGainChanged(
    ElevationGainChanged event,
    Emitter<RouteParametersState> emit,
  ) {
    if (event.elevationGain < 0) return;

    final maxElevation = state.parameters.distanceKm * state.parameters.terrainType.maxElevationGain;
    final elevation = event.elevationGain > maxElevation ? maxElevation : event.elevationGain;

    _updateParameters(
      emit,
      state.parameters.copyWith(elevationGain: elevation),
    );
  }

  void _onStartLocationUpdated(
    StartLocationUpdated event,
    Emitter<RouteParametersState> emit,
  ) {
    _updateParameters(
      emit,
      state.parameters.copyWith(
        startLongitude: event.longitude,
        startLatitude: event.latitude,
      ),
    );
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

  void _onLoopToggled(
    LoopToggled event,
    Emitter<RouteParametersState> emit,
  ) {
    _updateParameters(
      emit,
      state.parameters.copyWith(isLoop: event.isLoop),
    );
  }

  void _onAvoidTrafficToggled(
    AvoidTrafficToggled event,
    Emitter<RouteParametersState> emit,
  ) {
    _updateParameters(
      emit,
      state.parameters.copyWith(avoidTraffic: event.avoidTraffic),
    );
  }

  void _onPreferScenicToggled(
    PreferScenicToggled event,
    Emitter<RouteParametersState> emit,
  ) {
    _updateParameters(
      emit,
      state.parameters.copyWith(preferScenic: event.preferScenic),
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