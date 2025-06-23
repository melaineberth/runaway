const routeGeneratorService = require("../services/routeGeneratorService");
const { validateRouteParams } = require("../utils/validators");
const logger = require("../config/logger"); // Import direct du logger
const routeQualityService = require("../services/routeQualityService"); // ✅ AJOUT MANQUANT

class RouteController {
  /**
     * POST /api/routes/simple
     * Génère un itinéraire simple entre deux points
     */
  async generateSimpleRoute(req, res, next) {
    console.log('🔧 generateSimpleRoute appelée dans le contrôleur');
    console.log('🔧 Body reçu:', req.body);
    
    try {
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
      
      console.log('🔧 Validation réussie, génération de la route...');
      
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

      console.log('🔧 Route générée avec succès');

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
      console.log('❌ Erreur dans generateSimpleRoute:', error);
      
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
      // Utiliser les paramètres validés du middleware
      const params = req.validatedParams || req.body;
      
      if (!params) {
        return res.status(400).json({
          success: false,
          error: "Paramètres manquants"
        });
      }
  
      // Construire les paramètres pour le service avec validation
      const serviceParams = {
        startLat: params.startLatitude || params.startLat,
        startLon: params.startLongitude || params.startLon,
        activityType: params.activityType,
        distanceKm: params.distanceKm,
        terrainType: params.terrainType || 'mixed',
        urbanDensity: params.urbanDensity || 'mixed',
        elevationGain: params.elevationGain || 0,
        isLoop: params.isLoop !== false,
        avoidTraffic: params.avoidTraffic !== false,
        preferScenic: params.preferScenic !== false,
        searchRadius: params.searchRadius || params.distanceKm * 1000,
        requestId: params.requestId || `route_${Date.now()}`
      };
  
      logger.info("Enhanced route generation started:", {
        requestId: serviceParams.requestId,
        params: serviceParams
      });
  
      // Générer le parcours avec le service amélioré
      const route = await routeGeneratorService.generateRoute(serviceParams);
  
      // Validation de qualité post-génération
      const qualityValidation = routeQualityService.validateRoute(route, serviceParams);
      
      logger.info("Route quality validation completed:", {
        requestId: serviceParams.requestId,
        isValid: qualityValidation.isValid,
        quality: qualityValidation.quality,
        issues: qualityValidation.issues.length
      });
  
      // Si la qualité n'est pas acceptable, essayer de corriger
      let finalRoute = route;
      let appliedFixes = [];
      
      if (!qualityValidation.isValid && qualityValidation.quality !== 'critical') {
        logger.info("Attempting auto-fix for quality issues:", {
          requestId: serviceParams.requestId,
          issues: qualityValidation.issues
        });
        
        const { route: fixedRoute, fixes } = routeQualityService.autoFixRoute(route, serviceParams);
        finalRoute = fixedRoute;
        appliedFixes = fixes;
        
        if (fixes.length > 0) {
          logger.info("Auto-fixes applied successfully:", {
            requestId: serviceParams.requestId,
            fixes: fixes
          });
        }
      }
  
      // Formater la réponse enrichie pour Flutter
      const response = {
        success: true,
        route: {
          coordinates: finalRoute.coordinates,
          distance: finalRoute.distance,
          duration: finalRoute.duration,
          elevationGain: finalRoute.metadata?.elevationGain || 0,
          metadata: {
            ...finalRoute.metadata,
            generatedAt: new Date().toISOString(),
            parameters: serviceParams,
            quality: qualityValidation.quality,
            appliedFixes: appliedFixes,
            validationMetrics: qualityValidation.metrics,
            requestId: serviceParams.requestId
          },
        },
        instructions: finalRoute.instructions || [],
        elevationProfile: finalRoute.elevationProfile || [],
        bbox: finalRoute.bbox,
        qualityInfo: {
          overallQuality: qualityValidation.quality,
          isValid: qualityValidation.isValid,
          issues: qualityValidation.issues,
          appliedFixes: appliedFixes,
          suggestions: qualityValidation.suggestions || []
        }
      };
  
      // Logging final pour métriques
      logger.info("Enhanced route generation completed successfully:", {
        requestId: serviceParams.requestId,
        distance: `${(finalRoute.distance / 1000).toFixed(1)}km`,
        quality: qualityValidation.quality,
        fixes: appliedFixes.length,
        duration: `${Math.round(finalRoute.duration / 60000)}min`
      });
  
      res.json(response);
  
    } catch (error) {
      const requestId = req.validatedParams?.requestId || req.body?.requestId || 'unknown';
      
      logger.error("Enhanced route generation failed:", {
        requestId: requestId,
        error: error.message,
        stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
      });
  
      // Gestion d'erreurs spécifique selon le type d'erreur
      if (error.message.includes('Unable to generate acceptable route')) {
        return res.status(422).json({
          success: false,
          error: "Impossible de générer un parcours de qualité acceptable",
          details: {
            message: "Essayez de modifier les paramètres (distance, zone géographique, type d'activité)",
            suggestions: [
              "Réduire la distance demandée",
              "Changer de zone géographique", 
              "Modifier le type de terrain",
              "Ajuster le rayon de recherche"
            ]
          },
          requestId: requestId
        });
      }
  
      if (error.message.includes('Distance ratio too extreme')) {
        return res.status(422).json({
          success: false,
          error: "Distance générée trop différente de celle demandée",
          details: {
            message: "La zone géographique ne permet pas de générer un parcours de cette distance",
            suggestions: [
              "Essayer une distance différente",
              "Changer de point de départ",
              "Modifier les préférences de terrain"
            ]
          },
          requestId: requestId
        });
      }
  
      if (error.message.includes('GraphHopper')) {
        return res.status(503).json({
          success: false,
          error: 'Service de routage temporairement indisponible',
          details: process.env.NODE_ENV === 'development' ? error.message : undefined,
          requestId: requestId
        });
      }
  
      // Erreur générique
      res.status(500).json({
        success: false,
        error: error.message,
        requestId: requestId
      });
    }
  }  

  // Ajouter cette nouvelle méthode pour la régénération avec paramètres ajustés
  async regenerateWithAdjustments(req, res, next) {
    try {
      const { originalParams, adjustments } = req.body;
      
      if (!originalParams) {
        return res.status(400).json({
          success: false,
          error: "Paramètres originaux manquants"
        });
      }

      // Appliquer les ajustements
      const adjustedParams = {
        ...originalParams,
        ...adjustments,
        requestId: `regen_${Date.now()}`
      };

      logger.info("Route regeneration with adjustments:", {
        requestId: adjustedParams.requestId,
        adjustments: adjustments
      });

      // Utiliser la méthode generateRoute avec les paramètres ajustés
      req.body = adjustedParams;
      req.validatedParams = adjustedParams;
      
      return this.generateRoute(req, res, next);

    } catch (error) {
      logger.error("Route regeneration failed:", error);
      next(error);
    }
  }

  // Ajouter cette méthode pour l'analyse comparative
  async compareRouteOptions(req, res, next) {
    try {
      const baseParams = req.body;
      const variations = [
        { ...baseParams, terrainType: 'flat' },
        { ...baseParams, terrainType: 'mixed' },
        { ...baseParams, terrainType: 'hilly' },
        { ...baseParams, urbanDensity: 'urban' },
        { ...baseParams, urbanDensity: 'nature' }
      ];

      const results = [];
      
      for (let i = 0; i < variations.length; i++) {
        try {
          const params = {
            ...variations[i],
            requestId: `compare_${i}_${Date.now()}`
          };

          logger.info(`Generating comparison route ${i + 1}/${variations.length}`);
          
          const route = await routeGeneratorService.generateRoute(params);
          const quality = routeQualityService.validateRoute(route, params);
          
          results.push({
            params: params,
            route: {
              distance: route.distance,
              duration: route.duration,
              coordinates: route.coordinates.length
            },
            quality: quality.quality,
            isValid: quality.isValid
          });
          
        } catch (error) {
          results.push({
            params: variations[i],
            error: error.message,
            quality: 'failed'
          });
        }
      }

      // Trier par qualité
      const qualityOrder = { 'excellent': 5, 'good': 4, 'acceptable': 3, 'poor': 2, 'critical': 1, 'failed': 0 };
      results.sort((a, b) => qualityOrder[b.quality] - qualityOrder[a.quality]);

      res.json({
        success: true,
        comparisons: results,
        recommendation: results[0],
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      logger.error("Route comparison failed:", error);
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

const routeControllerInstance = new RouteController();

console.log('🔧 RouteController créé, méthodes disponibles:', Object.getOwnPropertyNames(Object.getPrototypeOf(routeControllerInstance)));
console.log('🔧 generateSimpleRoute existe?', typeof routeControllerInstance.generateSimpleRoute);

module.exports = routeControllerInstance;