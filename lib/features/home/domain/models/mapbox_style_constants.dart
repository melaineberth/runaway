import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class MapboxStyleData {
  final String id;
  final String name;
  final String uri;
  final IconData icon;
  final Color color;

  const MapboxStyleData({
    required this.id,
    required this.name,
    required this.uri,
    required this.icon,
    required this.color,
  });
}

class MapboxStyleConstants {
  static const List<MapboxStyleData> availableStyles = [
    MapboxStyleData(
      id: 'streets',
      name: 'Rues',
      uri: 'mapbox://styles/mapbox/streets-v12',
      icon: HugeIcons.strokeRoundedBuilding03,
      color: Color(0xFF4A90E2),
    ),
    MapboxStyleData(
      id: 'outdoors',
      name: 'Extérieur',
      uri: 'mapbox://styles/mapbox/outdoors-v12',
      icon: HugeIcons.strokeRoundedMountain,
      color: Color(0xFF7ED321),
    ),
    MapboxStyleData(
      id: 'light',
      name: 'Clair',
      uri: 'mapbox://styles/mapbox/light-v11',
      icon: HugeIcons.strokeRoundedSun03,
      color: Color(0xFFF5A623),
    ),
    MapboxStyleData(
      id: 'dark',
      name: 'Sombre',
      uri: 'mapbox://styles/mapbox/dark-v11',
      icon: HugeIcons.strokeRoundedMoon02,
      color: Color(0xFF9013FE),
    ),
    MapboxStyleData(
      id: 'satellite',
      name: 'Satellite',
      uri: 'mapbox://styles/mapbox/satellite-v9',
      icon: HugeIcons.strokeRoundedEarth,
      color: Color(0xFF50E3C2),
    ),
    MapboxStyleData(
      id: 'satellite_streets',
      name: 'Hybride',
      uri: 'mapbox://styles/mapbox/satellite-streets-v12',
      icon: HugeIcons.strokeRoundedLayers01,
      color: Color(0xFFBD10E0),
    ),
  ];

  static MapboxStyleData getStyleById(String id) {
    return availableStyles.firstWhere(
      (style) => style.id == id,
      orElse: () => availableStyles.first,
    );
  }

  static String getDefaultStyleId() => 'dark';
}