// src/services/elevationService.js
const logger = require('../config/logger'); // Import direct du logger
const graphhopperCloud = require('./graphhopperCloudService');

class ElevationService {
  constructor() {
    this.cache = new Map();
    this.batchSize = 100; // Nombre de points par requête
    this.cacheHits = 0;
    this.cacheMisses = 0;
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
    try {
      // Utiliser le service d'élévation de GraphHopper Cloud
      const elevationData = await graphhopperCloud.getElevation(coordinates);
      
      return elevationData.map((point, index) => ({
        lon: coordinates[index][0] || coordinates[index].lon,
        lat: coordinates[index][1] || coordinates[index].lat,
        elevation: point.elevation
      }));

    } catch (error) {
      logger.error('Erreur GraphHopper elevation:', error);
      // Fallback vers Open-Elevation API en cas d'échec
      return this.fetchOpenElevation(coordinates);
    }
  }

  /**
   * Fallback vers Open-Elevation API
   */
  async fetchOpenElevation(coordinates) {
    try {
      const axios = require('axios');
      
      const locations = coordinates.map(coord => ({
        latitude: coord[1] || coord.lat,
        longitude: coord[0] || coord.lon
      }));

      const response = await axios.post('https://api.open-elevation.com/api/v1/lookup', {
        locations
      }, {
        timeout: parseInt(process.env.ELEVATION_TIMEOUT) || 15000,
        headers: {
          'Content-Type': 'application/json'
        }
      });

      if (!response.data || !response.data.results) {
        throw new Error('Invalid response from Open-Elevation');
      }

      return response.data.results.map((result, index) => ({
        lon: coordinates[index][0] || coordinates[index].lon,
        lat: coordinates[index][1] || coordinates[index].lat,
        elevation: result.elevation || 0
      }));

    } catch (error) {
      logger.error('Erreur Open-Elevation:', error);
      
      // Dernier fallback: élévations par défaut
      return coordinates.map(coord => ({
        lon: coord[0] || coord.lon,
        lat: coord[1] || coord.lat,
        elevation: 0
      }));
    }
  }

  /**
   * Divise les coordonnées en batches
   */
  createBatches(coordinates, batchSize) {
    const batches = [];
    for (let i = 0; i < coordinates.length; i += batchSize) {
      batches.push(coordinates.slice(i, i + batchSize));
    }
    return batches;
  }

  /**
   * Récupère l'élévation pour un point unique avec cache
   */
  async getElevationForPoint(lat, lon) {
    const cacheKey = `${lat.toFixed(4)}_${lon.toFixed(4)}`;
    
    // Vérifier le cache
    if (this.cache.has(cacheKey)) {
      this.cacheHits++;
      return this.cache.get(cacheKey);
    }

    this.cacheMisses++;

    try {
      const result = await this.addElevationData([[lon, lat]]);
      const elevation = result[0]?.elevation || 0;
      
      // Mettre en cache
      this.cache.set(cacheKey, elevation);
      
      // Nettoyer le cache si trop volumineux
      if (this.cache.size > 1000) {
        const firstKey = this.cache.keys().next().value;
        this.cache.delete(firstKey);
      }
      
      return elevation;

    } catch (error) {
      logger.error('Erreur élévation point unique:', error);
      return 0;
    }
  }

  /**
   * Calcule le profil d'élévation pour un parcours
   */
  async generateElevationProfile(coordinates, sampleDistance = 100) {
    if (!coordinates || coordinates.length < 2) {
      return [];
    }

    try {
      const turf = require('@turf/turf');
      const line = turf.lineString(coordinates);
      const lineLength = turf.length(line, { units: 'meters' });
      
      // Calculer le nombre d'échantillons
      const numberOfSamples = Math.ceil(lineLength / sampleDistance);
      const samplePoints = [];
      
      // Échantillonner des points le long de la ligne
      for (let i = 0; i <= numberOfSamples; i++) {
        const distance = (i / numberOfSamples) * lineLength;
        const point = turf.along(line, distance, { units: 'meters' });
        samplePoints.push(point.geometry.coordinates);
      }
      
      // Récupérer les élévations pour les points échantillonnés
      const elevationData = await this.addElevationData(samplePoints);
      
      // Ajouter la distance cumulative
      let cumulativeDistance = 0;
      const profile = elevationData.map((point, index) => {
        if (index > 0) {
          cumulativeDistance += turf.distance(
            [elevationData[index - 1].lon, elevationData[index - 1].lat],
            [point.lon, point.lat],
            { units: 'meters' }
          );
        }
        
        return {
          ...point,
          distance: Math.round(cumulativeDistance),
          index
        };
      });
      
      return profile;

    } catch (error) {
      logger.error('Erreur génération profil élévation:', error);
      
      // Fallback: profil basique avec élévations par défaut
      return coordinates.map((coord, index) => ({
        lon: coord[0],
        lat: coord[1],
        elevation: 0,
        distance: index * sampleDistance,
        index
      }));
    }
  }

  /**
   * Calcule les statistiques d'élévation
   */
  calculateElevationStats(elevationProfile) {
    if (!elevationProfile || elevationProfile.length === 0) {
      return {
        minElevation: 0,
        maxElevation: 0,
        totalAscent: 0,
        totalDescent: 0,
        averageGrade: 0,
        maxGrade: 0
      };
    }

    const elevations = elevationProfile.map(p => p.elevation);
    const minElevation = Math.min(...elevations);
    const maxElevation = Math.max(...elevations);
    
    let totalAscent = 0;
    let totalDescent = 0;
    const grades = [];
    
    for (let i = 1; i < elevationProfile.length; i++) {
      const elevDiff = elevationProfile[i].elevation - elevationProfile[i - 1].elevation;
      const distDiff = elevationProfile[i].distance - elevationProfile[i - 1].distance;
      
      if (elevDiff > 0) {
        totalAscent += elevDiff;
      } else {
        totalDescent += Math.abs(elevDiff);
      }
      
      if (distDiff > 0) {
        const grade = (elevDiff / distDiff) * 100;
        grades.push(grade);
      }
    }
    
    const averageGrade = grades.length > 0 ? grades.reduce((a, b) => a + b, 0) / grades.length : 0;
    const maxGrade = grades.length > 0 ? Math.max(...grades.map(Math.abs)) : 0;
    
    return {
      minElevation: Math.round(minElevation),
      maxElevation: Math.round(maxElevation),
      totalAscent: Math.round(totalAscent),
      totalDescent: Math.round(totalDescent),
      averageGrade: Math.round(averageGrade * 10) / 10,
      maxGrade: Math.round(maxGrade * 10) / 10
    };
  }

  /**
   * Nettoie le cache d'élévation
   */
  clearCache() {
    this.cache.clear();
    this.cacheHits = 0;
    this.cacheMisses = 0;
    logger.info('Cache d\'élévation nettoyé');
  }

  /**
   * Obtient les statistiques du cache
   */
  getCacheStats() {
    return {
      size: this.cache.size,
      maxSize: 1000,
      hitRate: this.cacheHits / (this.cacheHits + this.cacheMisses) || 0,
      hits: this.cacheHits,
      misses: this.cacheMisses
    };
  }
}

module.exports = new ElevationService();