import 'package:equatable/equatable.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/features/home/domain/models/maps_styles.dart';

class MapStyleState extends Equatable {
  final MapsStyles style;
  final MapboxMap? map;

  const MapStyleState({
    this.style = MapsStyles.dark,
    this.map,
  });

  MapStyleState copyWith({
    MapsStyles? style,
    MapboxMap? map,
  }) {
    return MapStyleState(
      style: style ?? this.style,
      map: map ?? this.map,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'style': style.id,
    };
  }

  factory MapStyleState.fromJson(Map<String, dynamic> json) {
    return MapStyleState(
      style: MapsStyles.values.firstWhere(
        (s) => s.id == json['style'],
        orElse: () => MapsStyles.dark,
      ),
    );
  }

  @override
  List<Object?> get props => [style, map];
}