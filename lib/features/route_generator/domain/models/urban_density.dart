import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';

enum UrbanDensity {
  urban(
    id: 'urban',
    title: 'Urbain',
    description: 'Principalement en ville',
    greenSpaceRatio: 0.1,
    poiDensity: 'high',
  ),
  mixed(
    id: 'mixed',
    title: 'Mixte',
    description: 'Mélange ville et nature',
    greenSpaceRatio: 0.5,
    poiDensity: 'medium',
  ),
  nature(
    id: 'nature',
    title: 'Nature',
    description: 'Principalement en nature',
    greenSpaceRatio: 0.9,
    poiDensity: 'low',
  );

  final String id;
  final String title;
  final String description;
  final double greenSpaceRatio;
  final String poiDensity;

  const UrbanDensity({
    required this.id,
    required this.title,
    required this.description,
    required this.greenSpaceRatio,
    required this.poiDensity,
  });
}

extension ActivityL10n on UrbanDensity {
  /// Renvoie la chaîne localisée pour *cette* valeur de enum.
  String label(BuildContext context) {
    final l10n = context.l10n;     // ou `content.l10n` dans ton widget
    switch (this) {
      case UrbanDensity.nature:
        return l10n.nature;   // clé ARB : "statusPending"
      case UrbanDensity.mixed:
        return l10n.mixedUrbanization;
      case UrbanDensity.urban:
        return l10n.urban;
    }
  }
}

extension ActivityDescL10n on UrbanDensity {
  /// Renvoie la chaîne localisée pour *cette* valeur de enum.
  String desc(BuildContext context) {
    final l10n = context.l10n;     // ou `content.l10n` dans ton widget
    switch (this) {
      case UrbanDensity.nature:
        return l10n.natureDesc;   // clé ARB : "statusPending"
      case UrbanDensity.mixed:
        return l10n.mixedUrbanizationDesc;
      case UrbanDensity.urban:
        return l10n.urbanDesc;
    }
  }
}