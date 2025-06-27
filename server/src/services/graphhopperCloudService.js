const axios = require("axios");
const logger = require("../config/logger");

class GraphHopperCloudService {
  constructor() {
    this.baseUrl = "https://graphhopper.com/api/1";
    this.apiKey = process.env.GRAPHHOPPER_API_KEY;
    this.cache = new Map();

    // NOUVEAU : Configuration pour la génération organique
    this.organicConfig = {
      preferredDetailLevels: ['surface', 'road_class', 'road_environment'],
      antiGeometricSettings: {
        disableCH: true,        // Désactiver Contraction Hierarchies pour plus de contrôle
        disableLM: true,        // Désactiver Landmarks
        enableDetails: true,     // Activer les détails pour l'analyse
        flexibleRouting: true    // Routage flexible
      },
      qualityEnhancementSettings: {
        pointsEncoded: false,    // Points non encodés pour manipulation
        calcPoints: true,        // Calculer tous les points
        instructions: true,      // Inclure les instructions
        elevation: true          // Inclure l'élévation
      }
    };

    if (!this.apiKey) {
      logger.warn("GRAPHHOPPER_API_KEY manquante dans les variables d'environnement");
    }
  }

  /**
   * Génère un itinéraire avec prévention des parcours problématiques
   */
  async getRoute(params) {
    if (!this.apiKey) {
      throw new Error('GRAPHHOPPER_API_KEY non configurée');
    }
  
    const validatedParams = this.validateAndNormalizeParams(params);
    
    // ✅ FIX: Détecter les round trips et forcer l'algorithme approprié
    const isRoundTrip = validatedParams.points.length === 1 || 
                       (validatedParams.algorithm === 'round_trip') ||
                       (validatedParams.roundTripDistance > 0);
    
    // NOUVEAU : Détection des paramètres de génération organique
    const isOrganicGeneration = this.detectOrganicGenerationNeeds(validatedParams);
    
    // ✅ FIX: Pour les round trips organiques, s'assurer de la bonne configuration
    if (isRoundTrip && (isOrganicGeneration || params._forceOrganic)) {
      logger.info('Applying organic round trip generation parameters', {
        forceOrganic: params._forceOrganic,
        roundTripDistance: validatedParams.roundTripDistance,
        organicnessFactor: params._organicnessFactor
      });
      
      return await this.generateOrganicRoute(validatedParams);
    }
  
    // Génération standard avec validation améliorée
    return await this.generateStandardRoute(validatedParams);
  }  

  /**
   * NOUVEAU : Détecte si la génération organique est nécessaire
   */
  detectOrganicGenerationNeeds(params) {
    // Critères automatiques pour la génération organique
    const organicCriteria = [
      params._forceOrganic,
      params._avoidStraightLines,
      params.algorithm === 'organic',
      params.profile === 'foot' && params.points?.length === 1, // Round trip piéton
      params.roundTripDistance && params.roundTripDistance < 5000 // Courtes distances
    ];

    return organicCriteria.some(criteria => criteria === true);
  }

  /**
   * NOUVEAU : Génération de route organique
   */
  async generateOrganicRoute(params) {
    const {
      points,
      profile = 'foot',
      roundTripDistance = 10000,
      roundTripSeed = Math.floor(Math.random() * 1000000),
      organicnessFactor = 0.7,
      minimumWaypoints = 6
    } = params;

    try {
      // Configuration spéciale pour génération organique
      const requestParams = {
        key: this.apiKey,
        profile,
        ...this.organicConfig.qualityEnhancementSettings,
        ...this.organicConfig.antiGeometricSettings,
        details: this.organicConfig.preferredDetailLevels,
        locale: 'fr'
      };

      let route;

      if (points.length === 1) {
        // Round trip organique
        route = await this.generateOrganicRoundTrip(points[0], roundTripDistance, requestParams, organicnessFactor);
      } else {
        // Multi-points organique
        route = await this.generateOrganicMultiPoint(points, requestParams, organicnessFactor);
      }

      // NOUVEAU : Post-traitement pour améliorer l'organicité
      const enhancedRoute = await this.enhanceRouteOrganicity(route, {
        organicnessFactor,
        avoidStraightLines: params._avoidStraightLines,
        forceCurves: params._forceCurves
      });

      logger.info('Organic route generated successfully', {
        originalPoints: route.coordinates.length,
        enhancedPoints: enhancedRoute.coordinates.length,
        organicnessFactor: organicnessFactor,
        distance: enhancedRoute.distance / 1000
      });

      return enhancedRoute;

    } catch (error) {
      logger.error('Organic route generation failed:', error);
      // Fallback vers génération standard
      logger.info('Falling back to standard generation');
      return await this.generateStandardRoute(params);
    }
  }

  /**
   * NOUVEAU : Génération de round trip organique
   */
  async generateOrganicRoundTrip(centerPoint, distance, baseParams, organicnessFactor) {
    // Stratégie : générer plusieurs waypoints organiques puis router
    const waypoints = this.generateOrganicWaypoints(centerPoint, distance, organicnessFactor);
    
    logger.info('Generated organic waypoints for round trip', {
      center: [centerPoint.lat, centerPoint.lon],
      waypointCount: waypoints.length,
      targetDistance: distance
    });

    // Router entre les waypoints
    const url = this.buildRouteURL(waypoints, baseParams);
    const response = await axios.get(url, { timeout: 45000 });

    if (!response.data.paths || response.data.paths.length === 0) {
      throw new Error('Aucun itinéraire organique trouvé');
    }

    return this.formatResponse(response.data.paths[0]);
  }

  /**
   * NOUVEAU : Génération multi-points organique
   */
  async generateOrganicMultiPoint(points, baseParams, organicnessFactor) {
    // Ajouter des waypoints intermédiaires organiques
    const enhancedPoints = this.addOrganicWaypoints(points, organicnessFactor);
    
    logger.info('Enhanced route with organic waypoints', {
      originalPoints: points.length,
      enhancedPoints: enhancedPoints.length
    });

    const url = this.buildRouteURL(enhancedPoints, baseParams);
    const response = await axios.get(url, { timeout: 45000 });

    if (!response.data.paths || response.data.paths.length === 0) {
      throw new Error('Aucun itinéraire multi-points organique trouvé');
    }

    return this.formatResponse(response.data.paths[0]);
  }

  /**
   * NOUVEAU : Génère des waypoints organiques pour round trip
   */
  generateOrganicWaypoints(centerPoint, targetDistance, organicnessFactor) {
    const turf = require('@turf/turf');
    const waypoints = [centerPoint];
    
    // Calculer le nombre optimal de waypoints
    const waypointCount = Math.max(6, Math.min(12, Math.floor(targetDistance / 800)));
    
    // Rayon de base pour la distribution
    const baseRadius = (targetDistance / 1000) / (2 * Math.PI) * 1.2; // En km
    
    for (let i = 0; i < waypointCount; i++) {
      const waypoint = this.generateOrganicWaypoint(
        centerPoint,
        baseRadius,
        i,
        waypointCount,
        organicnessFactor
      );
      waypoints.push(waypoint);
    }

    // Retourner au centre pour fermer la boucle
    waypoints.push(centerPoint);

    return waypoints;
  }

  /**
   * NOUVEAU : Génère un waypoint organique individuel
   */
  generateOrganicWaypoint(center, baseRadius, index, totalCount, organicnessFactor) {
    const turf = require('@turf/turf');
    
    // Distribution angulaire avec variations organiques
    let angle = (360 / totalCount) * index;
    
    // Ajouter de la variation organique
    const organicVariation = (Math.random() - 0.5) * 60 * organicnessFactor; // ±30° max
    angle += organicVariation;
    
    // Distance avec variation organique
    const radiusVariation = 0.7 + (Math.random() * 0.6); // 70% à 130% du rayon de base
    const organicRadius = baseRadius * radiusVariation * (1 + organicnessFactor * 0.3);
    
    // Ajouter un effet spiral léger pour plus d'organicité
    if (organicnessFactor > 0.5) {
      const spiralFactor = Math.sin((index / totalCount) * Math.PI * 2) * organicnessFactor;
      angle += spiralFactor * 15;
      // organicRadius *= (1 + spiralFactor * 0.2);
    }

    const waypoint = turf.destination(
      [center.lon, center.lat],
      organicRadius,
      angle,
      { units: "kilometers" }
    );

    return {
      lat: waypoint.geometry.coordinates[1],
      lon: waypoint.geometry.coordinates[0]
    };
  }

  /**
   * NOUVEAU : Ajoute des waypoints organiques entre les points existants
   */
  addOrganicWaypoints(points, organicnessFactor) {
    if (points.length < 2) return points;

    const turf = require('@turf/turf');
    const enhanced = [points[0]];

    for (let i = 1; i < points.length; i++) {
      const from = points[i - 1];
      const to = points[i];
      
      const distance = turf.distance(
        [from.lon, from.lat],
        [to.lon, to.lat],
        { units: 'kilometers' }
      );

      // Ajouter des waypoints intermédiaires si la distance est significative
      if (distance > 2 && organicnessFactor > 0.3) {
        const intermediateCount = Math.min(3, Math.floor(distance * organicnessFactor));
        
        for (let j = 1; j <= intermediateCount; j++) {
          const fraction = j / (intermediateCount + 1);
          const intermediate = this.generateOrganicIntermediatePoint(from, to, fraction, organicnessFactor);
          enhanced.push(intermediate);
        }
      }

      enhanced.push(to);
    }

    return enhanced;
  }

  /**
   * NOUVEAU : Génère un point intermédiaire organique
   */
  generateOrganicIntermediatePoint(from, to, fraction, organicnessFactor) {
    const turf = require('@turf/turf');
    
    // Point linéaire entre from et to
    const line = turf.lineString([[from.lon, from.lat], [to.lon, to.lat]]);
    const distance = turf.length(line, { units: 'kilometers' });
    const alongPoint = turf.along(line, distance * fraction, { units: 'kilometers' });
    
    // Ajouter une déviation organique perpendiculaire
    const bearing = turf.bearing([from.lon, from.lat], [to.lon, to.lat]);
    const perpBearing = bearing + 90; // Perpendiculaire
    
    // Déviation proportionnelle à l'organicité et à la distance
    const maxDeviation = Math.min(1, distance * 0.3 * organicnessFactor); // Max 30% de la distance
    const deviation = (Math.random() - 0.5) * 2 * maxDeviation; // Déviation aléatoire
    
    let finalPoint = alongPoint.geometry.coordinates;
    
    if (Math.abs(deviation) > 0.1) { // Minimum 100m de déviation
      const deviatedPoint = turf.destination(
        alongPoint.geometry.coordinates,
        Math.abs(deviation),
        deviation > 0 ? perpBearing : perpBearing + 180,
        { units: 'kilometers' }
      );
      finalPoint = deviatedPoint.geometry.coordinates;
    }

    return {
      lat: finalPoint[1],
      lon: finalPoint[0]
    };
  }

  /**
   * NOUVEAU : Améliore l'organicité d'une route existante
   */
  async enhanceRouteOrganicity(route, enhancementParams) {
    if (!enhancementParams.avoidStraightLines && !enhancementParams.forceCurves) {
      return route; // Pas d'amélioration nécessaire
    }

    try {
      const turf = require('@turf/turf');
      let coordinates = [...route.coordinates];

      // 1. Détecter et corriger les segments trop droits
      if (enhancementParams.avoidStraightLines) {
        coordinates = this.softenStraightSegments(coordinates, enhancementParams.organicnessFactor);
      }

      // 2. Ajouter des courbes naturelles si demandé
      if (enhancementParams.forceCurves) {
        coordinates = this.addNaturalCurves(coordinates, enhancementParams.organicnessFactor);
      }

      // 3. Lisser le parcours final
      coordinates = this.smoothRoute(coordinates);

      // Recalculer la distance
      let newDistance = 0;
      for (let i = 1; i < coordinates.length; i++) {
        newDistance += turf.distance(coordinates[i-1], coordinates[i], { units: 'meters' });
      }

      return {
        ...route,
        coordinates: coordinates,
        distance: newDistance,
        metadata: {
          ...route.metadata,
          organicityEnhanced: true,
          enhancementApplied: Object.keys(enhancementParams).filter(k => enhancementParams[k])
        }
      };

    } catch (error) {
      logger.warn('Route organicity enhancement failed:', error.message);
      return route; // Retourner la route originale en cas d'erreur
    }
  }

  /**
   * NOUVEAU : Adoucit les segments droits
   */
  softenStraightSegments(coordinates, organicnessFactor) {
    if (coordinates.length < 3) return coordinates;

    const turf = require('@turf/turf');
    const softened = [coordinates[0]];
    const straightThreshold = 10; // Segments considérés droits si < 10° de variation

    for (let i = 1; i < coordinates.length - 1; i++) {
      const prev = coordinates[i - 1];
      const current = coordinates[i];
      const next = coordinates[i + 1];

      // Calculer l'angle de changement
      const bearing1 = turf.bearing(prev, current);
      const bearing2 = turf.bearing(current, next);
      const angleDiff = Math.abs(bearing1 - bearing2);
      const normalizedAngle = Math.min(angleDiff, 360 - angleDiff);

      if (normalizedAngle < straightThreshold) {
        // Segment trop droit, ajouter de la courbure
        const softenedPoint = this.createSoftenedPoint(prev, current, next, organicnessFactor);
        softened.push(softenedPoint);
      } else {
        softened.push(current);
      }
    }

    softened.push(coordinates[coordinates.length - 1]);
    return softened;
  }

  /**
   * NOUVEAU : Crée un point adouci pour un segment droit
   */
  createSoftenedPoint(prev, current, next, organicnessFactor) {
    const turf = require('@turf/turf');
    
    // Calculer la perpendiculaire au segment
    const bearing = turf.bearing(prev, next);
    const perpBearing = bearing + 90;
    
    // Distance de déviation basée sur la longueur du segment
    const segmentDistance = turf.distance(prev, next, { units: 'meters' });
    const maxDeviation = Math.min(200, segmentDistance * 0.1 * organicnessFactor); // Max 10% du segment
    
    // Déviation aléatoire
    const deviation = (Math.random() - 0.5) * 2 * maxDeviation;
    
    if (Math.abs(deviation) < 20) return current; // Déviation trop faible
    
    const deviatedPoint = turf.destination(
      current,
      Math.abs(deviation),
      deviation > 0 ? perpBearing : perpBearing + 180,
      { units: 'meters' }
    );

    return deviatedPoint.geometry.coordinates;
  }

  /**
   * NOUVEAU : Ajoute des courbes naturelles
   */
  addNaturalCurves(coordinates, organicnessFactor) {
    if (coordinates.length < 4) return coordinates;

    const turf = require('@turf/turf');
    const curved = [];
    
    // Traiter par groupes de 3 points pour créer des courbes
    for (let i = 0; i < coordinates.length - 2; i += 2) {
      curved.push(coordinates[i]);
      
      if (i + 2 < coordinates.length) {
        // Créer des points de contrôle pour une courbe de Bézier simple
        const curvePoints = this.generateBezierCurve(
          coordinates[i], 
          coordinates[i + 1], 
          coordinates[i + 2], 
          organicnessFactor
        );
        curved.push(...curvePoints);
      }
    }
    
    // Ajouter les derniers points
    if (coordinates.length % 2 === 0) {
      curved.push(coordinates[coordinates.length - 1]);
    }

    return curved;
  }

  /**
   * NOUVEAU : Génère une courbe de Bézier simple
   */
  generateBezierCurve(p1, p2, p3, organicnessFactor) {
    const turf = require('@turf/turf');
    
    // Contrôle de la courbe basé sur l'organicité
    const curveIntensity = 0.3 * organicnessFactor;
    const numPoints = Math.max(2, Math.floor(4 * organicnessFactor));
    
    const curve = [];
    
    for (let t = 0.2; t <= 0.8; t += 0.6 / numPoints) {
      // Courbe de Bézier quadratique simple
      const x = (1 - t) * (1 - t) * p1[0] + 2 * (1 - t) * t * p2[0] + t * t * p3[0];
      const y = (1 - t) * (1 - t) * p1[1] + 2 * (1 - t) * t * p2[1] + t * t * p3[1];
      
      // Ajouter de la variation naturelle
      const variation = (Math.random() - 0.5) * 0.001 * organicnessFactor; // Très petite variation
      
      curve.push([x + variation, y + variation]);
    }
    
    return curve;
  }

  /**
   * NOUVEAU : Lisse une route
   */
  smoothRoute(coordinates) {
    if (coordinates.length < 5) return coordinates;

    const smoothed = [coordinates[0]];
    const windowSize = 3;
    
    for (let i = 1; i < coordinates.length - 1; i++) {
      const start = Math.max(0, i - Math.floor(windowSize / 2));
      const end = Math.min(coordinates.length, i + Math.floor(windowSize / 2) + 1);
      
      let sumLon = 0, sumLat = 0, count = 0;
      
      for (let j = start; j < end; j++) {
        sumLon += coordinates[j][0];
        sumLat += coordinates[j][1];
        count++;
      }
      
      smoothed.push([sumLon / count, sumLat / count]);
    }
    
    smoothed.push(coordinates[coordinates.length - 1]);
    return smoothed;
  }

  /**
   * Génération standard avec validation améliorée
   */
  async generateStandardRoute(params) {
    const {
      points,
      profile = 'foot',
      algorithm = 'auto',
      roundTripDistance = 10000,
      roundTripSeed = Math.floor(Math.random() * 1000000),
      avoidTraffic = false,
      locale = 'fr'
    } = params;

    try {
      const requestParams = {
        key: this.apiKey,
        profile,
        points_encoded: false,
        elevation: true,
        instructions: true,
        calc_points: true,
        details: ['surface', 'road_class', 'road_environment'],
        locale
      };

      // Configuration selon le type d'algorithme
      if (algorithm === 'round_trip') {
        requestParams.algorithm = 'round_trip';
        requestParams.round_trip = {
          distance: this.adjustRoundTripDistance(roundTripDistance, points[0]),
          seed: roundTripSeed
        };
        requestParams.ch = false;
        requestParams.lm = false;
      } else {
        if (algorithm && algorithm !== 'auto') {
          requestParams.algorithm = algorithm;
          requestParams.ch = false;
          requestParams.lm = false;
        }
      }

      // Optimisations selon la distance
      if (roundTripDistance > 30000) {
        requestParams.ch = true;
        requestParams.lm = true;
      } else if (roundTripDistance < 5000) {
        requestParams.ch = false;
        requestParams.lm = false;
      }

      if (avoidTraffic) {
        requestParams.ch = false;
        requestParams.lm = false;
        requestParams.block_area = this.getTrafficAvoidanceAreas(points[0]);
      }

      const url = this.buildRouteURL(points, requestParams);
      
      logger.info('Standard route generation', { 
        pointsCount: points.length,
        profile,
        algorithm: algorithm === 'auto' ? 'default' : algorithm,
        roundTripDistance,
        ch_disabled: requestParams.ch === false
      });

      const response = await axios.get(url, { timeout: 45000 });

      if (!response.data.paths || response.data.paths.length === 0) {
        throw new Error('Aucun itinéraire trouvé par GraphHopper');
      }

      const formattedResponse = this.formatResponse(response.data.paths[0]);
      
      // Validation post-génération
      const postValidation = this.validateGeneratedRoute(formattedResponse, params);
      if (!postValidation.isValid) {
        logger.warn('Route validation warning:', postValidation.warnings);
        formattedResponse.metadata.validationWarnings = postValidation.warnings;
      }

      return formattedResponse;

    } catch (error) {
      logger.error('Standard route generation failed:', error);

      // ✅ GESTION SPÉCIFIQUE DES ERREURS DE LIMITE D'API
      if (error.response && error.response.status === 400) {
        const errorMessage = error.response.data?.message || '';
        if (errorMessage.includes('Too many points')) {
          throw new Error(`GraphHopper API limit: ${errorMessage}`);
        }
      }

      // ✅ GESTION ERREUR 429 (Rate Limiting)
      if (error.response && error.response.status === 429) {
        throw new Error('GraphHopper API rate limit exceeded. Please try again in a moment.');
      }

      throw error;
    }
  }

  /**
   * Construit l'URL de route
   */
  buildRouteURL(points, requestParams) {
    // ✅ FIX: Validation stricte du nombre de points
    if (points.length > 5) {
      logger.error(`Too many points for GraphHopper API: ${points.length}, max 5 allowed`);
      throw new Error(`GraphHopper API limit: Too many points (${points.length}), maximum 5 allowed`);
    }
  
    let url = `${this.baseUrl}/route?`;
    
    points.forEach(point => {
      url += `point=${point.lat},${point.lon}&`;
    });
  
    Object.entries(requestParams).forEach(([key, value]) => {
      if (typeof value === 'object') {
        Object.entries(value).forEach(([subKey, subValue]) => {
          url += `${key}.${subKey}=${subValue}&`;
        });
      } else if (Array.isArray(value)) {
        value.forEach(item => {
          url += `${key}=${item}&`;
        });
      } else {
        url += `${key}=${value}&`;
      }
    });
  
    logger.info(`GraphHopper URL built with ${points.length} points (API compliant)`);
    return url;
  }

  // Conserver toutes les méthodes existantes...
  validateAndNormalizeParams(params) {
    const validated = { ...params };

    if (!params.points || !Array.isArray(params.points) || params.points.length === 0) {
      throw new Error('Points manquants ou invalides');
    }

    params.points.forEach((point, index) => {
      if (!point.lat || !point.lon || 
          typeof point.lat !== 'number' || typeof point.lon !== 'number') {
        throw new Error(`Point ${index} invalide: lat/lon requis`);
      }
      
      if (point.lat < -90 || point.lat > 90) {
        throw new Error(`Point ${index}: latitude invalide (${point.lat})`);
      }
      
      if (point.lon < -180 || point.lon > 180) {
        throw new Error(`Point ${index}: longitude invalide (${point.lon})`);
      }
    });

    const validProfiles = ['foot', 'bike', 'car', 'motorcycle', 'mtb', 'racingbike', 'hiking'];
    if (params.profile && !validProfiles.includes(params.profile)) {
      logger.warn(`Profil inconnu: ${params.profile}, utilisation de 'foot'`);
      validated.profile = 'foot';
    }

    if (params.roundTripDistance) {
      if (params.roundTripDistance < 500) {
        logger.warn('Distance round_trip trop petite, minimum 500m');
        validated.roundTripDistance = 500;
      } else if (params.roundTripDistance > 100000) {
        logger.warn('Distance round_trip trop grande, maximum 100km');
        validated.roundTripDistance = 100000;
      }
    }

    return validated;
  }

  adjustRoundTripDistance(requestedDistance, startPoint) {
    let adjustmentFactor = 1.0;
    
    const urbanCenters = [
      { lat: 48.8566, lon: 2.3522, name: 'Paris' },
      { lat: 45.7640, lon: 4.8357, name: 'Lyon' },
      { lat: 43.2965, lon: 5.3698, name: 'Marseille' },
      { lat: 50.6292, lon: 3.0573, name: 'Lille' }
    ];

    const nearUrbanCenter = urbanCenters.some(center => {
      const distance = this.calculateDistance(startPoint.lat, startPoint.lon, center.lat, center.lon);
      return distance < 20000;
    });

    if (nearUrbanCenter) {
      adjustmentFactor = 0.9;
    }

    if (requestedDistance < 2000) {
      adjustmentFactor *= 1.1;
    } else if (requestedDistance > 20000) {
      adjustmentFactor *= 0.95;
    }

    const adjustedDistance = Math.round(requestedDistance * adjustmentFactor);
    
    if (adjustedDistance !== requestedDistance) {
      logger.info('Distance round_trip ajustée:', {
        original: requestedDistance,
        adjusted: adjustedDistance,
        factor: adjustmentFactor
      });
    }

    return adjustedDistance;
  }

  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371000;
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ/2) * Math.sin(Δλ/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

    return R * c;
  }

  estimateResultDistance(params) {
    if (params.algorithm === 'round_trip' && params.roundTripDistance) {
      return {
        min: params.roundTripDistance * 0.8,
        max: params.roundTripDistance * 1.3,
        expected: params.roundTripDistance
      };
    }

    if (params.points.length === 2) {
      const directDistance = this.calculateDistance(
        params.points[0].lat, params.points[0].lon,
        params.points[1].lat, params.points[1].lon
      );
      
      return {
        min: directDistance * 1.1,
        max: directDistance * 2.0,
        expected: directDistance * 1.4
      };
    }

    return { min: 0, max: 0, expected: 0 };
  }

  validateGeneratedRoute(route, originalParams) {
    const validation = {
      isValid: true,
      warnings: []
    };

    if (originalParams.roundTripDistance && originalParams.algorithm === 'round_trip') {
      const ratio = route.distance / originalParams.roundTripDistance;
      
      if (ratio < 0.7 || ratio > 1.5) {
        validation.warnings.push({
          type: 'distance_deviation',
          message: `Distance générée (${(route.distance/1000).toFixed(1)}km) diffère significativement de la cible (${(originalParams.roundTripDistance/1000).toFixed(1)}km)`,
          ratio: ratio
        });
      }
    }

    if (route.coordinates.length < 10) {
      validation.warnings.push({
        type: 'insufficient_points',
        message: `Peu de points dans le parcours (${route.coordinates.length})`,
        count: route.coordinates.length
      });
    }

    let largeGaps = 0;
    for (let i = 1; i < route.coordinates.length; i++) {
      const distance = this.calculateDistance(
        route.coordinates[i-1][1], route.coordinates[i-1][0],
        route.coordinates[i][1], route.coordinates[i][0]
      );
      
      if (distance > 2000) {
        largeGaps++;
      }
    }

    if (largeGaps > 0) {
      validation.warnings.push({
        type: 'large_gaps',
        message: `${largeGaps} gaps importants détectés dans le parcours`,
        count: largeGaps
      });
    }

    return validation;
  }

  getTrafficAvoidanceAreas(centerPoint) {
    const avoidanceAreas = [];
    
    if (Math.abs(centerPoint.lat - 48.8566) < 0.5 && 
        Math.abs(centerPoint.lon - 2.3522) < 0.5) {
      avoidanceAreas.push('highway=motorway');
      avoidanceAreas.push('highway=trunk');
    }

    return avoidanceAreas;
  }

  async optimizeWaypoints(waypoints, profile = "foot") {
    if (!this.apiKey) {
      logger.warn("API key manquante pour optimisation, retour ordre original");
      return waypoints;
    }

    try {
      const points = waypoints.map((wp) => ({ lat: wp.lat, lon: wp.lon }));

      const url = `${this.baseUrl}/optimize`;
      const requestData = {
        vehicles: [
          {
            vehicle_id: "v1",
            start_address: {
              location_id: "start",
              lat: points[0].lat,
              lon: points[0].lon,
            },
            end_address: {
              location_id: "end",
              lat: points[0].lat,
              lon: points[0].lon,
            },
            profile,
          },
        ],
        services: points.slice(1).map((point, index) => ({
          id: `service_${index}`,
          address: {
            location_id: `loc_${index}`,
            lat: point.lat,
            lon: point.lon,
          },
        })),
      };

      const response = await axios.post(url, requestData, {
        params: { key: this.apiKey },
        timeout: 30000,
      });

      return this.extractOptimizedRoute(response.data, waypoints);
    } catch (error) {
      logger.warn("Optimization failed, using original order:", error.message);
      return waypoints;
    }
  }

  async getElevation(coordinates) {
    if (!this.apiKey) {
      logger.warn("API key manquante pour élévation, retour élévations zéro");
      return coordinates.map((coord) => ({
        lat: coord[1] || coord.lat,
        lon: coord[0] || coord.lon,
        elevation: 0,
      }));
    }

    try {
      const points = coordinates
        .slice(0, 50)
        .map((coord) => {
          const lat = coord[1] || coord.lat;
          const lon = coord[0] || coord.lon;
          return `${lat},${lon}`;
        })
        .join("|");

      const url = `${this.baseUrl}/elevation`;
      const params = {
        key: this.apiKey,
        point: points,
        format: "json",
      };

      const response = await axios.get(url, {
        params,
        timeout: 15000,
      });

      if (response.data && Array.isArray(response.data)) {
        return response.data.map((point, index) => ({
          lat: coordinates[index][1] || coordinates[index].lat,
          lon: coordinates[index][0] || coordinates[index].lon,
          elevation: point.elevation || 0,
        }));
      }

      throw new Error("Format de réponse inattendu de GraphHopper elevation");
    } catch (error) {
      logger.warn("Élévation GraphHopper échouée, fallback vers Open-Elevation:", error.message);
      return this.getOpenElevation(coordinates);
    }
  }

  async getOpenElevation(coordinates) {
    try {
      const limitedCoords = coordinates.slice(0, 100);

      const locations = limitedCoords.map((coord) => ({
        latitude: coord[1] || coord.lat,
        longitude: coord[0] || coord.lon,
      }));

      const response = await axios.post(
        "https://api.open-elevation.com/api/v1/lookup",
        { locations },
        {
          timeout: 10000,
          headers: { "Content-Type": "application/json" },
        }
      );

      if (!response.data || !response.data.results) {
        throw new Error("Invalid response from Open-Elevation");
      }

      return response.data.results.map((result, index) => ({
        lat: limitedCoords[index][1] || limitedCoords[index].lat,
        lon: limitedCoords[index][0] || limitedCoords[index].lon,
        elevation: result.elevation || 0,
      }));
    } catch (error) {
      logger.error("Open-Elevation également échouée:", error.message);

      return coordinates.map((coord) => ({
        lat: coord[1] || coord.lat,
        lon: coord[0] || coord.lon,
        elevation: 0,
      }));
    }
  }

  async healthCheck() {
    if (!this.apiKey) {
      return {
        status: "unhealthy",
        error: "API key not configured",
      };
    }

    try {
      const response = await axios.get(`${this.baseUrl}/info`, {
        params: { key: this.apiKey },
        timeout: 5000,
      });

      return {
        status: "healthy",
        version: response.data.version || "unknown",
        limits: response.data.limits || {},
      };
    } catch (error) {
      return {
        status: "unhealthy",
        error: error.message,
      };
    }
  }

  formatResponse(path) {
    return {
      coordinates: path.points.coordinates,
      distance: path.distance,
      duration: path.time,
      instructions: path.instructions || [],
      bbox: path.bbox,
      metadata: {
        profile: path.details?.profile || "unknown",
        surface_breakdown: this.analyzeSurfaces(path.details?.surface),
        road_class_breakdown: this.analyzeRoadClasses(path.details?.road_class),
        environment_breakdown: this.analyzeEnvironment(path.details?.road_environment),
        ascent: path.ascent || 0,
        descent: path.descent || 0,
      },
    };
  }

  analyzeSurfaces(surfaceDetails) {
    if (!surfaceDetails) return { paved: 100 };

    const surfaces = {};
    let totalDistance = 0;

    surfaceDetails.forEach((detail) => {
      const distance = detail[1] - detail[0];
      const surface = detail[2] || "paved";
      surfaces[surface] = (surfaces[surface] || 0) + distance;
      totalDistance += distance;
    });

    const breakdown = {};
    Object.entries(surfaces).forEach(([surface, distance]) => {
      breakdown[surface] = Math.round((distance / totalDistance) * 100);
    });

    return breakdown;
  }

  analyzeRoadClasses(roadClassDetails) {
    if (!roadClassDetails) return { secondary: 100 };

    const classes = {};
    let totalDistance = 0;

    roadClassDetails.forEach((detail) => {
      const distance = detail[1] - detail[0];
      const roadClass = detail[2] || "secondary";
      classes[roadClass] = (classes[roadClass] || 0) + distance;
      totalDistance += distance;
    });

    const breakdown = {};
    Object.entries(classes).forEach(([roadClass, distance]) => {
      breakdown[roadClass] = Math.round((distance / totalDistance) * 100);
    });

    return breakdown;
  }

  analyzeEnvironment(environmentDetails) {
    if (!environmentDetails) return { urban: 100 };

    const environments = {};
    let totalDistance = 0;

    environmentDetails.forEach((detail) => {
      const distance = detail[1] - detail[0];
      const environment = detail[2] || "urban";
      environments[environment] = (environments[environment] || 0) + distance;
      totalDistance += distance;
    });

    const breakdown = {};
    Object.entries(environments).forEach(([env, distance]) => {
      breakdown[env] = Math.round((distance / totalDistance) * 100);
    });

    return breakdown;
  }

  extractOptimizedRoute(optimizationData, originalWaypoints) {
    if (!optimizationData.solution || !optimizationData.solution.routes) {
      return originalWaypoints;
    }

    const route = optimizationData.solution.routes[0];
    if (!route.activities) {
      return originalWaypoints;
    }

    const optimizedOrder = [];
    route.activities.forEach((activity) => {
      if (activity.location_id && activity.location_id !== "start" && activity.location_id !== "end") {
        const index = parseInt(activity.location_id.replace("loc_", ""));
        if (originalWaypoints[index + 1]) {
          optimizedOrder.push(originalWaypoints[index + 1]);
        }
      }
    });

    return [originalWaypoints[0], ...optimizedOrder];
  }

  selectProfile(activityType, terrainType, preferScenic, distanceKm) {
    const availableProfiles = ['car', 'bike', 'foot'];
    
    let profile;
    
    switch (activityType) {
      case 'running':
      case 'walking':
      case 'hiking':
        profile = 'foot';
        break;
        
      case 'cycling':
        profile = 'bike';
        break;
        
      default:
        profile = 'foot';
    }

    if (!availableProfiles.includes(profile)) {
      logger.warn(`Profile ${profile} not available, falling back to 'foot'`);
      profile = 'foot';
    }

    logger.info('Profile sélectionné avec capacités organiques:', {
      activityType,
      terrainType,
      preferScenic,
      selectedProfile: profile,
      organicCapable: true
    });

    return profile;
  }
}

module.exports = new GraphHopperCloudService();