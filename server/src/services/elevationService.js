const axios = require('axios');
const { logger } = require('../../server');

class ElevationService {
  constructor() {
    this.cache = new Map();
    this.batchSize = 100; // Nombre de points par requête
  }

  /**
   * Ajoute les données d'élévation à une liste de coordonnées
   */
  async addElevationData(coordinates) {
    if (!coordinates || coordinates.length === 0) {
      return [];
    }

    try {
      // Diviser en batches pour éviter les limites d'API
      const batches = this.createBatches(coordinates, this.batchSize);
      const results = [];

      for (const batch of batches) {
        const elevations = await this.fetchElevationBatch(batch);
        results.push(...elevations);
      }

      return results;
    } catch (error) {
      logger.error('Erreur récupération élévations:', error);
      // Retourner les coordonnées sans élévation en cas d'erreur
      return coordinates.map(coord => ({
        lon: coord[0],
        lat: coord[1],
        elevation: 0
      }));
    }
  }

  /**
   * Récupère l'élévation pour un batch de points
   */
  async fetchElevationBatch(coordinates) {
    // Utiliser le service d'élévation de GraphHopper
    const points = coordinates.map(coord => ({
      lat: coord[1],
      lng: coord[0]
    }));

    try {
      const response = await axios.post(
        `${process.env.GRAPHHOPPER_URL}/elevation`,
        { points },
        { timeout: 10000 }
      );

      return response.data.elevations.map((elevation, index) => ({
        lon: coordinates[index][0],
        lat: coordinates[index][1],
        elevation: elevation
      }));
    } catch (error) {
      // Si GraphHopper échoue, essayer avec Open-Elevation
      return this.fetchOpenElevation(coordinates);
    }
  }

  /**
   * Fallback vers Open-Elevation API
   */
  async fetchOpenElevation(coordinates) {
    try {
      const locations = coordinates.map(coord => ({
        latitude: coord[1],
        longitude: coord[0]
      }));

      const response = await axios.post(
        'https://api.open-elevation.com/api/v1/lookup',
        { locations },
        { timeout: 10000 }
      );

      return response.data.results.map((result, index) => ({
        lon: coordinates[index][0],
        lat: coordinates[index][1],
        elevation: result.elevation
      }));
    } catch (error) {
      logger.warn('Open-Elevation fallback échoué:', error.message);
      // Retourner une élévation par défaut
      return coordinates.map(coord => ({
        lon: coord[0],
        lat: coord[1],
        elevation: 50 // Élévation par défaut
      }));
    }
  }

  /**
   * Crée des batches de coordonnées
   */
  createBatches(array, batchSize) {
    const batches = [];
    for (let i = 0; i < array.length; i += batchSize) {
      batches.push(array.slice(i, i + batchSize));
    }
    return batches;
  }

  /**
   * Calcule le profil d'élévation avec distances cumulées
   */
  calculateElevationProfile(coordinatesWithElevation) {
    const profile = [];
    let cumulativeDistance = 0;

    for (let i = 0; i < coordinatesWithElevation.length; i++) {
      const point = coordinatesWithElevation[i];
      
      if (i > 0) {
        const prevPoint = coordinatesWithElevation[i - 1];
        const distance = this.calculateDistance(
          prevPoint.lat, prevPoint.lon,
          point.lat, point.lon
        );
        cumulativeDistance += distance;
      }

      profile.push({
        distance: Math.round(cumulativeDistance),
        elevation: Math.round(point.elevation),
        lat: point.lat,
        lon: point.lon
      });
    }

    return profile;
  }

  /**
   * Calcule les statistiques d'élévation
   */
  calculateElevationStats(elevationProfile) {
    if (!elevationProfile || elevationProfile.length === 0) {
      return {
        totalGain: 0,
        totalLoss: 0,
        minElevation: 0,
        maxElevation: 0,
        averageElevation: 0,
        maxGrade: 0,
        averagePositiveGrade: 0,
        averageNegativeGrade: 0
      };
    }

    let totalGain = 0;
    let totalLoss = 0;
    let minElevation = elevationProfile[0].elevation;
    let maxElevation = elevationProfile[0].elevation;
    let sumElevation = 0;
    let maxGrade = 0;
    let sumPositiveGrade = 0;
    let countPositiveGrade = 0;
    let sumNegativeGrade = 0;
    let countNegativeGrade = 0;

    for (let i = 0; i < elevationProfile.length; i++) {
      const elevation = elevationProfile[i].elevation;
      
      // Min/Max
      minElevation = Math.min(minElevation, elevation);
      maxElevation = Math.max(maxElevation, elevation);
      sumElevation += elevation;

      // Gains/Pertes et pentes
      if (i > 0) {
        const prevElevation = elevationProfile[i - 1].elevation;
        const elevationDiff = elevation - prevElevation;
        const distance = elevationProfile[i].distance - elevationProfile[i - 1].distance;

        if (elevationDiff > 0) {
          totalGain += elevationDiff;
        } else {
          totalLoss += Math.abs(elevationDiff);
        }

        // Calcul de la pente
        if (distance > 0) {
          const grade = (elevationDiff / distance) * 100;
          maxGrade = Math.max(maxGrade, Math.abs(grade));

          if (grade > 0) {
            sumPositiveGrade += grade;
            countPositiveGrade++;
          } else if (grade < 0) {
            sumNegativeGrade += Math.abs(grade);
            countNegativeGrade++;
          }
        }
      }
    }

    return {
      totalGain: Math.round(totalGain),
      totalLoss: Math.round(totalLoss),
      minElevation: Math.round(minElevation),
      maxElevation: Math.round(maxElevation),
      averageElevation: Math.round(sumElevation / elevationProfile.length),
      maxGrade: Math.round(maxGrade * 10) / 10,
      averagePositiveGrade: countPositiveGrade > 0 
        ? Math.round((sumPositiveGrade / countPositiveGrade) * 10) / 10 
        : 0,
      averageNegativeGrade: countNegativeGrade > 0 
        ? Math.round((sumNegativeGrade / countNegativeGrade) * 10) / 10 
        : 0
    };
  }

  /**
   * Lisse le profil d'élévation pour éliminer le bruit
   */
  smoothElevationProfile(profile, windowSize = 5) {
    if (profile.length <= windowSize) return profile;

    const smoothed = [...profile];
    const halfWindow = Math.floor(windowSize / 2);

    for (let i = halfWindow; i < profile.length - halfWindow; i++) {
      let sumElevation = 0;
      let count = 0;

      for (let j = i - halfWindow; j <= i + halfWindow; j++) {
        sumElevation += profile[j].elevation;
        count++;
      }

      smoothed[i] = {
        ...profile[i],
        elevation: Math.round(sumElevation / count)
      };
    }

    return smoothed;
  }

  /**
   * Calcule la distance entre deux points
   */
  calculateDistance(lat1, lon1, lat2, lon2) {
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
   * Identifie les segments de montée/descente significatifs
   */
  identifyClimbs(elevationProfile, minGrade = 3, minLength = 100) {
    const climbs = [];
    let currentClimb = null;

    for (let i = 1; i < elevationProfile.length; i++) {
      const distance = elevationProfile[i].distance - elevationProfile[i-1].distance;
      const elevationDiff = elevationProfile[i].elevation - elevationProfile[i-1].elevation;
      const grade = distance > 0 ? (elevationDiff / distance) * 100 : 0;

      if (Math.abs(grade) >= minGrade) {
        if (!currentClimb || (grade > 0) !== currentClimb.isAscent) {
          // Nouvelle montée/descente
          if (currentClimb && currentClimb.length >= minLength) {
            climbs.push(currentClimb);
          }
          currentClimb = {
            startIndex: i - 1,
            endIndex: i,
            startDistance: elevationProfile[i-1].distance,
            endDistance: elevationProfile[i].distance,
            startElevation: elevationProfile[i-1].elevation,
            endElevation: elevationProfile[i].elevation,
            isAscent: grade > 0,
            length: distance,
            totalElevationChange: elevationDiff,
            averageGrade: grade
          };
        } else {
          // Continuer la montée/descente actuelle
          currentClimb.endIndex = i;
          currentClimb.endDistance = elevationProfile[i].distance;
          currentClimb.endElevation = elevationProfile[i].elevation;
          currentClimb.length = currentClimb.endDistance - currentClimb.startDistance;
          currentClimb.totalElevationChange = currentClimb.endElevation - currentClimb.startElevation;
          currentClimb.averageGrade = (currentClimb.totalElevationChange / currentClimb.length) * 100;
        }
      } else {
        // Fin de la montée/descente
        if (currentClimb && currentClimb.length >= minLength) {
          climbs.push(currentClimb);
        }
        currentClimb = null;
      }
    }

    // Ajouter la dernière montée/descente si nécessaire
    if (currentClimb && currentClimb.length >= minLength) {
      climbs.push(currentClimb);
    }

    return climbs;
  }
}

module.exports = new ElevationService();