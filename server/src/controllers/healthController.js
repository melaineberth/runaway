// server/src/controllers/healthController.js
const os = require('os');
const logger = require('../config/logger');
const graphhopperCloud = require('../services/graphhopperCloudService');
const { metricsService } = require('../services/metricsService');

class HealthController {
  /**
   * GET /api/health
   * Vérification basique de santé
   */
  async checkHealth(req, res) {
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      service: 'runaway-api'
    });
  }

  /**
   * GET /api/status
   * Status détaillé du système
   */
  async getStatus(req, res) {
    try {
      // Vérifier GraphHopper Cloud API
      let graphhopperStatus = 'unknown';
      let graphhopperInfo = {};
      
      try {
        const ghHealth = await graphhopperCloud.healthCheck();
        graphhopperStatus = ghHealth.status;
        graphhopperInfo = {
          version: ghHealth.version,
          limits: ghHealth.limits,
          apiUrl: 'https://graphhopper.com/api/1',
          mode: 'cloud'
        };
        
        if (ghHealth.error) {
          graphhopperInfo.error = ghHealth.error;
        }
      } catch (error) {
        graphhopperStatus = 'unhealthy';
        graphhopperInfo.error = error.message;
        logger.error('GraphHopper Cloud health check failed:', error.message);
      }

      // Vérifier Redis si configuré
      let redisStatus = 'not_configured';
      if (process.env.REDIS_URL) {
        // TODO: Implémenter check Redis
        redisStatus = 'healthy';
      }

      // Vérification de l'API key GraphHopper
      let apiKeyStatus = 'not_configured';
      if (process.env.GRAPHHOPPER_API_KEY) {
        apiKeyStatus = process.env.GRAPHHOPPER_API_KEY.length > 10 ? 'configured' : 'invalid';
      }

      // Informations système
      const systemInfo = {
        hostname: os.hostname(),
        platform: os.platform(),
        cpus: os.cpus().length,
        memory: {
          total: Math.round(os.totalmem() / 1024 / 1024 / 1024) + ' GB',
          free: Math.round(os.freemem() / 1024 / 1024 / 1024) + ' GB',
          used: Math.round((os.totalmem() - os.freemem()) / 1024 / 1024 / 1024) + ' GB',
          percentage: Math.round(((os.totalmem() - os.freemem()) / os.totalmem()) * 100) + '%'
        },
        load: os.loadavg(),
        uptime: Math.round(os.uptime() / 60 / 60) + ' hours'
      };

      // Informations sur l'application
      const appInfo = {
        version: process.env.npm_package_version || '1.0.0',
        node_version: process.version,
        environment: process.env.NODE_ENV || 'development',
        pid: process.pid,
        uptime: Math.round(process.uptime() / 60) + ' minutes',
        memory_usage: {
          rss: Math.round(process.memoryUsage().rss / 1024 / 1024) + ' MB',
          heap_total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + ' MB',
          heap_used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + ' MB',
          external: Math.round(process.memoryUsage().external / 1024 / 1024) + ' MB'
        }
      };

      // Déterminer le statut global
      const overallStatus = this.determineOverallStatus({
        api: 'healthy',
        graphhopper: graphhopperStatus,
        apiKey: apiKeyStatus,
        redis: redisStatus
      });

      res.json({
        status: overallStatus,
        timestamp: new Date().toISOString(),
        services: {
          api: 'healthy',
          graphhopper_cloud: {
            status: graphhopperStatus,
            ...graphhopperInfo
          },
          api_key: {
            status: apiKeyStatus
          },
          redis: {
            status: redisStatus
          }
        },
        system: systemInfo,
        application: appInfo
      });

    } catch (error) {
      logger.error('Error getting system status:', error);
      res.status(500).json({
        status: 'error',
        message: 'Failed to retrieve system status',
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * GET /api/readiness
   * Vérification de la disponibilité du service
   */
  async checkReadiness(req, res) {
    try {
      // Vérifier que l'API key est configurée
      if (!process.env.GRAPHHOPPER_API_KEY) {
        return res.status(503).json({
          ready: false,
          reason: 'GraphHopper API key not configured',
          timestamp: new Date().toISOString()
        });
      }

      // Vérifier que GraphHopper Cloud est accessible
      const ghHealth = await graphhopperCloud.healthCheck();

      if (ghHealth.status === 'healthy') {
        res.json({
          ready: true,
          timestamp: new Date().toISOString(),
          graphhopper: {
            status: ghHealth.status,
            version: ghHealth.version
          }
        });
      } else {
        res.status(503).json({
          ready: false,
          reason: `GraphHopper Cloud not ready: ${ghHealth.error || 'unknown error'}`,
          timestamp: new Date().toISOString()
        });
      }
    } catch (error) {
      res.status(503).json({
        ready: false,
        reason: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * GET /api/liveness
   * Vérification que le service est vivant
   */
  async checkLiveness(req, res) {
    res.json({
      alive: true,
      timestamp: new Date().toISOString()
    });
  }

  /**
   * GET /api/graphhopper/limits
   * Informations sur les limites de l'API GraphHopper
   */
  async getGraphHopperLimits(req, res) {
    try {
      const healthInfo = await graphhopperCloud.healthCheck();
      
      if (healthInfo.status === 'healthy' && healthInfo.limits) {
        res.json({
          success: true,
          limits: healthInfo.limits,
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(503).json({
          success: false,
          error: 'GraphHopper API not available',
          timestamp: new Date().toISOString()
        });
      }
    } catch (error) {
      logger.error('Error getting GraphHopper limits:', error);
      res.status(500).json({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * POST /api/test/route
   * Test de génération d'un parcours simple
   */
  async testRoute(req, res) {
    try {
      const { lat = 48.8566, lon = 2.3522 } = req.body; // Paris par défaut

      // Test simple avec un petit parcours
      const testRoute = await graphhopperCloud.getRoute({
        points: [{ lat, lon }],
        profile: 'foot',
        algorithm: 'round_trip',
        roundTripDistance: 1000 // 1km de test
      });

      res.json({
        success: true,
        test_route: {
          distance: testRoute.distance,
          duration: testRoute.duration,
          coordinates_count: testRoute.coordinates.length
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      logger.error('Route test failed:', error);
      res.status(500).json({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * GET /api/metrics
   * Métriques détaillées
   */
  async getMetrics(req, res) {
    try {
      const metrics = metricsService.getMetrics();
      res.json({
        success: true,
        metrics,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('Error getting metrics:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve metrics'
      });
    }
  }

  /**
   * POST /api/metrics/reset
   * Réinitialiser les métriques
   */
  async resetMetrics(req, res) {
    try {
      metricsService.reset();
      res.json({
        success: true,
        message: 'Metrics reset successfully',
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('Error resetting metrics:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to reset metrics'
      });
    }
  }

  /**
   * Détermine le statut global du système
   */
  determineOverallStatus(services) {
    // Obligatoires pour le fonctionnement
    if (services.api !== 'healthy') return 'unhealthy';
    if (services.graphhopper !== 'healthy') return 'degraded';
    if (services.apiKey !== 'configured') return 'degraded';
    
    // Optionnels
    if (services.redis === 'unhealthy') return 'degraded';
    
    return 'operational';
  }
}

module.exports = new HealthController();