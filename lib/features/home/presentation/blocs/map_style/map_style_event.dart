import 'package:equatable/equatable.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/features/home/domain/models/maps_styles.dart';

abstract class MapStyleEvent extends Equatable {
  const MapStyleEvent();

  @override
  List<Object?> get props => [];
}

class MapStyleChanged extends MapStyleEvent {
  final MapsStyles style;

  const MapStyleChanged(this.style);

  @override
  List<Object?> get props => [style];
}

class MapRegistered extends MapStyleEvent {
  final MapboxMap map;

  const MapRegistered(this.map);

  @override
  List<Object?> get props => [map];
}