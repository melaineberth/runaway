// server/src/services/metricsService.js
const EventEmitter = require('events');

class MetricsService extends EventEmitter {
  constructor() {
    super();
    this.metrics = {
      requests: {
        total: 0,
        successful: 0,
        failed: 0,
        byEndpoint: new Map(),
        byStatusCode: new Map()
      },
      routes: {
        generated: 0,
        cached: 0,
        failed: 0,
        averageDistance: 0,
        totalDistance: 0
      },
      graphhopper: {
        apiCalls: 0,
        successful: 0,
        failed: 0,
        averageResponseTime: 0,
        totalResponseTime: 0
      },
      performance: {
        averageRequestTime: 0,
        totalRequestTime: 0,
        slowRequests: 0 // > 5 secondes
      }
    };
    
    this.startTime = Date.now();
  }
  
  recordRequest(endpoint, statusCode, duration) {
    this.metrics.requests.total++;
    
    if (statusCode < 400) {
      this.metrics.requests.successful++;
    } else {
      this.metrics.requests.failed++;
    }
    
    // Par endpoint
    const endpointCount = this.metrics.requests.byEndpoint.get(endpoint) || 0;
    this.metrics.requests.byEndpoint.set(endpoint, endpointCount + 1);
    
    // Par code de statut
    const statusCount = this.metrics.requests.byStatusCode.get(statusCode) || 0;
    this.metrics.requests.byStatusCode.set(statusCode, statusCount + 1);
    
    // Performance
    this.metrics.performance.totalRequestTime += duration;
    this.metrics.performance.averageRequestTime = 
      this.metrics.performance.totalRequestTime / this.metrics.requests.total;
    
    if (duration > 5000) {
      this.metrics.performance.slowRequests++;
    }
    
    this.emit('requestRecorded', { endpoint, statusCode, duration });
  }
  
  recordRouteGeneration(success, distance = 0) {
    if (success) {
      this.metrics.routes.generated++;
      this.metrics.routes.totalDistance += distance;
      this.metrics.routes.averageDistance = 
        this.metrics.routes.totalDistance / this.metrics.routes.generated;
    } else {
      this.metrics.routes.failed++;
    }
    
    this.emit('routeGenerated', { success, distance });
  }
  
  recordGraphHopperCall(success, responseTime) {
    this.metrics.graphhopper.apiCalls++;
    
    if (success) {
      this.metrics.graphhopper.successful++;
    } else {
      this.metrics.graphhopper.failed++;
    }
    
    this.metrics.graphhopper.totalResponseTime += responseTime;
    this.metrics.graphhopper.averageResponseTime = 
      this.metrics.graphhopper.totalResponseTime / this.metrics.graphhopper.apiCalls;
      
    this.emit('graphhopperCall', { success, responseTime });
  }
  
  getMetrics() {
    const uptime = Date.now() - this.startTime;
    
    return {
      ...this.metrics,
      uptime: {
        milliseconds: uptime,
        seconds: Math.floor(uptime / 1000),
        minutes: Math.floor(uptime / 60000),
        hours: Math.floor(uptime / 3600000)
      },
      health: this.calculateHealth()
    };
  }
  
  calculateHealth() {
    const successRate = this.metrics.requests.total > 0 
      ? (this.metrics.requests.successful / this.metrics.requests.total) * 100 
      : 100;
      
    const graphhopperSuccessRate = this.metrics.graphhopper.apiCalls > 0
      ? (this.metrics.graphhopper.successful / this.metrics.graphhopper.apiCalls) * 100
      : 100;
      
    if (successRate >= 95 && graphhopperSuccessRate >= 90) {
      return 'healthy';
    } else if (successRate >= 80 && graphhopperSuccessRate >= 70) {
      return 'degraded';
    } else {
      return 'unhealthy';
    }
  }
  
  reset() {
    Object.keys(this.metrics).forEach(key => {
      if (typeof this.metrics[key] === 'object') {
        Object.keys(this.metrics[key]).forEach(subKey => {
          if (this.metrics[key][subKey] instanceof Map) {
            this.metrics[key][subKey].clear();
          } else {
            this.metrics[key][subKey] = 0;
          }
        });
      }
    });
    
    this.startTime = Date.now();
    this.emit('metricsReset');
  }
}

// Instance globale
const metricsService = new MetricsService();

// Middleware pour enregistrer les métriques
const metricsMiddleware = (req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const endpoint = `${req.method} ${req.route?.path || req.path}`;
    
    metricsService.recordRequest(endpoint, res.statusCode, duration);
  });
  
  next();
};

module.exports = { 
  MetricsService, 
  metricsService, 
  metricsMiddleware
};