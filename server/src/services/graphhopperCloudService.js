const axios = require("axios");
const logger = require("../config/logger"); // Import direct du logger

class GraphHopperCloudService {
  constructor() {
    this.baseUrl = "https://graphhopper.com/api/1";
    this.apiKey = process.env.GRAPHHOPPER_API_KEY;
    this.cache = new Map(); // Cache pour éviter les appels répétés

    if (!this.apiKey) {
      logger.warn(
        "GRAPHHOPPER_API_KEY manquante dans les variables d'environnement"
      );
    }
  }

  /**
   * Génère un itinéraire via l'API GraphHopper
   */
  async getRoute(params) {
    if (!this.apiKey) {
      throw new Error('GRAPHHOPPER_API_KEY non configurée');
    }
  
    // Validation et normalisation des paramètres
    const validatedParams = this.validateAndNormalizeParams(params);
    
    const {
      points,
      profile = 'foot',
      algorithm = 'auto',
      roundTripDistance = 10000,
      roundTripSeed = Math.floor(Math.random() * 1000000),
      avoidTraffic = false,
      locale = 'fr'
    } = validatedParams;
  
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
  
      // Configuration adaptative selon le type d'itinéraire et la distance
      if (algorithm === 'round_trip') {
        requestParams.algorithm = 'round_trip';
        requestParams.round_trip = {
          distance: this.adjustRoundTripDistance(roundTripDistance, points[0]),
          seed: roundTripSeed
        };
        
        // Pour les round_trip, désactiver CH pour plus de contrôle
        requestParams.ch = false;
        requestParams.lm = false;
      } else {
        if (algorithm && algorithm !== 'auto') {
          requestParams.algorithm = algorithm;
          requestParams.ch = false;
          requestParams.lm = false;
        }
      }
  
      // Configuration selon la distance pour optimiser les résultats
      if (roundTripDistance > 30000) {
        // Longues distances: activer les optimisations
        requestParams.ch = true;
        requestParams.lm = true;
      } else if (roundTripDistance < 5000) {
        // Courtes distances: désactiver pour plus de précision
        requestParams.ch = false;
        requestParams.lm = false;
      }
  
      // Éviter le trafic si demandé
      if (avoidTraffic) {
        requestParams.ch = false;
        requestParams.lm = false;
        requestParams.block_area = this.getTrafficAvoidanceAreas(points[0]);
      }
  
      // Construire l'URL
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
  
      logger.info('Appel GraphHopper API avec validation:', { 
        pointsCount: points.length,
        profile,
        algorithm: algorithm === 'auto' ? 'default' : algorithm,
        roundTripDistance,
        ch_disabled: requestParams.ch === false,
        estimated_distance: this.estimateResultDistance(validatedParams)
      });
  
      const response = await axios.get(url, {
        timeout: 45000 // Augmenter timeout pour les longues distances
      });
  
      if (!response.data.paths || response.data.paths.length === 0) {
        throw new Error('Aucun itinéraire trouvé par GraphHopper');
      }
  
      const formattedResponse = this.formatResponse(response.data.paths[0]);
      
      // Validation post-génération
      const postValidation = this.validateGeneratedRoute(formattedResponse, validatedParams);
      if (!postValidation.isValid) {
        logger.warn('Route validation warning:', postValidation.warnings);
        // Ajouter les avertissements aux métadonnées
        formattedResponse.metadata.validationWarnings = postValidation.warnings;
      }
  
      return formattedResponse;
  
    } catch (error) {
      logger.error('Erreur GraphHopper API:', {
        message: error.message,
        status: error.response?.status,
        responseData: error.response?.data,
        requestParams: { ...params, key: '***' }
      });
      
      if (error.response?.status === 400) {
        throw new Error(`Paramètres invalides: ${error.response.data.message || error.message}`);
      } else if (error.response?.status === 429) {
        throw new Error('Limite de l\'API GraphHopper atteinte, veuillez réessayer plus tard');
      } else if (error.response?.status >= 500) {
        throw new Error('Service GraphHopper temporairement indisponible');
      }
      
      throw error;
    }  
  }

  /**
   * Valide et normalise les paramètres d'entrée
   */
  validateAndNormalizeParams(params) {
    const validated = { ...params };

    // Validation des points
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

    // Validation et ajustement du profil
    const validProfiles = ['foot', 'bike', 'car', 'motorcycle', 'mtb', 'racingbike', 'hiking'];
    if (params.profile && !validProfiles.includes(params.profile)) {
      logger.warn(`Profil inconnu: ${params.profile}, utilisation de 'foot'`);
      validated.profile = 'foot';
    }

    // Validation de la distance round_trip
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

  /**
   * Ajuste la distance round_trip selon la zone géographique
   */
  adjustRoundTripDistance(requestedDistance, startPoint) {
    // Facteurs d'ajustement selon la densité urbaine (approximation)
    let adjustmentFactor = 1.0;
    
    // Zones urbaines denses (approximation basée sur les coordonnées)
    const urbanCenters = [
      { lat: 48.8566, lon: 2.3522, name: 'Paris' },
      { lat: 45.7640, lon: 4.8357, name: 'Lyon' },
      { lat: 43.2965, lon: 5.3698, name: 'Marseille' },
      { lat: 50.6292, lon: 3.0573, name: 'Lille' }
    ];

    // Vérifier la proximité avec les centres urbains
    const nearUrbanCenter = urbanCenters.some(center => {
      const distance = this.calculateDistance(startPoint.lat, startPoint.lon, center.lat, center.lon);
      return distance < 20000; // 20km du centre
    });

    if (nearUrbanCenter) {
      adjustmentFactor = 0.9; // Réduire légèrement en zone urbaine
    }

    // Ajustement selon la distance demandée
    if (requestedDistance < 2000) {
      adjustmentFactor *= 1.1; // Augmenter pour très courtes distances
    } else if (requestedDistance > 20000) {
      adjustmentFactor *= 0.95; // Réduire pour longues distances
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

  /**
   * Calcule la distance entre deux points (Haversine)
   */
  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371000; // Rayon de la Terre en mètres
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

  /**
   * Estime la distance résultante avant l'appel API
   */
  estimateResultDistance(params) {
    if (params.algorithm === 'round_trip' && params.roundTripDistance) {
      // Pour round_trip, la distance réelle est généralement 10-30% différente
      return {
        min: params.roundTripDistance * 0.8,
        max: params.roundTripDistance * 1.3,
        expected: params.roundTripDistance
      };
    }

    if (params.points.length === 2) {
      // Pour point-à-point, calculer la distance à vol d'oiseau et estimer
      const directDistance = this.calculateDistance(
        params.points[0].lat, params.points[0].lon,
        params.points[1].lat, params.points[1].lon
      );
      
      // La distance par route est généralement 1.2-1.8x la distance directe
      return {
        min: directDistance * 1.1,
        max: directDistance * 2.0,
        expected: directDistance * 1.4
      };
    }

    return { min: 0, max: 0, expected: 0 };
  }

  /**
   * Valide un parcours généré
   */
  validateGeneratedRoute(route, originalParams) {
    const validation = {
      isValid: true,
      warnings: []
    };

    // Validation de la distance
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

    // Validation du nombre de points
    if (route.coordinates.length < 10) {
      validation.warnings.push({
        type: 'insufficient_points',
        message: `Peu de points dans le parcours (${route.coordinates.length})`,
        count: route.coordinates.length
      });
    }

    // Validation de la continuité
    let largeGaps = 0;
    for (let i = 1; i < route.coordinates.length; i++) {
      const distance = this.calculateDistance(
        route.coordinates[i-1][1], route.coordinates[i-1][0],
        route.coordinates[i][1], route.coordinates[i][0]
      );
      
      if (distance > 2000) { // Gap > 2km
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

  /**
   * Obtient les zones à éviter pour le trafic
   */
  getTrafficAvoidanceAreas(centerPoint) {
    // Zones d'évitement basiques (autoroutes, etc.)
    // À personnaliser selon les besoins
    const avoidanceAreas = [];
    
    // Zone autoroute approximative autour de Paris
    if (Math.abs(centerPoint.lat - 48.8566) < 0.5 && 
        Math.abs(centerPoint.lon - 2.3522) < 0.5) {
      avoidanceAreas.push('highway=motorway');
      avoidanceAreas.push('highway=trunk');
    }

    return avoidanceAreas;
  }

  /**
   * Optimise l'ordre des waypoints
   */
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
      return waypoints; // Fallback: retourner l'ordre original
    }
  }

  /**
   * Récupère les données d'élévation
   */
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
      // FIX: GraphHopper Cloud elevation API utilise un format différent
      // Il faut faire une requête GET avec les coordonnées dans l'URL
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

      logger.info("Demande élévation GraphHopper:", {
        points_count: coordinates.length,
        url_params: { ...params, key: "***" },
      });

      const response = await axios.get(url, {
        params,
        timeout: 15000,
      });

      // FIX: Traiter la réponse selon le format GraphHopper
      if (response.data && Array.isArray(response.data)) {
        return response.data.map((point, index) => ({
          lat: coordinates[index][1] || coordinates[index].lat,
          lon: coordinates[index][0] || coordinates[index].lon,
          elevation: point.elevation || 0,
        }));
      }

      // Si le format n'est pas celui attendu, retourner des valeurs par défaut
      throw new Error("Format de réponse inattendu de GraphHopper elevation");
    } catch (error) {
      logger.warn(
        "Élévation GraphHopper échouée, fallback vers Open-Elevation:",
        {
          message: error.message,
          status: error.response?.status,
          coordinates_count: coordinates.length,
        }
      );

      // Fallback immédiat vers Open-Elevation
      return this.getOpenElevation(coordinates);
    }
  }

  /**
   * Fallback vers Open-Elevation API (méthode ajoutée)
   */
  async getOpenElevation(coordinates) {
    try {
      const axios = require("axios");

      // Limiter à 100 points max pour Open-Elevation
      const limitedCoords = coordinates.slice(0, 100);

      const locations = limitedCoords.map((coord) => ({
        latitude: coord[1] || coord.lat,
        longitude: coord[0] || coord.lon,
      }));

      const response = await axios.post(
        "https://api.open-elevation.com/api/v1/lookup",
        {
          locations,
        },
        {
          timeout: 10000,
          headers: {
            "Content-Type": "application/json",
          },
        }
      );

      if (!response.data || !response.data.results) {
        throw new Error("Invalid response from Open-Elevation");
      }

      logger.info("Open-Elevation réussie:", {
        points_processed: response.data.results.length,
      });

      return response.data.results.map((result, index) => ({
        lat: limitedCoords[index][1] || limitedCoords[index].lat,
        lon: limitedCoords[index][0] || limitedCoords[index].lon,
        elevation: result.elevation || 0,
      }));
    } catch (error) {
      logger.error("Open-Elevation également échouée:", error.message);

      // Dernier fallback: élévations par défaut
      return coordinates.map((coord) => ({
        lat: coord[1] || coord.lat,
        lon: coord[0] || coord.lon,
        elevation: 0,
      }));
    }
  }

  /**
   * Vérifie l'état de l'API GraphHopper
   */
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

  /**
   * Formate la réponse de l'API GraphHopper
   */
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
        environment_breakdown: this.analyzeEnvironment(
          path.details?.road_environment
        ),
        ascent: path.ascent || 0,
        descent: path.descent || 0,
      },
    };
  }

  /**
   * Analyse la répartition des surfaces
   */
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

  /**
   * Analyse la répartition des classes de routes
   */
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

  /**
   * Analyse l'environnement
   */
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

  /**
   * Extrait l'itinéraire optimisé
   */
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
      if (
        activity.location_id &&
        activity.location_id !== "start" &&
        activity.location_id !== "end"
      ) {
        const index = parseInt(activity.location_id.replace("loc_", ""));
        if (originalWaypoints[index + 1]) {
          optimizedOrder.push(originalWaypoints[index + 1]);
        }
      }
    });

    return [originalWaypoints[0], ...optimizedOrder];
  }

  /**
   * Sélectionne le profil approprié selon l'activité
   */
  selectProfile(activityType, terrainType, preferScenic, distanceKm) {
    // Profils disponibles selon les limitations de l'API
  const availableProfiles = ['car', 'bike', 'foot'];
  
  let profile;
  
  switch (activityType) {
    case 'running':
    case 'walking':
    case 'hiking':
      profile = 'foot'; // Toujours utiliser 'foot' pour les activités pédestres
      break;
      
    case 'cycling':
      profile = 'bike'; // Utiliser 'bike' pour le cyclisme (tous types)
      break;
      
    default:
      profile = 'foot'; // Fallback par défaut
  }

  // Validation que le profil est dans la liste autorisée
  if (!availableProfiles.includes(profile)) {
    logger.warn(`Profile ${profile} not available, falling back to 'foot'`);
    profile = 'foot';
  }

  logger.info('Profile sélectionné avec limitation:', {
    activityType,
    terrainType,
    preferScenic,
    selectedProfile: profile,
    availableProfiles: availableProfiles
  });

  return profile;
  }
}

module.exports = new GraphHopperCloudService();
