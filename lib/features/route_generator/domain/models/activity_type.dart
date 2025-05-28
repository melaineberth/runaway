import 'package:hugeicons/hugeicons.dart';

enum ActivityType {
  running(
    id: 'running',
    title: 'Course',
    icon: HugeIcons.solidRoundedWorkoutRun,
    defaultSpeed: 10.0, // km/h
    minDistance: 1.0,
    maxDistance: 42.0,
    elevationMultiplier: 1.5,
  ),
  cycling(
    id: 'cycling',
    title: 'Vélo',
    icon: HugeIcons.solidRoundedBicycle01,
    defaultSpeed: 20.0, // km/h
    minDistance: 5.0,
    maxDistance: 200.0,
    elevationMultiplier: 1.0,
  );

  final String id;
  final String title;
  final dynamic icon;
  final double defaultSpeed;
  final double minDistance;
  final double maxDistance;
  final double elevationMultiplier;

  const ActivityType({
    required this.id,
    required this.title,
    required this.icon,
    required this.defaultSpeed,
    required this.minDistance,
    required this.maxDistance,
    required this.elevationMultiplier,
  });
}
