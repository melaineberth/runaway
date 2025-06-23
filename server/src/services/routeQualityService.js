// server/src/services/routeQualityService.js
const logger = require('../config/logger');
const turf = require('@turf/turf');

class RouteQualityService {
  constructor() {
    this.qualityThresholds = {
      distance: {
        minAcceptableRatio: 0.85,  // -15% minimum
        maxAcceptableRatio: 1.15,  // +15% maximum
        criticalRatio: 0.5         // Si < 50% ou > 200%, c'est critique
      },
      coordinates: {
        minPoints: 10,             // Minimum de points pour un parcours valide
        maxGapMeters: 1000,        // Gap maximum entre deux points consécutifs
        maxSpeed: 150              // Vitesse maximum théorique (km/h) entre points
      },
      loop: {
        maxEndDistanceMeters: 200  // Distance max entre début/fin pour une boucle
      }
    };
  }

  /**
   * Valide la qualité d'un parcours généré
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
      // 1. Validation de la distance
      const distanceValidation = this.validateDistance(route, requestedParams);
      validationResult.metrics.distance = distanceValidation;
      
      if (!distanceValidation.isValid) {
        validationResult.isValid = false;
        validationResult.issues.push(distanceValidation.issue);
        validationResult.suggestions.push(distanceValidation.suggestion);
      }

      // 2. Validation des coordonnées
      const coordinatesValidation = this.validateCoordinates(route.coordinates);
      validationResult.metrics.coordinates = coordinatesValidation;
      
      if (!coordinatesValidation.isValid) {
        validationResult.isValid = false;
        validationResult.issues.push(...coordinatesValidation.issues);
        validationResult.suggestions.push(...coordinatesValidation.suggestions);
      }

      // 3. Validation de la boucle (si demandée)
      if (requestedParams.isLoop) {
        const loopValidation = this.validateLoop(route.coordinates);
        validationResult.metrics.loop = loopValidation;
        
        if (!loopValidation.isValid) {
          validationResult.isValid = false;
          validationResult.issues.push(loopValidation.issue);
          validationResult.suggestions.push(loopValidation.suggestion);
        }
      }

      // 4. Calcul de la qualité globale
      validationResult.quality = this.calculateOverallQuality(validationResult.metrics);

      logger.info('Route quality validation completed', {
        isValid: validationResult.isValid,
        quality: validationResult.quality,
        issuesCount: validationResult.issues.length,
        requestedDistance: requestedParams.distanceKm,
        actualDistance: route.distance / 1000
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
   * Valide la distance du parcours
   */
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
      // Erreur critique : distance complètement aberrante
      validation.isValid = false;
      validation.severity = 'critical';
      validation.issue = `Distance critique: ${actualDistanceKm.toFixed(1)}km généré au lieu de ${requestedDistanceKm}km (ratio: ${ratio.toFixed(2)})`;
      validation.suggestion = 'Réessayer avec des paramètres différents ou une zone géographique différente';
    } else if (ratio < this.qualityThresholds.distance.minAcceptableRatio || 
               ratio > this.qualityThresholds.distance.maxAcceptableRatio) {
      // Avertissement : distance hors tolérance acceptable
      validation.isValid = false;
      validation.severity = 'warning';
      validation.issue = `Distance hors tolérance: ${actualDistanceKm.toFixed(1)}km généré au lieu de ${requestedDistanceKm}km`;
      validation.suggestion = 'Ajustement automatique recommandé';
    }

    return validation;
  }

  /**
   * Valide la cohérence des coordonnées
   */
  validateCoordinates(coordinates) {
    const validation = {
      pointsCount: coordinates.length,
      issues: [],
      suggestions: [],
      isValid: true,
      gaps: [],
      suspiciousSpeeds: []
    };

    // Vérifier le nombre minimum de points
    if (coordinates.length < this.qualityThresholds.coordinates.minPoints) {
      validation.isValid = false;
      validation.issues.push(`Trop peu de points: ${coordinates.length} (minimum: ${this.qualityThresholds.coordinates.minPoints})`);
      validation.suggestions.push('Augmenter la densité de points du parcours');
    }

    // Vérifier les gaps et vitesses suspectes
    for (let i = 1; i < coordinates.length; i++) {
      const distance = turf.distance(coordinates[i-1], coordinates[i], { units: 'meters' });
      
      // Gap trop important
      if (distance > this.qualityThresholds.coordinates.maxGapMeters) {
        validation.gaps.push({
          index: i,
          distance: Math.round(distance),
          from: coordinates[i-1],
          to: coordinates[i]
        });
      }

      // Vitesse théorique suspecte (si on avait le timing)
      // Pour l'instant, on détecte juste les sauts géographiques aberrants
      if (distance > 5000) { // Plus de 5km entre deux points consécutifs
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

  /**
   * Valide si c'est bien une boucle
   */
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

    const validation = {
      startEndDistance: Math.round(distance),
      isValid: distance <= this.qualityThresholds.loop.maxEndDistanceMeters,
      coordinates: { start, end }
    };

    if (!validation.isValid) {
      validation.issue = `Boucle non fermée: ${validation.startEndDistance}m entre début et fin (max: ${this.qualityThresholds.loop.maxEndDistanceMeters}m)`;
      validation.suggestion = 'Forcer la fermeture de la boucle en ajustant le dernier point';
    }

    return validation;
  }

  /**
   * Calcule la qualité globale du parcours
   */
  calculateOverallQuality(metrics) {
    let score = 100;
    
    // Pénalités pour la distance
    if (metrics.distance && !metrics.distance.isValid) {
      if (metrics.distance.severity === 'critical') {
        score -= 60; // Pénalité majeure pour distance aberrante
      } else {
        score -= 20; // Pénalité modérée pour distance hors tolérance
      }
    }

    // Pénalités pour les coordonnées
    if (metrics.coordinates && !metrics.coordinates.isValid) {
      score -= (metrics.coordinates.gaps.length * 10);
      score -= (metrics.coordinates.suspiciousSpeeds.length * 15);
    }

    // Pénalité pour boucle non fermée
    if (metrics.loop && !metrics.loop.isValid) {
      score -= 25;
    }

    // Déterminer la qualité
    if (score >= 90) return 'excellent';
    if (score >= 75) return 'good';
    if (score >= 60) return 'fair';
    if (score >= 40) return 'poor';
    return 'critical';
  }

  /**
   * Suggère des améliorations pour un parcours
   */
  suggestImprovements(route, requestedParams, validationResult) {
    const suggestions = [];

    if (!validationResult.isValid) {
      // Distance trop différente
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

      // Boucle non fermée
      if (validationResult.metrics.loop && !validationResult.metrics.loop.isValid) {
        suggestions.push({
          type: 'loop_not_closed',
          priority: 'medium',
          action: 'force_loop_closure',
          params: { closeLoop: true }
        });
      }

      // Gaps dans les coordonnées
      if (validationResult.metrics.coordinates && validationResult.metrics.coordinates.gaps.length > 0) {
        suggestions.push({
          type: 'coordinate_gaps',
          priority: 'medium',
          action: 'increase_point_density',
          params: { increaseDetails: true }
        });
      }
    }

    return suggestions;
  }

  /**
   * Applique automatiquement les corrections simples
   */
  autoFixRoute(route, requestedParams) {
    let fixedRoute = { ...route };
    const fixes = [];

    try {
      // 1. Fermer la boucle si nécessaire
      if (requestedParams.isLoop && route.coordinates.length > 1) {
        const start = route.coordinates[0];
        const end = route.coordinates[route.coordinates.length - 1];
        const distance = turf.distance(start, end, { units: 'meters' });

        if (distance > this.qualityThresholds.loop.maxEndDistanceMeters) {
          // Remplacer le dernier point par le premier pour fermer la boucle
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
        }
      }

      // 2. Supprimer les points dupliqués
      const uniqueCoordinates = [];
      for (let i = 0; i < fixedRoute.coordinates.length; i++) {
        const coord = fixedRoute.coordinates[i];
        const isFirstOccurrence = uniqueCoordinates.findIndex(
          existing => turf.distance(existing, coord, { units: 'meters' }) < 10
        ) === -1;
        
        if (isFirstOccurrence) {
          uniqueCoordinates.push(coord);
        }
      }

      if (uniqueCoordinates.length < fixedRoute.coordinates.length) {
        fixedRoute.coordinates = uniqueCoordinates;
        fixes.push('duplicates_removed');
      }

      if (fixes.length > 0) {
        logger.info('Route auto-fixes applied:', fixes);
      }

      return {
        route: fixedRoute,
        fixes: fixes
      };

    } catch (error) {
      logger.error('Auto-fix failed:', error);
      return {
        route: route,
        fixes: []
      };
    }
  }
}

module.exports = new RouteQualityService();