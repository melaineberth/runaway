const turf = require('@turf/turf');

/**
 * Utilitaires géométriques pour le traitement des coordonnées
 */
class GeoUtils {
  /**
   * Calcule la distance entre deux points en mètres
   */
  static calculateDistance(coord1, coord2) {
    const from = turf.point(coord1);
    const to = turf.point(coord2);
    return turf.distance(from, to, { units: 'meters' });
  }

  /**
   * Calcule la distance totale d'une liste de coordonnées
   */
  static calculateTotalDistance(coordinates) {
    let totalDistance = 0;
    
    for (let i = 1; i < coordinates.length; i++) {
      totalDistance += this.calculateDistance(
        coordinates[i-1],
        coordinates[i]
      );
    }
    
    return totalDistance;
  }

  /**
   * Interpole un point entre deux coordonnées
   */
  static interpolatePoint(coord1, coord2, ratio) {
    const line = turf.lineString([coord1, coord2]);
    const distance = turf.length(line, { units: 'kilometers' });
    const along = turf.along(line, distance * ratio, { units: 'kilometers' });
    return along.geometry.coordinates;
  }

  /**
   * Simplifie une ligne en réduisant le nombre de points
   */
  static simplifyLine(coordinates, tolerance = 0.001) {
    const line = turf.lineString(coordinates);
    const simplified = turf.simplify(line, { tolerance });
    return simplified.geometry.coordinates;
  }

  /**
   * Calcule le bearing (direction) entre deux points
   */
  static calculateBearing(coord1, coord2) {
    const from = turf.point(coord1);
    const to = turf.point(coord2);
    return turf.bearing(from, to);
  }

  /**
   * Trouve le point d'une ligne le plus proche d'un point donné
   */
  static nearestPointOnLine(lineCoordinates, point) {
    const line = turf.lineString(lineCoordinates);
    const pt = turf.point(point);
    const snapped = turf.nearestPointOnLine(line, pt);
    return snapped.geometry.coordinates;
  }

  /**
   * Vérifie si un point est dans un polygone
   */
  static isPointInPolygon(point, polygonCoordinates) {
    const pt = turf.point(point);
    const poly = turf.polygon([polygonCoordinates]);
    return turf.booleanPointInPolygon(pt, poly);
  }

  /**
   * Calcule la bounding box d'une liste de coordonnées
   */
  static calculateBoundingBox(coordinates) {
    const line = turf.lineString(coordinates);
    return turf.bbox(line);
  }

  /**
   * Crée un buffer autour d'une ligne
   */
  static createBuffer(coordinates, radius) {
    const line = turf.lineString(coordinates);
    const buffered = turf.buffer(line, radius, { units: 'meters' });
    return buffered.geometry.coordinates;
  }

  /**
   * Divise une ligne en segments de longueur égale
   */
  static splitLineIntoSegments(coordinates, segmentLength) {
    const line = turf.lineString(coordinates);
    const length = turf.length(line, { units: 'meters' });
    const segments = [];
    
    for (let i = 0; i < length; i += segmentLength) {
      const point = turf.along(line, i, { units: 'meters' });
      segments.push(point.geometry.coordinates);
    }
    
    // Ajouter le dernier point
    segments.push(coordinates[coordinates.length - 1]);
    
    return segments;
  }

  /**
   * Calcule l'aire d'un polygone formé par les coordonnées
   */
  static calculateArea(coordinates) {
    if (coordinates.length < 3) return 0;
    
    // Fermer le polygone si nécessaire
    const closed = [...coordinates];
    if (closed[0] !== closed[closed.length - 1]) {
      closed.push(closed[0]);
    }
    
    const polygon = turf.polygon([closed]);
    return turf.area(polygon);
  }

  /**
   * Trouve l'intersection entre deux lignes
   */
  static findLineIntersection(line1Coords, line2Coords) {
    const line1 = turf.lineString(line1Coords);
    const line2 = turf.lineString(line2Coords);
    const intersects = turf.lineIntersect(line1, line2);
    
    return intersects.features.map(f => f.geometry.coordinates);
  }

  /**
   * Convertit des degrés en radians
   */
  static degreesToRadians(degrees) {
    return degrees * (Math.PI / 180);
  }

  /**
   * Convertit des radians en degrés
   */
  static radiansToDegrees(radians) {
    return radians * (180 / Math.PI);
  }

  /**
   * Calcule le centre d'une liste de coordonnées
   */
  static calculateCenter(coordinates) {
    const points = turf.featureCollection(
      coordinates.map(coord => turf.point(coord))
    );
    const center = turf.center(points);
    return center.geometry.coordinates;
  }

  /**
   * Rotate des coordonnées autour d'un point
   */
  static rotateCoordinates(coordinates, angle, pivot) {
    const line = turf.lineString(coordinates);
    const rotated = turf.transformRotate(line, angle, { pivot });
    return rotated.geometry.coordinates;
  }

  /**
   * Vérifie si deux lignes se croisent
   */
  static doLinesIntersect(line1Coords, line2Coords) {
    const line1 = turf.lineString(line1Coords);
    const line2 = turf.lineString(line2Coords);
    return turf.booleanCrosses(line1, line2);
  }

  /**
   * Calcule la pente entre deux points (en pourcentage)
   */
  static calculateGrade(coord1, coord2, elevation1, elevation2) {
    const distance = this.calculateDistance(coord1, coord2);
    const elevationChange = elevation2 - elevation1;
    
    if (distance === 0) return 0;
    
    return (elevationChange / distance) * 100;
  }

  /**
   * Lisse une ligne en utilisant une moyenne mobile
   */
  static smoothLine(coordinates, windowSize = 3) {
    if (coordinates.length <= windowSize) return coordinates;
    
    const smoothed = [];
    const halfWindow = Math.floor(windowSize / 2);
    
    for (let i = 0; i < coordinates.length; i++) {
      const start = Math.max(0, i - halfWindow);
      const end = Math.min(coordinates.length, i + halfWindow + 1);
      
      let sumLon = 0, sumLat = 0;
      let count = 0;
      
      for (let j = start; j < end; j++) {
        sumLon += coordinates[j][0];
        sumLat += coordinates[j][1];
        count++;
      }
      
      smoothed.push([sumLon / count, sumLat / count]);
    }
    
    return smoothed;
  }
}

module.exports = GeoUtils;