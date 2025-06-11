const axios = require('axios');
const os = require('os');
const { logger } = require('../../server');

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
      // Vérifier GraphHopper
      let graphhopperStatus = 'unknown';
      let graphhopperVersion = 'unknown';
      
      try {
        const ghResponse = await axios.get(`${process.env.GRAPHHOPPER_URL}/info`, {
          timeout: 5000
        });
        graphhopperStatus = 'healthy';
        graphhopperVersion = ghResponse.data.version || 'unknown';
      } catch (error) {
        graphhopperStatus = 'unhealthy';
        logger.error('GraphHopper health check failed:', error.message);
      }

      // Vérifier Redis si configuré
      let redisStatus = 'not_configured';
      if (process.env.REDIS_URL) {
        // TODO: Implémenter check Redis
        redisStatus = 'healthy';
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

      res.json({
        status: 'operational',
        timestamp: new Date().toISOString(),
        services: {
          api: 'healthy',
          graphhopper: {
            status: graphhopperStatus,
            version: graphhopperVersion,
            url: process.env.GRAPHHOPPER_URL
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
      // Vérifier que GraphHopper est prêt
      const ghResponse = await axios.get(`${process.env.GRAPHHOPPER_URL}/health`, {
        timeout: 3000
      });

      if (ghResponse.status === 200) {
        res.json({
          ready: true,
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(503).json({
          ready: false,
          reason: 'GraphHopper not ready',
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
}

module.exports = new HealthController();