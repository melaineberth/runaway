const logger = require('../config/logger');
const turf = require('@turf/turf');

class GeographicAnalysisMiddleware {
  constructor() {
    // Zones connues problématiques (coordonnées approximatives)
    this.problematicZones = [
      // Zones trop géométriques/grilles urbaines strictes
      {
        name: 'Manhattan_Grid',
        bbox: [-74.02, 40.68, -73.93, 40.82],
        issues: ['grid_pattern', 'too_geometric'],
        severity: 'high',
        recommendations: ['use_organic_generation', 'increase_waypoints']
      },
      // Zones avec peu de variété topographique
      {
        name: 'Desert_Flat',
        bbox: [-120, 35, -115, 40],
        issues: ['monotonous_terrain', 'few_alternatives'],
        severity: 'medium',
        recommendations: ['force_organic_curves', 'use_longer_segments']
      }
    ];

    // Facteurs de qualité par type de zone
    this.zoneQualityFactors = {
      urban_dense: {
        organicnessFactor: 0.8,     // Plus d'organicité en ville dense
        waypointMultiplier: 1.5,    // Plus de waypoints
        avoidStraightLines: true,
        preferredStrategies: ['organic_natural', 'controlled_multi_waypoint']
      },
      urban_sparse: {
        organicnessFactor: 0.6,
        waypointMultiplier: 1.2,
        avoidStraightLines: false,
        preferredStrategies: ['organic_balanced', 'enhanced_traditional']
      },
      suburban: {
        organicnessFactor: 0.5,
        waypointMultiplier: 1.0,
        avoidStraightLines: false,
        preferredStrategies: ['organic_balanced', 'enhanced_traditional']
      },
      rural: {
        organicnessFactor: 0.4,
        waypointMultiplier: 0.8,
        avoidStraightLines: false,
        preferredStrategies: ['enhanced_traditional', 'organic_conservative']
      },
      natural: {
        organicnessFactor: 0.7,
        waypointMultiplier: 1.3,
        avoidStraightLines: true,
        preferredStrategies: ['organic_natural', 'organic_balanced']
      }
    };
  }

  /**
   * Middleware principal d'analyse géographique
   */
  static analyzeGeographicContext() {
    const instance = new GeographicAnalysisMiddleware();
    
    return async (req, res, next) => {
      try {
        const startTime = Date.now();
        const params = req.validatedParams || req.body;

        if (!params.startLatitude && !params.startLat) {
          return next(); // Pas de coordonnées, passer au suivant
        }

        const lat = params.startLatitude || params.startLat;
        const lon = params.startLongitude || params.startLon;

        // Analyse géographique complète
        const geoAnalysis = await instance.performGeographicAnalysis(lat, lon, params);
        
        // Recommandations de stratégie
        const strategyRecommendations = instance.recommendStrategies(geoAnalysis, params);
        
        // Optimisations de paramètres
        const optimizedParams = instance.optimizeForGeography(params, geoAnalysis);

        // Enrichir la requête
        req.geographicAnalysis = geoAnalysis;
        req.strategyRecommendations = strategyRecommendations;
        req.validatedParams = optimizedParams;
        req.geoAnalysisMetadata = {
          analysisTime: Date.now() - startTime,
          recommendedStrategies: strategyRecommendations.map(s => s.name),
          zoneType: geoAnalysis.zoneType,
          complexityRating: geoAnalysis.complexityRating
        };

        logger.info('Geographic analysis completed', {
          requestId: params.requestId,
          location: [lat, lon],
          zoneType: geoAnalysis.zoneType,
          complexityRating: geoAnalysis.complexityRating,
          riskLevel: geoAnalysis.riskLevel,
          recommendedStrategies: strategyRecommendations.slice(0, 2).map(s => s.name),
          analysisTime: req.geoAnalysisMetadata.analysisTime
        });

        next();

      } catch (error) {
        logger.error('Geographic analysis failed:', error);
        // En cas d'erreur, continuer sans analyse géographique
        next();
      }
    };
  }

  /**
   * Analyse géographique complète d'une zone
   */
  async performGeographicAnalysis(lat, lon, params) {
    const analysis = {
      coordinates: [lat, lon],
      zoneType: 'unknown',
      complexityRating: 0.5, // 0-1
      riskLevel: 'medium',
      features: {},
      constraints: [],
      opportunities: []
    };

    try {
      // 1. Classification de la zone
      analysis.zoneType = this.classifyZone(lat, lon);

      // 2. Analyse de la densité urbaine
      analysis.urbanDensity = this.analyzeUrbanDensity(lat, lon);

      // 3. Évaluation de la complexité topographique
      analysis.topographicalComplexity = this.evaluateTopographicalComplexity(lat, lon);

      // 4. Détection des zones problématiques
      analysis.problematicFactors = this.detectProblematicFactors(lat, lon);

      // 5. Évaluation du potentiel de génération de parcours intéressants
      analysis.routePotential = this.evaluateRoutePotential(analysis);

      // 6. Calcul de la note de complexité globale
      analysis.complexityRating = this.calculateComplexityRating(analysis);

      // 7. Évaluation du niveau de risque
      analysis.riskLevel = this.assessRiskLevel(analysis, params);

      // 8. Identification des contraintes et opportunités
      analysis.constraints = this.identifyConstraints(analysis);
      analysis.opportunities = this.identifyOpportunities(analysis);

      return analysis;

    } catch (error) {
      logger.warn('Geographic analysis partial failure:', error.message);
      return analysis; // Retourner l'analyse partielle
    }
  }

  /**
   * Classification du type de zone
   */
  classifyZone(lat, lon) {
    // Classification basée sur les coordonnées (approximative)
    // Dans une vraie implémentation, on utiliserait des APIs comme Overpass ou des données OSM

    // Grandes villes connues
    const majorCities = [
      { name: 'Paris', lat: 48.8566, lon: 2.3522, radius: 0.1 },
      { name: 'Lyon', lat: 45.7640, lon: 4.8357, radius: 0.05 },
      { name: 'Marseille', lat: 43.2965, lon: 5.3698, radius: 0.05 },
      { name: 'San Francisco', lat: 37.7749, lon: -122.4194, radius: 0.05 },
      { name: 'New York', lat: 40.7128, lon: -74.0060, radius: 0.1 }
    ];

    // Vérifier la proximité avec une grande ville
    for (const city of majorCities) {
      const distance = Math.sqrt(
        Math.pow(lat - city.lat, 2) + Math.pow(lon - city.lon, 2)
      );
      
      if (distance <= city.radius) {
        return 'urban_dense';
      } else if (distance <= city.radius * 2) {
        return 'urban_sparse';
      } else if (distance <= city.radius * 4) {
        return 'suburban';
      }
    }

    // Classification par région géographique
    if (lat > 45 && lat < 51 && lon > -5 && lon < 9) {
      return 'suburban'; // Europe du Nord/Ouest
    } else if (lat > 30 && lat < 50 && lon > -125 && lon < -65) {
      return 'suburban'; // États-Unis continentaux
    }

    return 'rural';
  }

  /**
   * Analyse de la densité urbaine
   */
  analyzeUrbanDensity(lat, lon) {
    // Simulation basée sur la zone
    const zoneType = this.classifyZone(lat, lon);
    
    const densityMapping = {
      'urban_dense': { score: 0.9, description: 'Very high density' },
      'urban_sparse': { score: 0.7, description: 'High density' },
      'suburban': { score: 0.4, description: 'Medium density' },
      'rural': { score: 0.2, description: 'Low density' },
      'natural': { score: 0.1, description: 'Very low density' }
    };

    return densityMapping[zoneType] || densityMapping['suburban'];
  }

  /**
   * Évaluation de la complexité topographique
   */
  evaluateTopographicalComplexity(lat, lon) {
    // Simulation basée sur des zones géographiques connues
    
    // Zones montagneuses
    const mountainousRegions = [
      { name: 'Alps', bbox: [5.5, 45.5, 11.0, 47.5], complexity: 0.8 },
      { name: 'Pyrenees', bbox: [-2.0, 42.0, 3.0, 43.5], complexity: 0.7 },
      { name: 'Sierra Nevada', bbox: [-120.0, 36.0, -118.0, 39.0], complexity: 0.8 }
    ];

    // Zones côtières (généralement plus complexes)
    const coastalDistance = this.estimateCoastalDistance(lat, lon);
    let coastalComplexity = coastalDistance < 50 ? 0.6 : 0.3; // 50km de la côte

    // Zones urbaines denses (complexité artificielle)
    const urbanComplexity = this.analyzeUrbanDensity(lat, lon).score * 0.5;

    // Vérifier les régions montagneuses
    let mountainComplexity = 0.3; // Default
    for (const region of mountainousRegions) {
      if (lat >= region.bbox[1] && lat <= region.bbox[3] &&
          lon >= region.bbox[0] && lon <= region.bbox[2]) {
        mountainComplexity = region.complexity;
        break;
      }
    }

    return {
      mountain: mountainComplexity,
      coastal: coastalComplexity,
      urban: urbanComplexity,
      overall: Math.max(mountainComplexity, coastalComplexity, urbanComplexity)
    };
  }

  /**
   * Estimation de la distance à la côte
   */
  estimateCoastalDistance(lat, lon) {
    // Approximation très basique - dans une vraie implémentation, 
    // on utiliserait des données géographiques précises
    
    // Côtes européennes
    if (lat > 40 && lat < 60 && lon > -10 && lon < 10) {
      // Distance approximative à la côte la plus proche
      const coastalPoints = [
        [48.8566, 2.3522], // Paris -> ~200km
        [43.2965, 5.3698], // Marseille -> ~0km
        [51.5074, -0.1278] // Londres -> ~50km
      ];
      
      let minDistance = Infinity;
      coastalPoints.forEach(([coastLat, coastLon]) => {
        const distance = this.calculateDistance(lat, lon, coastLat, coastLon);
        minDistance = Math.min(minDistance, distance);
      });
      
      return minDistance;
    }

    // Côtes américaines
    if (lat > 25 && lat < 50 && lon > -125 && lon < -65) {
      // Distance approximative aux côtes Est/Ouest
      const eastCoastDist = Math.abs(lon + 75) * 111; // ~111km par degré de longitude
      const westCoastDist = Math.abs(lon + 120) * 111;
      return Math.min(eastCoastDist, westCoastDist);
    }

    return 500; // Par défaut, loin de toute côte
  }

  /**
   * Détection des facteurs problématiques
   */
  detectProblematicFactors(lat, lon) {
    const factors = [];

    // Vérifier les zones problématiques connues
    for (const zone of this.problematicZones) {
      if (lat >= zone.bbox[1] && lat <= zone.bbox[3] &&
          lon >= zone.bbox[0] && lon <= zone.bbox[2]) {
        factors.push({
          type: 'known_problematic_zone',
          zone: zone.name,
          issues: zone.issues,
          severity: zone.severity
        });
      }
    }

    // Détecter les grilles urbaines (approximation)
    const zoneType = this.classifyZone(lat, lon);
    if (zoneType === 'urban_dense') {
      // Certaines villes ont des grilles très géométriques
      const gridCities = ['Manhattan', 'Chicago', 'Phoenix'];
      // Ici on pourrait faire une vérification plus précise
      factors.push({
        type: 'potential_grid_pattern',
        severity: 'medium',
        description: 'Dense urban area may have geometric street patterns'
      });
    }

    // Détecter les zones plates
    const topoComplexity = this.evaluateTopographicalComplexity(lat, lon);
    if (topoComplexity.overall < 0.3) {
      factors.push({
        type: 'low_topographical_variety',
        severity: 'medium',
        description: 'Area may lack topographical features for interesting routes'
      });
    }

    return factors;
  }

  /**
   * Évaluation du potentiel de génération de parcours
   */
  evaluateRoutePotential(analysis) {
    let potential = 0.5; // Base

    // Bonus pour la complexité topographique
    potential += analysis.topographicalComplexity.overall * 0.3;

    // Malus pour les facteurs problématiques
    const highSeverityIssues = analysis.problematicFactors.filter(f => f.severity === 'high');
    potential -= highSeverityIssues.length * 0.2;

    // Bonus pour la densité urbaine modérée (ni trop ni trop peu)
    const urbanScore = analysis.urbanDensity.score;
    if (urbanScore > 0.3 && urbanScore < 0.8) {
      potential += 0.1; // Sweet spot pour la variété
    }

    return Math.max(0, Math.min(1, potential));
  }

  /**
   * Calcul de la note de complexité globale
   */
  calculateComplexityRating(analysis) {
    let rating = 0;

    // Complexité topographique (40%)
    rating += analysis.topographicalComplexity.overall * 0.4;

    // Potentiel de parcours (30%)
    rating += analysis.routePotential * 0.3;

    // Variété urbaine (20%) - ni trop ni trop peu
    const urbanScore = analysis.urbanDensity.score;
    const urbanVariety = 1 - Math.abs(urbanScore - 0.5) * 2; // Peak à 0.5
    rating += urbanVariety * 0.2;

    // Pénalité pour facteurs problématiques (10%)
    const problemPenalty = analysis.problematicFactors.length * 0.05;
    rating -= problemPenalty;

    return Math.max(0, Math.min(1, rating));
  }

  /**
   * Évaluation du niveau de risque
   */
  assessRiskLevel(analysis, params) {
    let riskScore = 0;

    // Risque basé sur la complexité (plus c'est simple, plus c'est risqué)
    riskScore += (1 - analysis.complexityRating) * 2;

    // Risque basé sur les facteurs problématiques
    analysis.problematicFactors.forEach(factor => {
      if (factor.severity === 'high') riskScore += 2;
      else if (factor.severity === 'medium') riskScore += 1;
    });

    // Risque basé sur la distance demandée vs complexité
    if (params.distanceKm > 20 && analysis.complexityRating < 0.4) {
      riskScore += 1; // Long parcours dans zone simple = risqué
    }

    // Risque basé sur le type d'activité
    if (params.activityType === 'running' && analysis.urbanDensity.score > 0.8) {
      riskScore += 0.5; // Course en ville très dense
    }

    if (riskScore >= 3) return 'high';
    if (riskScore >= 1.5) return 'medium';
    return 'low';
  }

  /**
   * Identification des contraintes
   */
  identifyConstraints(analysis) {
    const constraints = [];

    if (analysis.urbanDensity.score > 0.8) {
      constraints.push({
        type: 'high_traffic_density',
        impact: 'May require more waypoints to avoid monotonous routes',
        mitigation: 'Use organic generation with increased waypoint density'
      });
    }

    if (analysis.topographicalComplexity.overall < 0.3) {
      constraints.push({
        type: 'flat_terrain',
        impact: 'Limited natural route variation',
        mitigation: 'Force organic curves and use longer route segments'
      });
    }

    analysis.problematicFactors.forEach(factor => {
      constraints.push({
        type: factor.type,
        impact: 'May produce geometric or uninteresting routes',
        mitigation: factor.zone?.recommendations?.join(', ') || 'Use organic generation'
      });
    });

    return constraints;
  }

  /**
   * Identification des opportunités
   */
  identifyOpportunities(analysis) {
    const opportunities = [];

    if (analysis.topographicalComplexity.coastal > 0.5) {
      opportunities.push({
        type: 'coastal_variety',
        description: 'Coastal area offers natural route complexity',
        suggestion: 'Use natural curve generation to follow coastline features'
      });
    }

    if (analysis.topographicalComplexity.mountain > 0.7) {
      opportunities.push({
        type: 'mountainous_terrain',
        description: 'Mountain terrain provides natural route interest',
        suggestion: 'Allow longer segments to take advantage of natural paths'
      });
    }

    if (analysis.urbanDensity.score > 0.4 && analysis.urbanDensity.score < 0.7) {
      opportunities.push({
        type: 'balanced_urban_density',
        description: 'Good balance of urban infrastructure and variety',
        suggestion: 'Use balanced organic generation for optimal results'
      });
    }

    if (analysis.routePotential > 0.7) {
      opportunities.push({
        type: 'high_route_potential',
        description: 'Area has excellent potential for interesting routes',
        suggestion: 'Can use more conservative generation strategies'
      });
    }

    return opportunities;
  }

  /**
   * Recommandation de stratégies basées sur l'analyse géographique
   */
  recommendStrategies(geoAnalysis, params) {
    const zoneQuality = this.zoneQualityFactors[geoAnalysis.zoneType] || this.zoneQualityFactors.suburban;
    const recommendations = [];

    // Stratégies prioritaires basées sur le type de zone
    zoneQuality.preferredStrategies.forEach((strategyName, index) => {
      recommendations.push({
        name: strategyName,
        priority: index + 1,
        reason: `Optimal for ${geoAnalysis.zoneType} areas`,
        confidence: this.calculateStrategyConfidence(strategyName, geoAnalysis)
      });
    });

    // Ajustements basés sur les contraintes
    if (geoAnalysis.riskLevel === 'high') {
      recommendations.unshift({
        name: 'organic_natural',
        priority: 0,
        reason: 'High risk area requires maximum organicity',
        confidence: 0.9
      });
    }

    // Ajustements basés sur la complexité
    if (geoAnalysis.complexityRating < 0.3) {
      recommendations.unshift({
        name: 'organic_natural',
        priority: 0,
        reason: 'Low complexity area needs organic curve generation',
        confidence: 0.85
      });
    }

    // Ajustements basés sur la distance
    if (params.distanceKm > 25 && geoAnalysis.complexityRating < 0.5) {
      recommendations.push({
        name: 'controlled_multi_waypoint',
        priority: recommendations.length + 1,
        reason: 'Long distance in simple area requires multiple waypoints',
        confidence: 0.8
      });
    }

    // Trier par priorité et confiance
    recommendations.sort((a, b) => {
      if (a.priority !== b.priority) return a.priority - b.priority;
      return b.confidence - a.confidence;
    });

    return recommendations.slice(0, 4); // Retourner top 4
  }

  /**
   * Calcul de la confiance dans une stratégie
   */
  calculateStrategyConfidence(strategyName, geoAnalysis) {
    let confidence = 0.5; // Base

    const strategyMapping = {
      'organic_natural': {
        good_for: ['low_complexity', 'urban_dense', 'high_risk'],
        bad_for: ['high_complexity', 'rural']
      },
      'organic_balanced': {
        good_for: ['medium_complexity', 'suburban', 'medium_risk'],
        bad_for: ['very_low_complexity']
      },
      'controlled_multi_waypoint': {
        good_for: ['urban_sparse', 'long_distance'],
        bad_for: ['rural', 'short_distance']
      },
      'enhanced_traditional': {
        good_for: ['high_complexity', 'rural', 'low_risk'],
        bad_for: ['urban_dense', 'high_risk']
      }
    };

    const strategy = strategyMapping[strategyName];
    if (!strategy) return confidence;

    // Augmenter la confiance pour les conditions favorables
    if (geoAnalysis.complexityRating < 0.3 && strategy.good_for.includes('low_complexity')) {
      confidence += 0.2;
    }
    if (geoAnalysis.complexityRating > 0.7 && strategy.good_for.includes('high_complexity')) {
      confidence += 0.2;
    }
    if (geoAnalysis.riskLevel === 'high' && strategy.good_for.includes('high_risk')) {
      confidence += 0.3;
    }
    if (geoAnalysis.zoneType.includes('urban') && strategy.good_for.includes('urban_dense')) {
      confidence += 0.15;
    }

    // Réduire la confiance pour les conditions défavorables
    if (geoAnalysis.complexityRating < 0.3 && strategy.bad_for.includes('very_low_complexity')) {
      confidence -= 0.2;
    }
    if (geoAnalysis.riskLevel === 'high' && strategy.bad_for.includes('high_risk')) {
      confidence -= 0.3;
    }

    return Math.max(0.1, Math.min(0.95, confidence));
  }

  /**
   * Optimisation des paramètres pour la géographie
   */
  optimizeForGeography(params, geoAnalysis) {
    const optimized = { ...params };
    const zoneQuality = this.zoneQualityFactors[geoAnalysis.zoneType] || this.zoneQualityFactors.suburban;

    // Ajustement du rayon de recherche
    if (geoAnalysis.complexityRating < 0.4) {
      // Zone simple = réduire le rayon pour plus de contrôle
      optimized.searchRadius = Math.max(1000, (optimized.searchRadius || 5000) * 0.7);
    } else if (geoAnalysis.complexityRating > 0.7) {
      // Zone complexe = augmenter le rayon pour profiter de la variété
      optimized.searchRadius = Math.min(50000, (optimized.searchRadius || 5000) * 1.3);
    }

    // Forcer la génération organique si nécessaire
    if (geoAnalysis.riskLevel === 'high' || geoAnalysis.complexityRating < 0.3) {
      optimized._forceOrganic = true;
      optimized._organicnessFactor = Math.max(0.7, zoneQuality.organicnessFactor);
    }

    // Ajustement du nombre de waypoints
    if (zoneQuality.waypointMultiplier !== 1.0) {
      optimized._waypointMultiplier = zoneQuality.waypointMultiplier;
    }

    // Forcer l'évitement des lignes droites si nécessaire
    if (zoneQuality.avoidStraightLines) {
      optimized._avoidStraightLines = true;
    }

    // Ajustements spécifiques aux contraintes
    geoAnalysis.constraints.forEach(constraint => {
      if (constraint.type === 'high_traffic_density') {
        optimized.avoidTraffic = true;
        optimized.preferScenic = true;
      }
      if (constraint.type === 'flat_terrain') {
        optimized._forceCurves = true;
      }
    });

    // Métadonnées d'optimisation
    optimized._geoOptimizations = {
      riskLevel: geoAnalysis.riskLevel,
      complexityRating: geoAnalysis.complexityRating,
      zoneType: geoAnalysis.zoneType,
      appliedOptimizations: this.getAppliedGeoOptimizations(params, optimized)
    };

    return optimized;
  }

  /**
   * Liste des optimisations géographiques appliquées
   */
  getAppliedGeoOptimizations(original, optimized) {
    const optimizations = [];

    if (optimized._forceOrganic) optimizations.push('forced_organic_generation');
    if (optimized._avoidStraightLines) optimizations.push('avoid_straight_lines');
    if (optimized._forceCurves) optimizations.push('force_natural_curves');
    if (optimized._waypointMultiplier && optimized._waypointMultiplier !== 1.0) {
      optimizations.push(`waypoint_multiplier_${optimized._waypointMultiplier}`);
    }
    if (optimized.searchRadius !== original.searchRadius) {
      optimizations.push('search_radius_adjusted');
    }

    return optimizations;
  }

  /**
   * Calcul de distance (Haversine)
   */
  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Rayon de la Terre en km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }
}

module.exports = GeographicAnalysisMiddleware;