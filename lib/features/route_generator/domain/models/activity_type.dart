import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';

enum ActivityType {
  walking(
    id: 'walking',
    title: 'Marche',
    icon: HugeIcons.solidRoundedRunningShoes,
    defaultSpeed: 10.0, // km/h
    minDistance: 1.0,
    maxDistance: 42.0,
    elevationMultiplier: 1.5,
  ),
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

extension ActivityL10n on ActivityType {
  /// Renvoie la chaîne localisée pour *cette* valeur de enum.
  String label(BuildContext context) {
    final l10n = context.l10n;     // ou `content.l10n` dans ton widget
    switch (this) {
      case ActivityType.walking:
        return l10n.walking;   // clé ARB : "statusPending"
      case ActivityType.running:
        return l10n.running;
      case ActivityType.cycling:
        return l10n.cycling;
    }
  }
}