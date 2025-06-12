const Joi = require('joi');

// Schémas de validation
const routeParamsSchema = Joi.object({
  startLatitude: Joi.number().min(-90).max(90).required(),
  startLongitude: Joi.number().min(-180).max(180).required(),
  activityType: Joi.string().valid('running', 'cycling', 'walking').required(),
  distanceKm: Joi.number().min(0.5).max(200).required(),
  terrainType: Joi.string().valid('flat', 'mixed', 'hilly').default('mixed'),
  urbanDensity: Joi.string().valid('urban', 'mixed', 'nature').default('mixed'),
  elevationGain: Joi.number().min(0).max(5000).default(0),
  isLoop: Joi.boolean().default(true),
  avoidTraffic: Joi.boolean().default(true),
  preferScenic: Joi.boolean().default(true),
  searchRadius: Joi.number().min(1000).max(50000).optional()
});

const analysisParamsSchema = Joi.object({
  coordinates: Joi.array().items(
    Joi.array().ordered(
      Joi.number().min(-180).max(180), // longitude
      Joi.number().min(-90).max(90),   // latitude
      Joi.number().optional()           // elevation
    )
  ).min(2).required(),
  includeElevation: Joi.boolean().default(true),
  sampleDistance: Joi.number().min(10).max(1000).default(100)
});

const coordinatesSchema = Joi.array().items(
  Joi.array().ordered(
    Joi.number().min(-180).max(180), // longitude
    Joi.number().min(-90).max(90),   // latitude
    Joi.number().optional()           // elevation
  )
).min(2);

/**
 * Valide les paramètres de génération de route
 */
function validateRouteParams(params) {
  const { error, value } = routeParamsSchema.validate(params, { 
    abortEarly: false,
    stripUnknown: true 
  });

  if (error) {
    return {
      valid: false,
      errors: error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }))
    };
  }

  // ✅ FIX: Vérifier que value existe ET a les propriétés requises
  if (!value || typeof value !== 'object') {
    return {
      valid: false,
      errors: [{ field: 'general', message: 'Données invalides' }]
    };
  }

  // Validations métier supplémentaires
  const additionalErrors = [];

  // Vérification du rayon de recherche
  if (value.searchRadius && value.distanceKm) {
    const minRadius = value.distanceKm * 500; // 500m par km minimum
    if (value.searchRadius < minRadius) {
      additionalErrors.push({
        field: 'searchRadius',
        message: `Le rayon de recherche doit être au moins ${minRadius}m pour ${value.distanceKm}km`
      });
    }
  }

  // Limites par activité avec vérification d'existence
  const activityLimits = {
    running: { minDistance: 1, maxDistance: 42 },
    cycling: { minDistance: 5, maxDistance: 200 },
    walking: { minDistance: 0.5, maxDistance: 30 }
  };

  if (value.activityType && value.distanceKm) {
    const limits = activityLimits[value.activityType];
    if (limits && (value.distanceKm < limits.minDistance || value.distanceKm > limits.maxDistance)) {
      additionalErrors.push({
        field: 'distanceKm',
        message: `Distance pour ${value.activityType}: ${limits.minDistance}-${limits.maxDistance}km`
      });
    }
  }

  if (additionalErrors.length > 0) {
    return { valid: false, errors: additionalErrors };
  }

  return { valid: true, value };
}

/**
 * Valide les paramètres d'analyse
 */
function validateAnalysisParams(params) {
  const { error, value } = analysisParamsSchema.validate(params, { 
    abortEarly: false,
    stripUnknown: true 
  });

  if (error) {
    return {
      valid: false,
      errors: error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }))
    };
  }

  // Validation supplémentaire de la continuité des coordonnées
  const coordsValidation = validateCoordinates(value.coordinates);
  if (!coordsValidation.valid) {
    return {
      valid: false,
      errors: [{ field: 'coordinates', message: coordsValidation.error }]
    };
  }

  return {
    valid: true,
    value: value
  };
}

/**
 * Valide un tableau de coordonnées
 */
function validateCoordinates(coordinates) {
  const { error } = coordinatesSchema.validate(coordinates);
  
  if (error) {
    return {
      valid: false,
      error: error.message
    };
  }

  // Vérifier la continuité
  for (let i = 1; i < coordinates.length; i++) {
    const distance = calculateDistance(
      coordinates[i-1][1], coordinates[i-1][0],
      coordinates[i][1], coordinates[i][0]
    );
    
    // Si deux points sont à plus de 1km, c'est suspect
    if (distance > 1000) {
      return {
        valid: false,
        error: `Gap de ${distance}m détecté entre les points ${i-1} et ${i}`
      };
    }
  }

  return { valid: true };
}

/**
 * Calcule la distance entre deux points (formule de Haversine)
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Rayon de la Terre en mètres
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
          Math.cos(φ1) * Math.cos(φ2) *
          Math.sin(Δλ/2) * Math.sin(Δλ/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

  return R * c;
}

/**
 * Valide les paramètres d'export
 */
function validateExportParams(format, coordinates) {
  const validFormats = ['gpx', 'geojson', 'kml'];
  
  if (!validFormats.includes(format.toLowerCase())) {
    return {
      valid: false,
      error: `Format invalide. Formats supportés: ${validFormats.join(', ')}`
    };
  }

  const coordsValidation = validateCoordinates(coordinates);
  if (!coordsValidation.valid) {
    return coordsValidation;
  }

  return { valid: true };
}

module.exports = {
  validateRouteParams,
  validateAnalysisParams,
  validateCoordinates,
  validateExportParams,
  calculateDistance
};