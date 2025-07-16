const turf = require("@turf/turf");
const logger = require("../config/logger");
const graphhopperCloud = require("./graphhopperCloudService");
const routeQualityService = require("./routeQualityService");
const { metricsService } = require("./metricsService");
const groqService = require("./groqService");

class RouteGeneratorService {
  constructor() {
    this.cache = new Map(); 
    this.retryConfig = {
      maxAttempts: 3,              // ✅ RÉDUIT : 5 -> 3 tentatives
      distanceToleranceRatio: 0.15,
      backoffMultiplier: 1.5       // ✅ AUGMENTÉ : délais plus longs
    };
    
    // ✅ NOUVEAUX PARAMÈTRES POUR GÉNÉRATION ORGANIQUE (CORRIGÉS)
    this.organicConfig = {
      minWaypoints: 1,           // ✅ RÉDUIRE : Minimum waypoints 
      maxWaypoints: 3,           // ✅ CRITIQUE : Maximum 3 waypoints (+ départ = 4 points total)
      waypointSpread: 0.3,       // Spread des waypoints (30% de la distance)
      organicnessFactor: 0.7,    // Facteur d'organicité (0-1)
      naturalCurveFactor: 1.2,   // Facteur de courbure naturelle
      avoidanceRadius: 200       // Rayon d'évitement des segments droits
    };
    
    console.log("🔧 RouteGeneratorService amélioré avec génération organique - API GraphHopper compliant");
  }

  /**
   * Génère un parcours avec algorithmes organiques améliorés
   */
  async generateRoute(params) {
    const startTime = Date.now();
  
    let aiTweaks;
    try {
      aiTweaks = await groqService.suggestGenerationTweaks(params);
      if (aiTweaks && typeof aiTweaks === 'object') {
        params = { ...params, ...aiTweaks };
        logger.info('Applied Groq AI tweaks', { aiTweaks });
      }
    } catch (err) {
      logger.warn('Groq AI tweak retrieval failed', err.message);
    }
  
    // 🆕 EXTRACTION DES NOUVEAUX PARAMÈTRES
    const {
      startLat,
      startLon,
      activityType,
      distanceKm,
      terrainType,
      urbanDensity,
      // Anciens paramètres maintenus pour compatibilité
      elevationGain,
      // 🆕 Nouveaux paramètres
      elevationRange,
      difficulty = 'moderate',
      maxInclinePercent = 12.0,
      preferredWaypoints = 3,
      avoidHighways = true,
      prioritizeParks = false,
      surfacePreference = 0.5,
      isLoop,
      avoidTraffic,
      preferScenic,
    } = params;
  
    // 🆕 MIGRATION : gérer elevationRange ou elevationGain
    const actualElevationRange = elevationRange || {
      min: 0,
      max: elevationGain || 0
    };
  
    logger.info("Enhanced route generation started", {
      requestId: params.requestId,
      activityType,
      distanceKm,
      terrainType,
      difficulty,
      elevationRange: actualElevationRange,
      maxInclinePercent,
      preferredWaypoints,
      surfacePreference,
      startCoords: [startLat, startLon],
      maxAttempts: this.retryConfig.maxAttempts
    });
  
    let lastError;
    let attemptedStrategies = [];
  
    // 🆕 STRATÉGIES ENRICHIES avec nouveaux paramètres
    const strategies = this.getEnhancedGenerationStrategies({
      ...params,
      elevationRange: actualElevationRange,
      difficulty,
      maxInclinePercent,
      preferredWaypoints,
      avoidHighways,
      prioritizeParks,
      surfacePreference
    });
  
    for (let attempt = 1; attempt <= this.retryConfig.maxAttempts; attempt++) {
      try {
        logger.info(`Enhanced route generation attempt ${attempt}/${this.retryConfig.maxAttempts}`);
    
        const strategy = strategies[(attempt - 1) % strategies.length];
        attemptedStrategies.push(strategy.name);
    
        logger.info(`Using enhanced strategy: ${strategy.name}`, {
          isOrganic: strategy.isOrganic,
          waypointCount: strategy.params.waypointCount,
          difficulty: difficulty,
          maxIncline: maxInclinePercent
        });
    
        // 🆕 GÉNÉRATION avec paramètres enrichis
        let route;
        if (strategy.isOrganic) {
          route = await this.generateOrganicRoute({
            ...params,
            elevationRange: actualElevationRange,
            difficulty,
            maxInclinePercent,
            preferredWaypoints,
            avoidHighways,
            prioritizeParks,
            surfacePreference
          }, strategy);
        } else if (isLoop) {
          route = await this.generateLoopRouteWithStrategy({
            ...params,
            elevationRange: actualElevationRange,
            difficulty,
            maxInclinePercent,
            preferredWaypoints,
            avoidHighways,
            prioritizeParks,
            surfacePreference
          }, strategy);
        } else {
          route = await this.generatePointToPointRouteWithStrategy({
            ...params,
            elevationRange: actualElevationRange,
            difficulty,
            maxInclinePercent,
            preferredWaypoints,
            avoidHighways,
            prioritizeParks,
            surfacePreference
          }, strategy);
        }
    
        // Validation de qualité
        const qualityValidation = routeQualityService.validateRoute(route, {
          ...params,
          elevationRange: actualElevationRange,
          difficulty,
          maxInclinePercent
        });
    
        logger.info('Enhanced route quality validation:', {
          attempt,
          isValid: qualityValidation.isValid,
          quality: qualityValidation.quality,
          difficulty: difficulty,
          actualDistance: route.distance / 1000
        });
    
        const isAcceptableQuality = qualityValidation.quality !== 'critical';
    
        if (isAcceptableQuality) {
          const { route: fixedRoute, fixes } = routeQualityService.autoFixRoute(route, {
            ...params,
            elevationRange: actualElevationRange,
            difficulty,
            maxInclinePercent
          });
          
          if (fixes.length > 0) {
            logger.info('Applied auto-fixes for enhanced route:', fixes);
          }
    
          // 🆕 MÉTADONNÉES ENRICHIES
          fixedRoute.metadata = {
            ...fixedRoute.metadata,
            aiTweaks,
            quality: qualityValidation.quality,
            generationAttempts: attempt,
            strategiesUsed: attemptedStrategies,
            appliedFixes: fixes,
            validationMetrics: qualityValidation.metrics,
            isOrganic: strategy.isOrganic,
            // Nouveaux paramètres dans les métadonnées
            difficulty: difficulty,
            elevationRange: actualElevationRange,
            maxInclinePercent: maxInclinePercent,
            preferredWaypoints: preferredWaypoints,
            surfacePreference: surfacePreference,
            avoidHighways: avoidHighways,
            prioritizeParks: prioritizeParks
          };
    
          const duration = Date.now() - startTime;
          logger.info("Enhanced route generation completed successfully", {
            requestId: params.requestId,
            duration: `${duration}ms`,
            attempts: attempt,
            quality: qualityValidation.quality,
            difficulty: difficulty,
            distance: fixedRoute.distance / 1000,
            coordinatesCount: fixedRoute.coordinates.length,
            strategy: strategy.name
          });
    
          metricsService.recordRouteGeneration(true, fixedRoute.distance / 1000);
          return fixedRoute;
        }
  
        lastError = new Error(`Route quality insufficient: ${qualityValidation.quality}`);
    
      } catch (error) {
        lastError = error;
        logger.warn(`Enhanced route generation attempt ${attempt} failed:`, {
          error: error.message,
          strategy: attemptedStrategies[attemptedStrategies.length - 1]
        });
    
        if (error.message.includes('429') || error.message.includes('Too Many Requests')) {
          logger.warn('GraphHopper API rate limit reached, trying fallback strategy');
          
          try {
            const fallbackRoute = await this.generateSimpleFallbackRoute({
              ...params,
              elevationRange: actualElevationRange,
              difficulty,
              avoidHighways
            });
            logger.info('Fallback route generated successfully due to rate limiting');
            
            metricsService.recordRouteGeneration(true, fallbackRoute.distance / 1000);
            return fallbackRoute;
          } catch (fallbackError) {
            logger.error('Fallback route also failed:', fallbackError.message);
            throw new Error('Service temporarily unavailable due to API rate limits');
          }
        }
    
        if (attempt < this.retryConfig.maxAttempts) {
          const delay = 2000 * Math.pow(this.retryConfig.backoffMultiplier, attempt - 1);
          logger.info(`Waiting ${delay}ms before next attempt due to API limits`);
          await new Promise(resolve => setTimeout(resolve, delay));
        }
      }
    }
  
    // Toutes les tentatives ont échoué
    const duration = Date.now() - startTime;
    logger.error("Enhanced route generation failed after all attempts", {
      requestId: params.requestId,
      duration: `${duration}ms`,
      attempts: this.retryConfig.maxAttempts,
      strategiesUsed: attemptedStrategies,
      lastError: lastError.message
    });
  
    metricsService.recordRouteGeneration(false);
    throw new Error(`Unable to generate acceptable enhanced route after ${this.retryConfig.maxAttempts} attempts. Last error: ${lastError.message}`);
  }  

  async generateWithProgressiveFallback(params) {
    const maxAttempts = 5; // Plus d'attempts avec stratégies différentes
    let lastError;
    
    // Stratégies progressivement plus permissives
    const fallbackStrategies = [
      { name: 'optimal', adjustments: {} },
      { name: 'relaxed_distance', adjustments: { distanceTolerance: 1.3 } },
      { name: 'simplified', adjustments: { 
        _minimumWaypoints: 1, 
        _organicnessFactor: 0.4 
      }},
      { name: 'basic_loop', adjustments: { 
        algorithm: 'round_trip',
        _forceSimple: true,
        _minimumWaypoints: 0
      }},
      { name: 'emergency', adjustments: {
        distanceKm: params.distanceKm * 0.8, // Réduire la distance
        _acceptAnyQuality: true
      }}
    ];
    
    for (let i = 0; i < maxAttempts; i++) {
      try {
        const strategy = fallbackStrategies[Math.min(i, fallbackStrategies.length - 1)];
        const attemptParams = {
          ...params,
          ...strategy.adjustments,
          _attemptNumber: i,
          _strategyName: strategy.name
        };
        
        logger.info(`Fallback attempt ${i + 1}/${maxAttempts}`, {
          strategy: strategy.name,
          adjustments: Object.keys(strategy.adjustments)
        });
        
        const route = await this.generateRoute(attemptParams);
        
        // Si on accepte n'importe quelle qualité, on prend
        if (attemptParams._acceptAnyQuality || route.metadata?.quality !== 'critical') {
          route.metadata = {
            ...route.metadata,
            fallbackStrategy: strategy.name,
            attemptNumber: i + 1
          };
          return route;
        }
        
      } catch (error) {
        lastError = error;
        logger.warn(`Fallback attempt ${i + 1} failed:`, error.message);
      }
    }
    
    // Dernier recours : générer un simple carré/triangle
    return this.generateEmergencyRoute(params);
  }
  
  // Méthode d'urgence pour toujours retourner quelque chose
  async generateEmergencyRoute(params) {
    const { startLat, startLon, distanceKm } = params;
    
    logger.warn('Using emergency route generation');
    
    // Générer un simple parcours triangulaire
    const radius = Math.sqrt(distanceKm * 1000 / (3 * Math.PI));
    const points = [];
    
    for (let i = 0; i < 3; i++) {
      const angle = (i * 120) + Math.random() * 30; // Triangle avec variation
      const point = turf.destination(
        [startLon, startLat],
        radius / 1000,
        angle,
        { units: 'kilometers' }
      );
      points.push({
        lat: point.geometry.coordinates[1],
        lon: point.geometry.coordinates[0]
      });
    }
    
    // Ajouter le point de départ à la fin pour fermer la boucle
    points.push({ lat: startLat, lon: startLon });
    
    try {
      // Essayer de router entre ces points
      const route = await graphhopperCloud.getRoute({
        points: [{ lat: startLat, lon: startLon }, ...points.slice(0, 2)],
        profile: 'foot',
        algorithm: 'round_trip',
        roundTripDistance: distanceKm * 1000
      });
      
      route.metadata = {
        ...route.metadata,
        emergency: true,
        quality: 'emergency',
        message: 'Route générée en mode urgence - qualité limitée'
      };
      
      return route;
      
    } catch (error) {
      // Retourner au moins les coordonnées
      return {
        coordinates: points.map(p => [p.lon, p.lat]),
        distance: distanceKm * 1000,
        duration: distanceKm * 12 * 60000, // Estimation 12min/km
        metadata: {
          emergency: true,
          quality: 'emergency',
          error: 'GraphHopper unavailable',
          message: 'Parcours basique généré localement'
        }
      };
    }
  }

  /**
 * NOUVELLE : Génération de fallback simple en cas de rate limiting
 */
  async generateSimpleFallbackRoute(params) {
    const { 
      startLat, 
      startLon, 
      distanceKm, 
      isLoop,
      avoidHighways = true 
    } = params;
    
    const profile = graphhopperCloud.selectProfile(
      params.activityType, 
      params.terrainType, 
      params.preferScenic
    );
  
    logger.info('Generating enhanced fallback route due to API constraints');
  
    if (isLoop) {
      return await graphhopperCloud.getRoute({
        points: [{ lat: startLat, lon: startLon }],
        profile,
        algorithm: 'round_trip',
        roundTripDistance: distanceKm * 1000,
        roundTripSeed: Math.floor(Math.random() * 1000),
        avoidHighways: avoidHighways, // 🆕 Utiliser le paramètre
        details: ['surface'] // 🆕 Demander infos surface
      });
    } else {
      const bearing = Math.random() * 360;
      const targetDistance = distanceKm * 0.8;
      
      const endpoint = turf.destination(
        [startLon, startLat],
        targetDistance,
        bearing,
        { units: "kilometers" }
      );
  
      return await graphhopperCloud.getRoute({
        points: [
          { lat: startLat, lon: startLon },
          { lat: endpoint.geometry.coordinates[1], lon: endpoint.geometry.coordinates[0] }
        ],
        profile,
        avoidHighways: avoidHighways // 🆕 Utiliser le paramètre
      });
    }
  }

  /**
   * NOUVELLE : Stratégies de génération améliorées avec approche organique
   */
  getEnhancedGenerationStrategies(params) {
    const { 
      distanceKm, 
      isLoop, 
      terrainType, 
      preferScenic, 
      activityType,
      difficulty = 'moderate',
      maxInclinePercent = 12.0,
      preferredWaypoints = 3,
      avoidHighways = true,
      prioritizeParks = false,
      surfacePreference = 0.5,
      elevationRange = { min: 0, max: 0 }
    } = params;
    
    const baseSearchRadius = Math.max(2000, distanceKm * 800);
    const baseRoundTripDistance = distanceKm * 1000;
  
    // 🆕 AJUSTEMENT SELON LA DIFFICULTÉ
    const difficultyMultipliers = {
      'easy': { organic: 0.4, waypoints: 0.7, radius: 0.8 },
      'moderate': { organic: 0.6, waypoints: 1.0, radius: 1.0 },
      'hard': { organic: 0.8, waypoints: 1.3, radius: 1.2 },
      'expert': { organic: 0.9, waypoints: 1.5, radius: 1.4 }
    };
  
    const diffMultiplier = difficultyMultipliers[difficulty] || difficultyMultipliers['moderate'];
  
    // ✅ CALCUL INTELLIGENT DU NOMBRE DE WAYPOINTS AVEC LIMITE STRICTE
    const rawWaypointCount = preferredWaypoints * diffMultiplier.waypoints;
    const adaptiveWaypointCount = Math.min(
      this.organicConfig.maxWaypoints, // Limite absolue de la classe
      Math.max(
        this.organicConfig.minWaypoints,
        Math.floor(rawWaypointCount / 2)
      )
    );

    logger.info('Enhanced strategies waypoint calculation', {
      difficulty,
      preferredWaypoints,
      rawCalculation: rawWaypointCount,
      adaptiveCount: adaptiveWaypointCount,
      maxAllowed: this.organicConfig.maxWaypoints
    });

    const strategies = [
      // Stratégie 1: Organique adaptée à la difficulté
      {
        name: 'organic_adaptive',
        isOrganic: true,
        params: {
          waypointCount: adaptiveWaypointCount,
          organicnessFactor: 0.7 * diffMultiplier.organic,
          naturalCurveFactor: 1.2 + (difficulty === 'expert' ? 0.3 : 0),
          searchRadius: baseSearchRadius * diffMultiplier.radius,
          avoidStraightLines: difficulty !== 'easy',
          useNaturalCurves: surfacePreference < 0.7,
          spreadPattern: 'adaptive',
          // 🆕 Nouveaux paramètres intégrés
          maxInclinePercent: maxInclinePercent,
          prioritizeParks: prioritizeParks,
          surfacePreference: surfacePreference,
          avoidHighways: avoidHighways
        }
      },
  
      // Stratégie 2: Contrôlée selon surface et parcs
      {
        name: 'surface_optimized',
        isOrganic: false,
        params: {
          useWaypoints: true,
          waypointCount: Math.min(adaptiveWaypointCount, 2), // ✅ Plus conservateur
          searchRadius: baseSearchRadius * (prioritizeParks ? 1.3 : 0.9),
          algorithm: 'auto',
          waypointDistribution: prioritizeParks ? 'park_focused' : 'standard',
          preferAsphalt: surfacePreference > 0.7,
          preferNatural: surfacePreference < 0.3,
          avoidHighways: avoidHighways,
          maxInclinePercent: maxInclinePercent
        }
      },
  
      // Stratégie 3: Élevation consciente  
      {
        name: 'elevation_aware',
        isOrganic: false,
        params: {
          searchRadius: baseSearchRadius,
          roundTripDistance: baseRoundTripDistance,
          algorithm: isLoop ? 'round_trip' : 'auto',
          seed: this.generateElevationAwareSeed(params),
          avoidHighways: avoidHighways,
          targetElevationGain: elevationRange.max,
          maxInclinePercent: maxInclinePercent,
          preferHilly: elevationRange.max > 200,
          details: ['surface', 'road_class', 'elevation']
        }
      },
  
      // Stratégie 4: Fallback adaptatif (ultra conservateur)
      {
        name: 'adaptive_fallback',
        isOrganic: difficulty === 'expert',
        params: {
          waypointCount: Math.min(1, adaptiveWaypointCount), // ✅ 1 waypoint maximum en fallback
          organicnessFactor: 0.3 * diffMultiplier.organic,
          searchRadius: Math.min(5000, baseSearchRadius * 0.8),
          avoidStraightLines: false,
          spreadPattern: 'simple',
          maxInclinePercent: Math.min(maxInclinePercent, 15.0),
          avoidHighways: avoidHighways,
          surfacePreference: Math.max(0.3, surfacePreference)
        }
      }
    ];
  
    logger.info('Generated enhanced strategies with API compliance', {
      difficulty,
      adaptiveWaypointCount,
      maxWaypointsAllowed: this.organicConfig.maxWaypoints,
      surfacePreference,
      prioritizeParks,
      strategiesCount: strategies.length
    });
  
    return strategies;
  }

  generateElevationAwareSeed(params) {
    const { 
      startLat, 
      startLon, 
      distanceKm, 
      activityType, 
      elevationRange = { min: 0, max: 0 },
      difficulty = 'moderate'
    } = params;
    
    const latInt = Math.floor(startLat * 1000);
    const lonInt = Math.floor(startLon * 1000);
    const distInt = Math.floor(distanceKm * 100);
    const activityHash = activityType.split('').reduce((a, b) => a + b.charCodeAt(0), 0);
    const elevationHash = Math.floor(elevationRange.max * 10);
    const difficultyHash = difficulty.split('').reduce((a, b) => a + b.charCodeAt(0), 0);
    
    return (latInt + lonInt + distInt + activityHash + elevationHash + difficultyHash) % 1000000;
  }  

  /**
   * NOUVELLE : Génération de parcours organique
   */
  async generateOrganicRoute(params, strategy) {
    const { 
      startLat, 
      startLon, 
      distanceKm,
      avoidHighways = true,
      prioritizeParks = false,
      surfacePreference = 0.5,
      maxInclinePercent = 12.0
    } = params;
    
    const profile = graphhopperCloud.selectProfile(
      params.activityType, 
      params.terrainType, 
      params.preferScenic
    );
  
    logger.info('Generating enhanced organic route', {
      strategy: strategy.name,
      organicnessFactor: strategy.params.organicnessFactor,
      waypointCount: strategy.params.waypointCount,
      avoidHighways,
      prioritizeParks,
      surfacePreference
    });
  
    // 🆕 PARAMÈTRES ENRICHIS pour GraphHopper
    const ghParams = {
      points: [{ lat: startLat, lon: startLon }],
      profile,
      algorithm: 'round_trip',
      roundTripDistance: distanceKm * 1000,
      roundTripSeed: Math.floor(Math.random() * 1000000),
      // 🆕 Paramètres enrichis
      avoidTraffic: params.avoidTraffic,
      avoidHighways: avoidHighways,
      // Transmission des paramètres organiques
      _forceOrganic: true,
      _organicnessFactor: strategy.params.organicnessFactor,
      _avoidStraightLines: strategy.params.avoidStraightLines,
      _forceCurves: strategy.params.useNaturalCurves,
      _maxInclinePercent: maxInclinePercent,
      _prioritizeParks: prioritizeParks,
      _surfacePreference: surfacePreference
    };
  
    // 🆕 AJUSTEMENTS SELON SURFACE PREFERENCE
    if (surfacePreference < 0.3) {
      // Préférence chemins naturels
      ghParams.details = ['surface', 'road_class'];
      ghParams._preferUnpaved = true;
    } else if (surfacePreference > 0.7) {
      // Préférence asphalte
      ghParams._preferPaved = true;
    }
  
    const route = await graphhopperCloud.getRoute(ghParams);
  
    // Forcer la fermeture de boucle
    return this.ensureLoopClosure(route, { lat: startLat, lon: startLon });
  }  
  
  /**
   * FIX: Garantir la fermeture de boucle
   */
  ensureLoopClosure(route, startPoint) {
    if (!route.coordinates || route.coordinates.length < 2) {
      return route;
    }
  
    const start = route.coordinates[0];
    const end = route.coordinates[route.coordinates.length - 1];
    const distance = turf.distance(start, end, { units: 'meters' });
  
    // ✅ FIX: Toujours forcer la fermeture pour les boucles
    if (distance > 50) { // Seuil réduit à 50m
      logger.info('Forcing loop closure', {
        originalEndDistance: Math.round(distance),
        startPoint: [startPoint.lat, startPoint.lon]
      });
  
      // Remplacer le dernier point par le premier exactement
      const closedCoordinates = [...route.coordinates];
      closedCoordinates[closedCoordinates.length - 1] = [...start];
  
      // Recalculer la distance
      let newDistance = 0;
      for (let i = 1; i < closedCoordinates.length; i++) {
        newDistance += turf.distance(
          closedCoordinates[i-1],
          closedCoordinates[i],
          { units: 'meters' }
        );
      }
  
      return {
        ...route,
        coordinates: closedCoordinates,
        distance: newDistance,
        metadata: {
          ...route.metadata,
          loopClosed: true,
          originalEndDistance: distance
        }
      };
    }
  
    return route;
  }

  /**
   * NOUVELLE : Génération de waypoints organiques
   */
  generateOrganicWaypoints(centerPoint, targetDistance, organicnessFactor, enhancedParams = {}) {
    const {
      preferredWaypoints = 3,
      prioritizeParks = false,
      surfacePreference = 0.5,
      difficulty = 'moderate'
    } = enhancedParams;
  
    const waypoints = [centerPoint];
    
    // ✅ CALCUL ADAPTATIF avec limites strictes de l'API
    const difficultyFactors = {
      'easy': 1,
      'moderate': 1.5,
      'hard': 2,
      'expert': 2
    };
  
    const rawWaypointCount = Math.floor(preferredWaypoints * difficultyFactors[difficulty] / 3);
    const waypointCount = Math.min(
      this.organicConfig.maxWaypoints, // Limite absolue (3)
      Math.max(
        this.organicConfig.minWaypoints, // Minimum (1)
        rawWaypointCount
      )
    );
    
    const baseRadius = Math.min(
      (targetDistance / 1000) / (2 * Math.PI) * 1.2,
      12 // Maximum 12km de rayon pour rester raisonnable
    );
    
    // 🆕 AJUSTEMENT SELON SURFACE avec limite
    const radiusMultiplier = surfacePreference < 0.3 ? 1.2 : 1.0;
    const adjustedRadius = baseRadius * radiusMultiplier;
    
    logger.info('Enhanced waypoint generation with strict API limits', {
      preferredWaypoints,
      rawCalculation: rawWaypointCount,
      actualWaypointCount: waypointCount,
      maxAllowed: this.organicConfig.maxWaypoints,
      difficulty,
      prioritizeParks,
      surfacePreference,
      adjustedRadius: adjustedRadius.toFixed(2) + 'km',
      totalPointsGenerated: waypointCount + 1 // +1 pour le point de départ
    });
  
    // Utiliser le nombre d'or pour une distribution naturelle
    const goldenRatio = 1.618;
    const angleStep = 360 / waypointCount;
    
    for (let i = 0; i < waypointCount; i++) {
      const distanceVariation = 0.7 + (Math.random() * 0.6); // 70% à 130%
      const radiusWithVariation = adjustedRadius * distanceVariation;
      
      // Angle de base avec variation du nombre d'or
      const baseAngle = angleStep * i;
      const goldenVariation = (i * goldenRatio * 137.5) % 360; // Suite de Fibonacci angulaire
      const organicVariation = (Math.random() - 0.5) * 45 * organicnessFactor; // ±22.5° max
      const finalAngle = (baseAngle + goldenVariation + organicVariation) % 360;
      
      // 🆕 BONUS SPIRAL contrôlé pour parks
      const spiralOffset = prioritizeParks 
        ? Math.sin(i * Math.PI / waypointCount) * 15 // Réduit de 30 à 15 degrés
        : Math.sin(i * Math.PI / waypointCount) * 10;
      
      const waypoint = turf.destination(
        [centerPoint.lon, centerPoint.lat],
        radiusWithVariation,
        finalAngle + spiralOffset,
        { units: "kilometers" }
      );
      
      waypoints.push({
        lat: waypoint.geometry.coordinates[1],
        lon: waypoint.geometry.coordinates[0]
      });
    }
    
    // ✅ VALIDATION FINALE
    if (waypoints.length > 5) {
      logger.error('CRITICAL: Generated too many waypoints for GraphHopper API', {
        generated: waypoints.length,
        maxAllowed: 5,
        waypointCount,
        centerPoint
      });
      
      // Garder seulement les 4 premiers waypoints (+ centre = 5 total)
      const safeLimitedWaypoints = waypoints.slice(0, 4);
      logger.warn('Applied emergency waypoint limiting', {
        original: waypoints.length,
        limited: safeLimitedWaypoints.length
      });
      
      return safeLimitedWaypoints;
    }
    
    logger.info('Organic waypoints generated successfully with API compliance', {
      totalWaypoints: waypoints.length,
      isAPICompliant: waypoints.length <= 5,
      generatedWaypoints: waypointCount
    });
    
    return waypoints;
  }

  /**
   * NOUVELLE : S'assurer que la boucle est fermée
   */
  ensureLoopClosure(route, startPoint) {
    if (!route.coordinates || route.coordinates.length < 2) {
      return route;
    }

    const start = route.coordinates[0];
    const end = route.coordinates[route.coordinates.length - 1];
    const distance = turf.distance(start, end, { units: 'meters' });

    // Si la distance entre début et fin > 100m, forcer la fermeture
    if (distance > 100) {
      logger.info('Forcing loop closure', {
        originalEndDistance: Math.round(distance),
        startPoint: [startPoint.lat, startPoint.lon]
      });

      // ✅ FIX: Remplacer le dernier point par le premier
      const closedCoordinates = [...route.coordinates];
      closedCoordinates[closedCoordinates.length - 1] = [...start];

      // Recalculer la distance
      let newDistance = 0;
      for (let i = 1; i < closedCoordinates.length; i++) {
        newDistance += turf.distance(
          closedCoordinates[i-1],
          closedCoordinates[i],
          { units: 'meters' }
        );
      }

      return {
        ...route,
        coordinates: closedCoordinates,
        distance: newDistance,
        metadata: {
          ...route.metadata,
          loopClosed: true,
          originalEndDistance: distance
        }
      };
    }

    return route;
  }

  /**
   * NOUVELLE : Génération d'un waypoint organique individuel
   */
  generateSingleOrganicWaypoint(centerLat, centerLon, baseRadius, index, totalCount, organicnessFactor, pattern) {
    let angle, distance;

    switch (pattern) {
      case 'natural':
        // Distribution naturelle avec variations aléatoires
        angle = (360 / totalCount) * index + (Math.random() - 0.5) * 60 * organicnessFactor;
        distance = baseRadius * (0.7 + Math.random() * 0.6) * (1 + organicnessFactor * 0.3);
        break;

      case 'balanced':
        // Distribution équilibrée avec légères variations
        angle = (360 / totalCount) * index + (Math.random() - 0.5) * 30 * organicnessFactor;
        distance = baseRadius * (0.8 + Math.random() * 0.4) * (1 + organicnessFactor * 0.2);
        break;

      case 'conservative':
        // Distribution conservative avec variations minimales
        angle = (360 / totalCount) * index + (Math.random() - 0.5) * 15 * organicnessFactor;
        distance = baseRadius * (0.9 + Math.random() * 0.2) * (1 + organicnessFactor * 0.1);
        break;

      default:
        angle = (360 / totalCount) * index;
        distance = baseRadius;
    }

    // Ajouter de la variation spiralée pour plus d'organicité
    if (organicnessFactor > 0.5) {
      const spiralFactor = Math.sin((index / totalCount) * Math.PI * 2) * organicnessFactor;
      distance *= (1 + spiralFactor * 0.3);
      angle += spiralFactor * 20;
    }

    // Convertir en coordonnées géographiques
    const waypoint = turf.destination(
      [centerLon, centerLat],
      distance,
      angle,
      { units: "kilometers" }
    );

    return {
      lat: waypoint.geometry.coordinates[1],
      lon: waypoint.geometry.coordinates[0]
    };
  }

  /**
   * NOUVELLE : Optimisation des waypoints organiques
   */
  async optimizeOrganicWaypoints(waypoints, profile) {
    if (waypoints.length <= 3) return waypoints;

    try {
      // Utiliser l'optimisation GraphHopper si disponible
      const optimized = await graphhopperCloud.optimizeWaypoints(waypoints, profile);
      
      // Vérifier que l'optimisation ne rend pas le parcours trop géométrique
      const originalComplexity = this.calculateWaypointComplexity(waypoints);
      const optimizedComplexity = this.calculateWaypointComplexity(optimized);
      
      // Si l'optimisation réduit trop la complexité, garder l'ordre original
      if (optimizedComplexity < originalComplexity * 0.7) {
        logger.info('Keeping original waypoint order to preserve organicity');
        return waypoints;
      }
      
      return optimized;
    } catch (error) {
      logger.warn('Waypoint optimization failed, using original order:', error.message);
      return waypoints;
    }
  }

  /**
   * NOUVELLE : Calcul de la complexité des waypoints
   */
  calculateWaypointComplexity(waypoints) {
    if (waypoints.length < 3) return 0;

    let totalAngleVariation = 0;
    let totalDistanceVariation = 0;

    for (let i = 1; i < waypoints.length - 1; i++) {
      // Variation d'angle
      const bearing1 = turf.bearing(
        [waypoints[i-1].lon, waypoints[i-1].lat],
        [waypoints[i].lon, waypoints[i].lat]
      );
      const bearing2 = turf.bearing(
        [waypoints[i].lon, waypoints[i].lat],
        [waypoints[i+1].lon, waypoints[i+1].lat]
      );
      
      const angleDiff = Math.abs(bearing1 - bearing2);
      const normalizedAngle = Math.min(angleDiff, 360 - angleDiff);
      totalAngleVariation += normalizedAngle;

      // Variation de distance
      const dist1 = turf.distance(
        [waypoints[i-1].lon, waypoints[i-1].lat],
        [waypoints[i].lon, waypoints[i].lat],
        { units: 'kilometers' }
      );
      const dist2 = turf.distance(
        [waypoints[i].lon, waypoints[i].lat],
        [waypoints[i+1].lon, waypoints[i+1].lat],
        { units: 'kilometers' }
      );
      
      const distanceRatio = Math.abs(dist1 - dist2) / Math.max(dist1, dist2);
      totalDistanceVariation += distanceRatio;
    }

    const avgAngleVariation = totalAngleVariation / (waypoints.length - 2);
    const avgDistanceVariation = totalDistanceVariation / (waypoints.length - 2);

    return (avgAngleVariation / 180) * 0.7 + avgDistanceVariation * 0.3;
  }

  /**
   * NOUVELLE : Amélioration de l'organicité post-génération
   */
  async enhanceRouteOrganicity(route, strategyParams) {
    if (!strategyParams.useNaturalCurves) return route;

    try {
      // Analyser les segments trop droits
      const straightSegments = this.findStraightSegments(route.coordinates);
      
      if (straightSegments.length === 0) return route;

      logger.info('Enhancing route organicity', {
        straightSegments: straightSegments.length,
        totalSegments: route.coordinates.length - 1
      });

      // Appliquer un lissage naturel aux segments droits
      const enhancedCoordinates = this.applySmoothingToStraightSegments(
        route.coordinates,
        straightSegments,
        strategyParams.organicnessFactor
      );

      // Recalculer la distance
      let newDistance = 0;
      for (let i = 1; i < enhancedCoordinates.length; i++) {
        newDistance += turf.distance(
          enhancedCoordinates[i-1],
          enhancedCoordinates[i],
          { units: 'meters' }
        );
      }

      return {
        ...route,
        coordinates: enhancedCoordinates,
        distance: newDistance,
        metadata: {
          ...route.metadata,
          organicityEnhanced: true,
          straightSegmentsSmoothed: straightSegments.length
        }
      };

    } catch (error) {
      logger.warn('Failed to enhance route organicity:', error.message);
      return route;
    }
  }

  /**
   * NOUVELLE : Détection des segments trop droits
   */
  findStraightSegments(coordinates, threshold = 10) {
    const straightSegments = [];
    let currentStraight = null;

    for (let i = 2; i < coordinates.length; i++) {
      const bearing1 = turf.bearing(coordinates[i-2], coordinates[i-1]);
      const bearing2 = turf.bearing(coordinates[i-1], coordinates[i]);
      const bearingDiff = Math.abs(bearing1 - bearing2);
      const normalizedDiff = Math.min(bearingDiff, 360 - bearingDiff);

      if (normalizedDiff < threshold) {
        if (!currentStraight) {
          currentStraight = { start: i-2, segments: 1 };
        }
        currentStraight.segments++;
      } else {
        if (currentStraight && currentStraight.segments >= 3) {
          currentStraight.end = i-1;
          straightSegments.push(currentStraight);
        }
        currentStraight = null;
      }
    }

    if (currentStraight && currentStraight.segments >= 3) {
      currentStraight.end = coordinates.length - 1;
      straightSegments.push(currentStraight);
    }

    return straightSegments;
  }

  /**
   * NOUVELLE : Application de lissage aux segments droits
   */
  applySmoothingToStraightSegments(coordinates, straightSegments, organicnessFactor) {
    let enhanced = [...coordinates];

    straightSegments.forEach(segment => {
      const segmentCoords = enhanced.slice(segment.start, segment.end + 1);
      const smoothedSegment = this.createNaturalCurve(segmentCoords, organicnessFactor);
      
      // Remplacer les coordonnées par la version lissée
      for (let i = 0; i < smoothedSegment.length; i++) {
        if (segment.start + i < enhanced.length) {
          enhanced[segment.start + i] = smoothedSegment[i];
        }
      }
    });

    return enhanced;
  }

  /**
   * NOUVELLE : Création de courbes naturelles
   */
  createNaturalCurve(segmentCoords, organicnessFactor) {
    if (segmentCoords.length < 3) return segmentCoords;

    const smoothed = [segmentCoords[0]];
    const curveFactor = organicnessFactor * 0.3; // Max 30% de déviation

    for (let i = 1; i < segmentCoords.length - 1; i++) {
      const prev = segmentCoords[i - 1];
      const current = segmentCoords[i];
      const next = segmentCoords[i + 1];

      // Calculer le point médian pour la courbe
      const midLat = (prev[1] + next[1]) / 2;
      const midLon = (prev[0] + next[0]) / 2;

      // Calculer la perpendiculaire pour la déviation
      const bearing = turf.bearing(prev, next);
      const perpBearing = (bearing + 90) % 360;
      
      // Distance de déviation basée sur la distance du segment
      const segmentDistance = turf.distance(prev, next, { units: 'meters' });
      const deviationDistance = segmentDistance * curveFactor * (Math.random() - 0.5) * 2;

      // Créer le point dévié
      if (Math.abs(deviationDistance) > 10) { // Minimum 10m de déviation
        const deviatedPoint = turf.destination(
          [midLon, midLat],
          Math.abs(deviationDistance),
          deviationDistance > 0 ? perpBearing : perpBearing + 180,
          { units: 'meters' }
        );

        // Interpoler entre le point actuel et le point dévié
        const lat = current[1] + (deviatedPoint.geometry.coordinates[1] - current[1]) * 0.5;
        const lon = current[0] + (deviatedPoint.geometry.coordinates[0] - current[0]) * 0.5;
        
        smoothed.push([lon, lat]);
      } else {
        smoothed.push(current);
      }
    }

    smoothed.push(segmentCoords[segmentCoords.length - 1]);
    return smoothed;
  }

  /**
   * NOUVELLE : Calcul du nombre optimal de waypoints
   */
  calculateOptimalWaypointCount(distanceKm, activityType) {
    // ✅ LIMITER STRICTEMENT SELON L'API GRAPHHOPPER (max 5 points = 4 waypoints + départ)
    const baseCount = {
      'running': Math.max(1, Math.min(2, Math.floor(distanceKm * 0.15))),    // ✅ TRÈS RÉDUIT
      'cycling': Math.max(1, Math.min(2, Math.floor(distanceKm * 0.12))),    // ✅ TRÈS RÉDUIT  
      'walking': Math.max(1, Math.min(3, Math.floor(distanceKm * 0.18))),    // ✅ RÉDUIT
      'hiking': Math.max(1, Math.min(3, Math.floor(distanceKm * 0.20)))      // ✅ RÉDUIT
    };
  
    const count = baseCount[activityType] || baseCount['running'];
    
    // ✅ GARANTIR QUE LE TOTAL (waypoints + départ) <= 4 points pour sécurité
    const safeCount = Math.min(count, 3); // Max 3 waypoints intermédiaires + départ = 4 points
    
    logger.info('Calculated optimal waypoint count', {
      activityType,
      distanceKm,
      baseCalculation: count,
      safeLimitedCount: safeCount,
      totalPoints: safeCount + 1 // +1 pour le point de départ
    });
    
    return safeCount;
  }

  /**
   * NOUVELLE : Ajustement des stratégies basé sur les métriques de qualité
   */
  adjustStrategiesBasedOnMetrics(strategies, metrics) {
    strategies.forEach(strategy => {
      if (metrics.aesthetics && metrics.aesthetics.score < 0.3) {
        // Augmenter l'organicité si le score esthétique est faible
        if (strategy.isOrganic) {
          strategy.params.organicnessFactor = Math.min(1.0, strategy.params.organicnessFactor + 0.2);
          strategy.params.waypointCount = Math.min(15, strategy.params.waypointCount + 2);
        }
      }

      if (metrics.complexity && metrics.complexity.score < 0.3) {
        // Augmenter la complexité si le score est faible
        if (strategy.params.waypointCount) {
          strategy.params.waypointCount = Math.min(15, strategy.params.waypointCount + 1);
        }
        if (strategy.params.searchRadius) {
          strategy.params.searchRadius = Math.min(50000, strategy.params.searchRadius * 1.2);
        }
      }

      if (metrics.distance && metrics.distance.ratio) {
        // Ajuster selon la précision de distance
        const ratio = metrics.distance.ratio;
        if (ratio > 1.3) {
          strategy.params.searchRadius = Math.max(1000, strategy.params.searchRadius * 0.8);
        } else if (ratio < 0.8) {
          strategy.params.searchRadius = Math.min(50000, strategy.params.searchRadius * 1.2);
        }
      }
    });
  }

  // Garder toutes les méthodes existantes pour compatibilité...
  generateSimpleRoute(params) {
    const { startLat, startLon, endLat, endLon, profile = 'foot' } = params;
    
    logger.info('Simple route generation started', {
      start: [startLat, startLon],
      end: [endLat, endLon],
      profile
    });

    return graphhopperCloud.getRoute({
      points: [
        { lat: startLat, lon: startLon },
        { lat: endLat, lon: endLon }
      ],
      profile,
      algorithm: 'auto',
      avoidTraffic: false
    });
  }

  async generateLoopRouteWithStrategy(params, strategy) {
    const { startLat, startLon, distanceKm, avoidTraffic } = params;
    const profile = graphhopperCloud.selectProfile(params.activityType, params.terrainType, params.preferScenic);
  
    let route;
  
    if (strategy.params.useWaypoints) {
      route = await this.generateManualLoopRouteWithControl(params, strategy, profile);
    } else {
      // ✅ FIX: Configuration round_trip stricte
      const ghParams = {
        points: [{ lat: startLat, lon: startLon }],
        profile,
        algorithm: 'round_trip',
        roundTripDistance: distanceKm * 1000,
        roundTripSeed: strategy.params.seed || Math.floor(Math.random() * 1000000),
        avoidTraffic: avoidTraffic || strategy.params.avoidHighways,
        details: strategy.params.details || ['surface']
      };
  
      route = await graphhopperCloud.getRoute(ghParams);
    }
  
    // ✅ FIX: Toujours forcer la fermeture de boucle
    return this.ensureLoopClosure(route, { lat: startLat, lon: startLon });
  }  

  generatePointToPointRouteWithStrategy(params, strategy) {
    const { startLat, startLon, distanceKm, avoidTraffic } = params;
    const profile = graphhopperCloud.selectProfile(params.activityType, params.terrainType, params.preferScenic);

    const bearing = this.calculateOptimalBearing(params, strategy);
    const targetDistance = distanceKm * 0.7;

    const endpoint = turf.destination(
      [startLon, startLat],
      targetDistance,
      bearing,
      { units: "kilometers" }
    );

    return graphhopperCloud.getRoute({
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
  }

  generateSmartSeed(params) {
    const { startLat, startLon, distanceKm, activityType } = params;
    
    const latInt = Math.floor(startLat * 1000);
    const lonInt = Math.floor(startLon * 1000);
    const distInt = Math.floor(distanceKm * 100);
    const activityHash = activityType.split('').reduce((a, b) => a + b.charCodeAt(0), 0);
    
    return (latInt + lonInt + distInt + activityHash) % 1000000;
  }

  calculateOptimalBearing(params, strategy) {
    const { preferScenic, terrainType, urbanDensity } = params;
    
    let bearing = Math.random() * 360;
    
    if (preferScenic && terrainType === 'nature') {
      bearing = (Math.random() * 180) + 90;
    }
    
    if (urbanDensity === 'urban') {
      bearing = (bearing + 180) % 360;
    }
    
    return bearing;
  }

  async generateManualLoopRouteWithControl(params, strategy, profile) {
    const { startLat, startLon, distanceKm } = params;
    
    const waypoints = this.generateControlledLoopWaypoints(
      startLat,
      startLon,
      distanceKm,
      strategy.params.waypointCount
    );
  
    // ✅ FIX: Utiliser round_trip au lieu de waypoints multiples
    if (waypoints.length <= 1) {
      // Si un seul point, utiliser round_trip simple
      const route = await graphhopperCloud.getRoute({
        points: [{ lat: startLat, lon: startLon }],
        profile,
        algorithm: 'round_trip',
        roundTripDistance: distanceKm * 1000,
        avoidTraffic: strategy.params.avoidHighways
      });
      return this.ensureLoopClosure(route, { lat: startLat, lon: startLon });
    } else {
      // Si plusieurs points, mais utiliser round_trip avec seed basé sur les waypoints
      const seed = this.generateSeedFromWaypoints(waypoints);
      const route = await graphhopperCloud.getRoute({
        points: [{ lat: startLat, lon: startLon }],
        profile,
        algorithm: 'round_trip',
        roundTripDistance: distanceKm * 1000,
        roundTripSeed: seed,
        avoidTraffic: strategy.params.avoidHighways
      });
      return this.ensureLoopClosure(route, { lat: startLat, lon: startLon });
    }
  }

  generateSeedFromWaypoints(waypoints) {
    let seed = 0;
    waypoints.forEach((wp, index) => {
      seed += Math.floor(wp.lat * 1000) + Math.floor(wp.lon * 1000) + index;
    });
    return Math.abs(seed) % 1000000;
  }

  generateControlledLoopWaypoints(startLat, startLon, distanceKm, waypointCount) {
    const waypoints = [{ lat: startLat, lon: startLon }];
    
    // ✅ FIX: Limiter le nombre de waypoints intermédiaires
    const MAX_INTERMEDIATE = 2;
    const safeWaypointCount = Math.min(waypointCount || 2, MAX_INTERMEDIATE);
    
    const radiusKm = distanceKm / (2 * Math.PI) * 1.3;
    
    for (let i = 0; i < safeWaypointCount; i++) {
      const bearing = (360 / safeWaypointCount) * i;
      const distance = radiusKm * (0.9 + Math.random() * 0.2);
  
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
  
    // ✅ FIX: NE PAS ajouter le point de fin pour round_trip
    // waypoints.push({ lat: startLat, lon: startLon }); // SUPPRIMÉ
  
    logger.info(`Generated controlled waypoints: ${waypoints.length} points`);
    return waypoints;
  }

  // Garder les autres méthodes existantes...
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

module.exports = new RouteGeneratorService();