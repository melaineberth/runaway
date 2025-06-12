// src/services/graphhopperCloudService.js
const axios = require('axios');
const logger = require('../config/logger'); // Import direct du logger

class GraphHopperCloudService {
  constructor() {
    this.baseUrl = 'https://graphhopper.com/api/1';
    this.apiKey = process.env.GRAPHHOPPER_API_KEY;
    this.cache = new Map(); // Cache pour éviter les appels répétés
    
    if (!this.apiKey) {
      logger.warn('GRAPHHOPPER_API_KEY manquante dans les variables d\'environnement');
    }
  }

  /**
   * Génère un itinéraire via l'API GraphHopper
   */
  async getRoute(params) {
    if (!this.apiKey) {
      throw new Error('GRAPHHOPPER_API_KEY non configurée');
    }

    const {
      points,
      profile = 'foot',
      algorithm = 'round_trip',
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
        details: ['surface', 'road_class', 'road_environment', 'country', 'state'],
        locale
      };

      // Configuration pour parcours en boucle
      if (algorithm === 'round_trip') {
        requestParams.algorithm = 'round_trip';
        requestParams.round_trip = {
          distance: roundTripDistance,
          seed: roundTripSeed
        };
      }

      // Éviter le trafic si demandé
      if (avoidTraffic) {
        requestParams.ch = false;
        requestParams.lm = false;
      }

      // Construire l'URL avec les points
      let url = `${this.baseUrl}/route?`;
      
      // Ajouter les points
      points.forEach(point => {
        url += `point=${point.lat},${point.lon}&`;
      });

      // Ajouter les autres paramètres
      Object.entries(requestParams).forEach(([key, value]) => {
        if (typeof value === 'object') {
          Object.entries(value).forEach(([subKey, subValue]) => {
            url += `${key}.${subKey}=${subValue}&`;
          });
        } else {
          url += `${key}=${value}&`;
        }
      });

      logger.info('Appel GraphHopper API:', { 
        url: url.substring(0, 200) + '...',
        points: points.length,
        profile 
      });

      const response = await axios.get(url, {
        timeout: 30000 // 30 secondes pour l'API externe
      });

      if (!response.data.paths || response.data.paths.length === 0) {
        throw new Error('Aucun itinéraire trouvé par GraphHopper');
      }

      return this.formatResponse(response.data.paths[0]);

    } catch (error) {
      logger.error('Erreur GraphHopper API:', error.message);
      
      if (error.response) {
        logger.error('Réponse API:', error.response.data);
        throw new Error(`GraphHopper API error: ${error.response.data.message || error.message}`);
      }
      
      throw error;
    }
  }

  /**
   * Optimise l'ordre des waypoints
   */
  async optimizeWaypoints(waypoints, profile = 'foot') {
    if (!this.apiKey) {
      logger.warn('API key manquante pour optimisation, retour ordre original');
      return waypoints;
    }

    try {
      const points = waypoints.map(wp => ({ lat: wp.lat, lon: wp.lon }));
      
      const url = `${this.baseUrl}/optimize`;
      const requestData = {
        vehicles: [{
          vehicle_id: 'v1',
          start_address: {
            location_id: 'start',
            lat: points[0].lat,
            lon: points[0].lon
          },
          end_address: {
            location_id: 'end',
            lat: points[0].lat,
            lon: points[0].lon
          },
          profile
        }],
        services: points.slice(1).map((point, index) => ({
          id: `service_${index}`,
          address: {
            location_id: `loc_${index}`,
            lat: point.lat,
            lon: point.lon
          }
        }))
      };

      const response = await axios.post(url, requestData, {
        params: { key: this.apiKey },
        timeout: 30000
      });

      return this.extractOptimizedRoute(response.data, waypoints);

    } catch (error) {
      logger.warn('Optimization failed, using original order:', error.message);
      return waypoints; // Fallback: retourner l'ordre original
    }
  }

  /**
   * Récupère les données d'élévation
   */
  async getElevation(coordinates) {
    if (!this.apiKey) {
      logger.warn('API key manquante pour élévation, retour élévations zéro');
      return coordinates.map(coord => ({
        lat: coord[1] || coord.lat,
        lon: coord[0] || coord.lon,
        elevation: 0
      }));
    }

    try {
      const points = coordinates.map(coord => ({
        lat: coord[1] || coord.lat,
        lng: coord[0] || coord.lon
      }));

      const response = await axios.post(`${this.baseUrl}/elevation`, {
        points
      }, {
        params: { key: this.apiKey },
        timeout: 15000
      });

      return response.data.elevations.map((elevation, index) => ({
        lat: points[index].lat,
        lon: points[index].lng,
        elevation
      }));

    } catch (error) {
      logger.error('Erreur récupération élévation:', error.message);
      // Retourner des élévations par défaut en cas d'erreur
      return coordinates.map(coord => ({
        lat: coord[1] || coord.lat,
        lon: coord[0] || coord.lon,
        elevation: 0
      }));
    }
  }

  /**
   * Vérifie l'état de l'API GraphHopper
   */
  async healthCheck() {
    if (!this.apiKey) {
      return {
        status: 'unhealthy',
        error: 'API key not configured'
      };
    }

    try {
      const response = await axios.get(`${this.baseUrl}/info`, {
        params: { key: this.apiKey },
        timeout: 5000
      });
      
      return {
        status: 'healthy',
        version: response.data.version || 'unknown',
        limits: response.data.limits || {}
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message
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
        profile: path.details?.profile || 'unknown',
        surface_breakdown: this.analyzeSurfaces(path.details?.surface),
        road_class_breakdown: this.analyzeRoadClasses(path.details?.road_class),
        environment_breakdown: this.analyzeEnvironment(path.details?.road_environment),
        ascent: path.ascent || 0,
        descent: path.descent || 0
      }
    };
  }

  /**
   * Analyse la répartition des surfaces
   */
  analyzeSurfaces(surfaceDetails) {
    if (!surfaceDetails) return { paved: 100 };
    
    const surfaces = {};
    let totalDistance = 0;
    
    surfaceDetails.forEach(detail => {
      const distance = detail[1] - detail[0];
      const surface = detail[2] || 'paved';
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
    
    roadClassDetails.forEach(detail => {
      const distance = detail[1] - detail[0];
      const roadClass = detail[2] || 'secondary';
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
    
    environmentDetails.forEach(detail => {
      const distance = detail[1] - detail[0];
      const environment = detail[2] || 'urban';
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
    route.activities.forEach(activity => {
      if (activity.location_id && activity.location_id !== 'start' && activity.location_id !== 'end') {
        const index = parseInt(activity.location_id.replace('loc_', ''));
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
  selectProfile(activityType, terrainType, preferScenic) {
    const profiles = {
      running: terrainType === 'trail' ? 'hiking' : 'foot',
      walking: 'foot',
      cycling: terrainType === 'mountain' ? 'mtb' : 'bike',
      hiking: 'hiking'
    };

    let profile = profiles[activityType] || 'foot';

    // Ajuster selon les préférences
    if (preferScenic && activityType === 'cycling') {
      profile = 'bike'; // Privilégier les routes cyclables scenic
    }

    return profile;
  }
}

module.exports = new GraphHopperCloudService();