// server/src/routes/index.js - Ajout des routes métriques
const express = require('express');
const router = express.Router();
const logger = require('../config/logger');

// Contrôleurs
const healthController = require('../controllers/healthController');
const routeController = require('../controllers/routeController');

// Middlewares
const { metricsMiddleware } = require('../services/metricsService');
const RequestLogger = require('../middleware/requestLogger');

// ============= MIDDLEWARES GLOBAUX =============

// Logging des requêtes
router.use(RequestLogger.middleware());

// Métriques
router.use(metricsMiddleware);

// ============= ROUTES DE SANTÉ =============

// Health checks
router.get('/health', healthController.checkHealth);
router.get('/status', healthController.getStatus);
router.get('/readiness', healthController.checkReadiness);
router.get('/liveness', healthController.checkLiveness);

// GraphHopper specific health
router.get('/graphhopper/limits', healthController.getGraphHopperLimits);
router.post('/test/route', healthController.testRoute);

// ============= ROUTES DE MÉTRIQUES =============

// Métriques système
router.get('/metrics', healthController.getMetrics);
router.post('/metrics/reset', healthController.resetMetrics);

// ============= ROUTES DE GÉNÉRATION =============

// Génération de parcours
router.post('/routes/generate', 
  routeController.generateRoute
);

// Génération de parcours simple
router.post('/routes/simple', 
  routeController.generateSimpleRoute
);

// Génération d'alternatives
router.post('/routes/alternative', 
  routeController.generateAlternatives
);

// ============= ROUTES D'ANALYSE =============

// Analyse d'un parcours existant
router.post('/routes/analyze', 
  routeController.analyzeRoute
);

// ============= ROUTES D'EXPORT =============

// Export de parcours
router.post('/routes/export/:format', 
  routeController.exportRoute
);

// ============= ROUTES D'ÉLÉVATION =============

// Récupération d'élévation pour des points
router.post('/elevation/points', async (req, res, next) => {
  try {
    const { coordinates } = req.body;
    
    if (!coordinates || !Array.isArray(coordinates)) {
      return res.status(400).json({
        error: 'Coordonnées manquantes ou invalides'
      });
    }

    const elevationService = require('../services/elevationService');
    const elevationData = await elevationService.addElevationData(coordinates);
    
    res.json({
      success: true,
      elevations: elevationData
    });

  } catch (error) {
    next(error);
  }
});

// Génération de profil d'élévation
router.post('/elevation/profile', async (req, res, next) => {
  try {
    const { coordinates, sampleDistance = 100 } = req.body;
    
    if (!coordinates || !Array.isArray(coordinates)) {
      return res.status(400).json({
        error: 'Coordonnées manquantes ou invalides'
      });
    }

    const elevationService = require('../services/elevationService');
    const profile = await elevationService.generateElevationProfile(coordinates, sampleDistance);
    const stats = elevationService.calculateElevationStats(profile);
    
    res.json({
      success: true,
      profile,
      statistics: stats
    });

  } catch (error) {
    next(error);
  }
});

// ============= ROUTES UTILITAIRES =============

// Validation de coordonnées
router.post('/utils/validate-coordinates', (req, res) => {
  const { coordinates } = req.body;
  const geoUtils = require('../utils/validators');
  
  if (!coordinates || !Array.isArray(coordinates)) {
    return res.status(400).json({
      valid: false,
      error: 'Coordonnées manquantes ou invalides'
    });
  }

  const validation = geoUtils.validateCoordinates(coordinates);
  res.json(validation);
});

// Calcul de distance entre deux points
router.post('/utils/distance', (req, res) => {
  try {
    const { point1, point2 } = req.body;
    
    if (!point1 || !point2) {
      return res.status(400).json({
        error: 'Points manquants'
      });
    }

    const turf = require('@turf/turf');
    const distance = turf.distance(point1, point2, { units: 'meters' });
    
    res.json({
      success: true,
      distance: Math.round(distance),
      unit: 'meters'
    });

  } catch (error) {
    res.status(400).json({
      error: error.message
    });
  }
});

// Recherche de POI (Points d'Intérêt) via Overpass API
router.post('/poi/search', async (req, res, next) => {
  try {
    const { bbox, types = ['amenity'], radius = 1000 } = req.body;
    
    if (!bbox || bbox.length !== 4) {
      return res.status(400).json({
        error: 'Bounding box invalide (format: [minLon, minLat, maxLon, maxLat])'
      });
    }

    // Simuler une recherche POI (à implémenter avec Overpass API)
    const pois = [
      {
        id: 'example_poi_1',
        name: 'Parc Public',
        type: 'leisure',
        coordinates: [(bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2],
        amenities: ['park', 'playground']
      }
    ];
    
    res.json({
      success: true,
      pois,
      count: pois.length
    });

  } catch (error) {
    next(error);
  }
});

// ============= ROUTES DE CACHE =============

// Statistiques du cache
router.get('/cache/stats', (req, res) => {
  const elevationService = require('../services/elevationService');
  const routeGeneratorService = require('../services/routeGeneratorService');
  
  res.json({
    elevation: elevationService.getCacheStats(),
    routes: {
      size: routeGeneratorService.cache?.size || 0
    }
  });
});

// Nettoyage du cache
router.delete('/cache/clear', (req, res) => {
  const elevationService = require('../services/elevationService');
  
  elevationService.clearCache();
  
  res.json({
    success: true,
    message: 'Cache nettoyé'
  });
});

// ============= GESTION D'ERREURS =============

// Middleware de gestion d'erreurs spécifique aux routes
router.use((error, req, res, next) => {
  logger.error('Route error:', error);
  
  // Erreurs GraphHopper spécifiques
  if (error.message.includes('GraphHopper')) {
    return res.status(503).json({
      error: 'Service de routage temporairement indisponible',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
  
  // Erreurs de validation
  if (error.name === 'ValidationError') {
    return res.status(400).json({
      error: 'Données invalides',
      details: error.message
    });
  }
  
  // Erreurs de timeout
  if (error.code === 'ECONNABORTED' || error.message.includes('timeout')) {
    return res.status(408).json({
      error: 'Requête expirée, veuillez réessayer'
    });
  }
  
  // Erreur générique
  res.status(500).json({
    error: 'Erreur interne du serveur',
    timestamp: new Date().toISOString(),
    ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
  });
});

module.exports = router;