const routeGeneratorService = require('../services/routeGeneratorService');
const { validateRouteParams } = require('../utils/validators');
const { logger } = require('../../server');

class RouteController {
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
          error: 'Paramètres invalides',
          details: validationResult.errors
        });
      }

      const params = {
        startLat: req.body.startLatitude,
        startLon: req.body.startLongitude,
        activityType: req.body.activityType,
        distanceKm: req.body.distanceKm,
        terrainType: req.body.terrainType,
        urbanDensity: req.body.urbanDensity,
        elevationGain: req.body.elevationGain || 0,
        isLoop: req.body.isLoop !== false,
        avoidTraffic: req.body.avoidTraffic !== false,
        preferScenic: req.body.preferScenic !== false,
        searchRadius: req.body.searchRadius || req.body.distanceKm * 1000
      };

      logger.info('Demande de génération de parcours:', params);

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
            parameters: params
          }
        },
        instructions: route.instructions,
        elevationProfile: route.elevationProfile,
        bbox: route.bbox
      };

      res.json(response);

    } catch (error) {
      logger.error('Erreur génération route:', error);
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
          error: 'Parcours original non trouvé'
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
          ...route
        }))
      });

    } catch (error) {
      logger.error('Erreur génération alternatives:', error);
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
          error: 'Coordonnées manquantes ou invalides'
        });
      }

      let exportData;
      let contentType;
      let filename;

      switch (format.toLowerCase()) {
        case 'gpx':
          exportData = this.exportToGPX(coordinates, metadata);
          contentType = 'application/gpx+xml';
          filename = `route_${Date.now()}.gpx`;
          break;

        case 'geojson':
          exportData = this.exportToGeoJSON(coordinates, metadata);
          contentType = 'application/geo+json';
          filename = `route_${Date.now()}.geojson`;
          break;

        case 'kml':
          exportData = this.exportToKML(coordinates, metadata);
          contentType = 'application/vnd.google-earth.kml+xml';
          filename = `route_${Date.now()}.kml`;
          break;

        default:
          return res.status(400).json({
            error: 'Format non supporté',
            supportedFormats: ['gpx', 'geojson', 'kml']
          });
      }

      res.set({
        'Content-Type': contentType,
        'Content-Disposition': `attachment; filename="${filename}"`
      });

      res.send(exportData);

    } catch (error) {
      logger.error('Erreur export route:', error);
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
          error: 'Coordonnées manquantes ou invalides'
        });
      }

      // Analyser le parcours
      const analysis = await routeGeneratorService.analyzeExistingRoute(coordinates);

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
          segments: analysis.segments
        }
      });

    } catch (error) {
      logger.error('Erreur analyse route:', error);
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
          error: 'Coordonnées manquantes'
        });
      }

      const pois = await routeGeneratorService.findNearbyPOIs(
        parseFloat(lat),
        parseFloat(lon),
        parseInt(radius),
        types?.split(',')
      );

      res.json({
        success: true,
        pois: pois
      });

    } catch (error) {
      logger.error('Erreur récupération POIs:', error);
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
      { distanceKm: params.distanceKm * (0.9 + Math.random() * 0.2) }
    ];

    return {
      ...params,
      ...variations[index % variations.length]
    };
  }

  exportToGPX(coordinates, metadata = {}) {
    const timestamp = new Date().toISOString();
    
    const gpx = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="RunAway" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>${metadata.name || 'RunAway Route'}</name>
    <time>${timestamp}</time>
  </metadata>
  <trk>
    <name>${metadata.name || 'RunAway Route'}</name>
    <trkseg>
${coordinates.map(coord => `      <trkpt lat="${coord[1]}" lon="${coord[0]}">
        ${coord[2] ? `<ele>${coord[2]}</ele>` : ''}
      </trkpt>`).join('\n')}
    </trkseg>
  </trk>
</gpx>`;

    return gpx;
  }

  exportToGeoJSON(coordinates, metadata = {}) {
    return JSON.stringify({
      type: 'Feature',
      properties: metadata,
      geometry: {
        type: 'LineString',
        coordinates: coordinates
      }
    }, null, 2);
  }

  exportToKML(coordinates, metadata = {}) {
    const coordinatesString = coordinates
      .map(coord => `${coord[0]},${coord[1]},${coord[2] || 0}`)
      .join(' ');

    return `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>${metadata.name || 'RunAway Route'}</name>
    <Placemark>
      <name>${metadata.name || 'Route'}</name>
      <LineString>
        <coordinates>${coordinatesString}</coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>`;
  }
}

module.exports = new RouteController();