import 'dart:math' as math;

/// Service pour optimiser et lisser les routes générées
class RouteOptimizerService {
  
  /// Optimise une route en supprimant les points redondants et en lissant le tracé
  static List<List<double>> optimizeRoute(List<List<double>> rawRoute) {
    if (rawRoute.length < 3) return rawRoute;
    
    // 1. Supprimer les doublons consécutifs
    var route = _removeDuplicates(rawRoute);
    
    // 2. Simplifier avec l'algorithme de Douglas-Peucker
    route = _douglasPeucker(route, 5.0); // Tolérance de 5 mètres
    
    // 3. Lisser les virages brusques
    route = _smoothSharpTurns(route);
    
    // 4. S'assurer que la route est continue
    route = _ensureContinuity(route);
    
    return route;
  }
  
  /// Supprime les points dupliqués consécutifs
  static List<List<double>> _removeDuplicates(List<List<double>> points) {
    if (points.isEmpty) return points;
    
    final result = <List<double>>[points.first];
    
    for (int i = 1; i < points.length; i++) {
      final prev = result.last;
      final curr = points[i];
      
      // Garder seulement si la distance est significative (> 1m)
      final dist = _calculateDistance(prev[1], prev[0], curr[1], curr[0]);
      if (dist > 1.0) {
        result.add(curr);
      }
    }
    
    return result;
  }
  
  /// Algorithme de Douglas-Peucker pour simplifier une polyligne
  static List<List<double>> _douglasPeucker(List<List<double>> points, double epsilon) {
    if (points.length < 3) return points;
    
    // Trouver le point le plus éloigné de la ligne entre le premier et le dernier point
    double maxDistance = 0;
    int maxIndex = 0;
    
    for (int i = 1; i < points.length - 1; i++) {
      final distance = _perpendicularDistance(
        points[i],
        points.first,
        points.last,
      );
      
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }
    
    // Si la distance max est plus grande que epsilon, subdiviser
    if (maxDistance > epsilon) {
      // Récursivement simplifier les deux sous-parties
      final left = _douglasPeucker(
        points.sublist(0, maxIndex + 1),
        epsilon,
      );
      final right = _douglasPeucker(
        points.sublist(maxIndex),
        epsilon,
      );
      
      // Combiner les résultats (sans dupliquer le point du milieu)
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      // Garder seulement les extrémités
      return [points.first, points.last];
    }
  }
  
  /// Calcule la distance perpendiculaire d'un point à une ligne
  static double _perpendicularDistance(
    List<double> point,
    List<double> lineStart,
    List<double> lineEnd,
  ) {
    final x0 = point[0];
    final y0 = point[1];
    final x1 = lineStart[0];
    final y1 = lineStart[1];
    final x2 = lineEnd[0];
    final y2 = lineEnd[1];
    
    final A = x0 - x1;
    final B = y0 - y1;
    final C = x2 - x1;
    final D = y2 - y1;
    
    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    
    double param = -1;
    if (lenSq != 0) {
      param = dot / lenSq;
    }
    
    double xx, yy;
    
    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * C;
      yy = y1 + param * D;
    }
    
    final dx = x0 - xx;
    final dy = y0 - yy;
    
    // Convertir en mètres (approximation)
    final latDist = dy * 111320; // 1 degré de latitude ≈ 111.32 km
    final lonDist = dx * 111320 * math.cos(y0 * math.pi / 180);
    
    return math.sqrt(latDist * latDist + lonDist * lonDist);
  }
  
  /// Lisse les virages trop brusques
  static List<List<double>> _smoothSharpTurns(List<List<double>> points) {
    if (points.length < 3) return points;
    
    final smoothed = <List<double>>[points.first];
    
    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];
      
      // Calculer l'angle du virage
      final angle = _calculateTurnAngle(prev, curr, next);
      
      // Si l'angle est trop aigu (< 45°), adoucir
      if (angle < 45) {
        // Ajouter un point intermédiaire pour adoucir le virage
        final mid1 = [
          (prev[0] * 0.75 + curr[0] * 0.25),
          (prev[1] * 0.75 + curr[1] * 0.25),
        ];
        final mid2 = [
          (curr[0] * 0.5 + next[0] * 0.5),
          (curr[1] * 0.5 + next[1] * 0.5),
        ];
        
        smoothed.add(mid1);
        smoothed.add(curr);
        smoothed.add(mid2);
      } else {
        smoothed.add(curr);
      }
    }
    
    smoothed.add(points.last);
    return smoothed;
  }
  
  /// Calcule l'angle d'un virage en degrés
  static double _calculateTurnAngle(
    List<double> p1,
    List<double> p2,
    List<double> p3,
  ) {
    final v1x = p1[0] - p2[0];
    final v1y = p1[1] - p2[1];
    final v2x = p3[0] - p2[0];
    final v2y = p3[1] - p2[1];
    
    final dot = v1x * v2x + v1y * v2y;
    final det = v1x * v2y - v1y * v2x;
    
    final angle = math.atan2(det, dot) * 180 / math.pi;
    return angle.abs();
  }
  
  /// S'assure que la route est continue (pas de sauts)
  static List<List<double>> _ensureContinuity(List<List<double>> points) {
    if (points.length < 2) return points;
    
    final continuous = <List<double>>[points.first];
    
    for (int i = 1; i < points.length; i++) {
      final prev = continuous.last;
      final curr = points[i];
      
      final dist = _calculateDistance(prev[1], prev[0], curr[1], curr[0]);
      
      // Si la distance est trop grande (> 100m), il y a probablement un saut
      if (dist > 100) {
        // Interpoler des points intermédiaires
        final steps = (dist / 50).ceil(); // Un point tous les 50m
        
        for (int j = 1; j < steps; j++) {
          final t = j / steps.toDouble();
          final interpLon = prev[0] + (curr[0] - prev[0]) * t;
          final interpLat = prev[1] + (curr[1] - prev[1]) * t;
          continuous.add([interpLon, interpLat]);
        }
      }
      
      continuous.add(curr);
    }
    
    return continuous;
  }
  
  /// Calcule la distance entre deux points en mètres
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Rayon de la Terre en mètres
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
              math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
  
  /// Valide que la route respecte les contraintes
  static bool validateRoute(
    List<List<double>> route,
    double targetDistanceKm,
    double tolerance,
  ) {
    if (route.isEmpty) return false;
    
    // Calculer la distance totale
    double totalDistance = 0;
    for (int i = 0; i < route.length - 1; i++) {
      totalDistance += _calculateDistance(
        route[i][1], route[i][0],
        route[i + 1][1], route[i + 1][0],
      );
    }
    
    final distanceKm = totalDistance / 1000;
    final error = (distanceKm - targetDistanceKm).abs() / targetDistanceKm;
    
    return error <= tolerance;
  }
}