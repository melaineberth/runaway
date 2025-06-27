const logger = require('../config/logger');
const turf = require('@turf/turf');

class RouteProblemPreventionService {
  constructor() {
    // Patterns problématiques identifiés
    this.problematicPatterns = {
      // Parcours trop géométriques comme dans les images
      straightLine: {
        name: 'straight_line',
        threshold: 0.15, // Max 15% de déviation de la ligne droite
        severity: 'critical',
        description: 'Route follows nearly straight path'
      },
      
      // Segments droits trop longs
      longStraightSegments: {
        name: 'long_straight_segments',
        maxSegmentRatio: 0.3, // Max 30% du parcours en un segment
        minDirectionChanges: 6, // Min 6 changements de direction
        severity: 'high'
      },
      
      // Formes géométriques simples (rectangle, triangle, etc.)
      geometricShape: {
        name: 'geometric_shape',
        maxShapeCompliance: 0.8, // Max 80% de conformité à une forme géométrique
        severity: 'high'
      },
      
      // Parcours en aller-retour
      backAndForth: {
        name: 'back_and_forth',
        maxBacktrackRatio: 0.4, // Max 40% de retour en arrière
        severity: 'medium'
      },

      // Boucles trop petites ou concentrées
      tightLoop: {
        name: 'tight_loop',
        minBoundingBoxArea: 0.5, // Min 0.5km² de surface couverte
        severity: 'medium'
      }
    };

    // Métriques de qualité minimales
    this.qualityMinimums = {
      directionChanges: 8,           // Minimum 8 changements de direction
      sinuosityRatio: 1.3,          // Minimum 1.3 de sinuosité (distance parcours / distance directe)
      boundingBoxUsage: 0.3,        // Utiliser au moins 30% de la bounding box
      segmentVariation: 0.2,        // Variation des segments d'au moins 20%
      aestheticScore: 0.4           // Score esthétique minimum
    };
  }

  /**
   * Détecte et prévient les parcours problématiques AVANT génération
   */
  async preventProblematicRoute(params, geoAnalysis) {
    logger.info('Analyzing route generation risk', {
      requestId: params.requestId,
      zoneType: geoAnalysis?.zoneType,
      riskLevel: geoAnalysis?.riskLevel
    });

    const preventionStrategy = {
      riskLevel: 'low',
      preventionMeasures: [],
      recommendedAdjustments: {},
      forceOrganicGeneration: false,
      mandatoryWaypoints: 0
    };

    try {
      // 1. Analyse du risque basée sur la géographie
      const geoRisk = this.assessGeographicRisk(params, geoAnalysis);
      preventionStrategy.riskLevel = geoRisk.level;
      preventionStrategy.preventionMeasures.push(...geoRisk.measures);

      // 2. Analyse du risque basée sur les paramètres
      const paramRisk = this.assessParameterRisk(params);
      if (paramRisk.level === 'high') {
        preventionStrategy.riskLevel = 'high';
      } else if (paramRisk.level === 'medium' && preventionStrategy.riskLevel === 'low') {
        preventionStrategy.riskLevel = 'medium';
      }
      preventionStrategy.preventionMeasures.push(...paramRisk.measures);

      // 3. Calcul des ajustements préventifs
      preventionStrategy.recommendedAdjustments = this.calculatePreventiveAdjustments(
        params, 
        preventionStrategy.riskLevel
      );

      // 4. Déterminer si la génération organique est obligatoire
      if (preventionStrategy.riskLevel === 'high' || 
          geoAnalysis?.complexityRating < 0.3) {
        preventionStrategy.forceOrganicGeneration = true;
        preventionStrategy.mandatoryWaypoints = this.calculateMandatoryWaypoints(params);
      }

      logger.info('Route problem prevention analysis completed', {
        requestId: params.requestId,
        riskLevel: preventionStrategy.riskLevel,
        forceOrganic: preventionStrategy.forceOrganicGeneration,
        measuresCount: preventionStrategy.preventionMeasures.length
      });

      return preventionStrategy;

    } catch (error) {
      logger.error('Route problem prevention failed:', error);
      // En cas d'erreur, appliquer des mesures conservatrices
      return {
        riskLevel: 'medium',
        preventionMeasures: ['apply_conservative_generation'],
        recommendedAdjustments: this.getConservativeAdjustments(params),
        forceOrganicGeneration: true,
        mandatoryWaypoints: Math.max(6, Math.floor(params.distanceKm))
      };
    }
  }

  /**
   * Valide un parcours généré pour détecter les patterns problématiques
   */
  validateGeneratedRoute(route, originalParams) {
    const validation = {
      isProblematic: false,
      detectedProblems: [],
      severity: 'none',
      confidence: 0,
      preventionRecommendations: []
    };

    try {
      const coordinates = route.coordinates;
      
      if (!coordinates || coordinates.length < 3) {
        validation.isProblematic = true;
        validation.detectedProblems.push({
          type: 'insufficient_coordinates',
          severity: 'critical',
          description: 'Route has too few coordinates'
        });
        return validation;
      }

      // 1. Détecter les lignes droites
      const straightLineAnalysis = this.detectStraightLinePattern(coordinates);
      if (straightLineAnalysis.isProblematic) {
        validation.detectedProblems.push(straightLineAnalysis);
      }

      // 2. Détecter les formes géométriques simples
      const geometricAnalysis = this.detectGeometricPattern(coordinates);
      if (geometricAnalysis.isProblematic) {
        validation.detectedProblems.push(geometricAnalysis);
      }

      // 3. Détecter les segments droits trop longs
      const longSegmentAnalysis = this.detectLongStraightSegments(coordinates);
      if (longSegmentAnalysis.isProblematic) {
        validation.detectedProblems.push(longSegmentAnalysis);
      }

      // 4. Détecter les allers-retours
      const backtrackAnalysis = this.detectBacktrackingPattern(coordinates);
      if (backtrackAnalysis.isProblematic) {
        validation.detectedProblems.push(backtrackAnalysis);
      }

      // 5. Détecter les boucles trop serrées
      const tightLoopAnalysis = this.detectTightLoopPattern(coordinates, originalParams);
      if (tightLoopAnalysis.isProblematic) {
        validation.detectedProblems.push(tightLoopAnalysis);
      }

      // 6. Évaluation globale
      validation.isProblematic = validation.detectedProblems.length > 0;
      validation.severity = this.calculateOverallSeverity(validation.detectedProblems);
      validation.confidence = this.calculateDetectionConfidence(validation.detectedProblems);
      validation.preventionRecommendations = this.generatePreventionRecommendations(
        validation.detectedProblems, 
        originalParams
      );

      logger.info('Route problem validation completed', {
        requestId: originalParams.requestId,
        isProblematic: validation.isProblematic,
        problemsCount: validation.detectedProblems.length,
        severity: validation.severity,
        confidence: validation.confidence
      });

      return validation;

    } catch (error) {
      logger.error('Route problem validation failed:', error);
      return {
        isProblematic: true,
        detectedProblems: [{ type: 'validation_error', severity: 'high', description: error.message }],
        severity: 'high',
        confidence: 0.9,
        preventionRecommendations: ['regenerate_with_organic_strategy']
      };
    }
  }

  /**
   * Détecte les patterns de ligne droite (comme dans l'image 1)
   */
  detectStraightLinePattern(coordinates) {
    const analysis = {
      isProblematic: false,
      type: 'straight_line_pattern',
      severity: 'critical',
      metrics: {}
    };

    if (coordinates.length < 3) return analysis;

    // Calculer la déviation par rapport à la ligne droite
    const startPoint = coordinates[0];
    const endPoint = coordinates[coordinates.length - 1];
    const directLine = turf.lineString([startPoint, endPoint]);
    const directDistance = turf.length(directLine, { units: 'meters' });

    let maxDeviation = 0;
    let totalDeviation = 0;

    // Mesurer la déviation de chaque point par rapport à la ligne directe
    for (let i = 1; i < coordinates.length - 1; i++) {
      const point = turf.point(coordinates[i]);
      const deviation = turf.pointToLineDistance(point, directLine, { units: 'meters' });
      
      maxDeviation = Math.max(maxDeviation, deviation);
      totalDeviation += deviation;
    }

    const averageDeviation = totalDeviation / (coordinates.length - 2);
    const deviationRatio = maxDeviation / directDistance;

    analysis.metrics = {
      maxDeviation: Math.round(maxDeviation),
      averageDeviation: Math.round(averageDeviation),
      deviationRatio: deviationRatio.toFixed(3),
      directDistance: Math.round(directDistance)
    };

    // Critères de détection de ligne droite problématique
    if (deviationRatio < this.problematicPatterns.straightLine.threshold) {
      analysis.isProblematic = true;
      analysis.description = `Route suit une ligne quasi-droite (déviation max: ${Math.round(maxDeviation)}m, ratio: ${(deviationRatio * 100).toFixed(1)}%)`;
      analysis.confidence = 0.9;
    }

    return analysis;
  }

  /**
   * Détecte les formes géométriques simples (rectangles, etc.)
   */
  detectGeometricPattern(coordinates) {
    const analysis = {
      isProblematic: false,
      type: 'geometric_pattern',
      severity: 'high',
      metrics: {}
    };

    if (coordinates.length < 4) return analysis;

    // Détecter les angles droits ou proches de 90°
    const angles = [];
    for (let i = 1; i < coordinates.length - 1; i++) {
      const bearing1 = turf.bearing(coordinates[i-1], coordinates[i]);
      const bearing2 = turf.bearing(coordinates[i], coordinates[i+1]);
      const angle = Math.abs(bearing1 - bearing2);
      const normalizedAngle = Math.min(angle, 360 - angle);
      angles.push(normalizedAngle);
    }

    // Compter les angles proches de 90° (±15°)
    const rightAngles = angles.filter(angle => Math.abs(angle - 90) < 15).length;
    const rightAngleRatio = rightAngles / angles.length;

    // Détecter les segments de longueur similaire (caractéristique des formes géométriques)
    const segments = [];
    for (let i = 1; i < coordinates.length; i++) {
      const distance = turf.distance(coordinates[i-1], coordinates[i], { units: 'meters' });
      segments.push(distance);
    }

    const avgSegmentLength = segments.reduce((a, b) => a + b, 0) / segments.length;
    const segmentVariation = segments.map(s => Math.abs(s - avgSegmentLength) / avgSegmentLength);
    const uniformityScore = 1 - (segmentVariation.reduce((a, b) => a + b, 0) / segmentVariation.length);

    analysis.metrics = {
      rightAngles: rightAngles,
      rightAngleRatio: rightAngleRatio.toFixed(2),
      averageAngle: (angles.reduce((a, b) => a + b, 0) / angles.length).toFixed(1),
      uniformityScore: uniformityScore.toFixed(2),
      segmentCount: segments.length
    };

    // Critères de détection de forme géométrique
    if (rightAngleRatio > 0.6 && uniformityScore > 0.7) {
      analysis.isProblematic = true;
      analysis.description = `Route forme une shape géométrique (${rightAngles} angles droits, uniformité: ${(uniformityScore * 100).toFixed(0)}%)`;
      analysis.confidence = 0.8;
    }

    return analysis;
  }

  /**
   * Détecte les segments droits trop longs
   */
  detectLongStraightSegments(coordinates) {
    const analysis = {
      isProblematic: false,
      type: 'long_straight_segments',
      severity: 'high',
      metrics: {}
    };

    if (coordinates.length < 4) return analysis;

    let totalDistance = 0;
    let straightDistance = 0;
    let longestStraightSegment = 0;
    let currentStraightLength = 0;

    for (let i = 2; i < coordinates.length; i++) {
      const bearing1 = turf.bearing(coordinates[i-2], coordinates[i-1]);
      const bearing2 = turf.bearing(coordinates[i-1], coordinates[i]);
      const segmentDistance = turf.distance(coordinates[i-1], coordinates[i], { units: 'meters' });
      
      totalDistance += segmentDistance;

      const bearingDiff = Math.abs(bearing1 - bearing2);
      const normalizedDiff = Math.min(bearingDiff, 360 - bearingDiff);

      if (normalizedDiff < 10) { // Segment "droit" si < 10° de différence
        straightDistance += segmentDistance;
        currentStraightLength += segmentDistance;
      } else {
        longestStraightSegment = Math.max(longestStraightSegment, currentStraightLength);
        currentStraightLength = 0;
      }
    }

    longestStraightSegment = Math.max(longestStraightSegment, currentStraightLength);
    const straightRatio = straightDistance / totalDistance;
    const longestSegmentRatio = longestStraightSegment / totalDistance;

    analysis.metrics = {
      straightDistance: Math.round(straightDistance),
      totalDistance: Math.round(totalDistance),
      straightRatio: straightRatio.toFixed(2),
      longestStraightSegment: Math.round(longestStraightSegment),
      longestSegmentRatio: longestSegmentRatio.toFixed(2)
    };

    // Critères problématiques
    if (straightRatio > this.problematicPatterns.longStraightSegments.maxSegmentRatio ||
        longestSegmentRatio > 0.4) {
      analysis.isProblematic = true;
      analysis.description = `Segments droits trop longs (${(straightRatio * 100).toFixed(0)}% du parcours, max: ${Math.round(longestStraightSegment)}m)`;
      analysis.confidence = 0.85;
    }

    return analysis;
  }

  /**
   * Détecte les patterns d'aller-retour
   */
  detectBacktrackingPattern(coordinates) {
    const analysis = {
      isProblematic: false,
      type: 'backtracking_pattern',
      severity: 'medium',
      metrics: {}
    };

    if (coordinates.length < 6) return analysis;

    let backtrackDistance = 0;
    let totalDistance = 0;
    const visited = new Set();

    for (let i = 1; i < coordinates.length; i++) {
      const segmentDistance = turf.distance(coordinates[i-1], coordinates[i], { units: 'meters' });
      totalDistance += segmentDistance;

      // Approximation: vérifier si on passe près d'un point déjà visité
      const currentCoordKey = `${coordinates[i][0].toFixed(4)}_${coordinates[i][1].toFixed(4)}`;
      
      // Chercher des points proches (dans un rayon de ~100m)
      let nearPreviousPoint = false;
      for (let j = 0; j < i - 3; j++) { // Éviter les points immédiatement adjacents
        const distance = turf.distance(coordinates[i], coordinates[j], { units: 'meters' });
        if (distance < 100) {
          nearPreviousPoint = true;
          backtrackDistance += segmentDistance;
          break;
        }
      }

      visited.add(currentCoordKey);
    }

    const backtrackRatio = backtrackDistance / totalDistance;

    analysis.metrics = {
      backtrackDistance: Math.round(backtrackDistance),
      totalDistance: Math.round(totalDistance),
      backtrackRatio: backtrackRatio.toFixed(2),
      visitedPointsCount: visited.size
    };

    if (backtrackRatio > this.problematicPatterns.backAndForth.maxBacktrackRatio) {
      analysis.isProblematic = true;
      analysis.description = `Pattern d'aller-retour détecté (${(backtrackRatio * 100).toFixed(0)}% de backtracking)`;
      analysis.confidence = 0.7;
    }

    return analysis;
  }

  /**
   * Détecte les boucles trop serrées
   */
  detectTightLoopPattern(coordinates, originalParams) {
    const analysis = {
      isProblematic: false,
      type: 'tight_loop',
      severity: 'medium',
      metrics: {}
    };

    if (coordinates.length < 4 || !originalParams.isLoop) return analysis;

    // Calculer la bounding box
    const bbox = turf.bbox(turf.lineString(coordinates));
    const width = bbox[2] - bbox[0]; // longitude
    const height = bbox[3] - bbox[1]; // latitude

    // Approximation de l'aire en km² (très approximative)
    const approxArea = width * height * 111 * 111 / 1000000; // 111km par degré approximativement

    // Calculer le rayon effectif de la boucle
    const center = turf.center(turf.featureCollection(coordinates.map(c => turf.point(c))));
    const distances = coordinates.map(coord => 
      turf.distance(center.geometry.coordinates, coord, { units: 'meters' })
    );
    const avgRadius = distances.reduce((a, b) => a + b, 0) / distances.length;
    const maxRadius = Math.max(...distances);

    analysis.metrics = {
      boundingBoxArea: approxArea.toFixed(3),
      averageRadius: Math.round(avgRadius),
      maxRadius: Math.round(maxRadius),
      radiusVariation: ((maxRadius - avgRadius) / avgRadius).toFixed(2),
      requestedDistance: originalParams.distanceKm
    };

    // Critères de boucle trop serrée
    const expectedMinArea = Math.pow(originalParams.distanceKm / 6, 2); // Aire minimale attendue
    if (approxArea < expectedMinArea || avgRadius < originalParams.distanceKm * 100) {
      analysis.isProblematic = true;
      analysis.description = `Boucle trop concentrée (aire: ${approxArea.toFixed(2)}km², rayon moyen: ${Math.round(avgRadius)}m)`;
      analysis.confidence = 0.75;
    }

    return analysis;
  }

  /**
   * Évalue le risque géographique
   */
  assessGeographicRisk(params, geoAnalysis) {
    const risk = {
      level: 'low',
      measures: []
    };

    if (!geoAnalysis) return risk;

    // Risque élevé pour zones à faible complexité
    if (geoAnalysis.complexityRating < 0.3) {
      risk.level = 'high';
      risk.measures.push('low_geographic_complexity');
    }

    // Risque pour zones urbaines denses (grilles)
    if (geoAnalysis.zoneType === 'urban_dense') {
      risk.level = risk.level === 'low' ? 'medium' : 'high';
      risk.measures.push('urban_grid_risk');
    }

    // Risque pour facteurs problématiques connus
    if (geoAnalysis.problematicFactors && geoAnalysis.problematicFactors.length > 0) {
      const highSeverityFactors = geoAnalysis.problematicFactors.filter(f => f.severity === 'high');
      if (highSeverityFactors.length > 0) {
        risk.level = 'high';
        risk.measures.push('known_problematic_zone');
      }
    }

    return risk;
  }

  /**
   * Évalue le risque basé sur les paramètres
   */
  assessParameterRisk(params) {
    const risk = {
      level: 'low',
      measures: []
    };

    // Risque pour très courtes distances
    if (params.distanceKm < 2) {
      risk.level = 'medium';
      risk.measures.push('very_short_distance');
    }

    // Risque pour longues distances en zone potentiellement simple
    if (params.distanceKm > 30) {
      risk.level = 'medium';
      risk.measures.push('long_distance_monotony_risk');
    }

    // Risque pour certains types d'activité en ville
    if (params.activityType === 'cycling' && params.distanceKm < 5) {
      risk.level = 'medium';
      risk.measures.push('short_cycling_urban_risk');
    }

    return risk;
  }

  /**
   * Calcule les ajustements préventifs
   */
  calculatePreventiveAdjustments(params, riskLevel) {
    const adjustments = {};

    switch (riskLevel) {
      case 'high':
        adjustments.forceOrganicGeneration = true;
        adjustments.organicnessFactor = 0.8;
        adjustments.minimumWaypoints = Math.max(8, Math.floor(params.distanceKm * 1.5));
        adjustments.avoidStraightLines = true;
        adjustments.preferredStrategies = ['organic_natural', 'organic_balanced'];
        break;

      case 'medium':
        adjustments.organicnessFactor = 0.6;
        adjustments.minimumWaypoints = Math.max(6, Math.floor(params.distanceKm));
        adjustments.preferredStrategies = ['organic_balanced', 'controlled_multi_waypoint'];
        break;

      case 'low':
        adjustments.minimumWaypoints = Math.max(4, Math.floor(params.distanceKm * 0.8));
        break;
    }

    return adjustments;
  }

  /**
   * Calcule le nombre de waypoints obligatoires
   */
  calculateMandatoryWaypoints(params) {
    let waypoints = Math.max(6, Math.floor(params.distanceKm * 1.2));
    
    // Ajustements par activité
    if (params.activityType === 'walking') {
      waypoints = Math.floor(waypoints * 1.3); // Plus de waypoints pour la marche
    } else if (params.activityType === 'cycling') {
      waypoints = Math.floor(waypoints * 0.9); // Moins pour le vélo
    }

    return Math.min(15, waypoints); // Maximum 15 waypoints
  }

  /**
   * Génère des ajustements conservateurs
   */
  getConservativeAdjustments(params) {
    return {
      forceOrganicGeneration: true,
      organicnessFactor: 0.7,
      minimumWaypoints: Math.max(8, Math.floor(params.distanceKm * 1.5)),
      avoidStraightLines: true,
      forceCurves: true,
      preferredStrategies: ['organic_natural']
    };
  }

  /**
   * Calcule la sévérité globale
   */
  calculateOverallSeverity(problems) {
    if (problems.length === 0) return 'none';
    
    const criticalCount = problems.filter(p => p.severity === 'critical').length;
    const highCount = problems.filter(p => p.severity === 'high').length;
    
    if (criticalCount > 0) return 'critical';
    if (highCount > 1) return 'critical';
    if (highCount > 0) return 'high';
    return 'medium';
  }

  /**
   * Calcule la confiance de détection
   */
  calculateDetectionConfidence(problems) {
    if (problems.length === 0) return 1.0;
    
    const confidences = problems.map(p => p.confidence || 0.5);
    return confidences.reduce((a, b) => a + b, 0) / confidences.length;
  }

  /**
   * Génère des recommandations de prévention
   */
  generatePreventionRecommendations(problems, originalParams) {
    const recommendations = [];

    const hasGeometricProblems = problems.some(p => 
      p.type === 'geometric_pattern' || p.type === 'straight_line_pattern'
    );

    const hasSegmentProblems = problems.some(p => 
      p.type === 'long_straight_segments'
    );

    if (hasGeometricProblems) {
      recommendations.push({
        action: 'use_organic_generation',
        priority: 'high',
        description: 'Utiliser la génération organique pour éviter les formes géométriques'
      });
    }

    if (hasSegmentProblems) {
      recommendations.push({
        action: 'increase_waypoint_density',
        priority: 'high',
        description: 'Augmenter le nombre de waypoints pour créer plus de variation'
      });
    }

    if (problems.length > 2) {
      recommendations.push({
        action: 'change_generation_strategy',
        priority: 'critical',
        description: 'Changer complètement de stratégie de génération'
      });
    }

    return recommendations;
  }
}

module.exports = new RouteProblemPreventionService();