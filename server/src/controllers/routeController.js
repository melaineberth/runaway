const routeGeneratorService = require("../services/routeGeneratorService");
const routeProblemPreventionService = require("../services/routeProblemPreventionService"); // NOUVEAU
const { validateRouteParams } = require("../utils/validators");
const logger = require("../config/logger");
const routeQualityService = require("../services/routeQualityService");

class RouteController {
  /**
   * POST /api/routes/simple - Génère un itinéraire simple entre deux points
   */
  async generateSimpleRoute(req, res, next) {
    console.log('🔧 generateSimpleRoute appelée dans le contrôleur');
    console.log('🔧 Body reçu:', req.body);
    
    try {
      const { points, profile = 'foot' } = req.body;
      
      // Validation des paramètres
      if (!points || !Array.isArray(points) || points.length !== 2) {
        console.log('❌ Invalid points:', points);
        return res.status(400).json({
          success: false,
          error: 'Exactly 2 points required: [[lon1, lat1], [lon2, lat2]]'
        });
      }

      // Valider chaque point
      for (let i = 0; i < points.length; i++) {
        const point = points[i];
        if (!Array.isArray(point) || point.length < 2) {
          return res.status(400).json({
            success: false,
            error: `Point ${i} invalid format. Expected [longitude, latitude]`
          });
        }
        
        const [lon, lat] = point;
        if (typeof lon !== 'number' || typeof lat !== 'number') {
          return res.status(400).json({
            success: false,
            error: `Point ${i} coordinates must be numbers`
          });
        }
        
        if (lon < -180 || lon > 180 || lat < -90 || lat > 90) {
          return res.status(400).json({
            success: false,
            error: `Point ${i} coordinates out of bounds`
          });
        }
      }

      const [start, end] = points;
      
      console.log('🔧 Validation réussie, génération de la route...');
      
      logger.info('Simple route generation started', {
        start: [start[1], start[0]], // lat, lon pour les logs
        end: [end[1], end[0]],
        profile
      });

      // Générer l'itinéraire via GraphHopper
      const route = await routeGeneratorService.generateSimpleRoute({
        startLat: start[1],  // start[1] = lat
        startLon: start[0],  // start[0] = lon
        endLat: end[1],      // end[1] = lat
        endLon: end[0],      // end[0] = lon
        profile
      });

      console.log('🔧 Route générée avec succès');

      // Formater la réponse pour le client Flutter
      const response = {
        success: true,
        route: {
          coordinates: route.coordinates,
          distance: route.distance,
          duration: route.duration,
          instructions: route.instructions || [],
          metadata: {
            profile,
            generatedAt: new Date().toISOString(),
            points_count: route.coordinates.length,
            type: 'simple_route'
          }
        }
      };

      logger.info('Simple route generation completed', {
        distance: `${(route.distance / 1000).toFixed(1)}km`,
        duration: `${Math.round(route.duration / 60000)}min`,
        points: route.coordinates.length
      });

      res.json(response);

    } catch (error) {
      console.log('❌ Erreur dans generateSimpleRoute:', error);
      
      logger.error('Simple route generation failed:', {
        error: error.message,
        stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
      });

      // Gestion d'erreurs spécifiques GraphHopper
      if (error.message.includes('GraphHopper')) {
        return res.status(503).json({
          success: false,
          error: 'Routing service temporarily unavailable',
          details: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
      }

      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  /**
   * POST /api/routes/generate - Génère un parcours avec prévention intelligente des problèmes
   */
  async generateRoute(req, res, next) {
    const startTime = Date.now();
    
    try {
      // Utiliser les paramètres validés et enrichis par les middlewares
      const params = req.validatedParams || req.body;
      const geoAnalysis = req.geographicAnalysis;
      const strategyRecommendations = req.strategyRecommendations;
      
      if (!params) {
        return res.status(400).json({
          success: false,
          error: "Paramètres manquants"
        });
      }

      const requestId = params.requestId || `route_${Date.now()}`;
      
      logger.info("Enhanced route generation started with full pipeline", {
        requestId: requestId,
        geoAnalysis: geoAnalysis ? {
          zoneType: geoAnalysis.zoneType,
          riskLevel: geoAnalysis.riskLevel,
          complexityRating: geoAnalysis.complexityRating
        } : 'not_available',
        recommendedStrategies: strategyRecommendations?.slice(0, 3).map(s => s.name) || ['none'],
        params: {
          activityType: params.activityType,
          distanceKm: params.distanceKm,
          isLoop: params.isLoop
        }
      });

      // ✅ ÉTAPE 1: Prévention des parcours problématiques
      const preventionStrategy = await routeProblemPreventionService.preventProblematicRoute(
        params, 
        geoAnalysis
      );

      logger.info("Problem prevention analysis completed", {
        requestId: requestId,
        riskLevel: preventionStrategy.riskLevel,
        forceOrganic: preventionStrategy.forceOrganicGeneration,
        measuresCount: preventionStrategy.preventionMeasures.length,
        mandatoryWaypoints: preventionStrategy.mandatoryWaypoints
      });

      // ✅ ÉTAPE 2: Application des ajustements préventifs
      const enhancedParams = this.applyPreventionAdjustments(params, preventionStrategy, strategyRecommendations);

      // ✅ ÉTAPE 3: Génération du parcours avec paramètres optimisés
      logger.info("Starting route generation with enhanced parameters", {
        requestId: requestId,
        originalStrategy: params.activityType,
        forcedStrategy: enhancedParams._forcedStrategy,
        organicGeneration: enhancedParams._forceOrganic,
        waypointCount: enhancedParams._minimumWaypoints
      });

      const route = await routeGeneratorService.generateRoute(enhancedParams);

      // ✅ ÉTAPE 4: Validation post-génération avec détection de problèmes
      const problemValidation = routeProblemPreventionService.validateGeneratedRoute(route, enhancedParams);
      const qualityValidation = routeQualityService.validateRoute(route, enhancedParams);

      logger.info("Post-generation validation completed", {
        requestId: requestId,
        problemsDetected: problemValidation.isProblematic,
        problemCount: problemValidation.detectedProblems.length,
        qualityLevel: qualityValidation.quality,
        overallValid: !problemValidation.isProblematic && qualityValidation.isValid
      });

      // ✅ ÉTAPE 5: Gestion des parcours problématiques détectés
      let finalRoute = route;
      let appliedFixes = [];
      let regenerationAttempts = 0;

      if (problemValidation.isProblematic && problemValidation.severity === 'critical') {
        logger.warn("Critical problems detected, attempting regeneration", {
          requestId: requestId,
          problems: problemValidation.detectedProblems.map(p => p.type)
        });

        // Tentative de régénération avec paramètres plus stricts
        const emergencyParams = this.createEmergencyParameters(enhancedParams, problemValidation);
        
        try {
          finalRoute = await routeGeneratorService.generateRoute(emergencyParams);
          regenerationAttempts = 1;
          
          // Re-valider
          const newValidation = routeProblemPreventionService.validateGeneratedRoute(finalRoute, emergencyParams);
          if (!newValidation.isProblematic) {
            logger.info("Emergency regeneration successful", { requestId: requestId });
          }
        } catch (error) {
          logger.warn("Emergency regeneration failed, using original route", {
            requestId: requestId,
            error: error.message
          });
          // Garder la route originale mais appliquer des corrections
        }
      }

      // ✅ ÉTAPE 6: Application des corrections automatiques
      if (!problemValidation.isProblematic || problemValidation.severity !== 'critical') {
        const { route: fixedRoute, fixes } = routeQualityService.autoFixRoute(finalRoute, enhancedParams);
        finalRoute = fixedRoute;
        appliedFixes = fixes;

        if (fixes.length > 0) {
          logger.info("Auto-fixes applied successfully", {
            requestId: requestId,
            fixes: fixes
          });
        }
      }

      // ✅ ÉTAPE 7: Enrichissement des métadonnées
      finalRoute.metadata = {
        ...finalRoute.metadata,
        requestId: requestId,
        generatedAt: new Date().toISOString(),
        
        // Informations de génération
        generation: {
          attempts: route.metadata?.generationAttempts || 1,
          regenerationAttempts: regenerationAttempts,
          strategiesUsed: route.metadata?.strategiesUsed || [],
          finalStrategy: enhancedParams._forcedStrategy || 'auto',
          appliedFixes: appliedFixes
        },

        // Analyse géographique
        geographic: geoAnalysis ? {
          zoneType: geoAnalysis.zoneType,
          riskLevel: geoAnalysis.riskLevel,
          complexityRating: geoAnalysis.complexityRating,
          routePotential: geoAnalysis.routePotential
        } : null,

        // Prévention et qualité
        prevention: {
          initialRiskLevel: preventionStrategy.riskLevel,
          measuresApplied: preventionStrategy.preventionMeasures,
          organicGeneration: preventionStrategy.forceOrganicGeneration
        },

        // Validation de qualité
        quality: {
          overall: qualityValidation.quality,
          isValid: qualityValidation.isValid,
          aestheticsScore: qualityValidation.metrics.aesthetics?.score || 0,
          complexityScore: qualityValidation.metrics.complexity?.score || 0,
          distanceAccuracy: qualityValidation.metrics.distance?.grade || 'unknown'
        },

        // Détection de problèmes
        problems: {
          detected: problemValidation.isProblematic,
          count: problemValidation.detectedProblems.length,
          severity: problemValidation.severity,
          types: problemValidation.detectedProblems.map(p => p.type)
        }
      };

      // ✅ ÉTAPE 8: Formater la réponse enrichie
      const response = {
        success: true,
        route: {
          coordinates: finalRoute.coordinates,
          distance: finalRoute.distance,
          duration: finalRoute.duration,
          elevationGain: finalRoute.metadata?.elevationGain || 0,
          metadata: finalRoute.metadata
        },
        instructions: finalRoute.instructions || [],
        elevationProfile: finalRoute.elevationProfile || [],
        bbox: finalRoute.bbox,

        // Informations de qualité pour le client
        qualityInfo: {
          overallQuality: qualityValidation.quality,
          isReliable: !problemValidation.isProblematic && qualityValidation.isValid,
          confidence: Math.round((1 - problemValidation.confidence) * 100), // Inverser pour avoir confiance
          appliedEnhancements: appliedFixes.length + preventionStrategy.preventionMeasures.length,
          
          // Scores détaillés
          scores: {
            aesthetics: Math.round((qualityValidation.metrics.aesthetics?.score || 0) * 100),
            complexity: Math.round((qualityValidation.metrics.complexity?.score || 0) * 100),
            interest: Math.round((qualityValidation.metrics.interest?.score || 0) * 100)
          }
        },

        // Informations sur la génération (optionnel, pour debug)
        ...(process.env.NODE_ENV === 'development' && {
          generationInfo: {
            geoAnalysis: geoAnalysis,
            strategyRecommendations: strategyRecommendations,
            preventionStrategy: preventionStrategy,
            problemValidation: problemValidation,
            processingTime: Date.now() - startTime
          }
        })
      };

      // ✅ ÉTAPE 9: Logging final et métriques
      const processingTime = Date.now() - startTime;
      
      logger.info("Enhanced route generation completed successfully", {
        requestId: requestId,
        processingTime: `${processingTime}ms`,
        distance: `${(finalRoute.distance / 1000).toFixed(1)}km`,
        quality: qualityValidation.quality,
        problemsDetected: problemValidation.isProblematic,
        appliedFixes: appliedFixes.length,
        coordinatesCount: finalRoute.coordinates.length,
        isReliable: response.qualityInfo.isReliable,
        aestheticsScore: response.qualityInfo.scores.aesthetics,
        complexityScore: response.qualityInfo.scores.complexity
      });

      // Enregistrer les métriques
      const { metricsService } = require("../services/metricsService");
      metricsService.recordRouteGeneration(true, finalRoute.distance / 1000);

      res.json(response);

    } catch (error) {
      const requestId = req.validatedParams?.requestId || req.body?.requestId || 'unknown';
      const processingTime = Date.now() - startTime;
      
      logger.error("Enhanced route generation failed", {
        requestId: requestId,
        processingTime: `${processingTime}ms`,
        error: error.message,
        stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
      });

      // Gestion d'erreurs spécifique avec recommandations
      if (error.message.includes('Unable to generate acceptable route') || 
          error.message.includes('Unable to generate acceptable organic route')) {
        return res.status(422).json({
          success: false,
          error: "Impossible de générer un parcours de qualité acceptable dans cette zone",
          details: {
            message: "La zone géographique ou les paramètres rendent difficile la génération d'un parcours intéressant",
            suggestions: [
              "Essayer une distance différente (±20%)",
              "Changer de point de départ dans un rayon de 500m",
              "Modifier le type d'activité",
              "Utiliser un terrain moins contraignant"
            ],
            alternativeApproach: "Vous pouvez utiliser la route /routes/simple pour un itinéraire basique"
          },
          requestId: requestId,
          geoAnalysis: req.geographicAnalysis || null
        });
      }

      if (error.message.includes('Distance ratio too extreme')) {
        return res.status(422).json({
          success: false,
          error: "Paramètres incompatibles avec la zone géographique",
          details: {
            message: "La distance demandée ne peut pas être générée efficacement dans cette zone",
            suggestions: [
              `Essayer une distance entre ${Math.max(1, req.validatedParams?.distanceKm * 0.7).toFixed(1)} et ${(req.validatedParams?.distanceKm * 1.3).toFixed(1)} km`,
              "Changer de zone de départ",
              "Utiliser le mode point-à-point au lieu de boucle"
            ]
          },
          requestId: requestId
        });
      }

      if (error.message.includes('GraphHopper')) {
        return res.status(503).json({
          success: false,
          error: 'Service de routage temporairement indisponible',
          details: {
            message: "Le service externe de cartographie rencontre des difficultés",
            retryAdvice: "Veuillez réessayer dans quelques minutes"
          },
          requestId: requestId
        });
      }

      // Erreur générique avec information contextuelle
      res.status(500).json({
        success: false,
        error: "Erreur lors de la génération du parcours",
        details: {
          message: error.message,
          context: req.geographicAnalysis ? {
            zoneType: req.geographicAnalysis.zoneType,
            riskLevel: req.geographicAnalysis.riskLevel
          } : null
        },
        requestId: requestId
      });
    }
  }

  /**
   * NOUVELLE MÉTHODE : Applique les ajustements de prévention
   */
  applyPreventionAdjustments(originalParams, preventionStrategy, strategyRecommendations) {
    const enhanced = { ...originalParams };

    // Application des ajustements recommandés par la prévention
    Object.assign(enhanced, preventionStrategy.recommendedAdjustments);

    // Force la génération organique si nécessaire
    if (preventionStrategy.forceOrganicGeneration) {
      enhanced._forceOrganic = true;
      enhanced._organicnessFactor = enhanced._organicnessFactor || 0.8;
      enhanced._minimumWaypoints = preventionStrategy.mandatoryWaypoints;
    }

    // Utiliser la stratégie recommandée par l'analyse géographique
    if (strategyRecommendations && strategyRecommendations.length > 0 && !enhanced._forcedStrategy) {
      const topRecommendation = strategyRecommendations[0];
      if (topRecommendation.confidence > 0.7) {
        enhanced._forcedStrategy = topRecommendation.name;
        
        logger.info("Applying geographic strategy recommendation", {
          requestId: enhanced.requestId,
          recommendedStrategy: topRecommendation.name,
          confidence: topRecommendation.confidence,
          reason: topRecommendation.reason
        });
      }
    }

    // Ajustements spécifiques selon les mesures préventives
    preventionStrategy.preventionMeasures.forEach(measure => {
      switch (measure) {
        case 'low_geographic_complexity':
          enhanced._avoidStraightLines = true;
          enhanced._forceCurves = true;
          break;
        case 'urban_grid_risk':
          enhanced._organicnessFactor = Math.max(enhanced._organicnessFactor || 0, 0.7);
          enhanced._minimumWaypoints = Math.max(enhanced._minimumWaypoints || 0, 8);
          break;
        case 'known_problematic_zone':
          enhanced._forceOrganic = true;
          enhanced._organicnessFactor = 0.9;
          break;
        case 'very_short_distance':
          enhanced._minimumWaypoints = Math.max(enhanced._minimumWaypoints || 0, 6);
          enhanced._forceCurves = true;
          break;
      }
    });

    return enhanced;
  }

  /**
   * NOUVELLE MÉTHODE : Crée des paramètres d'urgence pour la régénération
   */
  createEmergencyParameters(originalParams, problemValidation) {
    const emergency = { ...originalParams };

    // Paramètres d'urgence maximaux
    emergency._forceOrganic = true;
    emergency._organicnessFactor = 0.9;
    emergency._avoidStraightLines = true;
    emergency._forceCurves = true;
    emergency._minimumWaypoints = Math.max(emergency._minimumWaypoints || 0, 10);
    emergency._forcedStrategy = 'organic_natural';
    emergency.requestId = `emergency_${originalParams.requestId}`;

    // Ajustements spécifiques selon les problèmes détectés
    const problemTypes = problemValidation.detectedProblems.map(p => p.type);
    
    if (problemTypes.includes('straight_line_pattern')) {
      emergency._organicnessFactor = 1.0;
      emergency._minimumWaypoints = Math.max(emergency._minimumWaypoints, 12);
    }

    if (problemTypes.includes('geometric_pattern')) {
      emergency._forceCurves = true;
      emergency._avoidStraightLines = true;
      emergency.searchRadius = Math.max(2000, emergency.searchRadius * 0.6);
    }

    if (problemTypes.includes('tight_loop')) {
      emergency.searchRadius = Math.min(50000, emergency.searchRadius * 1.5);
      emergency._minimumWaypoints = Math.max(emergency._minimumWaypoints, 8);
    }

    logger.info("Created emergency regeneration parameters", {
      originalRequestId: originalParams.requestId,
      emergencyRequestId: emergency.requestId,
      detectedProblems: problemTypes,
      emergencyMeasures: {
        organicnessFactor: emergency._organicnessFactor,
        minimumWaypoints: emergency._minimumWaypoints,
        forcedStrategy: emergency._forcedStrategy
      }
    });

    return emergency;
  }

  /**
   * POST /api/routes/regenerate - Régénère avec ajustements intelligents
   */
  async regenerateWithAdjustments(req, res, next) {
    try {
      const { originalParams, adjustments, problems } = req.body;
      
      if (!originalParams) {
        return res.status(400).json({
          success: false,
          error: "Paramètres originaux manquants"
        });
      }

      // Appliquer les ajustements avec intelligence
      const adjustedParams = this.createIntelligentAdjustments(originalParams, adjustments, problems);

      logger.info("Intelligent route regeneration", {
        originalRequestId: originalParams.requestId,
        adjustedRequestId: adjustedParams.requestId,
        appliedAdjustments: Object.keys(adjustments || {}),
        detectedProblems: problems?.map(p => p.type) || []
      });

      // Utiliser la méthode generateRoute avec les paramètres ajustés
      req.body = adjustedParams;
      req.validatedParams = adjustedParams;
      
      return this.generateRoute(req, res, next);

    } catch (error) {
      logger.error("Intelligent regeneration failed:", error);
      next(error);
    }
  }

  /**
   * NOUVELLE MÉTHODE : Crée des ajustements intelligents
   */
  createIntelligentAdjustments(originalParams, userAdjustments, detectedProblems) {
    const adjusted = {
      ...originalParams,
      ...userAdjustments,
      requestId: `regen_${Date.now()}`
    };

    // Ajustements automatiques basés sur les problèmes détectés
    if (detectedProblems) {
      detectedProblems.forEach(problem => {
        switch (problem.type) {
          case 'straight_line_pattern':
            adjusted._forceOrganic = true;
            adjusted._organicnessFactor = Math.max(adjusted._organicnessFactor || 0, 0.8);
            break;
          case 'geometric_pattern':
            adjusted._avoidStraightLines = true;
            adjusted._forceCurves = true;
            break;
          case 'long_straight_segments':
            adjusted._minimumWaypoints = Math.max(adjusted._minimumWaypoints || 0, 10);
            break;
          case 'tight_loop':
            adjusted.searchRadius = Math.min(50000, (adjusted.searchRadius || 5000) * 1.3);
            break;
        }
      });
    }

    // Validation des ajustements pour éviter les valeurs extrêmes
    if (adjusted.distanceKm) {
      adjusted.distanceKm = Math.max(0.5, Math.min(100, adjusted.distanceKm));
    }
    if (adjusted.searchRadius) {
      adjusted.searchRadius = Math.max(1000, Math.min(50000, adjusted.searchRadius));
    }
    if (adjusted._organicnessFactor) {
      adjusted._organicnessFactor = Math.max(0.1, Math.min(1.0, adjusted._organicnessFactor));
    }

    return adjusted;
  }

  /**
   * POST /api/routes/alternative - Génère des parcours alternatifs intelligents
   */
  async generateAlternatives(req, res, next) {
    try {
      const { baseParams, numberOfAlternatives = 3, diversityFactor = 0.7 } = req.body;

      if (!baseParams) {
        return res.status(400).json({
          success: false,
          error: "Paramètres de base manquants"
        });
      }

      const alternatives = [];
      const generationPromises = [];

      // Créer des variations intelligentes
      for (let i = 0; i < numberOfAlternatives; i++) {
        const variationParams = this.createIntelligentVariation(baseParams, i, diversityFactor);
        
        generationPromises.push(
          this.generateSingleAlternative(variationParams, i)
            .catch(error => ({
              index: i,
              success: false,
              error: error.message
            }))
        );
      }

      // Générer en parallèle avec timeout
      const results = await Promise.allSettled(generationPromises);
      
      results.forEach((result, index) => {
        if (result.status === 'fulfilled' && result.value.success) {
          alternatives.push({
            id: `alt_${index}`,
            ...result.value.route,
            variation: result.value.variation
          });
        } else {
          logger.warn(`Alternative ${index} generation failed:`, result.reason || result.value?.error);
        }
      });

      // Trier par qualité si on a plusieurs alternatives
      if (alternatives.length > 1) {
        alternatives.sort((a, b) => {
          const qualityA = a.metadata?.quality?.overall || 'poor';
          const qualityB = b.metadata?.quality?.overall || 'poor';
          const qualityOrder = { 'excellent': 5, 'good': 4, 'acceptable': 3, 'poor': 2, 'critical': 1 };
          return qualityOrder[qualityB] - qualityOrder[qualityA];
        });
      }

      res.json({
        success: true,
        alternatives: alternatives,
        generated: alternatives.length,
        requested: numberOfAlternatives,
        baseParams: baseParams
      });

    } catch (error) {
      logger.error("Alternative generation failed:", error);
      next(error);
    }
  }

  /**
   * NOUVELLE MÉTHODE : Crée une variation intelligente
   */
  createIntelligentVariation(baseParams, index, diversityFactor) {
    const variation = { ...baseParams };
    
    // Variations de base
    const variations = [
      { // Variation 1: Distance légèrement différente
        distanceKm: baseParams.distanceKm * (0.85 + Math.random() * 0.3),
        _organicnessFactor: 0.6,
        variation: 'distance_adjusted'
      },
      { // Variation 2: Terrain différent
        terrainType: baseParams.terrainType === 'flat' ? 'mixed' : 'flat',
        _forceCurves: true,
        variation: 'terrain_modified'
      },
      { // Variation 3: Plus organique
        _forceOrganic: true,
        _organicnessFactor: 0.8,
        _minimumWaypoints: Math.max(8, Math.floor(baseParams.distanceKm * 1.5)),
        variation: 'organic_enhanced'
      },
      { // Variation 4: Direction différente
        _seedOffset: index * 1000,
        searchRadius: baseParams.searchRadius * (0.8 + Math.random() * 0.4),
        variation: 'direction_varied'
      }
    ];

    const selectedVariation = variations[index % variations.length];
    Object.assign(variation, selectedVariation);
    
    // Ajouter de la diversité supplémentaire
    if (diversityFactor > 0.5) {
      variation._organicnessFactor = (variation._organicnessFactor || 0.5) + 
                                   (Math.random() - 0.5) * diversityFactor * 0.4;
      variation._organicnessFactor = Math.max(0.2, Math.min(1.0, variation._organicnessFactor));
    }

    variation.requestId = `alt_${index}_${baseParams.requestId || Date.now()}`;
    
    return variation;
  }

  /**
   * NOUVELLE MÉTHODE : Génère une alternative unique
   */
  async generateSingleAlternative(params, index) {
    try {
      const route = await routeGeneratorService.generateRoute(params);
      
      // Validation rapide
      const qualityValidation = routeQualityService.validateRoute(route, params);
      
      return {
        success: true,
        route: route,
        variation: params.variation,
        quality: qualityValidation.quality,
        index: index
      };
    } catch (error) {
      throw new Error(`Alternative ${index}: ${error.message}`);
    }
  }

  // Conserver toutes les méthodes existantes...
  async exportRoute(req, res, next) {
    try {
      const { format } = req.params;
      const { coordinates, metadata } = req.body;

      if (!coordinates || !Array.isArray(coordinates)) {
        return res.status(400).json({
          error: "Coordonnées manquantes ou invalides",
        });
      }

      let exportData;
      let contentType;
      let filename;

      switch (format.toLowerCase()) {
        case "gpx":
          exportData = this.exportToGPX(coordinates, metadata);
          contentType = "application/gpx+xml";
          filename = `route_${Date.now()}.gpx`;
          break;

        case "geojson":
          exportData = this.exportToGeoJSON(coordinates, metadata);
          contentType = "application/geo+json";
          filename = `route_${Date.now()}.geojson`;
          break;

        case "kml":
          exportData = this.exportToKML(coordinates, metadata);
          contentType = "application/vnd.google-earth.kml+xml";
          filename = `route_${Date.now()}.kml`;
          break;

        default:
          return res.status(400).json({
            error: "Format non supporté",
            supportedFormats: ["gpx", "geojson", "kml"],
          });
      }

      res.set({
        "Content-Type": contentType,
        "Content-Disposition": `attachment; filename="${filename}"`,
      });

      res.send(exportData);
    } catch (error) {
      logger.error("Erreur export route:", error);
      next(error);
    }
  }

  async analyzeRoute(req, res, next) {
    try {
      const { coordinates } = req.body;

      if (!coordinates || !Array.isArray(coordinates)) {
        return res.status(400).json({
          error: "Coordonnées manquantes ou invalides",
        });
      }

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
          segments: analysis.segments,
        },
      });
    } catch (error) {
      logger.error("Erreur analyse route:", error);
      next(error);
    }
  }

  async getNearbyPOIs(req, res, next) {
    try {
      const { lat, lon, radius = 1000, types } = req.query;

      if (!lat || !lon) {
        return res.status(400).json({
          error: "Coordonnées manquantes",
        });
      }

      const pois = await routeGeneratorService.findNearbyPOIs(
        parseFloat(lat),
        parseFloat(lon),
        parseInt(radius),
        types?.split(",")
      );

      res.json({
        success: true,
        pois: pois,
      });
    } catch (error) {
      logger.error("Erreur récupération POIs:", error);
      next(error);
    }
  }

  // Méthodes utilitaires d'export...
  exportToGPX(coordinates, metadata = {}) {
    const timestamp = new Date().toISOString();

    const gpx = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="RunAway Enhanced" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>${metadata.name || "RunAway Enhanced Route"}</name>
    <time>${timestamp}</time>
    <desc>Generated with intelligent route optimization</desc>
  </metadata>
  <trk>
    <name>${metadata.name || "RunAway Enhanced Route"}</name>
    <type>${metadata.activityType || "running"}</type>
    <trkseg>
${coordinates
  .map(
    (coord) => `      <trkpt lat="${coord[1]}" lon="${coord[0]}">
        ${coord[2] ? `<ele>${coord[2]}</ele>` : ""}
      </trkpt>`
  )
  .join("\n")}
    </trkseg>
  </trk>
</gpx>`;

    return gpx;
  }

  exportToGeoJSON(coordinates, metadata = {}) {
    return JSON.stringify(
      {
        type: "Feature",
        properties: {
          ...metadata,
          generatedBy: "RunAway Enhanced Route Generator",
          timestamp: new Date().toISOString()
        },
        geometry: {
          type: "LineString",
          coordinates: coordinates,
        },
      },
      null,
      2
    );
  }

  exportToKML(coordinates, metadata = {}) {
    const coordinatesString = coordinates
      .map((coord) => `${coord[0]},${coord[1]},${coord[2] || 0}`)
      .join(" ");

    return `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>${metadata.name || "RunAway Enhanced Route"}</name>
    <description>Generated with intelligent route optimization</description>
    <Placemark>
      <name>${metadata.name || "Route"}</name>
      <description>Activity: ${metadata.activityType || "running"}</description>
      <LineString>
        <coordinates>${coordinatesString}</coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>`;
  }
}

// ✅ CORRECTION : Export avec binding correct
const routeControllerInstance = new RouteController();

// Bind toutes les méthodes pour préserver le contexte
Object.getOwnPropertyNames(RouteController.prototype).forEach(name => {
  if (typeof routeControllerInstance[name] === 'function' && name !== 'constructor') {
    routeControllerInstance[name] = routeControllerInstance[name].bind(routeControllerInstance);
  }
});

console.log('🔧 Enhanced RouteController créé avec prévention intelligente des problèmes');

module.exports = routeControllerInstance;