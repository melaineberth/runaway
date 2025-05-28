import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/features/home/domain/models/maps_styles.dart';

class MapsParametersController extends ChangeNotifier {
  MapsStyles _mapsStyles = MapsStyles.standard;
  MapboxMap? _mapboxMap;

  MapsStyles get mapsStyles => _mapsStyles;

  void registerMap(MapboxMap map) {
    _mapboxMap = map;
  }

  Future<void> setMapStyle(MapsStyles newStyle) async {
    if (_mapsStyles != newStyle) {
      _mapsStyles = newStyle;
      notifyListeners();
      if (_mapboxMap != null) {
        await _mapboxMap!.loadStyleURI(newStyle.style);
      }
    }
  }
}
