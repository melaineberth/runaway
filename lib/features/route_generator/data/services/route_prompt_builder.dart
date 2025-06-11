// features/route_generator/data/services/route_prompt_builder.dart
import 'dart:convert';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

/// Builder pour construire des prompts intelligents pour l'IA
class RoutePromptBuilder {
  
  /// Construit un prompt avancé pour la génération de parcours
  static String buildAdvancedPrompt({
    required RouteParameters parameters,
    required Map<String, dynamic> networkData,
    required List<Map<String, dynamic>> poisData,
  }) {
    final buffer = StringBuffer();
    
    // 1. Contexte et objectif
    buffer.writeln(_buildContextSection(parameters));
    
    // 2. Données réseau
    buffer.writeln(_buildNetworkSection(networkData));
    
    // 3. Points d'intérêt
    buffer.writeln(_buildPoisSection(poisData));
    
    // 4. Instructions spécifiques
    buffer.writeln(_buildInstructionsSection(parameters));
    
    // 5. Format de sortie
    buffer.writeln(_buildOutputFormatSection());
    
    return buffer.toString();
  }

  /// Section contexte et objectif
  static String _buildContextSection(RouteParameters parameters) {
    final activity = parameters.activityType.title.toLowerCase();
    // final terrain = parameters.terrainType.title.toLowerCase();
    // final urbanDensity = parameters.urbanDensity.title.toLowerCase();
    
    return '''
=== CONTEXTE DE GÉNÉRATION ===

OBJECTIF: Créer un parcours de $activity de ${parameters.distanceKm} km

PARAMÈTRES UTILISATEUR:
- Activité: ${parameters.activityType.title}
- Distance cible: ${parameters.distanceKm} km
- Type de terrain: ${parameters.terrainType.title} (${parameters.terrainType.description})
- Urbanisation: ${parameters.urbanDensity.title} (${parameters.urbanDensity.description})
- Dénivelé souhaité: ${parameters.elevationGain.toStringAsFixed(0)} m
- Type de parcours: ${parameters.isLoop ? 'Boucle (retour au point de départ)' : 'Aller simple'}
- Éviter le trafic: ${parameters.avoidTraffic ? 'Oui' : 'Non'}
- Parcours pittoresque: ${parameters.preferScenic ? 'Oui' : 'Non'}

POINT DE DÉPART: [${parameters.startLongitude}, ${parameters.startLatitude}]

PRÉFÉRENCES SPÉCIFIQUES:
${_getActivitySpecificPreferences(parameters)}
${_getTerrainSpecificPreferences(parameters)}
${_getUrbanDensityPreferences(parameters)}
''';
  }

  /// Section données réseau
  static String _buildNetworkSection(Map<String, dynamic> networkData) {
    final network = networkData['network'] as List;
    final stats = networkData['statistics'] as Map<String, dynamic>;
    
    return '''
=== RÉSEAU DE CHEMINS DISPONIBLE ===

STATISTIQUES GÉNÉRALES:
- Segments total: ${stats['total_segments']}
- Distance totale: ${stats['total_length_km']} km
- Segments de qualité: ${stats['quality_segments']}
- Segments dans les parcs: ${stats['park_segments']}
- Segments en nature: ${stats['nature_segments']}

TYPES DE CHEMINS DISPONIBLES:
${_analyzeNetworkTypes(network)}

ÉCHANTILLON DU RÉSEAU (premiers 5 segments):
${_formatNetworkSample(network.take(5).toList())}

[... Le réseau complet contient ${network.length} segments ...]

RÉSEAU COMPLET:
${jsonEncode(network)}
''';
  }

  /// Section points d'intérêt
  static String _buildPoisSection(List<Map<String, dynamic>> poisData) {
    if (poisData.isEmpty) {
      return '''
=== POINTS D'INTÉRÊT ===
Aucun POI disponible dans cette zone.
''';
    }

    final poiByType = <String, List<Map<String, dynamic>>>{};
    for (final poi in poisData) {
      final type = poi['type'] as String;
      poiByType.putIfAbsent(type, () => []).add(poi);
    }

    final buffer = StringBuffer();
    buffer.writeln('=== POINTS D\'INTÉRÊT (${poisData.length} total) ===');
    buffer.writeln();
    
    for (final entry in poiByType.entries) {
      buffer.writeln('${entry.key.toUpperCase()} (${entry.value.length}):');
      for (final poi in entry.value.take(3)) { // Max 3 par type pour le prompt
        buffer.writeln('- ${poi['name']}: ${poi['coordinates']} (${poi['distance_from_center']}m du centre)');
      }
      if (entry.value.length > 3) {
        buffer.writeln('... et ${entry.value.length - 3} autres');
      }
      buffer.writeln();
    }

    buffer.writeln('DONNÉES COMPLÈTES:');
    buffer.writeln(jsonEncode(poisData));

    return buffer.toString();
  }

  /// Section instructions spécifiques
  static String _buildInstructionsSection(RouteParameters parameters) {
    return '''
=== INSTRUCTIONS DE GÉNÉRATION ===

RÈGLES ABSOLUES:
1. Utilise UNIQUEMENT les segments fournis dans le réseau
2. Respecte la distance de ${parameters.distanceKm} km (tolérance ±10%)
3. Assure la CONTINUITÉ du parcours (chaque point doit être connecté au suivant)
4. Le parcours doit être PRATICABLE pour ${parameters.activityType.title.toLowerCase()}
5. ${parameters.isLoop ? 'RETOUR OBLIGATOIRE au point de départ' : 'Parcours en aller simple'}

PRIORITÉS PAR ORDRE D'IMPORTANCE:
1. SÉCURITÉ: Évite les routes dangereuses, privilégie les chemins dédiés
2. QUALITÉ: Utilise les segments avec quality_score élevé
3. COHÉRENCE: Respecte les préférences de terrain et d'urbanisation
4. AGRÉMENT: Intègre les POIs pertinents quand possible
5. OPTIMISATION: Minimise les détours inutiles

CRITÈRES SPÉCIFIQUES:
${_getGenerationCriteria(parameters)}

GESTION DES POIs:
- Intègre les POIs pertinents sans détour excessif (max 200m)
- Privilégie: ${_getPriorityPois(parameters)}
- Évite les détours pour les POIs peu pertinents

VALIDATION REQUISE:
- Vérifier que chaque segment existe dans le réseau fourni
- Vérifier la continuité géographique
- Calculer la distance réelle du parcours
''';
  }

  /// Section format de sortie
  static String _buildOutputFormatSection() {
    return '''
=== FORMAT DE RÉPONSE REQUIS ===

Tu DOIS répondre avec un JSON valide et UNIQUEMENT ce JSON:

{
  "route": {
    "coordinates": [
      [longitude, latitude],
      [longitude, latitude],
      ...
    ],
    "metadata": {
      "distance_km": "X.XX",
      "estimated_duration_minutes": X,
      "elevation_gain_m": X,
      "route_type": "loop|one_way",
      "segments_used": X,
      "quality_score": X.X,
      "pois_included": X,
      "surface_breakdown": {
        "asphalt": "XX%",
        "gravel": "XX%",
        "dirt": "XX%",
        "other": "XX%"
      },
      "environment_breakdown": {
        "urban": "XX%",
        "park": "XX%",
        "nature": "XX%",
        "mixed": "XX%"
      }
    },
    "reasoning": "Explication concise de la logique de construction du parcours",
    "included_pois": [
      {
        "name": "Nom du POI",
        "type": "Type",
        "coordinates": [lon, lat],
        "integration_reason": "Pourquoi inclus"
      }
    ],
    "quality_assessment": {
      "safety_score": X.X,
      "scenic_score": X.X,
      "technical_difficulty": "easy|moderate|hard",
      "traffic_exposure": "low|moderate|high"
    }
  }
}

IMPORTANT:
- Les coordonnées doivent être des nombres réels, pas des chaînes
- La distance doit être précise et respecter la cible
- Le raisonnement doit expliquer les choix principaux
- Tous les segments utilisés doivent exister dans le réseau fourni
''';
  }

  /// Analyse les types de chemins disponibles
  static String _analyzeNetworkTypes(List<dynamic> network) {
    final typeCount = <String, int>{};
    final surfaceCount = <String, int>{};
    
    for (final segment in network) {
      final type = segment['type'] as String?;
      final surface = segment['surface'] as String?;
      
      if (type != null) {
        typeCount[type] = (typeCount[type] ?? 0) + 1;
      }
      if (surface != null) {
        surfaceCount[surface] = (surfaceCount[surface] ?? 0) + 1;
      }
    }

    final buffer = StringBuffer();
    
    buffer.writeln('Types de voies:');
    typeCount.entries.forEach((e) => buffer.writeln('- ${e.key}: ${e.value} segments'));
    
    buffer.writeln('\nSurfaces:');
    surfaceCount.entries.forEach((e) => buffer.writeln('- ${e.key}: ${e.value} segments'));
    
    return buffer.toString();
  }

  /// Formate un échantillon du réseau
  static String _formatNetworkSample(List<dynamic> sample) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < sample.length; i++) {
      final segment = sample[i];
      buffer.writeln('''
${i + 1}. ID: ${segment['id']} | Type: ${segment['type']} | Surface: ${segment['surface']}
   Longueur: ${segment['length_m']}m | Qualité: ${segment['quality_score']}
   Start: ${segment['start']} → End: ${segment['end']}
   Running: ${segment['suitable_running']} | Cycling: ${segment['suitable_cycling']}''');
    }
    
    return buffer.toString();
  }

  /// Obtient les préférences spécifiques à l'activité
  static String _getActivitySpecificPreferences(RouteParameters parameters) {
    switch (parameters.activityType.id) {
      case 'running':
        return '''
- Privilégier: footway, path, cycleway avec surface douce
- Éviter: primary, secondary, trunk (routes principales)
- Accepter: residential avec traffic_calming
- Préférer: surfaces asphalt, paved, gravel fin''';
      
      case 'cycling':
        return '''
- Privilégier: cycleway, residential, service
- Accepter: unclassified, tertiary si bicycle=yes
- Éviter: footway sauf si bicycle=designated
- Préférer: surfaces asphalt, paved, concrete''';
      
      default:
        return '- Chemins mixtes acceptés selon surface et sécurité';
    }
  }

  /// Obtient les préférences spécifiques au terrain
  static String _getTerrainSpecificPreferences(RouteParameters parameters) {
    switch (parameters.terrainType.id) {
      case 'flat':
        return '''
- Éviter les segments avec fort dénivelé
- Privilégier les zones plates (parks, residential)
- Limiter elevation_gain total''';
      
      case 'hilly':
        return '''
- Rechercher activement des segments avec dénivelé
- Accepter les tracks et paths en montée
- Intégrer des portions vallonnées''';
      
      case 'mixed':
        return '''
- Équilibrer entre zones plates et vallonnées
- Varier les types de terrain dans le parcours''';
      
      default:
        return '';
    }
  }

  /// Obtient les préférences de densité urbaine
  static String _getUrbanDensityPreferences(RouteParameters parameters) {
    switch (parameters.urbanDensity.id) {
      case 'urban':
        return '''
- Privilégier: residential, service, pedestrian
- Utiliser: sidewalks, urban parks
- Éviter: tracks, paths en nature''';
      
      case 'nature':
        return '''
- Privilégier: is_in_nature=true, is_in_park=true
- Utiliser: tracks, paths, natural=*
- Éviter: residential dense, commercial''';
      
      case 'mixed':
        return '''
- Équilibrer entre urbain et nature
- Transitions progressives entre environnements''';
      
      default:
        return '';
    }
  }

  /// Obtient les critères de génération
  static String _getGenerationCriteria(RouteParameters parameters) {
    final buffer = StringBuffer();
    
    if (parameters.avoidTraffic) {
      buffer.writeln('- ÉVITER: routes avec trafic important (primary, secondary, trunk)');
      buffer.writeln('- PRIVILÉGIER: living_street, traffic_calming zones');
    }
    
    if (parameters.preferScenic) {
      buffer.writeln('- PRIVILÉGIER: segments avec is_in_park=true ou is_in_nature=true');
      buffer.writeln('- RECHERCHER: waterway proximity, natural features');
    }
    
    buffer.writeln('- QUALITÉ MINIMUM: quality_score >= 5');
    buffer.writeln('- LONGUEUR SEGMENT: entre 50m et 2000m idéalement');
    
    return buffer.toString();
  }

  /// Obtient les POIs prioritaires
  static String _getPriorityPois(RouteParameters parameters) {
    final priorities = <String>[];
    
    switch (parameters.activityType.id) {
      case 'running':
        priorities.addAll(['Parc', 'Eau potable', 'Toilettes', 'Point de vue']);
        break;
      case 'cycling':
        priorities.addAll(['Parc', 'Point de vue', 'Eau potable']);
        break;
    }
    
    if (parameters.preferScenic) {
      priorities.insertAll(0, ['Point de vue', 'Point d\'eau', 'Parc']);
    }
    
    return priorities.join(', ');
  }
}