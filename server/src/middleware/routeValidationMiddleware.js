const logger = require('../config/logger');
const { validateRouteParams } = require('../utils/validators');

class RouteValidationMiddleware {
  /**
   * Middleware de validation et d'optimisation des paramètres de route
   */
  static validateAndOptimizeParams() {
    return (req, res, next) => {
      try {
        const startTime = Date.now();
        
        // Validation de base avec Joi
        const baseValidation = validateRouteParams(req.body);
        if (!baseValidation.valid) {
          return res.status(400).json({
            success: false,
            error: 'Paramètres invalides',
            details: baseValidation.errors
          });
        }

        const params = baseValidation.value;

        // Optimisation intelligente des paramètres
        const optimizedParams = this.optimizeParameters(params);
        
        // Ajouter des métadonnées de validation
        req.validatedParams = optimizedParams;
        req.originalParams = params;
        req.validationMetadata = {
          validationTime: Date.now() - startTime,
          optimizationsApplied: this.getAppliedOptimizations(params, optimizedParams),
          riskLevel: this.assessRiskLevel(optimizedParams)
        };

        logger.info('Route parameters validated and optimized', {
          requestId: req.requestId,
          original: this.sanitizeParamsForLog(params),
          optimized: this.sanitizeParamsForLog(optimizedParams),
          optimizations: req.validationMetadata.optimizationsApplied,
          riskLevel: req.validationMetadata.riskLevel
        });

        next();

      } catch (error) {
        logger.error('Parameter validation failed:', error);
        res.status(500).json({
          success: false,
          error: 'Erreur de validation des paramètres',
          details: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
      }
    };
  }

  /**
   * Optimise les paramètres selon les meilleures pratiques
   */
  static optimizeParameters(params) {
    const optimized = { ...params };

    // Optimisation du rayon de recherche selon la distance
    if (!params.searchRadius || params.searchRadius === 0) {
      optimized.searchRadius = this.calculateOptimalSearchRadius(params.distanceKm, params.activityType);
    } else {
      // Vérifier que le rayon est cohérent avec la distance
      const recommendedRadius = this.calculateOptimalSearchRadius(params.distanceKm, params.activityType);
      const ratio = params.searchRadius / recommendedRadius;
      
      if (ratio > 3.0) {
        // Rayon trop grand, risque de parcours aberrant
        optimized.searchRadius = recommendedRadius * 2;
        optimized._radiusReduced = true;
      } else if (ratio < 0.3) {
        // Rayon trop petit, risque d'échec
        optimized.searchRadius = recommendedRadius * 0.5;
        optimized._radiusIncreased = true;
      }
    }

    // Optimisation selon l'activité et le terrain
    if (params.activityType === 'running' && params.distanceKm > 25) {
      // Course longue: privilégier les surfaces douces
      optimized.preferScenic = true;
      optimized.avoidTraffic = true;
    }

    if (params.activityType === 'cycling' && params.distanceKm < 3) {
      // Vélo courte distance: forcer mode urbain
      optimized.urbanDensity = 'urban';
    }

    // Optimisation du dénivelé selon l'activité
    if (params.elevationGain > 0) {
      const maxRecommended = this.getMaxRecommendedElevation(params.activityType, params.distanceKm);
      if (params.elevationGain > maxRecommended) {
        optimized.elevationGain = maxRecommended;
        optimized._elevationReduced = true;
      }
    }

    // Optimisation de la boucle selon la distance
    if (params.distanceKm < 1.0 && !params.isLoop) {
      // Très courtes distances: forcer la boucle
      optimized.isLoop = true;
      optimized._forcedLoop = true;
    }

    // Ajout d'un ID de requête pour le tracking
    optimized.requestId = this.generateRequestId();

    return optimized;
  }

  /**
   * Calcule le rayon de recherche optimal
   */
  static calculateOptimalSearchRadius(distanceKm, activityType) {
    const baseRadius = {
      'running': 600,    // 600m par km
      'walking': 400,    // 400m par km
      'cycling': 1000,   // 1000m par km
      'hiking': 800      // 800m par km
    };

    const multiplier = baseRadius[activityType] || 600;
    let radius = distanceKm * multiplier;

    // Limites min/max
    radius = Math.max(1000, radius);   // Minimum 1km
    radius = Math.min(50000, radius);  // Maximum 50km

    // Ajustements selon la distance
    if (distanceKm > 30) {
      radius = radius * 0.8; // Réduire pour longues distances
    } else if (distanceKm < 2) {
      radius = radius * 1.5; // Augmenter pour courtes distances
    }

    return Math.round(radius);
  }

  /**
   * Obtient l'élévation maximum recommandée
   */
  static getMaxRecommendedElevation(activityType, distanceKm) {
    const recommendations = {
      'running': Math.min(1000, distanceKm * 30),  // 30m par km max
      'walking': Math.min(1500, distanceKm * 50),  // 50m par km max
      'cycling': Math.min(2000, distanceKm * 40),  // 40m par km max
      'hiking': distanceKm * 100                   // 100m par km max
    };

    return recommendations[activityType] || 500;
  }

  /**
   * Évalue le niveau de risque d'échec
   */
  static assessRiskLevel(params) {
    let riskScore = 0;

    // Facteurs de risque pour la distance
    if (params.distanceKm > 50) riskScore += 2;
    if (params.distanceKm < 0.5) riskScore += 1;

    // Facteurs de risque pour l'élévation
    const maxElevation = this.getMaxRecommendedElevation(params.activityType, params.distanceKm);
    if (params.elevationGain > maxElevation) riskScore += 2;

    // Facteurs de risque pour le rayon de recherche
    const optimalRadius = this.calculateOptimalSearchRadius(params.distanceKm, params.activityType);
    const radiusRatio = params.searchRadius / optimalRadius;
    if (radiusRatio > 2.5 || radiusRatio < 0.4) riskScore += 1;

    // Facteurs de risque combinés
    if (params.distanceKm > 20 && params.elevationGain > 500) riskScore += 1;
    if (params.isLoop && params.distanceKm > 30) riskScore += 1;

    // Déterminer le niveau
    if (riskScore >= 4) return 'high';
    if (riskScore >= 2) return 'medium';
    return 'low';
  }

  /**
   * Identifie les optimisations appliquées
   */
  static getAppliedOptimizations(original, optimized) {
    const optimizations = [];

    if (optimized._radiusReduced) optimizations.push('search_radius_reduced');
    if (optimized._radiusIncreased) optimizations.push('search_radius_increased');
    if (optimized._elevationReduced) optimizations.push('elevation_reduced');
    if (optimized._forcedLoop) optimizations.push('forced_loop');

    if (optimized.searchRadius !== original.searchRadius && !optimized._radiusReduced && !optimized._radiusIncreased) {
      optimizations.push('search_radius_calculated');
    }

    if (optimized.preferScenic !== original.preferScenic) {
      optimizations.push('scenic_preference_adjusted');
    }

    return optimizations;
  }

  /**
   * Génère un ID de requête unique
   */
  static generateRequestId() {
    return `route_${Date.now()}_${Math.random().toString(36).substr(2, 8)}`;
  }

  /**
   * Nettoie les paramètres pour les logs
   */
  static sanitizeParamsForLog(params) {
    return {
      activityType: params.activityType,
      distanceKm: params.distanceKm,
      terrainType: params.terrainType,
      urbanDensity: params.urbanDensity,
      elevationGain: params.elevationGain,
      isLoop: params.isLoop,
      searchRadius: params.searchRadius
    };
  }

  /**
   * Middleware pour valider les résultats de génération
   */
  static validateGenerationResult() {
    return (req, res, next) => {
      const originalSend = res.send;
      
      res.send = function(data) {
        try {
          // Intercepter et analyser la réponse
          if (res.statusCode === 200 && data) {
            const response = typeof data === 'string' ? JSON.parse(data) : data;
            
            if (response.success && response.route) {
              const qualityMetrics = RouteValidationMiddleware.analyzeRouteQuality(
                response.route, 
                req.validatedParams
              );
              
              // Ajouter les métriques à la réponse
              response.qualityMetrics = qualityMetrics;
              response.validationMetadata = req.validationMetadata;
              
              logger.info('Route generation result analyzed', {
                requestId: req.validatedParams?.requestId,
                quality: qualityMetrics.overallQuality,
                distance: response.route.distance / 1000,
                distanceAccuracy: qualityMetrics.distanceAccuracy
              });
              
              data = typeof data === 'string' ? JSON.stringify(response) : response;
            }
          }
        } catch (error) {
          logger.error('Error analyzing route quality:', error);
        }
        
        originalSend.call(this, data);
      };
      
      next();
    };
  }

  /**
   * Analyse la qualité du parcours généré
   */
  static analyzeRouteQuality(route, originalParams) {
    const actualDistanceKm = route.distance / 1000;
    const requestedDistanceKm = originalParams.distanceKm;
    const distanceRatio = actualDistanceKm / requestedDistanceKm;

    const metrics = {
      distanceAccuracy: {
        requested: requestedDistanceKm,
        actual: Math.round(actualDistanceKm * 100) / 100,
        ratio: Math.round(distanceRatio * 100) / 100,
        deviation: Math.round(Math.abs(distanceRatio - 1) * 100),
        grade: this.gradeDistanceAccuracy(distanceRatio)
      },
      routeComplexity: {
        pointsCount: route.coordinates.length,
        pointDensity: Math.round(route.coordinates.length / actualDistanceKm),
        grade: this.gradeRouteComplexity(route.coordinates, actualDistanceKm)
      },
      overallQuality: 'calculating...'
    };

    // Calculer la qualité globale
    metrics.overallQuality = this.calculateOverallQuality(metrics);

    return metrics;
  }

  /**
   * Note la précision de distance
   */
  static gradeDistanceAccuracy(ratio) {
    if (ratio >= 0.95 && ratio <= 1.05) return 'excellent';
    if (ratio >= 0.90 && ratio <= 1.10) return 'good';
    if (ratio >= 0.80 && ratio <= 1.20) return 'acceptable';
    if (ratio >= 0.60 && ratio <= 1.50) return 'poor';
    return 'critical';
  }

  /**
   * Note la complexité de la route
   */
  static gradeRouteComplexity(coordinates, distanceKm) {
    const pointDensity = coordinates.length / distanceKm;
    
    if (pointDensity >= 15 && pointDensity <= 50) return 'excellent';
    if (pointDensity >= 10 && pointDensity <= 70) return 'good';
    if (pointDensity >= 5 && pointDensity <= 100) return 'acceptable';
    return 'poor';
  }

  /**
   * Calcule la qualité globale
   */
  static calculateOverallQuality(metrics) {
    const scores = {
      'excellent': 5,
      'good': 4,
      'acceptable': 3,
      'poor': 2,
      'critical': 1
    };

    const distanceScore = scores[metrics.distanceAccuracy.grade] || 1;
    const complexityScore = scores[metrics.routeComplexity.grade] || 1;
    
    const averageScore = (distanceScore + complexityScore) / 2;

    if (averageScore >= 4.5) return 'excellent';
    if (averageScore >= 3.5) return 'good';
    if (averageScore >= 2.5) return 'acceptable';
    if (averageScore >= 1.5) return 'poor';
    return 'critical';
  }
}

module.exports = RouteValidationMiddleware;