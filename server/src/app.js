const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const routes = require('./routes');

// ✅ NOUVEAUX SERVICES intégrés
const { monitoringMiddleware } = require('./services/routeMonitoringService');
const logger = require('./config/logger');

const app = express();

// ============= CONFIGURATION AVANCÉE =============

// Configuration Helmet avec optimisations pour les API de routage
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"], // ✅ Autoriser scripts inline
      styleSrc: ["'self'", "'unsafe-inline'"],  // ✅ Pour les styles aussi
      connectSrc: ["'self'", "https://graphhopper.com", "https://api.open-elevation.com"],
    },
  },
  crossOriginEmbedderPolicy: false, // Désactiver pour compatibilité mobile
}));

// Compression avec configuration optimisée
app.use(compression({
  level: 6, // Bon compromis entre vitesse et compression
  threshold: 1024, // Compresser seulement > 1KB
  filter: (req, res) => {
    // Ne pas compresser les réponses déjà compressées
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  }
}));

// CORS optimisé avec gestion dynamique des origines
app.use(cors({
  origin: (origin, callback) => {
    // Autoriser les requêtes sans origine (mobile apps)
    if (!origin) return callback(null, true);
    
    const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || ['*'];
    
    // En développement, autoriser localhost avec différents ports
    if (process.env.NODE_ENV === 'development') {
      if (origin.includes('localhost') || origin.includes('127.0.0.1')) {
        return callback(null, true);
      }
    }
    
    // Vérifier la liste des origines autorisées
    if (allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Origin'],
  exposedHeaders: ['X-Request-ID', 'X-Response-Time']
}));

// ============= PARSING ET SÉCURITÉ =============

// Parser JSON avec limites et validation
app.use(express.json({ 
  limit: '10mb',
  verify: (req, res, buf, encoding) => {
    // Validation basique du JSON pour éviter les attaques
    if (buf.length > 10 * 1024 * 1024) { // 10MB
      throw new Error('Request too large');
    }
  }
}));

app.use(express.urlencoded({ 
  extended: true, 
  limit: '10mb',
  parameterLimit: 1000 // Limiter le nombre de paramètres
}));

// ============= MIDDLEWARES DE PERFORMANCE =============

// Middleware de timeout pour éviter les requêtes qui traînent
app.use((req, res, next) => {
  // Timeout adaptatif selon le type de requête
  let timeout = 30000; // 30s par défaut
  
  if (req.path.includes('/routes/generate')) {
    timeout = 60000; // 60s pour la génération de routes
  } else if (req.path.includes('/routes/analyze')) {
    timeout = 45000; // 45s pour l'analyse
  } else if (req.path.includes('/elevation')) {
    timeout = 30000; // 30s pour l'élévation
  }
  
  req.setTimeout(timeout, () => {
    logger.warn('Request timeout', {
      path: req.path,
      method: req.method,
      timeout: timeout,
      ip: req.ip
    });
    
    if (!res.headersSent) {
      res.status(408).json({
        success: false,
        error: 'Request timeout',
        details: 'La requête a pris trop de temps à traiter'
      });
    }
  });
  
  next();
});

// ✅ MIDDLEWARE DE MONITORING (NOUVEAU)
app.use(monitoringMiddleware);

// Middleware de logging des requêtes avec optimisations
app.use((req, res, next) => {
  const startTime = Date.now();
  const requestId = `req_${Date.now()}_${Math.random().toString(36).substr(2, 8)}`;
  
  // Ajouter l'ID de requête
  req.requestId = requestId;
  res.setHeader('X-Request-ID', requestId);
  
  // Log initial (seulement pour les routes importantes)
  if (req.path.includes('/routes/') || req.path.includes('/analyze')) {
    logger.info('Request started', {
      requestId: requestId,
      method: req.method,
      path: req.path,
      ip: req.ip,
      userAgent: req.get('user-agent')?.substr(0, 100), // Limiter pour éviter les logs trop longs
      contentLength: req.get('content-length')
    });
  }
  
  // Intercepter la réponse pour logging et métriques
  const originalSend = res.send;
  res.send = function(data) {
    const duration = Date.now() - startTime;
    res.setHeader('X-Response-Time', `${duration}ms`);
    
    // Log de la réponse (seulement pour routes importantes ou erreurs)
    if (req.path.includes('/routes/') || req.path.includes('/analyze') || res.statusCode >= 400) {
      const logLevel = res.statusCode >= 400 ? 'warn' : 'info';
      logger[logLevel]('Request completed', {
        requestId: requestId,
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        duration: `${duration}ms`,
        responseSize: Buffer.isBuffer(data) ? data.length : (typeof data === 'string' ? data.length : JSON.stringify(data).length),
        success: res.statusCode < 400
      });
    }
    
    originalSend.call(this, data);
  };
  
  next();
});

// ============= MIDDLEWARE DE CACHE INTELLIGENT =============

// Cache simple en mémoire pour les réponses statiques
const cache = new Map();
const CACHE_TTL = 300000; // 5 minutes

app.use((req, res, next) => {
  // Cacher seulement les GET et certaines routes
  if (req.method !== 'GET' || 
      req.path.includes('/health') || 
      req.path.includes('/status') ||
      req.path.includes('/metrics')) {
    return next();
  }
  
  const cacheKey = `${req.method}:${req.path}:${JSON.stringify(req.query)}`;
  const cached = cache.get(cacheKey);
  
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    res.setHeader('X-Cache', 'HIT');
    res.setHeader('X-Cache-TTL', Math.round((CACHE_TTL - (Date.now() - cached.timestamp)) / 1000));
    return res.json(cached.data);
  }
  
  // Intercepter la réponse pour mise en cache
  const originalJson = res.json;
  res.json = function(data) {
    // Cacher seulement les réponses 200
    if (res.statusCode === 200 && data) {
      cache.set(cacheKey, {
        data: data,
        timestamp: Date.now()
      });
      
      // Nettoyer le cache périodiquement
      if (cache.size > 100) {
        const oldEntries = Array.from(cache.entries())
          .filter(([key, value]) => Date.now() - value.timestamp > CACHE_TTL);
        oldEntries.forEach(([key]) => cache.delete(key));
      }
    }
    
    res.setHeader('X-Cache', 'MISS');
    originalJson.call(this, data);
  };
  
  next();
});

// ============= ROUTES PRINCIPALES =============

// Monter les routes APRÈS tous les middlewares
app.use('/api', routes);

// ============= ROUTES DE MONITORING (NOUVELLES) =============

// ✅ Route de statut de monitoring détaillé
app.get('/api/monitoring/status', (req, res) => {
  try {
    const { routeMonitoringService } = require('./services/routeMonitoringService');
    const status = routeMonitoringService.getMonitoringStatus();
    
    res.json({
      success: true,
      monitoring: status,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Failed to get monitoring status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve monitoring status'
    });
  }
});

// ✅ Route d'export des métriques
app.get('/api/monitoring/export/:format?', (req, res) => {
  try {
    const { format = 'json' } = req.params;
    const { routeMonitoringService } = require('./services/routeMonitoringService');
    
    const data = routeMonitoringService.exportMetrics(format);
    
    if (format === 'csv') {
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename="route-metrics-${Date.now()}.csv"`);
      res.send(data);
    } else {
      res.json({
        success: true,
        format: format,
        data: JSON.parse(data)
      });
    }
  } catch (error) {
    logger.error('Failed to export metrics:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to export metrics'
    });
  }
});

// ✅ Route d'acquittement d'alertes
app.post('/api/monitoring/alerts/:alertId/acknowledge', (req, res) => {
  try {
    const { alertId } = req.params;
    const { userId = 'api_user' } = req.body;
    
    const { routeMonitoringService } = require('./services/routeMonitoringService');
    const acknowledged = routeMonitoringService.acknowledgeAlert(alertId, userId);
    
    if (acknowledged) {
      res.json({
        success: true,
        message: 'Alert acknowledged successfully'
      });
    } else {
      res.status(404).json({
        success: false,
        error: 'Alert not found or already acknowledged'
      });
    }
  } catch (error) {
    logger.error('Failed to acknowledge alert:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to acknowledge alert'
    });
  }
});

// ============= ROUTES DE SANTÉ AVANCÉES =============

// Health check enrichi avec informations de monitoring
app.get('/api/health/detailed', (req, res) => {
  try {
    const { routeMonitoringService } = require('./services/routeMonitoringService');
    const monitoringStatus = routeMonitoringService.getMonitoringStatus();
    
    const healthInfo = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: {
        used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
        total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        external: Math.round(process.memoryUsage().external / 1024 / 1024)
      },
      monitoring: {
        overall: monitoringStatus.overall,
        activeAlerts: monitoringStatus.alerts.active,
        qualityScore: monitoringStatus.currentHour.qualityScore,
        recentProblems: monitoringStatus.patterns.recentProblems
      },
      services: {
        graphhopper: process.env.GRAPHHOPPER_API_KEY ? 'configured' : 'not_configured',
        monitoring: 'active',
        cache: 'active'
      }
    };

    // Ajuster le statut selon les alertes critiques
    if (monitoringStatus.alerts.critical > 0) {
      healthInfo.status = 'degraded';
    }
    if (monitoringStatus.overall === 'critical') {
      healthInfo.status = 'unhealthy';
    }

    res.json(healthInfo);
  } catch (error) {
    logger.error('Detailed health check failed:', error);
    res.status(500).json({
      status: 'error',
      error: 'Health check failed'
    });
  }
});

// ============= GESTION D'ERREURS AVANCÉE =============

// Middleware pour les routes non trouvées
app.use((req, res) => {
  logger.warn('Route not found', {
    method: req.method,
    path: req.path,
    ip: req.ip,
    userAgent: req.get('user-agent')
  });
  
  res.status(404).json({ 
    success: false,
    error: 'Route not found',
    path: req.path,
    method: req.method,
    availableEndpoints: [
      'GET /api/health',
      'GET /api/status', 
      'POST /api/routes/generate',
      'POST /api/routes/simple',
      'GET /api/monitoring/status'
    ]
  });
});

// Gestionnaire d'erreurs global amélioré
app.use((err, req, res, next) => {
  const requestId = req.requestId || 'unknown';
  
  // Log détaillé de l'erreur
  logger.error('Unhandled application error', {
    requestId: requestId,
    error: err.message,
    stack: err.stack,
    method: req.method,
    path: req.path,
    ip: req.ip,
    userAgent: req.get('user-agent'),
    body: process.env.NODE_ENV === 'development' ? req.body : '[hidden]'
  });

  // Réponse d'erreur sécurisée
  const errorResponse = {
    success: false,
    error: 'Internal server error',
    requestId: requestId,
    timestamp: new Date().toISOString()
  };

  // Ajouter des détails en développement
  if (process.env.NODE_ENV === 'development') {
    errorResponse.details = {
      message: err.message,
      stack: err.stack?.split('\n').slice(0, 5) // Limiter la stack trace
    };
  }

  // Gestion spécifique selon le type d'erreur
  if (err.name === 'ValidationError') {
    errorResponse.error = 'Validation failed';
    return res.status(400).json(errorResponse);
  }

  if (err.message.includes('timeout')) {
    errorResponse.error = 'Request timeout';
    return res.status(408).json(errorResponse);
  }

  if (err.message.includes('Not allowed by CORS')) {
    errorResponse.error = 'CORS policy violation';
    return res.status(403).json(errorResponse);
  }

  // Erreur générique
  res.status(err.status || 500).json(errorResponse);
});

// ============= OPTIMISATIONS FINALES =============

// Configuration pour éviter les attaques de slowloris
app.use((req, res, next) => {
  res.setTimeout(120000, () => { // 2 minutes max
    logger.warn('Response timeout', {
      requestId: req.requestId,
      path: req.path,
      method: req.method
    });
    
    if (!res.headersSent) {
      res.status(408).json({
        success: false,
        error: 'Response timeout'
      });
    }
  });
  next();
});

// Middleware de nettoyage périodique
let lastCleanup = Date.now();
app.use((req, res, next) => {
  // Nettoyage léger toutes les 10 minutes
  if (Date.now() - lastCleanup > 600000) {
    if (global.gc) {
      global.gc(); // Force garbage collection si disponible
    }
    lastCleanup = Date.now();
    logger.debug('Periodic cleanup performed');
  }
  next();
});

// Logging de démarrage
logger.info('Enhanced RunAway API configured', {
  environment: process.env.NODE_ENV || 'development',
  monitoring: 'enabled',
  caching: 'enabled',
  graphhopperConfigured: !!process.env.GRAPHHOPPER_API_KEY,
  features: [
    'organic_route_generation',
    'geographic_analysis', 
    'problem_prevention',
    'quality_monitoring',
    'intelligent_retry',
    'performance_optimization'
  ]
});

console.log('🚀 Enhanced RunAway API fully configured with:');
console.log('   ✅ Organic route generation');
console.log('   ✅ Geographic analysis');
console.log('   ✅ Problem prevention');
console.log('   ✅ Quality monitoring');
console.log('   ✅ Intelligent caching');
console.log('   ✅ Advanced error handling');
console.log('   ✅ Performance optimization');

module.exports = app;