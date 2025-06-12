// server/src/middleware/requestLogger.js
const logger = require('../config/logger');

class RequestLogger {
  static middleware() {
    return (req, res, next) => {
      const startTime = Date.now();
      const requestId = this.generateRequestId();
      
      // Ajouter l'ID de requête aux headers et au req
      req.requestId = requestId;
      res.setHeader('X-Request-ID', requestId);
      
      // Log de la requête entrante
      logger.info('Request started', {
        requestId,
        method: req.method,
        url: req.url,
        ip: req.ip,
        userAgent: req.get('user-agent'),
        contentType: req.get('content-type'),
        contentLength: req.get('content-length'),
        body: this.sanitizeBody(req.body)
      });
      
      // Intercepter la réponse
      const originalSend = res.send;
      res.send = function(data) {
        const duration = Date.now() - startTime;
        
        logger.info('Request completed', {
          requestId,
          statusCode: res.statusCode,
          duration: `${duration}ms`,
          responseSize: Buffer.byteLength(data, 'utf8'),
          success: res.statusCode < 400
        });
        
        // Log détaillé pour les erreurs
        if (res.statusCode >= 400) {
          logger.error('Request failed', {
            requestId,
            statusCode: res.statusCode,
            error: data,
            duration: `${duration}ms`
          });
        }
        
        originalSend.call(this, data);
      };
      
      next();
    };
  }
  
  static generateRequestId() {
    return `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
  
  static sanitizeBody(body) {
    if (!body) return null;
    
    // Masquer les informations sensibles
    const sanitized = { ...body };
    const sensitiveFields = ['password', 'token', 'apiKey', 'secret'];
    
    sensitiveFields.forEach(field => {
      if (sanitized[field]) {
        sanitized[field] = '***MASKED***';
      }
    });
    
    return sanitized;
  }
}

module.exports = RequestLogger;