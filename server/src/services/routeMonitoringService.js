const logger = require('../config/logger');
const { EventEmitter } = require('events');

class RouteMonitoringService extends EventEmitter {
  constructor() {
    super();
    
    // Métriques de qualité en temps réel
    this.qualityMetrics = {
      currentHour: {
        total: 0,
        excellent: 0,
        good: 0,
        acceptable: 0,
        poor: 0,
        critical: 0,
        problematic: 0,
        avgProcessingTime: 0,
        totalProcessingTime: 0
      },
      last24Hours: [],
      trends: {
        qualityTrend: 'stable', // improving, degrading, stable
        performanceTrend: 'stable',
        problemFrequency: 'normal' // low, normal, high, critical
      }
    };

    // Alertes actives
    this.activeAlerts = new Map();
    
    // Seuils d'alerte
    this.alertThresholds = {
      criticalRouteRate: 0.15,      // >15% de routes critiques
      poorRouteRate: 0.30,          // >30% de routes poor/critical
      problematicRouteRate: 0.20,   // >20% de routes problématiques
      avgProcessingTime: 10000,     // >10s de temps de traitement
      failureRate: 0.10,            // >10% d'échecs
      consecutiveFailures: 3         // 3 échecs consécutifs
    };

    // Statistiques par zone géographique
    this.geographicStats = new Map();
    
    // Compteurs pour détection de patterns
    this.patternCounters = {
      consecutiveFailures: 0,
      straightLineRoutes: 0,
      geometricRoutes: 0,
      lastHourProblems: []
    };

    // Initialiser le cycle de nettoyage
    this.startCleanupCycle();
    
    logger.info('Route Monitoring Service initialized');
  }

  /**
   * Enregistre une route générée pour monitoring
   */
  recordRouteGeneration(routeData) {
    try {
      const {
        success,
        route,
        metadata,
        processingTime,
        qualityInfo,
        problems,
        geoAnalysis
      } = routeData;

      const currentHour = this.qualityMetrics.currentHour;
      currentHour.total++;
      currentHour.totalProcessingTime += processingTime;
      currentHour.avgProcessingTime = currentHour.totalProcessingTime / currentHour.total;

      if (success && route) {
        // Enregistrer la qualité
        const quality = qualityInfo?.overallQuality || metadata?.quality?.overall || 'unknown';
        if (currentHour[quality] !== undefined) {
          currentHour[quality]++;
        }

        // Enregistrer les problèmes détectés
        if (problems?.detected) {
          currentHour.problematic++;
          this.recordProblems(problems, geoAnalysis);
        }

        // Enregistrer les statistiques géographiques
        if (geoAnalysis) {
          this.recordGeographicStats(geoAnalysis, quality, problems?.detected || false);
        }

        // Réinitialiser le compteur d'échecs consécutifs
        this.patternCounters.consecutiveFailures = 0;

        logger.debug('Route generation recorded', {
          quality: quality,
          processingTime: processingTime,
          hasProblems: problems?.detected || false,
          zoneType: geoAnalysis?.zoneType
        });

      } else {
        // Enregistrer l'échec
        this.recordFailure(routeData);
      }

      // Vérifier les seuils d'alerte
      this.checkAlertThresholds();

      // Émettre l'événement pour les listeners
      this.emit('routeRecorded', {
        success,
        quality: qualityInfo?.overallQuality,
        processingTime,
        problems: problems?.detected
      });

    } catch (error) {
      logger.error('Failed to record route generation:', error);
    }
  }

  /**
   * Enregistre les problèmes détectés
   */
  recordProblems(problems, geoAnalysis) {
    const now = Date.now();
    
    problems.types?.forEach(problemType => {
      // Compter les types de problèmes spécifiques
      if (problemType === 'straight_line_pattern') {
        this.patternCounters.straightLineRoutes++;
      }
      if (problemType === 'geometric_pattern') {
        this.patternCounters.geometricRoutes++;
      }

      // Ajouter à l'historique des problèmes de la dernière heure
      this.patternCounters.lastHourProblems.push({
        type: problemType,
        timestamp: now,
        severity: problems.severity,
        zoneType: geoAnalysis?.zoneType
      });
    });

    // Nettoyer l'historique (garder seulement la dernière heure)
    this.patternCounters.lastHourProblems = this.patternCounters.lastHourProblems
      .filter(p => now - p.timestamp < 3600000); // 1 heure
  }

  /**
   * Enregistre les statistiques géographiques
   */
  recordGeographicStats(geoAnalysis, quality, hasProblems) {
    const zoneType = geoAnalysis.zoneType;
    
    if (!this.geographicStats.has(zoneType)) {
      this.geographicStats.set(zoneType, {
        total: 0,
        qualityDistribution: { excellent: 0, good: 0, acceptable: 0, poor: 0, critical: 0 },
        problemRate: 0,
        avgComplexity: 0,
        totalComplexity: 0,
        riskDistribution: { low: 0, medium: 0, high: 0 }
      });
    }

    const stats = this.geographicStats.get(zoneType);
    stats.total++;
    
    if (stats.qualityDistribution[quality]) {
      stats.qualityDistribution[quality]++;
    }

    if (hasProblems) {
      stats.problemRate = ((stats.problemRate * (stats.total - 1)) + 1) / stats.total;
    } else {
      stats.problemRate = (stats.problemRate * (stats.total - 1)) / stats.total;
    }

    // Complexité moyenne
    if (geoAnalysis.complexityRating !== undefined) {
      stats.totalComplexity += geoAnalysis.complexityRating;
      stats.avgComplexity = stats.totalComplexity / stats.total;
    }

    // Distribution des risques
    if (stats.riskDistribution[geoAnalysis.riskLevel]) {
      stats.riskDistribution[geoAnalysis.riskLevel]++;
    }
  }

  /**
   * Enregistre un échec de génération
   */
  recordFailure(failureData) {
    this.patternCounters.consecutiveFailures++;
    
    logger.warn('Route generation failure recorded', {
      consecutiveFailures: this.patternCounters.consecutiveFailures,
      error: failureData.error,
      geoAnalysis: failureData.geoAnalysis
    });

    // Vérifier si on atteint le seuil d'échecs consécutifs
    if (this.patternCounters.consecutiveFailures >= this.alertThresholds.consecutiveFailures) {
      this.triggerAlert('consecutive_failures', {
        count: this.patternCounters.consecutiveFailures,
        lastError: failureData.error
      });
    }
  }

  /**
   * Vérifie les seuils d'alerte
   */
  checkAlertThresholds() {
    const current = this.qualityMetrics.currentHour;
    
    if (current.total < 10) return; // Pas assez de données

    // Taux de routes critiques
    const criticalRate = current.critical / current.total;
    if (criticalRate > this.alertThresholds.criticalRouteRate) {
      this.triggerAlert('high_critical_rate', {
        rate: criticalRate,
        count: current.critical,
        total: current.total
      });
    }

    // Taux de routes poor + critical
    const poorRate = (current.poor + current.critical) / current.total;
    if (poorRate > this.alertThresholds.poorRouteRate) {
      this.triggerAlert('high_poor_rate', {
        rate: poorRate,
        poorCount: current.poor,
        criticalCount: current.critical,
        total: current.total
      });
    }

    // Taux de routes problématiques
    const problematicRate = current.problematic / current.total;
    if (problematicRate > this.alertThresholds.problematicRouteRate) {
      this.triggerAlert('high_problematic_rate', {
        rate: problematicRate,
        count: current.problematic,
        total: current.total
      });
    }

    // Temps de traitement moyen
    if (current.avgProcessingTime > this.alertThresholds.avgProcessingTime) {
      this.triggerAlert('slow_processing', {
        avgTime: current.avgProcessingTime,
        threshold: this.alertThresholds.avgProcessingTime
      });
    }

    // Patterns problématiques spécifiques
    if (this.patternCounters.straightLineRoutes > 5) {
      this.triggerAlert('frequent_straight_lines', {
        count: this.patternCounters.straightLineRoutes
      });
    }

    if (this.patternCounters.geometricRoutes > 3) {
      this.triggerAlert('frequent_geometric_routes', {
        count: this.patternCounters.geometricRoutes
      });
    }
  }

  /**
   * Déclenche une alerte
   */
  triggerAlert(alertType, details) {
    const alertId = `${alertType}_${Date.now()}`;
    const alert = {
      id: alertId,
      type: alertType,
      severity: this.getAlertSeverity(alertType),
      message: this.generateAlertMessage(alertType, details),
      details: details,
      timestamp: new Date(),
      acknowledged: false,
      autoResolved: false
    };

    // Éviter les doublons d'alertes
    const existingAlert = Array.from(this.activeAlerts.values())
      .find(a => a.type === alertType && !a.acknowledged && !a.autoResolved);

    if (existingAlert) {
      // Mettre à jour l'alerte existante
      existingAlert.details = details;
      existingAlert.timestamp = new Date();
      logger.debug(`Updated existing alert: ${alertType}`);
      return;
    }

    this.activeAlerts.set(alertId, alert);

    logger.warn('Alert triggered', {
      alertId: alertId,
      type: alertType,
      severity: alert.severity,
      details: details
    });

    // Émettre l'événement d'alerte
    this.emit('alertTriggered', alert);

    // Auto-résolution programmée pour certains types d'alertes
    if (this.shouldAutoResolve(alertType)) {
      setTimeout(() => {
        this.autoResolveAlert(alertId);
      }, this.getAutoResolveDelay(alertType));
    }
  }

  /**
   * Génère le message d'alerte
   */
  generateAlertMessage(alertType, details) {
    switch (alertType) {
      case 'high_critical_rate':
        return `Taux élevé de routes critiques: ${(details.rate * 100).toFixed(1)}% (${details.count}/${details.total})`;
      
      case 'high_poor_rate':
        return `Taux élevé de routes de mauvaise qualité: ${(details.rate * 100).toFixed(1)}%`;
      
      case 'high_problematic_rate':
        return `Taux élevé de routes problématiques: ${(details.rate * 100).toFixed(1)}%`;
      
      case 'slow_processing':
        return `Temps de traitement lent: ${Math.round(details.avgTime)}ms (seuil: ${details.threshold}ms)`;
      
      case 'consecutive_failures':
        return `${details.count} échecs consécutifs de génération`;
      
      case 'frequent_straight_lines':
        return `${details.count} routes en ligne droite détectées récemment`;
      
      case 'frequent_geometric_routes':
        return `${details.count} routes géométriques détectées récemment`;
      
      default:
        return `Alerte ${alertType}`;
    }
  }

  /**
   * Détermine la sévérité de l'alerte
   */
  getAlertSeverity(alertType) {
    const severityMap = {
      'high_critical_rate': 'critical',
      'consecutive_failures': 'critical',
      'high_poor_rate': 'high',
      'high_problematic_rate': 'high',
      'slow_processing': 'medium',
      'frequent_straight_lines': 'medium',
      'frequent_geometric_routes': 'medium'
    };

    return severityMap[alertType] || 'low';
  }

  /**
   * Détermine si l'alerte doit être auto-résolue
   */
  shouldAutoResolve(alertType) {
    const autoResolveTypes = [
      'slow_processing',
      'frequent_straight_lines',
      'frequent_geometric_routes'
    ];
    return autoResolveTypes.includes(alertType);
  }

  /**
   * Délai d'auto-résolution
   */
  getAutoResolveDelay(alertType) {
    const delays = {
      'slow_processing': 300000,        // 5 minutes
      'frequent_straight_lines': 600000, // 10 minutes
      'frequent_geometric_routes': 600000 // 10 minutes
    };
    return delays[alertType] || 300000;
  }

  /**
   * Auto-résout une alerte
   */
  autoResolveAlert(alertId) {
    const alert = this.activeAlerts.get(alertId);
    if (alert && !alert.acknowledged) {
      alert.autoResolved = true;
      alert.resolvedAt = new Date();
      
      logger.info(`Alert auto-resolved: ${alert.type}`);
      this.emit('alertResolved', alert);
    }
  }

  /**
   * Acquitte une alerte manuellement
   */
  acknowledgeAlert(alertId, userId = 'system') {
    const alert = this.activeAlerts.get(alertId);
    if (alert) {
      alert.acknowledged = true;
      alert.acknowledgedBy = userId;
      alert.acknowledgedAt = new Date();
      
      logger.info(`Alert acknowledged by ${userId}: ${alert.type}`);
      this.emit('alertAcknowledged', alert);
      return true;
    }
    return false;
  }

  /**
   * Obtient le statut de monitoring actuel
   */
  getMonitoringStatus() {
    const current = this.qualityMetrics.currentHour;
    const activeAlertsList = Array.from(this.activeAlerts.values())
      .filter(a => !a.acknowledged && !a.autoResolved);

    const status = {
      timestamp: new Date(),
      overall: this.calculateOverallHealth(),
      
      currentHour: {
        total: current.total,
        qualityDistribution: {
          excellent: current.excellent,
          good: current.good,
          acceptable: current.acceptable,
          poor: current.poor,
          critical: current.critical
        },
        problematicRoutes: current.problematic,
        avgProcessingTime: Math.round(current.avgProcessingTime),
        qualityScore: this.calculateQualityScore(current)
      },

      alerts: {
        active: activeAlertsList.length,
        critical: activeAlertsList.filter(a => a.severity === 'critical').length,
        high: activeAlertsList.filter(a => a.severity === 'high').length,
        recent: activeAlertsList.slice(-5) // 5 alertes les plus récentes
      },

      patterns: {
        consecutiveFailures: this.patternCounters.consecutiveFailures,
        recentProblems: this.patternCounters.lastHourProblems.length,
        commonProblemTypes: this.getCommonProblemTypes()
      },

      geographic: this.getGeographicSummary(),

      trends: this.qualityMetrics.trends
    };

    return status;
  }

  /**
   * Calcule la santé globale du système
   */
  calculateOverallHealth() {
    const current = this.qualityMetrics.currentHour;
    const activeAlerts = Array.from(this.activeAlerts.values())
      .filter(a => !a.acknowledged && !a.autoResolved);

    // Pas assez de données
    if (current.total < 5) return 'unknown';

    // Alertes critiques actives
    if (activeAlerts.some(a => a.severity === 'critical')) return 'critical';

    // Taux de qualité
    const goodRate = (current.excellent + current.good) / current.total;
    const criticalRate = current.critical / current.total;

    if (criticalRate > 0.1) return 'poor';
    if (goodRate < 0.5) return 'degraded';
    if (goodRate > 0.8) return 'excellent';
    
    return 'good';
  }

  /**
   * Calcule le score de qualité
   */
  calculateQualityScore(current) {
    if (current.total === 0) return 0;

    const weights = { excellent: 5, good: 4, acceptable: 3, poor: 2, critical: 1 };
    const weightedSum = Object.keys(weights)
      .reduce((sum, quality) => sum + (current[quality] * weights[quality]), 0);

    return Math.round((weightedSum / (current.total * 5)) * 100);
  }

  /**
   * Obtient les types de problèmes les plus communs
   */
  getCommonProblemTypes() {
    const problemCounts = {};
    
    this.patternCounters.lastHourProblems.forEach(problem => {
      problemCounts[problem.type] = (problemCounts[problem.type] || 0) + 1;
    });

    return Object.entries(problemCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([type, count]) => ({ type, count }));
  }

  /**
   * Obtient un résumé géographique
   */
  getGeographicSummary() {
    const summary = {};
    
    this.geographicStats.forEach((stats, zoneType) => {
      const qualityScore = this.calculateQualityScore(stats.qualityDistribution);
      
      summary[zoneType] = {
        total: stats.total,
        qualityScore: qualityScore,
        problemRate: Math.round(stats.problemRate * 100),
        avgComplexity: Math.round(stats.avgComplexity * 100),
        status: qualityScore > 80 ? 'good' : qualityScore > 60 ? 'fair' : 'poor'
      };
    });

    return summary;
  }

  /**
   * Cycle de nettoyage des données anciennes
   */
  startCleanupCycle() {
    setInterval(() => {
      this.performCleanup();
    }, 3600000); // Toutes les heures
  }

  /**
   * Nettoie les données anciennes
   */
  performCleanup() {
    const now = Date.now();
    
    // Archiver les métriques de l'heure actuelle
    this.qualityMetrics.last24Hours.push({
      timestamp: now,
      ...this.qualityMetrics.currentHour
    });

    // Garder seulement les 24 dernières heures
    this.qualityMetrics.last24Hours = this.qualityMetrics.last24Hours
      .filter(h => now - h.timestamp < 86400000); // 24 heures

    // Réinitialiser les métriques de l'heure actuelle
    Object.keys(this.qualityMetrics.currentHour).forEach(key => {
      if (typeof this.qualityMetrics.currentHour[key] === 'number') {
        this.qualityMetrics.currentHour[key] = 0;
      }
    });

    // Nettoyer les alertes anciennes résolues
    const oldAlerts = Array.from(this.activeAlerts.entries())
      .filter(([id, alert]) => {
        const age = now - alert.timestamp.getTime();
        return (alert.acknowledged || alert.autoResolved) && age > 86400000; // 24h
      });

    oldAlerts.forEach(([id]) => {
      this.activeAlerts.delete(id);
    });

    // Réinitialiser les compteurs de patterns
    this.patternCounters.straightLineRoutes = 0;
    this.patternCounters.geometricRoutes = 0;

    logger.info('Monitoring cleanup completed', {
      archivedHours: this.qualityMetrics.last24Hours.length,
      activeAlerts: this.activeAlerts.size,
      removedAlerts: oldAlerts.length
    });
  }

  /**
   * Exporte les métriques pour analyse externe
   */
  exportMetrics(format = 'json') {
    const data = {
      timestamp: new Date(),
      currentStatus: this.getMonitoringStatus(),
      historicalData: this.qualityMetrics.last24Hours,
      geographicStats: Object.fromEntries(this.geographicStats),
      alertHistory: Array.from(this.activeAlerts.values())
    };

    switch (format) {
      case 'csv':
        return this.convertToCSV(data);
      case 'json':
      default:
        return JSON.stringify(data, null, 2);
    }
  }

  /**
   * Convertit les données en CSV (simplifié)
   */
  convertToCSV(data) {
    const hourlyData = data.historicalData.map(h => ({
      timestamp: new Date(h.timestamp).toISOString(),
      total: h.total,
      excellent: h.excellent,
      good: h.good,
      acceptable: h.acceptable,
      poor: h.poor,
      critical: h.critical,
      problematic: h.problematic,
      avgProcessingTime: h.avgProcessingTime
    }));

    if (hourlyData.length === 0) return '';

    const headers = Object.keys(hourlyData[0]).join(',');
    const rows = hourlyData.map(row => Object.values(row).join(','));
    
    return [headers, ...rows].join('\n');
  }
}

// Instance globale
const routeMonitoringService = new RouteMonitoringService();

// Middleware pour enregistrer automatiquement les routes
const monitoringMiddleware = (req, res, next) => {
  const originalSend = res.send;
  const startTime = Date.now();
  
  res.send = function(data) {
    const processingTime = Date.now() - startTime;
    
    try {
      if (req.path?.includes('/routes/generate') && res.statusCode) {
        const parsedData = typeof data === 'string' ? JSON.parse(data) : data;
        
        routeMonitoringService.recordRouteGeneration({
          success: res.statusCode === 200 && parsedData.success,
          route: parsedData.route,
          metadata: parsedData.route?.metadata,
          processingTime: processingTime,
          qualityInfo: parsedData.qualityInfo,
          problems: parsedData.route?.metadata?.problems,
          geoAnalysis: req.geographicAnalysis
        });
      }
    } catch (error) {
      logger.error('Monitoring middleware error:', error);
    }
    
    originalSend.call(this, data);
  };
  
  next();
};

module.exports = { 
  RouteMonitoringService, 
  routeMonitoringService, 
  monitoringMiddleware 
};