import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';

enum TerrainType {
  flat(
    id: 'flat',
    title: 'Plat',
    description: 'Terrain plat avec peu de dénivelé',
    elevationGain: 0.0, // % du parcours
    maxElevationGain: 50, // m/km
  ),
  mixed(
    id: 'mixed',
    title: 'Mixte',
    description: 'Terrain varié avec dénivelé modéré',
    elevationGain: 0.5,
    maxElevationGain: 100,
  ),
  hilly(
    id: 'hilly',
    title: 'Vallonné',
    description: 'Terrain avec fort dénivelé',
    elevationGain: 1.0,
    maxElevationGain: 200,
  );

  final String id;
  final String title;
  final String description;
  final double elevationGain;
  final int maxElevationGain;

  const TerrainType({
    required this.id,
    required this.title,
    required this.description,
    required this.elevationGain,
    required this.maxElevationGain,
  });
}

extension ActivityTitleL10n on TerrainType {
  /// Renvoie la chaîne localisée pour *cette* valeur de enum.
  String label(BuildContext context) {
    final l10n = context.l10n;     // ou `content.l10n` dans ton widget
    switch (this) {
      case TerrainType.flat:
        return l10n.flat;   // clé ARB : "statusPending"
      case TerrainType.mixed:
        return l10n.mixedTerrain;
      case TerrainType.hilly:
        return l10n.hilly;
    }
  }
}

extension ActivityDescL10n on TerrainType {
  /// Renvoie la chaîne localisée pour *cette* valeur de enum.
  String desc(BuildContext context) {
    final l10n = context.l10n;     // ou `content.l10n` dans ton widget
    switch (this) {
      case TerrainType.flat:
        return l10n.flatDesc;   // clé ARB : "statusPending"
      case TerrainType.mixed:
        return l10n.mixedTerrainDesc;
      case TerrainType.hilly:
        return l10n.hillyDesc;
    }
  }
}