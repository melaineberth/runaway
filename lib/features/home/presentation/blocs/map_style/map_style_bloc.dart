import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'map_style_event.dart';
import 'map_style_state.dart';

class MapStyleBloc extends HydratedBloc<MapStyleEvent, MapStyleState> {
  MapStyleBloc() : super(const MapStyleState()) {
    on<MapStyleChanged>(_onMapStyleChanged);
    on<MapRegistered>(_onMapRegistered);
  }

  Future<void> _onMapStyleChanged(
    MapStyleChanged event,
    Emitter<MapStyleState> emit,
  ) async {
    emit(state.copyWith(style: event.style));
    
    // Appliquer le style à la carte si elle est enregistrée
    if (state.map != null) {
      await state.map!.loadStyleURI(event.style.style);
    }
  }

  void _onMapRegistered(
    MapRegistered event,
    Emitter<MapStyleState> emit,
  ) {
    emit(state.copyWith(map: event.map));
  }

  @override
  MapStyleState? fromJson(Map<String, dynamic> json) {
    return MapStyleState.fromJson(json);
  }

  @override
  Map<String, dynamic>? toJson(MapStyleState state) {
    return state.toJson();
  }
}