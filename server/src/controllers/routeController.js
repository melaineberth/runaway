const routeGeneratorService = require("../services/routeGeneratorService");
const { validateRouteParams } = require("../utils/validators");
const logger = require("../config/logger"); // Import direct du logger

class RouteController {
  /**
   * POST /api/routes/simple
   * Génère un itinéraire simple entre deux points
   */
  async generateSimpleRoute(req, res, next) {
    try {
      console.log('🛣️ generateSimpleRoute called with body:', req.body);
      
      const { points, profile = 'foot' } = req.body;
      
      // Validation des paramètres
      if (!points || !Array.isArray(points) || points.length !== 2) {
        console.log('❌ Invalid points:', points);
        return res.status(400).json({
          success: false,
          error: 'Exactly 2 points required: [[lon1, lat1], [lon2, lat2]]'
        });
      }

      // Valider chaque point
      for (let i = 0; i < points.length; i++) {
        const point = points[i];
        if (!Array.isArray(point) || point.length < 2) {
          return res.status(400).json({
            success: false,
            error: `Point ${i} invalid format. Expected [longitude, latitude]`
          });
        }
        
        const [lon, lat] = point;
        if (typeof lon !== 'number' || typeof lat !== 'number') {
          return res.status(400).json({
            success: false,
            error: `Point ${i} coordinates must be numbers`
          });
        }
        
        if (lon < -180 || lon > 180 || lat < -90 || lat > 90) {
          return res.status(400).json({
            success: false,
            error: `Point ${i} coordinates out of bounds`
          });
        }
      }

      const [start, end] = points;
      
      logger.info('Simple route generation started', {
        start: [start[1], start[0]], // lat, lon pour les logs
        end: [end[1], end[0]],
        profile
      });

      // Générer l'itinéraire via GraphHopper
      const route = await routeGeneratorService.generateSimpleRoute({
        startLat: start[1],  // start[1] = lat
        startLon: start[0],  // start[0] = lon
        endLat: end[1],      // end[1] = lat
        endLon: end[0],      // end[0] = lon
        profile
      });

      // Formater la réponse pour le client Flutter
      const response = {
        success: true,
        route: {
          coordinates: route.coordinates,
          distance: route.distance,
          duration: route.duration,
          instructions: route.instructions || [],
          metadata: {
            profile,
            generatedAt: new Date().toISOString(),
            points_count: route.coordinates.length,
            type: 'simple_route'
          }
        }
      };

      logger.info('Simple route generation completed', {
        distance: `${(route.distance / 1000).toFixed(1)}km`,
        duration: `${Math.round(route.duration / 60000)}min`,
        points: route.coordinates.length
      });

      res.json(response);

    } catch (error) {
      logger.error('Simple route generation failed:', {
        error: error.message,
        stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
      });

      // Gestion d'erreurs spécifiques GraphHopper
      if (error.message.includes('GraphHopper')) {
        return res.status(503).json({
          success: false,
          error: 'Routing service temporarily unavailable',
          details: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
      }

      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }
  
  /**
   * POST /api/routes/generate
   * Génère un nouveau parcours
   */
  async generateRoute(req, res, next) {
    try {
      // Validation des paramètres
      const validationResult = validateRouteParams(req.body);
      if (!validationResult.valid) {
        return res.status(400).json({
          error: "Paramètres invalides",
          details: validationResult.errors,
        });
      }

      const params = {
        startLat: validationResult.value.startLatitude,
        startLon: validationResult.value.startLongitude,
        activityType: validationResult.value.activityType,
        distanceKm: validationResult.value.distanceKm,
        terrainType: validationResult.value.terrainType,
        urbanDensity: validationResult.value.urbanDensity,
        elevationGain: validationResult.value.elevationGain || 0,
        isLoop: validationResult.value.isLoop !== false,
        avoidTraffic: validationResult.value.avoidTraffic !== false,
        preferScenic: validationResult.value.preferScenic !== false,
        searchRadius:
          validationResult.value.searchRadius ||
          validationResult.value.distanceKm * 1000,
      };

      logger.info("Demande de génération de parcours:", params);

      // Générer le parcours
      const route = await routeGeneratorService.generateRoute(params);

      // Formater la réponse pour Flutter
      const response = {
        success: true,
        route: {
          coordinates: route.coordinates,
          distance: route.distance,
          duration: route.duration,
          elevationGain: route.metadata.elevationGain || 0,
          metadata: {
            ...route.metadata,
            generatedAt: new Date().toISOString(),
            parameters: params,
          },
        },
        instructions: route.instructions,
        elevationProfile: route.elevationProfile,
        bbox: route.bbox,
      };

      res.json(response);
    } catch (error) {
      logger.error("Erreur génération route:", error);
      next(error);
    }
  }

  /**
   * POST /api/routes/alternative
   * Génère des parcours alternatifs
   */
  async generateAlternatives(req, res, next) {
    try {
      const { routeId, numberOfAlternatives = 3 } = req.body;

      // Récupérer les paramètres originaux depuis le cache ou la DB
      const originalParams = await this.getOriginalParams(routeId);

      if (!originalParams) {
        return res.status(404).json({
          error: "Parcours original non trouvé",
        });
      }

      const alternatives = [];

      // Générer plusieurs alternatives avec des variations
      for (let i = 0; i < numberOfAlternatives; i++) {
        const modifiedParams = this.createVariation(originalParams, i);
        const route = await routeGeneratorService.generateRoute(modifiedParams);
        alternatives.push(route);
      }

      res.json({
        success: true,
        alternatives: alternatives.map((route, index) => ({
          id: `alt_${index}`,
          ...route,
        })),
      });
    } catch (error) {
      logger.error("Erreur génération alternatives:", error);
      next(error);
    }
  }

  /**
   * GET /api/routes/export/:format
   * Exporte un parcours dans différents formats
   */
  async exportRoute(req, res, next) {
    try {
      const { format } = req.params;
      const { coordinates, metadata } = req.body;

      if (!coordinates || !Array.isArray(coordinates)) {
        return res.status(400).json({
          error: "Coordonnées manquantes ou invalides",
        });
      }

      let exportData;
      let contentType;
      let filename;

      switch (format.toLowerCase()) {
        case "gpx":
          exportData = this.exportToGPX(coordinates, metadata);
          contentType = "application/gpx+xml";
          filename = `route_${Date.now()}.gpx`;
          break;

        case "geojson":
          exportData = this.exportToGeoJSON(coordinates, metadata);
          contentType = "application/geo+json";
          filename = `route_${Date.now()}.geojson`;
          break;

        case "kml":
          exportData = this.exportToKML(coordinates, metadata);
          contentType = "application/vnd.google-earth.kml+xml";
          filename = `route_${Date.now()}.kml`;
          break;

        default:
          return res.status(400).json({
            error: "Format non supporté",
            supportedFormats: ["gpx", "geojson", "kml"],
          });
      }

      res.set({
        "Content-Type": contentType,
        "Content-Disposition": `attachment; filename="${filename}"`,
      });

      res.send(exportData);
    } catch (error) {
      logger.error("Erreur export route:", error);
      next(error);
    }
  }

  /**
   * POST /api/routes/analyze
   * Analyse un parcours existant
   */
  async analyzeRoute(req, res, next) {
    try {
      const { coordinates } = req.body;

      if (!coordinates || !Array.isArray(coordinates)) {
        return res.status(400).json({
          error: "Coordonnées manquantes ou invalides",
        });
      }

      // Analyser le parcours
      const analysis = await routeGeneratorService.analyzeExistingRoute(
        coordinates
      );

      res.json({
        success: true,
        analysis: {
          distance: analysis.distance,
          duration: analysis.estimatedDuration,
          elevationGain: analysis.elevationGain,
          elevationLoss: analysis.elevationLoss,
          averageGrade: analysis.averageGrade,
          maxGrade: analysis.maxGrade,
          surfaceBreakdown: analysis.surfaces,
          difficulty: analysis.difficulty,
          segments: analysis.segments,
        },
      });
    } catch (error) {
      logger.error("Erreur analyse route:", error);
      next(error);
    }
  }

  /**
   * GET /api/routes/nearby-pois
   * Récupère les POIs proches d'un parcours
   */
  async getNearbyPOIs(req, res, next) {
    try {
      const { lat, lon, radius = 1000, types } = req.query;

      if (!lat || !lon) {
        return res.status(400).json({
          error: "Coordonnées manquantes",
        });
      }

      const pois = await routeGeneratorService.findNearbyPOIs(
        parseFloat(lat),
        parseFloat(lon),
        parseInt(radius),
        types?.split(",")
      );

      res.json({
        success: true,
        pois: pois,
      });
    } catch (error) {
      logger.error("Erreur récupération POIs:", error);
      next(error);
    }
  }

  // Méthodes utilitaires

  async getOriginalParams(routeId) {
    // TODO: Implémenter la récupération depuis Redis ou DB
    return null;
  }

  createVariation(params, index) {
    const variations = [
      { preferScenic: !params.preferScenic },
      { avoidTraffic: !params.avoidTraffic },
      { distanceKm: params.distanceKm * (0.9 + Math.random() * 0.2) },
    ];

    return {
      ...params,
      ...variations[index % variations.length],
    };
  }

  exportToGPX(coordinates, metadata = {}) {
    const timestamp = new Date().toISOString();

    const gpx = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="RunAway" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>${metadata.name || "RunAway Route"}</name>
    <time>${timestamp}</time>
  </metadata>
  <trk>
    <name>${metadata.name || "RunAway Route"}</name>
    <trkseg>
${coordinates
  .map(
    (coord) => `      <trkpt lat="${coord[1]}" lon="${coord[0]}">
        ${coord[2] ? `<ele>${coord[2]}</ele>` : ""}
      </trkpt>`
  )
  .join("\n")}
    </trkseg>
  </trk>
</gpx>`;

    return gpx;
  }

  exportToGeoJSON(coordinates, metadata = {}) {
    return JSON.stringify(
      {
        type: "Feature",
        properties: metadata,
        geometry: {
          type: "LineString",
          coordinates: coordinates,
        },
      },
      null,
      2
    );
  }

  exportToKML(coordinates, metadata = {}) {
    const coordinatesString = coordinates
      .map((coord) => `${coord[0]},${coord[1]},${coord[2] || 0}`)
      .join(" ");

    return `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>${metadata.name || "RunAway Route"}</name>
    <Placemark>
      <name>${metadata.name || "Route"}</name>
      <LineString>
        <coordinates>${coordinatesString}</coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>`;
  }
}

module.exports = new RouteController();
