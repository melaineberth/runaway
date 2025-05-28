import 'package:hugeicons/hugeicons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

enum MapsStyles {
  dark(
    id: 'DARK',
    title: 'Sombre',
    description: "Idéal pour les activités nocturnes ou les environnements peu lumineux.",
    icon: HugeIcons.solidRoundedMoon02,
    style: mp.MapboxStyles.DARK,
  ),
  light(
    id: 'LIGHT',
    title: 'Clair',
    description: "Parfait en plein jour, avec des couleurs douces et lisibles.",
    icon: HugeIcons.solidRoundedSun03,
    style: mp.MapboxStyles.LIGHT,
  ),
  satellite(
    id: 'SATELLITE',
    title: 'Satellite',
    description: "Affiche des images aériennes réalistes pour une vue précise du terrain.",
    icon: HugeIcons.solidRoundedSatellite03,
    style: mp.MapboxStyles.SATELLITE,
  ),
  standard(
    id: 'STANDARD',
    title: 'Standard',
    description: "Vue classique avec un bon équilibre entre détails et lisibilité.",
    icon: HugeIcons.solidRoundedEarth,
    style: mp.MapboxStyles.STANDARD,
  );

  final String id;
  final String title;
  final String description;
  final dynamic icon;
  final String style;

  const MapsStyles({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.style,
  });
}
