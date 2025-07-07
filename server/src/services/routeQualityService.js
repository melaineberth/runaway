const logger = require('../config/logger');
const turf = require('@turf/turf');

class RouteQualityService {
  constructor() {
    this.qualityThresholds = {
      distance: {
        minAcceptableRatio: 0.70,  // Assoupli de 0.85 à 0.70
        maxAcceptableRatio: 1.30,  // Assoupli de 1.15 à 1.30
        criticalRatio: 0.4         // Assoupli de 0.5 à 0.4
      },
      coordinates: {
        minPoints: 10,             // Réduit de 15 à 10
        maxGapMeters: 1000,        // Augmenté de 800 à 1000
        maxSpeed: 150
      },
      loop: {
        maxEndDistanceMeters: 200  // Augmenté de 150 à 200
      },
      aesthetics: {
        minDirectionChanges: 4,    // Réduit de 8 à 4
        maxStraightSegmentRatio: 0.5, // Augmenté de 0.4 à 0.5
        minComplexityScore: 0.2,   // Réduit de 0.3 à 0.2
        preferredTurnAngleRange: [20, 160] // Élargi
      }
    };
  }  

  /**
   * Valide la qualité avec critères esthétiques améliorés
   */
  validateRoute(route, requestedParams) {
    const validationResult = {
      isValid: true,
      quality: 'excellent',
      issues: [],
      metrics: {},
      suggestions: []
    };

    try {
      // Validations existantes
      const distanceValidation = this.validateDistance(route, requestedParams);
      const coordinatesValidation = this.validateCoordinates(route.coordinates);
      
      // NOUVELLES VALIDATIONS ESTHÉTIQUES
      const aestheticsValidation = this.validateAesthetics(route.coordinates);
      const complexityValidation = this.validateComplexity(route.coordinates);
      const interestValidation = this.validateInterest(route.coordinates, requestedParams);

      validationResult.metrics = {
        distance: distanceValidation,
        coordinates: coordinatesValidation,
        aesthetics: aestheticsValidation,
        complexity: complexityValidation,
        interest: interestValidation
      };

      // Compilation des problèmes
      [distanceValidation, coordinatesValidation, aestheticsValidation, complexityValidation, interestValidation]
        .forEach(validation => {
          if (!validation.isValid) {
            validationResult.isValid = false;
            if (validation.issue) validationResult.issues.push(validation.issue);
            if (validation.issues) validationResult.issues.push(...validation.issues);
            if (validation.suggestion) validationResult.suggestions.push(validation.suggestion);
            if (validation.suggestions) validationResult.suggestions.push(...validation.suggestions);
          }
        });

      // Validation spéciale pour les boucles
      if (requestedParams.isLoop) {
        const loopValidation = this.validateLoop(route.coordinates);
        validationResult.metrics.loop = loopValidation;
        
        if (!loopValidation.isValid) {
          validationResult.isValid = false;
          validationResult.issues.push(loopValidation.issue);
          validationResult.suggestions.push(loopValidation.suggestion);
        }
      }

      // Calcul de la qualité globale avec nouveaux critères
      validationResult.quality = this.calculateEnhancedQuality(validationResult.metrics);

      logger.info('Enhanced route quality validation completed', {
        isValid: validationResult.isValid,
        quality: validationResult.quality,
        issuesCount: validationResult.issues.length,
        aestheticsScore: aestheticsValidation.score,
        complexityScore: complexityValidation.score
      });

      return validationResult;

    } catch (error) {
      logger.error('Route quality validation failed:', error);
      return {
        isValid: false,
        quality: 'error',
        issues: ['Validation failed: ' + error.message],
        metrics: {},
        suggestions: ['Please try generating the route again']
      };
    }
  }

  /**
   * NOUVELLE : Validation des aspects esthétiques
   */
  validateAesthetics(coordinates) {
    const validation = {
      isValid: true,
      score: 0,
      issues: [],
      suggestions: [],
      metrics: {}
    };
  
    // 1. Analyse des changements de direction - ✅ ASSOUPLI
    const directionChanges = this.analyzeDirectionChanges(coordinates);
    validation.metrics.directionChanges = directionChanges.count;
    
    if (directionChanges.count < 6) { // ✅ RÉDUIT de 8 à 6
      validation.isValid = false;
      validation.issues.push(`Parcours trop monotone: seulement ${directionChanges.count} changements de direction`);
      validation.suggestions.push('Ajouter des waypoints intermédiaires pour plus de variété');
    }
  
    // 2. Analyse des segments droits - ✅ ASSOUPLI
    const straightSegments = this.analyzeStraightSegments(coordinates);
    validation.metrics.straightSegmentRatio = straightSegments.ratio;
    
    if (straightSegments.ratio > 0.5) { // ✅ AUGMENTÉ de 0.4 à 0.5
      validation.isValid = false;
      validation.issues.push(`Trop de segments droits: ${(straightSegments.ratio * 100).toFixed(1)}%`);
      validation.suggestions.push('Créer un parcours plus sinueux avec des courbes naturelles');
    }
  
    // 3. Analyse de la distribution des angles
    const angleDistribution = this.analyzeAngleDistribution(coordinates);
    validation.metrics.angleDistribution = angleDistribution;
    
    if (angleDistribution.sharpTurns > 8) { // ✅ AUGMENTÉ de 5 à 8
      validation.issues.push(`Trop de virages serrés: ${angleDistribution.sharpTurns}`);
      validation.suggestions.push('Éviter les virages à angle droit pour un parcours plus fluide');
    }
  
    // 4. Score esthétique global - ✅ SEUIL ASSOUPLI
    validation.score = this.calculateAestheticsScore(validation.metrics);
    
    if (validation.score < 0.25) { // ✅ RÉDUIT de 0.3 à 0.25
      validation.isValid = false;
      validation.issues.push(`Score esthétique insuffisant: ${validation.score.toFixed(2)}`);
    }
  
    return validation;
  }

  /**
   * NOUVELLE : Validation de la complexité du parcours
   */
  validateComplexity(coordinates) {
    const validation = {
      isValid: true,
      score: 0,
      metrics: {}
    };

    // 1. Calcul de la complexité géométrique
    const geometricComplexity = this.calculateGeometricComplexity(coordinates);
    validation.metrics.geometric = geometricComplexity;

    // 2. Analyse de la répartition spatiale
    const spatialDistribution = this.analyzeSpatialDistribution(coordinates);
    validation.metrics.spatial = spatialDistribution;

    // 3. Calcul du facteur de sinuosité
    const sinuosity = this.calculateSinuosity(coordinates);
    validation.metrics.sinuosity = sinuosity;

    // Score de complexité global
    validation.score = (geometricComplexity + spatialDistribution.score + sinuosity) / 3;

    if (validation.score < 0.4) {
      validation.isValid = false;
      validation.issue = `Parcours trop simple: score de complexité ${validation.score.toFixed(2)}`;
      validation.suggestion = 'Utiliser plus de waypoints pour créer un parcours plus complexe';
    }

    return validation;
  }

  /**
   * NOUVELLE : Validation de l'intérêt du parcours
   */
  validateInterest(coordinates, params) {
    const validation = {
      isValid: true,
      score: 0,
      metrics: {}
    };

    // 1. Vérifier la variété des environnements traversés
    const environmentVariety = this.analyzeEnvironmentVariety(coordinates);
    validation.metrics.environmentVariety = environmentVariety;

    // 2. Analyser la découverte progressive
    const explorationScore = this.calculateExplorationScore(coordinates);
    validation.metrics.exploration = explorationScore;

    // 3. Vérifier l'équilibre du parcours
    const balance = this.analyzeRouteBalance(coordinates);
    validation.metrics.balance = balance;

    validation.score = (environmentVariety + explorationScore + balance.score) / 3;

    if (validation.score < 0.3) {
      validation.isValid = false;
      validation.issue = `Parcours peu intéressant: score ${validation.score.toFixed(2)}`;
      validation.suggestion = 'Choisir un tracé qui explore différentes zones';
    }

    return validation;
  }

  // ============= MÉTHODES D'ANALYSE ESTHÉTIQUE =============

  analyzeDirectionChanges(coordinates) {
    let changes = 0;
    let previousBearing = null;

    for (let i = 1; i < coordinates.length; i++) {
      const bearing = turf.bearing(coordinates[i-1], coordinates[i]);
      
      if (previousBearing !== null) {
        const bearingDiff = Math.abs(bearing - previousBearing);
        const normalizedDiff = Math.min(bearingDiff, 360 - bearingDiff);
        
        if (normalizedDiff > 15) { // Changement significatif > 15°
          changes++;
        }
      }
      
      previousBearing = bearing;
    }

    return { count: changes, frequency: changes / coordinates.length };
  }

  analyzeStraightSegments(coordinates) {
    let straightDistance = 0;
    let totalDistance = 0;
    let currentStraightStart = 0;

    for (let i = 2; i < coordinates.length; i++) {
      const bearing1 = turf.bearing(coordinates[i-2], coordinates[i-1]);
      const bearing2 = turf.bearing(coordinates[i-1], coordinates[i]);
      const bearingDiff = Math.abs(bearing1 - bearing2);
      const normalizedDiff = Math.min(bearingDiff, 360 - bearingDiff);

      const segmentDistance = turf.distance(coordinates[i-1], coordinates[i], { units: 'meters' });
      totalDistance += segmentDistance;

      if (normalizedDiff < 10) { // Segment "droit" si < 10° de différence
        straightDistance += segmentDistance;
      }
    }

    return {
      ratio: straightDistance / totalDistance,
      straightDistance,
      totalDistance
    };
  }

  analyzeAngleDistribution(coordinates) {
    const angles = [];
    
    for (let i = 1; i < coordinates.length - 1; i++) {
      const bearing1 = turf.bearing(coordinates[i-1], coordinates[i]);
      const bearing2 = turf.bearing(coordinates[i], coordinates[i+1]);
      const angle = Math.abs(bearing1 - bearing2);
      const normalizedAngle = Math.min(angle, 360 - angle);
      angles.push(normalizedAngle);
    }

    return {
      average: angles.reduce((a, b) => a + b, 0) / angles.length,
      sharpTurns: angles.filter(a => a > 120).length,
      gentleTurns: angles.filter(a => a >= 30 && a <= 90).length,
      angles
    };
  }

  calculateAestheticsScore(metrics) {
    let score = 0;

    // Score basé sur les changements de direction (30%)
    const directionScore = Math.min(metrics.directionChanges / 15, 1);
    score += directionScore * 0.3;

    // Score basé sur le ratio de segments droits (30%)
    const straightScore = 1 - Math.min(metrics.straightSegmentRatio / 0.4, 1);
    score += straightScore * 0.3;

    // Score basé sur la distribution des angles (40%)
    const angleScore = metrics.angleDistribution.gentleTurns / 
                     (metrics.angleDistribution.gentleTurns + metrics.angleDistribution.sharpTurns + 1);
    score += angleScore * 0.4;

    return Math.max(0, Math.min(1, score));
  }

  calculateGeometricComplexity(coordinates) {
    if (coordinates.length < 3) return 0;

    // Calculer la fractal dimension approximative
    let totalLength = 0;
    let boundingBoxDiagonal = 0;

    // Longueur totale du parcours
    for (let i = 1; i < coordinates.length; i++) {
      totalLength += turf.distance(coordinates[i-1], coordinates[i], { units: 'meters' });
    }

    // Diagonale de la bounding box
    const bbox = turf.bbox(turf.lineString(coordinates));
    const sw = [bbox[0], bbox[1]];
    const ne = [bbox[2], bbox[3]];
    boundingBoxDiagonal = turf.distance(sw, ne, { units: 'meters' });

    // Ratio de complexité
    const complexity = boundingBoxDiagonal > 0 ? totalLength / boundingBoxDiagonal : 0;
    
    // Normaliser entre 0 et 1
    return Math.min(1, Math.max(0, (complexity - 1) / 3));
  }

  analyzeSpatialDistribution(coordinates) {
    // Analyser comment les points sont distribués dans l'espace
    const bbox = turf.bbox(turf.lineString(coordinates));
    const width = bbox[2] - bbox[0];
    const height = bbox[3] - bbox[1];
    
    // Diviser en grille et compter les cellules visitées
    const gridSize = 10;
    const cellWidth = width / gridSize;
    const cellHeight = height / gridSize;
    const visitedCells = new Set();

    coordinates.forEach(coord => {
      const cellX = Math.floor((coord[0] - bbox[0]) / cellWidth);
      const cellY = Math.floor((coord[1] - bbox[1]) / cellHeight);
      visitedCells.add(`${cellX}-${cellY}`);
    });

    const coverage = visitedCells.size / (gridSize * gridSize);
    
    return {
      coverage,
      visitedCells: visitedCells.size,
      totalCells: gridSize * gridSize,
      score: coverage
    };
  }

  calculateSinuosity(coordinates) {
    if (coordinates.length < 2) return 0;

    // Distance directe entre début et fin
    const directDistance = turf.distance(
      coordinates[0], 
      coordinates[coordinates.length - 1], 
      { units: 'meters' }
    );

    // Distance totale du parcours
    let totalDistance = 0;
    for (let i = 1; i < coordinates.length; i++) {
      totalDistance += turf.distance(coordinates[i-1], coordinates[i], { units: 'meters' });
    }

    // Sinuosité = distance parcours / distance directe
    const sinuosity = directDistance > 0 ? totalDistance / directDistance : 1;
    
    // Normaliser : sinuosité idéale entre 1.5 et 3
    if (sinuosity < 1.5) return 0.3; // Trop direct
    if (sinuosity > 3) return 0.7;   // Trop sinueux
    
    return Math.min(1, (sinuosity - 1) / 2); // Score entre 0 et 1
  }

  analyzeEnvironmentVariety(coordinates) {
    // Estimer la variété basée sur la répartition géographique
    // Dans une vraie implémentation, on utiliserait des données OSM
    
    const segments = coordinates.length;
    const quarterPoints = Math.floor(segments / 4);
    
    let varietyScore = 0;
    
    // Analyser les changements de direction pour simuler les changements d'environnement
    for (let i = quarterPoints; i < coordinates.length - quarterPoints; i += quarterPoints) {
      const bearing1 = turf.bearing(coordinates[0], coordinates[i]);
      const bearing2 = turf.bearing(coordinates[i], coordinates[coordinates.length - 1]);
      const diff = Math.abs(bearing1 - bearing2);
      
      if (diff > 45) varietyScore += 0.25;
    }
    
    return Math.min(1, varietyScore);
  }

  calculateExplorationScore(coordinates) {
    // Score basé sur l'éloignement progressif puis le retour
    const center = turf.center(turf.featureCollection(coordinates.map(c => turf.point(c))));
    const centerCoord = center.geometry.coordinates;
    
    let maxDistance = 0;
    let totalExploration = 0;
    
    coordinates.forEach(coord => {
      const distance = turf.distance(centerCoord, coord, { units: 'meters' });
      maxDistance = Math.max(maxDistance, distance);
      totalExploration += distance;
    });
    
    const averageDistance = totalExploration / coordinates.length;
    return Math.min(1, averageDistance / (maxDistance + 1));
  }

  analyzeRouteBalance(coordinates) {
    // Analyser l'équilibre entre les différentes directions
    const bearings = [];
    
    for (let i = 1; i < coordinates.length; i++) {
      const bearing = turf.bearing(coordinates[i-1], coordinates[i]);
      bearings.push((bearing + 360) % 360); // Normaliser 0-360
    }
    
    // Diviser en quadrants
    const quadrants = [0, 0, 0, 0];
    bearings.forEach(bearing => {
      const quadrant = Math.floor(bearing / 90);
      quadrants[quadrant]++;
    });
    
    // Calculer l'équilibre (plus équilibré = meilleur score)
    const total = bearings.length;
    const ideal = total / 4;
    const variance = quadrants.reduce((sum, count) => sum + Math.pow(count - ideal, 2), 0) / 4;
    const balance = 1 - (variance / (ideal * ideal));
    
    return {
      quadrants,
      variance,
      score: Math.max(0, balance)
    };
  }

  /**
   * Calcul de qualité amélioré avec critères esthétiques
   */
  calculateEnhancedQuality(metrics) {
    let score = 100;
    
    // Pénalités réduites
    if (metrics.distance && !metrics.distance.isValid) {
      score -= metrics.distance.severity === 'critical' ? 20 : 5; // Réduit
    }

    if (metrics.coordinates && !metrics.coordinates.isValid) {
      score -= (metrics.coordinates.gaps.length * 2); // Réduit
      score -= (metrics.coordinates.suspiciousSpeeds.length * 3); // Réduit
    }

    if (metrics.aesthetics) {
      const aestheticsScore = metrics.aesthetics.score * 30; // Augmenté le poids
      score -= (30 - aestheticsScore);
    }

    // Seuils assouplis
    if (score >= 70) return 'excellent';
    if (score >= 55) return 'good';
    if (score >= 40) return 'acceptable';
    if (score >= 25) return 'poor';
    return 'critical';
  }

  // Garder les méthodes existantes sans modification pour compatibilité
  validateDistance(route, requestedParams) {
    const actualDistanceKm = route.distance / 1000;
    const requestedDistanceKm = requestedParams.distanceKm;
    const ratio = actualDistanceKm / requestedDistanceKm;

    const validation = {
      requestedKm: requestedDistanceKm,
      actualKm: Math.round(actualDistanceKm * 100) / 100,
      ratio: Math.round(ratio * 100) / 100,
      isValid: true,
      severity: 'none'
    };

    if (ratio < this.qualityThresholds.distance.criticalRatio || 
        ratio > (2 - this.qualityThresholds.distance.criticalRatio)) {
      validation.isValid = false;
      validation.severity = 'critical';
      validation.issue = `Distance critique: ${actualDistanceKm.toFixed(1)}km généré au lieu de ${requestedDistanceKm}km (ratio: ${ratio.toFixed(2)})`;
      validation.suggestion = 'Réessayer avec des paramètres différents ou une zone géographique différente';
    } else if (ratio < this.qualityThresholds.distance.minAcceptableRatio || 
               ratio > this.qualityThresholds.distance.maxAcceptableRatio) {
      validation.isValid = false;
      validation.severity = 'warning';
      validation.issue = `Distance hors tolérance: ${actualDistanceKm.toFixed(1)}km généré au lieu de ${requestedDistanceKm}km`;
      validation.suggestion = 'Ajustement automatique recommandé';
    }

    return validation;
  }

  validateCoordinates(coordinates) {
    const validation = {
      pointsCount: coordinates.length,
      issues: [],
      suggestions: [],
      isValid: true,
      gaps: [],
      suspiciousSpeeds: []
    };

    if (coordinates.length < this.qualityThresholds.coordinates.minPoints) {
      validation.isValid = false;
      validation.issues.push(`Trop peu de points: ${coordinates.length} (minimum: ${this.qualityThresholds.coordinates.minPoints})`);
      validation.suggestions.push('Augmenter la densité de points du parcours');
    }

    for (let i = 1; i < coordinates.length; i++) {
      const distance = turf.distance(coordinates[i-1], coordinates[i], { units: 'meters' });
      
      if (distance > this.qualityThresholds.coordinates.maxGapMeters) {
        validation.gaps.push({
          index: i,
          distance: Math.round(distance),
          from: coordinates[i-1],
          to: coordinates[i]
        });
      }

      if (distance > 5000) {
        validation.suspiciousSpeeds.push({
          index: i,
          distance: Math.round(distance)
        });
      }
    }

    if (validation.gaps.length > 0) {
      validation.isValid = false;
      validation.issues.push(`${validation.gaps.length} gaps importants détectés dans le parcours`);
      validation.suggestions.push('Vérifier la continuité du parcours ou augmenter la densité de points');
    }

    if (validation.suspiciousSpeeds.length > 0) {
      validation.isValid = false;
      validation.issues.push(`${validation.suspiciousSpeeds.length} sauts géographiques suspects détectés`);
      validation.suggestions.push('Recalculer le parcours avec des contraintes géographiques plus strictes');
    }

    return validation;
  }

  validateLoop(coordinates) {
    if (coordinates.length < 2) {
      return {
        isValid: false,
        issue: 'Pas assez de coordonnées pour former une boucle',
        suggestion: 'Générer plus de points pour le parcours'
      };
    }
  
    const start = coordinates[0];
    const end = coordinates[coordinates.length - 1];
    const distance = turf.distance(start, end, { units: 'meters' });
  
    // ✅ FIX: Seuil réduit à 50m pour plus de précision
    const validation = {
      startEndDistance: Math.round(distance),
      isValid: distance <= 50,
      coordinates: { start, end }
    };
  
    if (!validation.isValid) {
      validation.issue = `Boucle non fermée: ${validation.startEndDistance}m entre début et fin (max: 50m)`;
      validation.suggestion = 'Forcer la fermeture de la boucle en ajustant le dernier point';
    }
  
    return validation;
  }

  // Garder les autres méthodes existantes...
  suggestImprovements(route, requestedParams, validationResult) {
    const suggestions = [];

    if (!validationResult.isValid) {
      if (validationResult.metrics.distance && !validationResult.metrics.distance.isValid) {
        const ratio = validationResult.metrics.distance.ratio;
        
        if (ratio > 1.5) {
          suggestions.push({
            type: 'distance_too_long',
            priority: 'high',
            action: 'reduce_search_radius',
            params: { searchRadius: requestedParams.searchRadius * 0.7 }
          });
        } else if (ratio < 0.7) {
          suggestions.push({
            type: 'distance_too_short',
            priority: 'high', 
            action: 'increase_search_radius',
            params: { searchRadius: requestedParams.searchRadius * 1.3 }
          });
        }
      }

      // NOUVELLES SUGGESTIONS ESTHÉTIQUES
      if (validationResult.metrics.aesthetics && !validationResult.metrics.aesthetics.isValid) {
        suggestions.push({
          type: 'poor_aesthetics',
          priority: 'high',
          action: 'increase_waypoints',
          params: { useMoreWaypoints: true, waypointStrategy: 'organic' }
        });
      }

      if (validationResult.metrics.complexity && validationResult.metrics.complexity.score < 0.3) {
        suggestions.push({
          type: 'low_complexity',
          priority: 'medium',
          action: 'use_organic_generation',
          params: { generateOrganic: true, complexityBoost: true }
        });
      }

      if (validationResult.metrics.loop && !validationResult.metrics.loop.isValid) {
        suggestions.push({
          type: 'loop_not_closed',
          priority: 'medium',
          action: 'force_loop_closure',
          params: { closeLoop: true }
        });
      }
    }

    return suggestions;
  }

  autoFixRoute(route, requestedParams) {
    let fixedRoute = { ...route };
    const fixes = [];
  
    try {
      // ✅ FIX: Correction PRIORITAIRE de la boucle
      if (requestedParams.isLoop && route.coordinates.length > 1) {
        const start = route.coordinates[0];
        const end = route.coordinates[route.coordinates.length - 1];
        const distance = turf.distance(start, end, { units: 'meters' });
  
        // ✅ FIX: Seuil plus strict pour la fermeture
        if (distance > 50) {
          // Forcer la fermeture exacte
          fixedRoute.coordinates = [...route.coordinates];
          fixedRoute.coordinates[fixedRoute.coordinates.length - 1] = [...start];
          fixes.push('loop_closed');
          
          // Recalculer la distance
          let newDistance = 0;
          for (let i = 1; i < fixedRoute.coordinates.length; i++) {
            newDistance += turf.distance(
              fixedRoute.coordinates[i-1], 
              fixedRoute.coordinates[i], 
              { units: 'meters' }
            );
          }
          fixedRoute.distance = newDistance;
  
          logger.info('Loop closure forced in auto-fix', {
            originalDistance: Math.round(distance),
            newDistance: Math.round(newDistance),
            coordinatesCount: fixedRoute.coordinates.length
          });
        }
      }
  
      // Autres fixes existants...
      if (fixedRoute.coordinates.length < this.qualityThresholds.coordinates.minPoints) {
        fixedRoute.coordinates = this.densifyCoordinates(fixedRoute.coordinates);
        fixes.push('coordinates_densified');
      }
  
      return { route: fixedRoute, fixes: fixes };
  
    } catch (error) {
      logger.error('Auto-fix failed:', error);
      return { route: route, fixes: [] };
    }
  }

    /**
   * NOUVELLE : Simplifie une route pour respecter une distance cible
   */
  simplifyRouteForDistance(coordinates, targetDistanceM) {
    if (coordinates.length < 3) return coordinates;

    const line = turf.lineString(coordinates);
    const totalLength = turf.length(line, { units: 'meters' });
    
    if (totalLength <= targetDistanceM * 1.1) return coordinates;

    // Calculer le ratio de simplification nécessaire
    const simplificationRatio = targetDistanceM / totalLength;
    const targetPointCount = Math.max(
      10, 
      Math.floor(coordinates.length * simplificationRatio)
    );

    // Échantillonner les points de manière uniforme
    const simplified = [coordinates[0]]; // Toujours garder le premier point
    
    const step = (coordinates.length - 1) / (targetPointCount - 1);
    for (let i = 1; i < targetPointCount - 1; i++) {
      const index = Math.round(i * step);
      simplified.push(coordinates[index]);
    }
    
    // ✅ FIX: Pour les boucles, s'assurer que le dernier point = premier point
    simplified.push([...coordinates[0]]);

    return simplified;
  }

  /**
   * NOUVELLE : Densifie les coordonnées pour un parcours plus fluide
   */
  densifyCoordinates(coordinates) {
    if (coordinates.length < 2) return coordinates;

    const densified = [coordinates[0]];
    
    for (let i = 1; i < coordinates.length; i++) {
      const from = coordinates[i - 1];
      const to = coordinates[i];
      const distance = turf.distance(from, to, { units: 'meters' });
      
      // Si le segment est long (> 300m), ajouter des points intermédiaires
      if (distance > 300) {
        const numPoints = Math.ceil(distance / 200); // Un point tous les 200m
        
        for (let j = 1; j < numPoints; j++) {
          const fraction = j / numPoints;
          const interpolated = turf.along(
            turf.lineString([from, to]), 
            distance * fraction, 
            { units: 'meters' }
          );
          densified.push(interpolated.geometry.coordinates);
        }
      }
      
      densified.push(to);
    }
    
    return densified;
  }
}

module.exports = new RouteQualityService();