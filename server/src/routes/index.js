const express = require('express');
const router = express.Router();
const logger = require('../config/logger');
const RouteValidationMiddleware = require('../middleware/routeValidationMiddleware');
const GeographicAnalysisMiddleware = require('../middleware/geographicAnalysisMiddleware'); // NOUVEAU
const routeQualityService = require('../services/routeQualityService');

// Contrôleurs
const healthController = require('../controllers/healthController');
const routeController = require('../controllers/routeController');

// Middlewares
const { metricsMiddleware } = require('../services/metricsService');
const RequestLogger = require('../middleware/requestLogger');

// ============= MIDDLEWARES GLOBAUX =============
router.use(RequestLogger.middleware());
router.use(metricsMiddleware);

// ============= ROUTES DE SANTÉ =============
router.get('/health', healthController.checkHealth);
router.get('/status', healthController.getStatus);
router.get('/readiness', healthController.checkReadiness);
router.get('/liveness', healthController.checkLiveness);
router.get('/graphhopper/limits', healthController.getGraphHopperLimits);
router.post('/test/route', healthController.testRoute);

// ============= ROUTES DE MÉTRIQUES =============
router.get('/metrics', healthController.getMetrics);
router.post('/metrics/reset', healthController.resetMetrics);

// ============= ROUTES DE GÉNÉRATION AMÉLIORÉES =============

// ✅ ROUTE PRINCIPALE avec analyse géographique complète
router.post('/routes/generate', 
  // 1. Validation et optimisation de base
  RouteValidationMiddleware.validateAndOptimizeParams(),
  
  // 2. NOUVEAU : Analyse géographique et recommandations de stratégie
  GeographicAnalysisMiddleware.analyzeGeographicContext(),
  
  // 3. Validation et optimisation des résultats
  RouteValidationMiddleware.validateGenerationResult(),
  
  // 4. Génération avec toutes les améliorations
  routeController.generateRoute
);

// ============= ROUTES D'AUTHENTIFICATION =============
const authRoutes = require('./authRoutes');
router.use('/auth', authRoutes);

// ✅ NOUVELLE ROUTE : Analyse préalable de zone
router.post('/routes/analyze-zone', async (req, res, next) => {
  try {
    const { latitude, longitude, distanceKm, activityType } = req.body;
    
    if (!latitude || !longitude) {
      return res.status(400).json({
        success: false,
        error: 'Latitude et longitude requises'
      });
    }

    // Créer un objet de paramètres temporaire pour l'analyse
    const tempParams = {
      startLat: latitude,
      startLon: longitude,
      distanceKm: distanceKm || 5,
      activityType: activityType || 'running'
    };

    // Utiliser le middleware géographique directement
    const geoMiddleware = GeographicAnalysisMiddleware.analyzeGeographicContext();
    
    // Simuler l'exécution du middleware
    req.body = tempParams;
    await new Promise((resolve, reject) => {
      geoMiddleware(req, res, (error) => {
        if (error) reject(error);
        else resolve();
      });
    });

    res.json({
      success: true,
      analysis: req.geographicAnalysis,
      recommendations: req.strategyRecommendations,
      riskAssessment: {
        level: req.geographicAnalysis.riskLevel,
        factors: req.geographicAnalysis.problematicFactors,
        mitigation: req.geographicAnalysis.constraints.map(c => c.mitigation)
      },
      qualityPrediction: {
        expectedComplexity: req.geographicAnalysis.complexityRating,
        routePotential: req.geographicAnalysis.routePotential,
        recommendedStrategies: req.strategyRecommendations.slice(0, 3)
      }
    });

  } catch (error) {
    logger.error('Zone analysis failed:', error);
    next(error);
  }
});

// ✅ NOUVELLE ROUTE : Génération avec stratégie spécifique
router.post('/routes/generate-with-strategy', 
  RouteValidationMiddleware.validateAndOptimizeParams(),
  GeographicAnalysisMiddleware.analyzeGeographicContext(),
  async (req, res, next) => {
    try {
      const { strategy } = req.body;
      
      if (!strategy) {
        return res.status(400).json({
          success: false,
          error: 'Stratégie requise'
        });
      }

      // Forcer l'utilisation de la stratégie spécifiée
      req.validatedParams._forcedStrategy = strategy;
      req.validatedParams._bypassStrategyRecommendations = true;

      logger.info('Forced strategy generation', {
        requestId: req.validatedParams.requestId,
        forcedStrategy: strategy,
        recommendedStrategies: req.strategyRecommendations.map(s => s.name)
      });

      // Continuer avec la génération normale
      return routeController.generateRoute(req, res, next);

    } catch (error) {
      logger.error('Strategy-specific generation failed:', error);
      next(error);
    }
  }
);

// ✅ ROUTE SIMPLE améliorée avec validation minimale
router.post('/routes/simple', (req, res, next) => {
  console.log('🔧 Route /routes/simple interceptée, body:', req.body);
  
  if (typeof routeController.generateSimpleRoute !== 'function') {
    console.log('❌ generateSimpleRoute n\'est pas une fonction!');
    return res.status(500).json({
      success: false,
      error: 'generateSimpleRoute method not found'
    });
  }
  
  routeController.generateSimpleRoute(req, res, next);
});

// ✅ NOUVELLE ROUTE : Comparaison de stratégies
router.post('/routes/compare-strategies', 
  RouteValidationMiddleware.validateAndOptimizeParams(),
  GeographicAnalysisMiddleware.analyzeGeographicContext(),
  async (req, res, next) => {
    try {
      const strategiesToTest = req.body.strategies || req.strategyRecommendations.slice(0, 3).map(s => s.name);
      const results = [];

      logger.info('Strategy comparison started', {
        requestId: req.validatedParams.requestId,
        strategiesToTest: strategiesToTest,
        zoneType: req.geographicAnalysis.zoneType
      });

      for (const strategyName of strategiesToTest) {
        try {
          // Créer une copie des paramètres pour chaque test
          const testParams = {
            ...req.validatedParams,
            _forcedStrategy: strategyName,
            requestId: `compare_${strategyName}_${Date.now()}`
          };

          logger.info(`Testing strategy: ${strategyName}`);
          
          // Dans une implémentation complète, on appellerait vraiment le service
          // Ici on simule pour la démonstration
          const simulatedResult = {
            strategy: strategyName,
            success: true,
            estimatedDistance: testParams.distanceKm * (0.9 + Math.random() * 0.2),
            estimatedQuality: this.simulateQualityScore(strategyName, req.geographicAnalysis),
            confidence: req.strategyRecommendations.find(s => s.name === strategyName)?.confidence || 0.5,
            estimatedGenerationTime: Math.floor(Math.random() * 3000) + 1000
          };

          results.push(simulatedResult);
          
        } catch (error) {
          results.push({
            strategy: strategyName,
            success: false,
            error: error.message
          });
        }
      }

      // Trier par qualité estimée et confiance
      results.sort((a, b) => {
        if (a.success !== b.success) return b.success - a.success;
        if (a.estimatedQuality !== b.estimatedQuality) return b.estimatedQuality - a.estimatedQuality;
        return b.confidence - a.confidence;
      });

      res.json({
        success: true,
        comparison: {
          zoneAnalysis: req.geographicAnalysis,
          testedStrategies: results,
          recommendation: results.find(r => r.success),
          geoFactors: {
            riskLevel: req.geographicAnalysis.riskLevel,
            complexityRating: req.geographicAnalysis.complexityRating,
            zoneType: req.geographicAnalysis.zoneType
          }
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      logger.error('Strategy comparison failed:', error);
      next(error);
    }
  }
);

// Méthode utilitaire pour simuler le score de qualité
router.simulateQualityScore = function(strategyName, geoAnalysis) {
  const baseScores = {
    'organic_natural': 0.8,
    'organic_balanced': 0.7,
    'controlled_multi_waypoint': 0.6,
    'enhanced_traditional': 0.5,
    'organic_conservative': 0.6
  };

  let score = baseScores[strategyName] || 0.5;

  // Ajustements basés sur l'analyse géographique
  if (geoAnalysis.riskLevel === 'high' && strategyName.includes('organic')) {
    score += 0.1; // Les stratégies organiques sont meilleures en zone à risque
  }

  if (geoAnalysis.complexityRating < 0.3 && strategyName === 'organic_natural') {
    score += 0.15; // Stratégie naturelle excellente pour zones simples
  }

  if (geoAnalysis.zoneType === 'urban_dense' && strategyName.includes('waypoint')) {
    score += 0.05; // Multi-waypoints bon en ville dense
  }

  return Math.max(0.3, Math.min(1.0, score));
};

// ============= ROUTES D'ANALYSE QUALITÉ =============

// Validation de qualité d'un parcours existant
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
      canAutoFix: qualityValidation.issues.length > 0 && qualityValidation.quality !== 'critical',
      qualityBreakdown: {
        overall: qualityValidation.quality,
        distance: qualityValidation.metrics.distance?.grade || 'unknown',
        aesthetics: qualityValidation.metrics.aesthetics?.score || 0,
        complexity: qualityValidation.metrics.complexity?.score || 0,
        interest: qualityValidation.metrics.interest?.score || 0
      }
    });

  } catch (error) {
    logger.error('Route quality validation failed:', error);
    next(error);
  }
});

// Application de corrections automatiques
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
      improvement: fixes.length > 0,
      qualityImprovement: {
        before: route.metadata?.quality || 'unknown',
        after: newValidation.quality,
        improved: newValidation.quality !== route.metadata?.quality
      }
    });

  } catch (error) {
    logger.error('Auto-fix failed:', error);
    next(error);
  }
});

// ============= ROUTES EXISTANTES CONSERVÉES =============

// Génération d'alternatives
router.post('/routes/alternative', routeController.generateAlternatives);

// Analyse d'un parcours existant
router.post('/routes/analyze', routeController.analyzeRoute);

// Export de parcours
router.post('/routes/export/:format', routeController.exportRoute);

// ============= NOUVELLES ROUTES UTILITAIRES =============

// Statistiques de qualité des parcours générés
router.get('/routes/quality-stats', async (req, res, next) => {
  try {
    const { metricsService } = require('../services/metricsService');
    const metrics = metricsService.getMetrics();
    
    const qualityStats = {
      totalRoutes: metrics.routes.generated,
      successRate: metrics.routes.generated > 0 ? 
        ((metrics.routes.generated - metrics.routes.failed) / metrics.routes.generated * 100).toFixed(1) : 0,
      averageDistance: metrics.routes.averageDistance,
      qualityDistribution: {
        excellent: 0, // Ces données seraient collectées dans une implémentation réelle
        good: 0,
        acceptable: 0,
        poor: 0,
        critical: 0
      },
      geographicBreakdown: {
        // Simulation de données géographiques
        urban_dense: Math.floor(metrics.routes.generated * 0.3),
        urban_sparse: Math.floor(metrics.routes.generated * 0.25),
        suburban: Math.floor(metrics.routes.generated * 0.25),
        rural: Math.floor(metrics.routes.generated * 0.2)
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

// Test de résistance pour différentes zones géographiques
router.post('/routes/stress-test-zone', async (req, res, next) => {
  try {
    const { coordinates, testCount = 5 } = req.body;
    
    if (!coordinates || coordinates.length !== 2) {
      return res.status(400).json({
        success: false,
        error: 'Coordonnées [latitude, longitude] requises'
      });
    }

    const [latitude, longitude] = coordinates;
    const results = [];
    
    // Tester différentes distances et activités
    const testCases = [
      { distance: 2, activity: 'running' },
      { distance: 5, activity: 'running' },
      { distance: 10, activity: 'running' },
      { distance: 15, activity: 'cycling' },
      { distance: 25, activity: 'cycling' }
    ];

    for (const testCase of testCases) {
      for (let i = 0; i < testCount; i++) {
        try {
          const testParams = {
            startLat: latitude,
            startLon: longitude,
            distanceKm: testCase.distance,
            activityType: testCase.activity,
            requestId: `stress_test_${testCase.distance}km_${testCase.activity}_${i}`
          };

          // Analyser la zone
          req.body = testParams;
          const geoMiddleware = GeographicAnalysisMiddleware.analyzeGeographicContext();
          
          await new Promise((resolve, reject) => {
            geoMiddleware(req, {}, (error) => {
              if (error) reject(error);
              else resolve();
            });
          });

          results.push({
            testCase,
            attempt: i + 1,
            success: true,
            riskLevel: req.geographicAnalysis.riskLevel,
            complexityRating: req.geographicAnalysis.complexityRating,
            recommendedStrategy: req.strategyRecommendations[0]?.name || 'unknown',
            confidence: req.strategyRecommendations[0]?.confidence || 0
          });

        } catch (error) {
          results.push({
            testCase,
            attempt: i + 1,
            success: false,
            error: error.message
          });
        }
      }
    }

    // Analyser les résultats
    const analysis = this.analyzeStressTestResults(results);

    res.json({
      success: true,
      stressTest: {
        coordinates: coordinates,
        testCount: testCount,
        results: results,
        analysis: analysis
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('Stress test failed:', error);
    next(error);
  }
});

// Méthode d'analyse des résultats de stress test
router.analyzeStressTestResults = function(results) {
  const successful = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);
  
  const riskDistribution = {};
  const strategyDistribution = {};
  
  successful.forEach(result => {
    riskDistribution[result.riskLevel] = (riskDistribution[result.riskLevel] || 0) + 1;
    strategyDistribution[result.recommendedStrategy] = (strategyDistribution[result.recommendedStrategy] || 0) + 1;
  });

  return {
    successRate: (successful.length / results.length * 100).toFixed(1),
    totalTests: results.length,
    successful: successful.length,
    failed: failed.length,
    riskDistribution,
    strategyDistribution,
    averageComplexity: successful.length > 0 ? 
      (successful.reduce((sum, r) => sum + r.complexityRating, 0) / successful.length).toFixed(2) : 0,
    averageConfidence: successful.length > 0 ? 
      (successful.reduce((sum, r) => sum + r.confidence, 0) / successful.length).toFixed(2) : 0,
    recommendations: this.generateZoneRecommendations(riskDistribution, strategyDistribution)
  };
};

// Génération de recommandations basées sur les tests
router.generateZoneRecommendations = function(riskDistribution, strategyDistribution) {
  const recommendations = [];
  
  const highRiskRatio = (riskDistribution.high || 0) / Object.values(riskDistribution).reduce((a, b) => a + b, 1);
  
  if (highRiskRatio > 0.6) {
    recommendations.push({
      type: 'high_risk_zone',
      message: 'Cette zone présente un risque élevé de génération de parcours monotones',
      suggestion: 'Utiliser prioritairement les stratégies organiques'
    });
  }

  const topStrategy = Object.keys(strategyDistribution).reduce((a, b) => 
    strategyDistribution[a] > strategyDistribution[b] ? a : b, 'unknown');
  
  if (topStrategy !== 'unknown') {
    recommendations.push({
      type: 'optimal_strategy',
      message: `Stratégie recommandée pour cette zone: ${topStrategy}`,
      suggestion: `Cette stratégie a été recommandée dans ${strategyDistribution[topStrategy]} tests`
    });
  }

  return recommendations;
};

// ============= ROUTES D'ÉLÉVATION ET AUTRES (conservées) =============

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

// ============= GESTION D'ERREURS =============

router.use((error, req, res, next) => {
  logger.error('Enhanced route error:', error);
  
  if (error.message.includes('GraphHopper')) {
    return res.status(503).json({
      error: 'Service de routage temporairement indisponible',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
  
  if (error.name === 'ValidationError') {
    return res.status(400).json({
      error: 'Données invalides',
      details: error.message
    });
  }
  
  if (error.code === 'ECONNABORTED' || error.message.includes('timeout')) {
    return res.status(408).json({
      error: 'Requête expirée, veuillez réessayer'
    });
  }
  
  res.status(500).json({
    error: 'Erreur interne du serveur',
    timestamp: new Date().toISOString(),
    ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
  });
});

console.log('🔧 Routes enrichies avec analyse géographique et génération organique configurées');

module.exports = router;