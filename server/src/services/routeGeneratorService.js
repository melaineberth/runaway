// src/services/routeGeneratorService.js
const turf = require("@turf/turf");
const logger = require("../config/logger"); // Import direct du logger
const graphhopperCloud = require("./graphhopperCloudService");
const { metricsService } = require("./metricsService");

class RouteGeneratorService {
  constructor() {
    this.cache = new Map(); // Cache en mémoire
    console.log("🔧 RouteGeneratorService construit");
  }

  /**
   * Génère un itinéraire simple entre deux points
   */
  async generateSimpleRoute(params) {
    const { startLat, startLon, endLat, endLon, profile = 'foot' } = params;
    
    logger.info('Simple route generation started', {
      start: [startLat, startLon],
      end: [endLat, endLon],
      profile
    });

    try {
      // ✅ Utiliser GraphHopper avec l'algorithme par défaut (pas dijkstra)
      const route = await graphhopperCloud.getRoute({
        points: [
          { lat: startLat, lon: startLon },
          { lat: endLat, lon: endLon }
        ],
        profile,
        algorithm: 'auto', // ✅ Laisser GraphHopper choisir le meilleur algorithme
        avoidTraffic: false
      });

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
   * Génère un parcours selon les paramètres fournis
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

    logger.info("Route generation started", {
      requestId: params.requestId,
      activityType,
      distanceKm,
      terrainType,
      urbanDensity,
      startCoords: [startLat, startLon],
    });

    try {
      // Sélectionner le profil GraphHopper approprié
      const profile = graphhopperCloud.selectProfile(
        activityType,
        terrainType,
        preferScenic
      );

      let route;
      if (isLoop) {
        route = await this.generateLoopRoute(params, profile);
      } else {
        route = await this.generatePointToPointRoute(params, profile);
      }

      const duration = Date.now() - startTime;
      logger.info("Route generation completed", {
        requestId: params.requestId,
        duration: `${duration}ms`,
        distance: route.distance,
        coordinatesCount: route.coordinates.length,
        profile,
      });

      metricsService.recordRouteGeneration(true, route.distance / 1000);
      return route;
      
    } catch (error) {
      const duration = Date.now() - startTime;
      logger.error("Route generation failed", {
        requestId: params.requestId,
        duration: `${duration}ms`,
        error: error.message,
        stack: process.env.NODE_ENV === "development" ? error.stack : undefined,
      });

      metricsService.recordRouteGeneration(false);
      throw error;
    }
  }

  /**
   * Génère un parcours en boucle
   */
  async generateLoopRoute(params, profile) {
    const { startLat, startLon, distanceKm, elevationGain, avoidTraffic } =
      params;

    try {
      // Utiliser l'algorithme round_trip de GraphHopper
      const route = await graphhopperCloud.getRoute({
        points: [{ lat: startLat, lon: startLon }],
        profile,
        algorithm: "round_trip",
        roundTripDistance: distanceKm * 1000, // Convertir en mètres
        roundTripSeed: Math.floor(Math.random() * 1000000),
        avoidTraffic,
      });

      // Ajouter les données d'élévation si nécessaire
      if (elevationGain > 0 || params.includeElevation) {
        const elevationData = await graphhopperCloud.getElevation(
          route.coordinates
        );
        route.elevationProfile = elevationData;

        // Calculer le dénivelé réel
        const actualElevationGain = this.calculateElevationGain(elevationData);
        route.metadata.elevationGain = actualElevationGain;
      }

      // Vérifier si la distance correspond aux attentes
      const actualDistanceKm = route.distance / 1000;
      const distanceRatio = actualDistanceKm / distanceKm;

      if (distanceRatio < 0.8 || distanceRatio > 1.2) {
        logger.warn(
          `Distance générée (${actualDistanceKm.toFixed(
            1
          )}km) diffère de la cible (${distanceKm}km)`
        );
      }

      return route;
    } catch (error) {
      logger.error("Erreur génération boucle:", error);
      // Fallback: générer une boucle manuellement
      return await this.generateManualLoopRoute(params, profile);
    }
  }

  /**
   * Génère un parcours point à point
   */
  async generatePointToPointRoute(params, profile) {
    const { startLat, startLon, distanceKm, avoidTraffic } = params;

    // Générer un point d'arrivée à la distance souhaitée
    const bearing = Math.random() * 360; // Direction aléatoire
    const endpoint = turf.destination(
      [startLon, startLat],
      distanceKm * 0.8, // 80% de la distance en ligne droite
      bearing,
      { units: "kilometers" }
    );

    try {
      const route = await graphhopperCloud.getRoute({
        points: [
          { lat: startLat, lon: startLon },
          {
            lat: endpoint.geometry.coordinates[1],
            lon: endpoint.geometry.coordinates[0],
          },
        ],
        profile,
        avoidTraffic,
      });

      return await this.adjustRouteDistance(route, distanceKm, profile);
    } catch (error) {
      logger.error("Erreur génération point-à-point:", error);
      throw new Error("Impossible de générer l'itinéraire demandé");
    }
  }

  /**
   * Fallback: génère une boucle manuellement avec plusieurs waypoints
   */
  async generateManualLoopRoute(params, profile) {
    const { startLat, startLon, distanceKm, avoidTraffic } = params;

    logger.info("Génération manuelle de boucle...");

    // Créer plusieurs waypoints formant une boucle
    const waypoints = this.generateLoopWaypoints(
      startLat,
      startLon,
      distanceKm
    );

    try {
      // Optimiser l'ordre des waypoints
      const optimizedWaypoints = await graphhopperCloud.optimizeWaypoints(
        waypoints,
        profile
      );

      // Construire le parcours avec tous les waypoints
      const route = await graphhopperCloud.getRoute({
        points: optimizedWaypoints,
        profile,
        avoidTraffic,
      });

      return await this.adjustRouteDistance(route, distanceKm, profile);
    } catch (error) {
      logger.error("Échec génération manuelle:", error);
      throw new Error("Impossible de générer un parcours dans cette zone");
    }
  }

  /**
   * Génère des waypoints pour former une boucle
   */
  generateLoopWaypoints(startLat, startLon, distanceKm) {
    const waypoints = [{ lat: startLat, lon: startLon }];
    const radiusKm = distanceKm / 4; // Rayon approximatif de la boucle
    const numberOfWaypoints = Math.min(
      6,
      Math.max(3, Math.floor(distanceKm / 2))
    );

    for (let i = 0; i < numberOfWaypoints; i++) {
      const bearing = (360 / numberOfWaypoints) * i;
      const distance = radiusKm * (0.8 + Math.random() * 0.4); // Variation de distance

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
   * Ajuste la distance du parcours si nécessaire
   */
  async adjustRouteDistance(route, targetDistanceKm, profile) {
    const currentDistanceKm = route.distance / 1000;
    const ratio = targetDistanceKm / currentDistanceKm;

    if (Math.abs(ratio - 1) < 0.15) {
      // Distance acceptable (±15%)
      return route;
    }

    logger.info(
      `Ajustement distance: ${currentDistanceKm.toFixed(
        1
      )}km -> ${targetDistanceKm}km`
    );

    if (ratio > 1.3) {
      // Parcours trop court, ajouter des détours
      return await this.extendRoute(route, targetDistanceKm, profile);
    } else if (ratio < 0.7) {
      // Parcours trop long, essayer de raccourcir
      return await this.shortenRoute(route, targetDistanceKm, profile);
    }

    return route; // Garder le parcours tel quel si l'écart est raisonnable
  }

  /**
   * Étend un parcours trop court
   */
  async extendRoute(route, targetDistanceKm, profile) {
    try {
      const currentDistanceKm = route.distance / 1000;
      const additionalDistanceKm = targetDistanceKm - currentDistanceKm;

      // Trouver le point milieu pour ajouter un détour
      const midIndex = Math.floor(route.coordinates.length / 2);
      const midPoint = route.coordinates[midIndex];

      // Créer un point de détour
      const detourBearing = Math.random() * 360;
      const detourDistance = additionalDistanceKm / 3; // Distance du détour

      const detourPoint = turf.destination(
        midPoint,
        detourDistance,
        detourBearing,
        { units: "kilometers" }
      );

      // Recalculer le parcours avec le détour
      const waypoints = [
        { lat: route.coordinates[0][1], lon: route.coordinates[0][0] },
        {
          lat: detourPoint.geometry.coordinates[1],
          lon: detourPoint.geometry.coordinates[0],
        },
        {
          lat: route.coordinates[route.coordinates.length - 1][1],
          lon: route.coordinates[route.coordinates.length - 1][0],
        },
      ];

      const extendedRoute = await graphhopperCloud.getRoute({
        points: waypoints,
        profile,
      });

      return extendedRoute;
    } catch (error) {
      logger.warn("Impossible d'étendre le parcours:", error.message);
      return route; // Retourner le parcours original
    }
  }

  /**
   * Raccourcit un parcours trop long
   */
  async shortenRoute(route, targetDistanceKm, profile) {
    try {
      // Stratégie simple: créer un itinéraire plus direct
      const start = route.coordinates[0];
      const end = route.coordinates[route.coordinates.length - 1];

      // Si c'est une boucle, créer une boucle plus petite
      if (this.isLoop(route.coordinates)) {
        const centerLat = start[1];
        const centerLon = start[0];
        const smallerRadius = targetDistanceKm / 6;

        const smallWaypoints = [];
        for (let i = 0; i < 4; i++) {
          const bearing = (360 / 4) * i;
          const waypoint = turf.destination(
            [centerLon, centerLat],
            smallerRadius,
            bearing,
            { units: "kilometers" }
          );

          smallWaypoints.push({
            lat: waypoint.geometry.coordinates[1],
            lon: waypoint.geometry.coordinates[0],
          });
        }

        const shortenedRoute = await graphhopperCloud.getRoute({
          points: smallWaypoints,
          profile,
        });

        return shortenedRoute;
      }

      return route; // Si pas de solution, garder le parcours original
    } catch (error) {
      logger.warn("Impossible de raccourcir le parcours:", error.message);
      return route;
    }
  }

  /**
   * Vérifie si le parcours est une boucle
   */
  isLoop(coordinates) {
    if (coordinates.length < 2) return false;

    const start = coordinates[0];
    const end = coordinates[coordinates.length - 1];
    const distance = turf.distance(start, end, { units: "meters" });

    return distance < 100; // Moins de 100m entre début et fin
  }

  /**
   * Calcule le dénivelé positif total
   */
  calculateElevationGain(elevationProfile) {
    let totalGain = 0;

    for (let i = 1; i < elevationProfile.length; i++) {
      const diff =
        elevationProfile[i].elevation - elevationProfile[i - 1].elevation;
      if (diff > 0) {
        totalGain += diff;
      }
    }

    return Math.round(totalGain);
  }

  /**
   * Analyse un parcours existant
   */
  async analyzeExistingRoute(coordinates) {
    try {
      // Calculer la distance totale
      let totalDistance = 0;
      for (let i = 1; i < coordinates.length; i++) {
        totalDistance += turf.distance(coordinates[i - 1], coordinates[i], {
          units: "meters",
        });
      }

      // Récupérer les données d'élévation
      const elevationData = await graphhopperCloud.getElevation(coordinates);

      // Calculer les métriques d'élévation
      const elevationGain = this.calculateElevationGain(elevationData);
      const elevationLoss = this.calculateElevationLoss(elevationData);
      const { averageGrade, maxGrade } = this.calculateGrades(elevationData);

      // Estimer la durée (vitesse basée sur le profil)
      const estimatedDuration = this.estimateDuration(
        totalDistance,
        elevationGain
      );

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

  /**
   * Calcule la perte d'élévation
   */
  calculateElevationLoss(elevationProfile) {
    let totalLoss = 0;

    for (let i = 1; i < elevationProfile.length; i++) {
      const diff =
        elevationProfile[i].elevation - elevationProfile[i - 1].elevation;
      if (diff < 0) {
        totalLoss += Math.abs(diff);
      }
    }

    return Math.round(totalLoss);
  }

  /**
   * Calcule les pentes
   */
  calculateGrades(elevationProfile) {
    const grades = [];

    for (let i = 1; i < elevationProfile.length; i++) {
      const elevationDiff =
        elevationProfile[i].elevation - elevationProfile[i - 1].elevation;
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

    const averageGrade =
      grades.length > 0 ? grades.reduce((a, b) => a + b, 0) / grades.length : 0;
    const maxGrade = grades.length > 0 ? Math.max(...grades.map(Math.abs)) : 0;

    return {
      averageGrade: Math.round(averageGrade * 10) / 10,
      maxGrade: Math.round(maxGrade * 10) / 10,
    };
  }

  /**
   * Estime la durée du parcours
   */
  estimateDuration(distanceMeters, elevationGain) {
    // Vitesses moyennes en m/min selon l'activité
    const baseSpeed = 80; // 4.8 km/h pour la marche

    // Temps de base
    let duration = distanceMeters / baseSpeed;

    // Ajout pour le dénivelé (règle de Naismith modifiée)
    duration += elevationGain / 10; // +1 min par 10m de dénivelé

    return Math.round(duration); // Retourner en minutes
  }
}

const serviceInstance = new RouteGeneratorService();

console.log(
  "🔧 RouteGeneratorService créé, méthodes disponibles:",
  Object.getOwnPropertyNames(Object.getPrototypeOf(serviceInstance))
);
console.log(
  "🔧 generateSimpleRoute existe dans le service?",
  typeof serviceInstance.generateSimpleRoute
);

module.exports = serviceInstance;
