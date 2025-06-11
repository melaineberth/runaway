const axios = require('axios');
const turf = require('@turf/turf');
const { logger } = require('../../server');
const geoUtils = require('../utils/validators');
const elevationService = require('./elevationService');

class RouteGeneratorService {
  constructor(graphhopperUrl) {
    this.graphhopperUrl = graphhopperUrl || process.env.GRAPHHOPPER_URL;
    this.cache = new Map(); // Simple cache en mémoire
  }

  /**
   * Génère un parcours selon les paramètres fournis
   */
  async generateRoute(params) {
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
      preferScenic
    } = params;

    logger.info('Génération de parcours:', params);

    try {
      // Sélectionner le profil GraphHopper approprié
      const profile = this.selectProfile(activityType, terrainType, preferScenic);
      
      if (isLoop) {
        return await this.generateLoopRoute(params, profile);
      } else {
        return await this.generatePointToPointRoute(params, profile);
      }
    } catch (error) {
      logger.error('Erreur génération parcours:', error);
      throw error;
    }
  }

  /**
   * Génère un parcours en boucle
   */
  async generateLoopRoute(params, profile) {
    const { startLat, startLon, distanceKm, elevationGain } = params;
    
    // Stratégie: créer plusieurs waypoints formant une boucle
    const waypoints = this.generateLoopWaypoints(startLat, startLon, distanceKm);
    
    // Optimiser l'ordre des waypoints
    const optimizedRoute = await this.optimizeWaypoints(waypoints, profile);
    
    // Construire le parcours final
    const route = await this.buildDetailedRoute(optimizedRoute, profile);
    
    // Ajuster pour respecter la distance cible
    const adjustedRoute = await this.adjustRouteDistance(route, distanceKm);
    
    // Valider le dénivelé si nécessaire
    if (elevationGain > 0) {
      const elevationData = await elevationService.addElevationData(adjustedRoute.coordinates);
      adjustedRoute.elevationProfile = elevationData;
      
      // Vérifier si le dénivelé correspond
      const actualElevationGain = this.calculateElevationGain(elevationData);
      adjustedRoute.metadata.elevationGain = actualElevationGain;
    }
    
    return adjustedRoute;
  }

  /**
   * Génère des waypoints pour former une boucle
   */
  generateLoopWaypoints(centerLat, centerLon, distanceKm) {
    const numWaypoints = Math.max(4, Math.floor(distanceKm / 5));
    const radius = distanceKm / (2 * Math.PI); // Rayon approximatif en km
    const waypoints = [];
    
    for (let i = 0; i < numWaypoints; i++) {
      const angle = (2 * Math.PI * i) / numWaypoints;
      const point = turf.destination(
        [centerLon, centerLat],
        radius,
        angle * 180 / Math.PI,
        { units: 'kilometers' }
      );
      waypoints.push({
        lat: point.geometry.coordinates[1],
        lon: point.geometry.coordinates[0]
      });
    }
    
    // Ajouter le point de départ à la fin pour fermer la boucle
    waypoints.push({ lat: centerLat, lon: centerLon });
    
    return waypoints;
  }

  /**
   * Optimise l'ordre des waypoints avec GraphHopper
   */
  async optimizeWaypoints(waypoints, profile) {
    const points = waypoints.map(wp => [wp.lon, wp.lat]);
    
    try {
      const response = await axios.post(`${this.graphhopperUrl}/route-optimization`, {
        objectives: [{
          type: "min",
          value: "transport_time"
        }],
        vehicles: [{
          vehicle_id: "runner",
          start_address: {
            location_id: "start",
            lon: points[0][0],
            lat: points[0][1]
          },
          return_to_depot: true
        }],
        services: points.slice(1, -1).map((point, idx) => ({
          id: `waypoint_${idx}`,
          address: {
            location_id: `loc_${idx}`,
            lon: point[0],
            lat: point[1]
          }
        })),
        configuration: {
          routing: {
            profile: profile
          }
        }
      });

      return response.data.solution.routes[0].activities
        .filter(act => act.type === "service")
        .map(act => ({
          lat: act.address.lat,
          lon: act.address.lon
        }));
    } catch (error) {
      logger.warn('Optimisation échouée, utilisation ordre original');
      return waypoints;
    }
  }

  /**
   * Construit un parcours détaillé via GraphHopper
   */
  async buildDetailedRoute(waypoints, profile) {
    const points = waypoints.map(wp => [wp.lon, wp.lat]);
    
    const response = await axios.post(`${this.graphhopperUrl}/route`, {
      points: points,
      profile: profile,
      points_encoded: false,
      elevation: true,
      instructions: true,
      calc_points: true,
      details: ["surface", "road_class", "road_environment"],
      algorithm: "alternative_route"
    });

    const route = response.data.paths[0];
    
    return {
      coordinates: route.points.coordinates,
      distance: route.distance,
      duration: route.time,
      metadata: {
        profile: profile,
        surface_breakdown: this.analyzeSurfaces(route.details.surface),
        road_class_breakdown: this.analyzeRoadClasses(route.details.road_class),
        environment_breakdown: this.analyzeEnvironment(route.details.road_environment)
      },
      instructions: route.instructions,
      bbox: route.bbox
    };
  }

  /**
   * Ajuste la distance du parcours
   */
  async adjustRouteDistance(route, targetDistanceKm) {
    const currentDistanceKm = route.distance / 1000;
    const ratio = targetDistanceKm / currentDistanceKm;
    
    if (Math.abs(ratio - 1) < 0.1) {
      // Distance déjà proche de la cible (±10%)
      return route;
    }
    
    if (ratio > 1) {
      // Parcours trop court, ajouter des détours
      return await this.extendRoute(route, targetDistanceKm);
    } else {
      // Parcours trop long, raccourcir
      return await this.shortenRoute(route, targetDistanceKm);
    }
  }

  /**
   * Étend un parcours trop court
   */
  async extendRoute(route, targetDistanceKm) {
    const currentDistanceKm = route.distance / 1000;
    const additionalDistanceKm = targetDistanceKm - currentDistanceKm;
    
    // Trouver le meilleur endroit pour ajouter un détour
    const midPoint = Math.floor(route.coordinates.length / 2);
    const detourPoint = route.coordinates[midPoint];
    
    // Créer un point de détour
    const detour = turf.destination(
      detourPoint,
      additionalDistanceKm / 2,
      Math.random() * 360,
      { units: 'kilometers' }
    );
    
    // Insérer le détour dans le parcours
    const newCoordinates = [
      ...route.coordinates.slice(0, midPoint),
      detour.geometry.coordinates,
      ...route.coordinates.slice(midPoint)
    ];
    
    route.coordinates = newCoordinates;
    route.distance = targetDistanceKm * 1000;
    
    return route;
  }

  /**
   * Raccourcit un parcours trop long
   */
  async shortenRoute(route, targetDistanceKm) {
    const targetDistance = targetDistanceKm * 1000;
    let currentDistance = 0;
    const shortenedCoordinates = [route.coordinates[0]];
    
    for (let i = 1; i < route.coordinates.length; i++) {
      const segmentDistance = geoUtils.calculateDistance(
        route.coordinates[i-1],
        route.coordinates[i]
      );
      
      if (currentDistance + segmentDistance > targetDistance) {
        // Interpoler le point final
        const ratio = (targetDistance - currentDistance) / segmentDistance;
        const finalPoint = geoUtils.interpolatePoint(
          route.coordinates[i-1],
          route.coordinates[i],
          ratio
        );
        shortenedCoordinates.push(finalPoint);
        break;
      }
      
      shortenedCoordinates.push(route.coordinates[i]);
      currentDistance += segmentDistance;
    }
    
    route.coordinates = shortenedCoordinates;
    route.distance = targetDistance;
    
    return route;
  }

  /**
   * Sélectionne le profil GraphHopper approprié
   */
  selectProfile(activityType, terrainType, preferScenic) {
    const profileMap = {
      running: {
        scenic: 'running_scenic',
        normal: 'running'
      },
      cycling: {
        safe: 'cycling_safe',
        normal: 'cycling'
      },
      walking: {
        normal: 'walking'
      }
    };

    const activity = profileMap[activityType] || profileMap.running;
    
    if (preferScenic && activity.scenic) {
      return activity.scenic;
    } else if (terrainType === 'urban' && activity.safe) {
      return activity.safe;
    }
    
    return activity.normal || 'running';
  }

  /**
   * Analyse la répartition des surfaces
   */
  analyzeSurfaces(surfaceDetails) {
    const surfaces = {};
    let totalDistance = 0;
    
    surfaceDetails.forEach(detail => {
      const distance = detail[1] - detail[0];
      const surface = detail[2] || 'unknown';
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
   * Analyse les types de routes
   */
  analyzeRoadClasses(roadClassDetails) {
    const classes = {};
    let totalDistance = 0;
    
    roadClassDetails.forEach(detail => {
      const distance = detail[1] - detail[0];
      const roadClass = detail[2] || 'unknown';
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
   * Calcule le dénivelé positif total
   */
  calculateElevationGain(elevationProfile) {
    let totalGain = 0;
    
    for (let i = 1; i < elevationProfile.length; i++) {
      const diff = elevationProfile[i].elevation - elevationProfile[i-1].elevation;
      if (diff > 0) {
        totalGain += diff;
      }
    }
    
    return Math.round(totalGain);
  }

  /**
   * Génère un parcours point à point
   */
  async generatePointToPointRoute(params, profile) {
    const { startLat, startLon, distanceKm } = params;
    
    // Générer un point d'arrivée à la distance souhaitée
    const bearing = Math.random() * 360; // Direction aléatoire
    const endpoint = turf.destination(
      [startLon, startLat],
      distanceKm * 0.8, // 80% de la distance en ligne droite
      bearing,
      { units: 'kilometers' }
    );
    
    const waypoints = [
      { lat: startLat, lon: startLon },
      { lat: endpoint.geometry.coordinates[1], lon: endpoint.geometry.coordinates[0] }
    ];
    
    const route = await this.buildDetailedRoute(waypoints, profile);
    return await this.adjustRouteDistance(route, distanceKm);
  }
}

module.exports = new RouteGeneratorService();