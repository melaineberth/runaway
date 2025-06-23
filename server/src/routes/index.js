const express = require('express');
const router = express.Router();
const logger = require('../config/logger');
const RouteValidationMiddleware = require('../middleware/routeValidationMiddleware');
const routeQualityService = require('../services/routeQualityService');

console.log('🔧 routes/index.js est en train de se charger...');

// Contrôleurs
const healthController = require('../controllers/healthController');
const routeController = require('../controllers/routeController');

console.log('🔧 Contrôleurs chargés:', {
  healthController: !!healthController,
  routeController: !!routeController,
  generateSimpleRoute: typeof routeController.generateSimpleRoute
});

// Middlewares
const { metricsMiddleware } = require('../services/metricsService');
const RequestLogger = require('../middleware/requestLogger');

console.log('🔧 Middlewares chargés');

// ============= MIDDLEWARES GLOBAUX =============

// Logging des requêtes
router.use(RequestLogger.middleware());

// Métriques
router.use(metricsMiddleware);

console.log('🔧 Middlewares globaux appliqués');

// ============= ROUTES DE SANTÉ =============

// Health checks
router.get('/health', healthController.checkHealth);
router.get('/status', healthController.getStatus);
router.get('/readiness', healthController.checkReadiness);
router.get('/liveness', healthController.checkLiveness);

// GraphHopper specific health
router.get('/graphhopper/limits', healthController.getGraphHopperLimits);
router.post('/test/route', healthController.testRoute);

console.log('🔧 Routes de santé ajoutées');

// ============= ROUTES DE MÉTRIQUES =============

// Métriques système
router.get('/metrics', healthController.getMetrics);
router.post('/metrics/reset', healthController.resetMetrics);

console.log('🔧 Routes de métriques ajoutées');

// ============= ROUTES DE GÉNÉRATION =============

// ✅ FIX: Génération de parcours avec validation et optimisation complètes
router.post('/routes/generate', 
  RouteValidationMiddleware.validateAndOptimizeParams(),
  RouteValidationMiddleware.validateGenerationResult(),
  routeController.generateRoute // ✅ Appel direct sans wrapper inutile
);

console.log('🔧 Route /routes/generate ajoutée');

// ✅ ROUTE DE DEBUG SIMPLE (sans middlewares complexes)
router.post('/routes/simple-test', (req, res) => {
  console.log('🔧 Route de test /routes/simple-test appelée');
  res.json({ 
    success: true, 
    message: 'Test route works',
    body: req.body 
  });
});

console.log('🔧 Route de test /routes/simple-test ajoutée');

// ✅ ROUTE SIMPLE AVEC LOG DÉTAILLÉ
router.post('/routes/simple', (req, res, next) => {
  console.log('🔧 Route /routes/simple interceptée, body:', req.body);
  console.log('🔧 Appel de routeController.generateSimpleRoute...');
  
  if (typeof routeController.generateSimpleRoute !== 'function') {
    console.log('❌ generateSimpleRoute n\'est pas une fonction!');
    return res.status(500).json({
      success: false,
      error: 'generateSimpleRoute method not found'
    });
  }
  
  routeController.generateSimpleRoute(req, res, next);
});

// Nouvelle route pour validation de qualité d'un parcours existant
router.post('/routes/validate-quality', async (req, res, next) => {
  try {
    const { route, originalParams } = req.body;
    
    if (!route || !route.coordinates || !originalParams) {
      return res.status(400).json({
        success: false,
        error: 'Route et paramètres originaux requis'
      });
    }

    const qualityValidation = routeQualityService.validateRoute(route, originalParams);
    const suggestions = routeQualityService.suggestImprovements(route, originalParams, qualityValidation);
    
    res.json({
      success: true,
      validation: qualityValidation,
      suggestions,
      canAutoFix: qualityValidation.issues.length > 0 && qualityValidation.quality !== 'critical'
    });

  } catch (error) {
    logger.error('Route quality validation failed:', error);
    next(error);
  }
});

// Nouvelle route pour appliquer des corrections automatiques
router.post('/routes/auto-fix', async (req, res, next) => {
  try {
    const { route, originalParams } = req.body;
    
    if (!route || !route.coordinates || !originalParams) {
      return res.status(400).json({
        success: false,
        error: 'Route et paramètres originaux requis'
      });
    }

    const { route: fixedRoute, fixes } = routeQualityService.autoFixRoute(route, originalParams);
    const newValidation = routeQualityService.validateRoute(fixedRoute, originalParams);
    
    res.json({
      success: true,
      fixedRoute,
      appliedFixes: fixes,
      validation: newValidation,
      improvement: fixes.length > 0
    });

  } catch (error) {
    logger.error('Auto-fix failed:', error);
    next(error);
  }
});

console.log('🔧 Route /routes/simple ajoutée avec debug');

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

// Route pour obtenir des paramètres optimisés
router.post('/routes/optimize-params', (req, res, next) => {
  try {
    const { validateRouteParams } = require('../utils/validators');
    const baseValidation = validateRouteParams(req.body);
    if (!baseValidation.valid) {
      return res.status(400).json({
        success: false,
        error: 'Paramètres invalides',
        details: baseValidation.errors
      });
    }

    const optimizedParams = RouteValidationMiddleware.optimizeParameters(baseValidation.value);
    const riskLevel = RouteValidationMiddleware.assessRiskLevel(optimizedParams);
    const appliedOptimizations = RouteValidationMiddleware.getAppliedOptimizations(
      baseValidation.value, 
      optimizedParams
    );

    res.json({
      success: true,
      originalParams: baseValidation.value,
      optimizedParams,
      riskLevel,
      appliedOptimizations,
      recommendations: RouteValidationMiddleware.getRecommendations(optimizedParams)
    });

  } catch (error) {
    logger.error('Parameter optimization failed:', error);
    next(error);
  }
});

// ============= NOUVELLES ROUTES DE MONITORING =============

// Statistiques de qualité des parcours
router.get('/routes/quality-stats', async (req, res, next) => {
  try {
    const { metricsService } = require('../services/metricsService');
    // Récupérer les statistiques depuis les métriques
    const metrics = metricsService.getMetrics();
    
    // Ajouter des statistiques spécifiques à la qualité
    const qualityStats = {
      totalRoutes: metrics.routes.generated,
      successRate: metrics.routes.generated > 0 ? 
        ((metrics.routes.generated - metrics.routes.failed) / metrics.routes.generated * 100).toFixed(1) : 0,
      averageDistance: metrics.routes.averageDistance,
      qualityDistribution: {
        // Ces données seraient collectées dans une implémentation réelle
        excellent: 0,
        good: 0,
        acceptable: 0,
        poor: 0,
        critical: 0
      }
    };

    res.json({
      success: true,
      stats: qualityStats,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('Failed to get quality stats:', error);
    next(error);
  }
});

// Route de test pour différentes stratégies
router.post('/routes/test-strategies', async (req, res, next) => {
  try {
    const { params, strategiesToTest = ['optimized_default', 'controlled_radius'] } = req.body;
    
    const results = [];
    
    for (const strategyName of strategiesToTest) {
      try {
        // Simuler les différentes stratégies
        const testParams = {
          ...params,
          _testStrategy: strategyName,
          requestId: `test_${strategyName}_${Date.now()}`
        };
        
        logger.info(`Testing strategy: ${strategyName}`);
        
        // Ici, dans une implémentation réelle, on appellerait le service avec chaque stratégie
        // Pour cette démonstration, on simule des résultats
        results.push({
          strategy: strategyName,
          success: true,
          simulatedDistance: params.distanceKm * (0.9 + Math.random() * 0.2),
          estimatedQuality: ['excellent', 'good', 'acceptable'][Math.floor(Math.random() * 3)]
        });
        
      } catch (error) {
        results.push({
          strategy: strategyName,
          success: false,
          error: error.message
        });
      }
    }

    res.json({
      success: true,
      testResults: results,
      recommendedStrategy: results.find(r => r.success && r.estimatedQuality === 'excellent')?.strategy || 
                           results.find(r => r.success)?.strategy
    });

  } catch (error) {
    logger.error('Strategy testing failed:', error);
    next(error);
  }
});

console.log('🔧 Toutes les routes sont configurées');

// ✅ FIX: Ajouter la méthode manquante
RouteValidationMiddleware.getRecommendations = function(params) {
  const recommendations = [];
  
  if (params.distanceKm > 30) {
    recommendations.push({
      type: 'long_distance',
      message: 'Pour les longues distances, considérez diviser en segments',
      priority: 'medium'
    });
  }
  
  if (params.elevationGain > 1000) {
    recommendations.push({
      type: 'high_elevation',
      message: 'Dénivelé important, vérifiez la faisabilité',
      priority: 'high'
    });
  }
  
  if (params.distanceKm < 1 && !params.isLoop) {
    recommendations.push({
      type: 'short_distance',
      message: 'Pour les courtes distances, une boucle est recommandée',
      priority: 'low'
    });
  }
  
  return recommendations;
};

module.exports = router;