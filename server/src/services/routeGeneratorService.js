// server/src/services/routeGeneratorService.js (VERSION AMÉLIORÉE)
const turf = require("@turf/turf");
const logger = require("../config/logger");
const graphhopperCloud = require("./graphhopperCloudService");
const routeQualityService = require("./routeQualityService");
const { metricsService } = require("./metricsService");

class RouteGeneratorService {
  constructor() {
    this.cache = new Map(); 
    this.retryConfig = {
      maxAttempts: 5,
      distanceToleranceRatio: 0.15, // ±15%
      backoffMultiplier: 1.2
    };
    console.log("🔧 RouteGeneratorService construit avec validation de qualité");
  }

  /**
   * Génère un itinéraire simple entre deux points avec validation
   */
  async generateSimpleRoute(params) {
    const { startLat, startLon, endLat, endLon, profile = 'foot' } = params;
    
    logger.info('Simple route generation started', {
      start: [startLat, startLon],
      end: [endLat, endLon],
      profile
    });

    try {
      const route = await graphhopperCloud.getRoute({
        points: [
          { lat: startLat, lon: startLon },
          { lat: endLat, lon: endLon }
        ],
        profile,
        algorithm: 'auto',
        avoidTraffic: false
      });

      // Validation basique pour les routes simples
      if (!route.coordinates || route.coordinates.length < 2) {
        throw new Error('Route invalide: pas assez de coordonnées');
      }

      logger.info('Simple route generated successfully', {
        distance: `${(route.distance / 1000).toFixed(1)}km`,
        duration: `${Math.round(route.duration / 60000)}min`,
        points: route.coordinates.length
      });

      return route;

    } catch (error) {
      logger.error('Simple route generation failed:', error);
      throw new Error(`Failed to generate simple route: ${error.message}`);
    }
  }

  /**
   * Génère un parcours avec validation de qualité et retry intelligent
   */
  async generateRoute(params) {
    const startTime = Date.now();
    const {
      startLat,
      startLon,
      activityType,
      distanceKm,
      terrainType,
      urbanDensity,
      elevationGain,
      isLoop,
      avoidTraffic,
      preferScenic,
    } = params;

    logger.info("Route generation started with quality control", {
      requestId: params.requestId,
      activityType,
      distanceKm,
      terrainType,
      startCoords: [startLat, startLon],
      maxAttempts: this.retryConfig.maxAttempts
    });

    let lastError;
    let attemptedStrategies = [];

    // Stratégies à essayer dans l'ordre
    const strategies = this.getGenerationStrategies(params);

    for (let attempt = 1; attempt <= this.retryConfig.maxAttempts; attempt++) {
      try {
        logger.info(`Route generation attempt ${attempt}/${this.retryConfig.maxAttempts}`);

        // Sélectionner la stratégie pour cette tentative
        const strategy = strategies[(attempt - 1) % strategies.length];
        attemptedStrategies.push(strategy.name);

        logger.info(`Using strategy: ${strategy.name}`, strategy.params);

        // Générer le parcours avec la stratégie sélectionnée
        let route;
        if (isLoop) {
          route = await this.generateLoopRouteWithStrategy(params, strategy);
        } else {
          route = await this.generatePointToPointRouteWithStrategy(params, strategy);
        }

        // Validation de qualité
        const qualityValidation = routeQualityService.validateRoute(route, params);
        
        logger.info('Route quality validation result:', {
          attempt,
          isValid: qualityValidation.isValid,
          quality: qualityValidation.quality,
          issues: qualityValidation.issues.length,
          actualDistance: route.distance / 1000,
          requestedDistance: distanceKm
        });

        // Si la qualité est acceptable, appliquer les corrections mineures et retourner
        if (qualityValidation.isValid || qualityValidation.quality !== 'critical') {
          const { route: fixedRoute, fixes } = routeQualityService.autoFixRoute(route, params);
          
          if (fixes.length > 0) {
            logger.info('Applied auto-fixes:', fixes);
          }

          // Ajouter les métadonnées de qualité
          fixedRoute.metadata = {
            ...fixedRoute.metadata,
            quality: qualityValidation.quality,
            generationAttempts: attempt,
            strategiesUsed: attemptedStrategies,
            appliedFixes: fixes,
            validationMetrics: qualityValidation.metrics
          };

          const duration = Date.now() - startTime;
          logger.info("Route generation completed successfully", {
            requestId: params.requestId,
            duration: `${duration}ms`,
            attempts: attempt,
            quality: qualityValidation.quality,
            distance: fixedRoute.distance / 1000,
            coordinatesCount: fixedRoute.coordinates.length,
            strategy: strategy.name
          });

          metricsService.recordRouteGeneration(true, fixedRoute.distance / 1000);
          return fixedRoute;
        }

        // Si la qualité est critique, essayer une autre stratégie
        lastError = new Error(`Route quality is ${qualityValidation.quality}: ${qualityValidation.issues.join(', ')}`);
        
        // Ajuster la stratégie pour la prochaine tentative
        if (qualityValidation.metrics.distance && !qualityValidation.metrics.distance.isValid) {
          strategies.forEach(s => {
            const ratio = qualityValidation.metrics.distance.ratio;
            if (ratio > 1.5) {
              // Route trop longue, réduire les paramètres
              s.params.searchRadius = Math.max(1000, s.params.searchRadius * 0.8);
              s.params.roundTripDistance = Math.max(1000, s.params.roundTripDistance * 0.8);
            } else if (ratio < 0.7) {
              // Route trop courte, augmenter les paramètres
              s.params.searchRadius = Math.min(50000, s.params.searchRadius * 1.3);
              s.params.roundTripDistance = Math.min(50000, s.params.roundTripDistance * 1.3);
            }
          });
        }

      } catch (error) {
        lastError = error;
        logger.warn(`Route generation attempt ${attempt} failed:`, {
          error: error.message,
          strategy: attemptedStrategies[attemptedStrategies.length - 1]
        });

        // Attendre avant la prochaine tentative (backoff)
        if (attempt < this.retryConfig.maxAttempts) {
          const delay = 1000 * Math.pow(this.retryConfig.backoffMultiplier, attempt - 1);
          await new Promise(resolve => setTimeout(resolve, delay));
        }
      }
    }

    // Toutes les tentatives ont échoué
    const duration = Date.now() - startTime;
    logger.error("Route generation failed after all attempts", {
      requestId: params.requestId,
      duration: `${duration}ms`,
      attempts: this.retryConfig.maxAttempts,
      strategiesUsed: attemptedStrategies,
      lastError: lastError.message
    });

    metricsService.recordRouteGeneration(false);
    throw new Error(`Unable to generate acceptable route after ${this.retryConfig.maxAttempts} attempts. Last error: ${lastError.message}`);
  }

  /**
   * Définit les stratégies de génération selon les paramètres
   */
  getGenerationStrategies(params) {
    const { distanceKm, isLoop, terrainType, preferScenic } = params;
    
    const baseSearchRadius = Math.max(2000, distanceKm * 800);
    const baseRoundTripDistance = distanceKm * 1000;

    const strategies = [
      // Stratégie 1: Paramètres par défaut optimisés
      {
        name: 'optimized_default',
        params: {
          searchRadius: baseSearchRadius,
          roundTripDistance: baseRoundTripDistance,
          algorithm: isLoop ? 'round_trip' : 'auto',
          seed: this.generateSmartSeed(params),
          avoidHighways: true,
          details: ['surface', 'road_class']
        }
      },
      
      // Stratégie 2: Rayon réduit pour plus de contrôle
      {
        name: 'controlled_radius',
        params: {
          searchRadius: baseSearchRadius * 0.7,
          roundTripDistance: baseRoundTripDistance * 0.9,
          algorithm: isLoop ? 'round_trip' : 'auto',
          seed: this.generateSmartSeed(params) + 1000,
          avoidHighways: true,
          preferScenic: preferScenic
        }
      },

      // Stratégie 3: Approche conservative
      {
        name: 'conservative',
        params: {
          searchRadius: Math.min(5000, baseSearchRadius * 0.5),
          roundTripDistance: baseRoundTripDistance * 0.8,
          algorithm: isLoop ? 'round_trip' : 'dijkstra',
          seed: this.generateSmartSeed(params) + 2000,
          avoidHighways: true,
          avoidToll: true
        }
      },

      // Stratégie 4: Multi-waypoints pour plus de contrôle
      {
        name: 'multi_waypoint',
        params: {
          useWaypoints: true,
          waypointCount: Math.max(3, Math.min(8, Math.floor(distanceKm / 3))),
          searchRadius: baseSearchRadius * 0.6,
          algorithm: 'auto'
        }
      },

      // Stratégie 5: Fallback avec paramètres très conservateurs
      {
        name: 'fallback_conservative',
        params: {
          searchRadius: Math.min(3000, distanceKm * 300),
          roundTripDistance: baseRoundTripDistance * 0.7,
          algorithm: 'auto',
          seed: this.generateSmartSeed(params) + 5000,
          avoidHighways: true,
          avoidToll: true,
          avoidFerries: true
        }
      }
    ];

    return strategies;
  }

  /**
   * Génère un seed intelligent basé sur la localisation et les paramètres
   */
  generateSmartSeed(params) {
    // Utiliser les coordonnées et paramètres pour générer un seed reproductible mais varié
    const { startLat, startLon, distanceKm, activityType } = params;
    
    const latInt = Math.floor(startLat * 1000);
    const lonInt = Math.floor(startLon * 1000);
    const distInt = Math.floor(distanceKm * 100);
    const activityHash = activityType.split('').reduce((a, b) => a + b.charCodeAt(0), 0);
    
    return (latInt + lonInt + distInt + activityHash) % 1000000;
  }

  /**
   * Génère un parcours en boucle avec une stratégie spécifique
   */
  async generateLoopRouteWithStrategy(params, strategy) {
    const { startLat, startLon, distanceKm, avoidTraffic } = params;
    const profile = graphhopperCloud.selectProfile(params.activityType, params.terrainType, params.preferScenic);

    if (strategy.params.useWaypoints) {
      // Utiliser la stratégie multi-waypoints
      return await this.generateManualLoopRouteWithControl(params, strategy, profile);
    }

    // Utiliser l'API round_trip de GraphHopper avec paramètres contrôlés
    const ghParams = {
      points: [{ lat: startLat, lon: startLon }],
      profile,
      algorithm: strategy.params.algorithm,
      roundTripDistance: strategy.params.roundTripDistance,
      roundTripSeed: strategy.params.seed,
      avoidTraffic: avoidTraffic || strategy.params.avoidHighways,
      details: strategy.params.details || ['surface']
    };

    logger.info('Generating loop with GraphHopper round_trip', {
      targetDistance: distanceKm,
      roundTripDistance: strategy.params.roundTripDistance,
      seed: strategy.params.seed,
      profile
    });

    const route = await graphhopperCloud.getRoute(ghParams);

    // Validation immédiate de la distance
    const actualDistanceKm = route.distance / 1000;
    const ratio = actualDistanceKm / distanceKm;

    if (ratio < 0.5 || ratio > 2.0) {
      throw new Error(`Distance ratio too extreme: ${ratio.toFixed(2)} (${actualDistanceKm.toFixed(1)}km vs ${distanceKm}km requested)`);
    }

    return route;
  }

  /**
   * Génère un parcours point-à-point avec une stratégie spécifique
   */
  async generatePointToPointRouteWithStrategy(params, strategy) {
    const { startLat, startLon, distanceKm, avoidTraffic } = params;
    const profile = graphhopperCloud.selectProfile(params.activityType, params.terrainType, params.preferScenic);

    // Calculer un point d'arrivée intelligent
    const bearing = this.calculateOptimalBearing(params, strategy);
    const targetDistance = distanceKm * 0.7; // 70% de la distance en ligne droite

    const endpoint = turf.destination(
      [startLon, startLat],
      targetDistance,
      bearing,
      { units: "kilometers" }
    );

    const route = await graphhopperCloud.getRoute({
      points: [
        { lat: startLat, lon: startLon },
        {
          lat: endpoint.geometry.coordinates[1],
          lon: endpoint.geometry.coordinates[0],
        },
      ],
      profile,
      avoidTraffic: avoidTraffic || strategy.params.avoidHighways,
      details: strategy.params.details || ['surface']
    });

    // Ajuster si nécessaire
    return await this.adjustRouteDistanceWithControl(route, distanceKm, profile, strategy);
  }

  /**
   * Calcule un bearing optimal selon la stratégie
   */
  calculateOptimalBearing(params, strategy) {
    const { preferScenic, terrainType, urbanDensity } = params;
    
    let bearing = Math.random() * 360;
    
    // Ajuster selon les préférences
    if (preferScenic && terrainType === 'nature') {
      // Privilégier les directions vers les espaces verts (approximation)
      bearing = (Math.random() * 180) + 90; // Entre 90° et 270° (est-ouest)
    }
    
    if (urbanDensity === 'urban') {
      // Éviter les directions vers le centre-ville (approximation)
      bearing = (bearing + 180) % 360;
    }
    
    return bearing;
  }

  /**
   * Génère une boucle manuelle avec contrôle de distance
   */
  async generateManualLoopRouteWithControl(params, strategy, profile) {
    const { startLat, startLon, distanceKm } = params;
    
    logger.info("Generating manual loop with waypoint control", {
      waypointCount: strategy.params.waypointCount,
      targetDistance: distanceKm
    });

    // Créer des waypoints avec un contrôle plus strict de la distance
    const waypoints = this.generateControlledLoopWaypoints(
      startLat,
      startLon,
      distanceKm,
      strategy.params.waypointCount
    );

    const route = await graphhopperCloud.getRoute({
      points: waypoints,
      profile,
      avoidTraffic: strategy.params.avoidHighways
    });

    return route;
  }

  /**
   * Génère des waypoints avec contrôle de distance
   */
  generateControlledLoopWaypoints(startLat, startLon, distanceKm, waypointCount) {
    const waypoints = [{ lat: startLat, lon: startLon }];
    
    // Calculer le rayon pour que le périmètre approximatif soit proche de la distance cible
    const radiusKm = distanceKm / (2 * Math.PI) * 1.3; // Facteur de correction pour les routes réelles
    
    for (let i = 0; i < waypointCount; i++) {
      const bearing = (360 / waypointCount) * i;
      const distance = radiusKm * (0.9 + Math.random() * 0.2); // Variation ±10%

      const waypoint = turf.destination(
        [startLon, startLat],
        distance,
        bearing,
        { units: "kilometers" }
      );

      waypoints.push({
        lat: waypoint.geometry.coordinates[1],
        lon: waypoint.geometry.coordinates[0],
      });
    }

    // Retourner au point de départ
    waypoints.push({ lat: startLat, lon: startLon });

    return waypoints;
  }

  /**
   * Ajuste la distance avec contrôle strict
   */
  async adjustRouteDistanceWithControl(route, targetDistanceKm, profile, strategy) {
    const currentDistanceKm = route.distance / 1000;
    const ratio = targetDistanceKm / currentDistanceKm;

    // Si la distance est acceptable, ne rien faire
    if (Math.abs(ratio - 1) < this.retryConfig.distanceToleranceRatio) {
      return route;
    }

    logger.info(`Adjusting route distance: ${currentDistanceKm.toFixed(1)}km -> ${targetDistanceKm}km (ratio: ${ratio.toFixed(2)})`);

    // Selon la différence, appliquer différentes stratégies
    if (ratio > 1.2 && ratio < 2.0) {
      // Route trop courte, mais pas trop - ajouter un petit détour
      return await this.addControlledDetour(route, targetDistanceKm, profile);
    } else if (ratio < 0.8 && ratio > 0.5) {
      // Route trop longue, mais pas trop - essayer de raccourcir
      return await this.shortenRouteControlled(route, targetDistanceKm, profile);
    }

    // Si l'écart est trop important, lancer une erreur pour essayer une autre stratégie
    throw new Error(`Distance adjustment needed is too large: ratio ${ratio.toFixed(2)}`);
  }

  /**
   * Ajoute un détour contrôlé pour allonger le parcours
   */
  async addControlledDetour(route, targetDistanceKm, profile) {
    const currentDistanceKm = route.distance / 1000;
    const additionalKm = targetDistanceKm - currentDistanceKm;
    
    // Trouver le point optimal pour insérer le détour (milieu du parcours)
    const midIndex = Math.floor(route.coordinates.length / 2);
    const detourPoint = route.coordinates[midIndex];

    // Créer un détour perpendiculaire
    const bearing = this.calculatePerpendicularBearing(route.coordinates, midIndex);
    const detourDistance = Math.min(additionalKm / 2, 2); // Max 2km de détour

    const detourWaypoint = turf.destination(
      detourPoint,
      detourDistance,
      bearing,
      { units: "kilometers" }
    );

    // Reconstruire le parcours avec le détour
    const waypoints = [
      { lat: route.coordinates[0][1], lon: route.coordinates[0][0] },
      { 
        lat: detourWaypoint.geometry.coordinates[1], 
        lon: detourWaypoint.geometry.coordinates[0] 
      },
      { 
        lat: route.coordinates[route.coordinates.length - 1][1], 
        lon: route.coordinates[route.coordinates.length - 1][0] 
      }
    ];

    return await graphhopperCloud.getRoute({
      points: waypoints,
      profile
    });
  }

  /**
   * Calcule un bearing perpendiculaire au parcours
   */
  calculatePerpendicularBearing(coordinates, index) {
    if (index === 0 || index >= coordinates.length - 1) {
      return Math.random() * 360;
    }

    const bearing = turf.bearing(coordinates[index - 1], coordinates[index + 1]);
    return (bearing + 90) % 360; // Perpendiculaire
  }

  /**
   * Raccourcit un parcours de manière contrôlée
   */
  async shortenRouteControlled(route, targetDistanceKm, profile) {
    // Stratégie simple: créer un parcours plus direct
    const start = route.coordinates[0];
    const end = route.coordinates[route.coordinates.length - 1];
    
    // Si c'est une boucle, créer une boucle plus petite
    if (this.isLoop(route.coordinates)) {
      const centerLat = start[1];
      const centerLon = start[0];
      const newRadius = targetDistanceKm / 8; // Rayon plus petit

      const smallWaypoints = [{ lat: centerLat, lon: centerLon }];
      
      for (let i = 0; i < 3; i++) {
        const bearing = (360 / 3) * i;
        const waypoint = turf.destination(
          [centerLon, centerLat],
          newRadius,
          bearing,
          { units: "kilometers" }
        );

        smallWaypoints.push({
          lat: waypoint.geometry.coordinates[1],
          lon: waypoint.geometry.coordinates[0],
        });
      }
      
      smallWaypoints.push({ lat: centerLat, lon: centerLon });

      return await graphhopperCloud.getRoute({
        points: smallWaypoints,
        profile
      });
    }

    // Pour les parcours point-à-point, retourner tel quel
    return route;
  }

  // ... (garder les autres méthodes existantes sans modification)
  isLoop(coordinates) {
    if (coordinates.length < 2) return false;
    const start = coordinates[0];
    const end = coordinates[coordinates.length - 1];
    const distance = turf.distance(start, end, { units: "meters" });
    return distance < 100;
  }

  calculateElevationGain(elevationProfile) {
    let totalGain = 0;
    for (let i = 1; i < elevationProfile.length; i++) {
      const diff = elevationProfile[i].elevation - elevationProfile[i - 1].elevation;
      if (diff > 0) {
        totalGain += diff;
      }
    }
    return Math.round(totalGain);
  }

  async analyzeExistingRoute(coordinates) {
    try {
      let totalDistance = 0;
      for (let i = 1; i < coordinates.length; i++) {
        totalDistance += turf.distance(coordinates[i - 1], coordinates[i], {
          units: "meters",
        });
      }

      const elevationData = await graphhopperCloud.getElevation(coordinates);
      const elevationGain = this.calculateElevationGain(elevationData);
      const elevationLoss = this.calculateElevationLoss(elevationData);
      const { averageGrade, maxGrade } = this.calculateGrades(elevationData);
      const estimatedDuration = this.estimateDuration(totalDistance, elevationGain);

      return {
        distance: totalDistance,
        elevationGain,
        elevationLoss,
        averageGrade,
        maxGrade,
        estimatedDuration,
        elevationProfile: elevationData,
      };
    } catch (error) {
      logger.error("Erreur analyse parcours:", error);
      throw new Error("Impossible d'analyser le parcours");
    }
  }

  calculateElevationLoss(elevationProfile) {
    let totalLoss = 0;
    for (let i = 1; i < elevationProfile.length; i++) {
      const diff = elevationProfile[i].elevation - elevationProfile[i - 1].elevation;
      if (diff < 0) {
        totalLoss += Math.abs(diff);
      }
    }
    return Math.round(totalLoss);
  }

  calculateGrades(elevationProfile) {
    const grades = [];
    for (let i = 1; i < elevationProfile.length; i++) {
      const elevationDiff = elevationProfile[i].elevation - elevationProfile[i - 1].elevation;
      const distance = turf.distance(
        [elevationProfile[i - 1].lon, elevationProfile[i - 1].lat],
        [elevationProfile[i].lon, elevationProfile[i].lat],
        { units: "meters" }
      );

      if (distance > 0) {
        const grade = (elevationDiff / distance) * 100;
        grades.push(grade);
      }
    }

    const averageGrade = grades.length > 0 ? grades.reduce((a, b) => a + b, 0) / grades.length : 0;
    const maxGrade = grades.length > 0 ? Math.max(...grades.map(Math.abs)) : 0;

    return {
      averageGrade: Math.round(averageGrade * 10) / 10,
      maxGrade: Math.round(maxGrade * 10) / 10,
    };
  }

  estimateDuration(distanceMeters, elevationGain) {
    const baseSpeed = 80;
    let duration = distanceMeters / baseSpeed;
    duration += elevationGain / 10;
    return Math.round(duration);
  }
}

const serviceInstance = new RouteGeneratorService();

console.log("🔧 RouteGeneratorService amélioré créé avec validation de qualité");

module.exports = serviceInstance;