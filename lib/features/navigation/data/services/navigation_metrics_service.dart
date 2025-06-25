// lib/features/navigation/data/services/navigation_metrics_service.dart
import 'dart:math' as math;
import '../../domain/models/navigation_models.dart';

/// Service pour calculer les métriques de navigation en temps réel
class NavigationMetricsService {
  
  /// Calculer les métriques à partir des points de tracking
  static NavigationMetrics calculateMetrics({
    required List<TrackingPoint> trackingPoints,
    required List<List<double>> originalRoute,
    required DateTime startTime,
    double targetDistanceKm = 0.0,
  }) {
    if (trackingPoints.isEmpty) {
      return NavigationMetrics.zero;
    }

    final currentTime = DateTime.now();
    final elapsedTime = currentTime.difference(startTime);
    
    // Calculs de base
    final distanceKm = _calculateTotalDistance(trackingPoints);
    final currentAltitude = trackingPoints.last.altitude ?? 0.0;
    final elevationGain = _calculateElevationGain(trackingPoints);
    
    // Calculs de vitesse
    final currentSpeedKmh = _calculateCurrentSpeed(trackingPoints);
    final averageSpeedKmh = _calculateAverageSpeed(distanceKm, elapsedTime);
    
    // Calculs de rythme (pace)
    final currentPaceSecPerKm = _calculateCurrentPace(currentSpeedKmh);
    final averagePaceSecPerKm = _calculateAveragePace(distanceKm, elapsedTime);
    
    // Calculs de progression
    final progressPercent = _calculateProgress(distanceKm, targetDistanceKm);
    final estimatedTimeRemaining = _calculateEstimatedTimeRemaining(
      distanceKm,
      targetDistanceKm,
      averageSpeedKmh,
    );

    final remainingDistanceKm = _calculateRemainingDistance(
      trackingPoints: trackingPoints,
      originalRoute: originalRoute,
      targetDistanceKm: targetDistanceKm,
      travelledKm: distanceKm,
    );

    return NavigationMetrics(
      elapsedTime: elapsedTime,
      distanceKm: distanceKm,
      currentSpeedKmh: currentSpeedKmh,
      averageSpeedKmh: averageSpeedKmh,
      currentAltitude: currentAltitude,
      totalElevationGain: elevationGain,
      currentPaceSecPerKm: currentPaceSecPerKm,
      averagePaceSecPerKm: averagePaceSecPerKm,
      estimatedTimeRemaining: estimatedTimeRemaining,
      progressPercent: progressPercent,
      remainingDistanceKm: remainingDistanceKm,
    );
  }

  /// Calculer la distance totale parcourue
  static double _calculateTotalDistance(List<TrackingPoint> points) {
    if (points.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < points.length; i++) {
      totalDistance += points[i].distanceFrom(points[i - 1]); // ✅ Méthode maintenant définie
    }

    return totalDistance / 1000.0; // Convertir en km
  }

  /// Calculer le dénivelé positif total
  static double _calculateElevationGain(List<TrackingPoint> points) {
    if (points.length < 2) return 0.0;

    double totalGain = 0.0;
    for (int i = 1; i < points.length; i++) {
      // 🔧 FIX: Gestion des altitudes nullables
      final currentAlt = points[i].altitude ?? 0.0;
      final previousAlt = points[i - 1].altitude ?? 0.0;
      final altitudeDiff = currentAlt - previousAlt;
      
      if (altitudeDiff > 0) {
        totalGain += altitudeDiff;
      }
    }

    return totalGain;
  }

  /// Calculer la vitesse actuelle (basée sur les derniers points)
  static double _calculateCurrentSpeed(List<TrackingPoint> points) {
    if (points.isEmpty) return 0.0;

    // Utiliser la vitesse du GPS si disponible
    final lastPoint = points.last;
    final speed = lastPoint.speed ?? 0.0; // 🔧 FIX: Gestion nullable
    if (speed > 0) {
      return speed * 3.6; // Convertir m/s en km/h
    }

    // Sinon calculer à partir des derniers points (sur 30 secondes max)
    final now = DateTime.now();
    final recentPoints = points.where((point) {
      return now.difference(point.timestamp).inSeconds <= 30;
    }).toList();

    if (recentPoints.length < 2) return 0.0;

    final distance = _calculateTotalDistance(recentPoints) * 1000; // en mètres
    final timeSeconds = recentPoints.last.timestamp
        .difference(recentPoints.first.timestamp)
        .inSeconds;

    if (timeSeconds <= 0) return 0.0;

    final speedMs = distance / timeSeconds;
    return speedMs * 3.6; // Convertir en km/h
  }

  /// Calculer la vitesse moyenne
  static double _calculateAverageSpeed(double distanceKm, Duration elapsedTime) {
    if (elapsedTime.inSeconds <= 0) return 0.0;
    return distanceKm / (elapsedTime.inSeconds / 3600.0);
  }

  /// Calculer le rythme actuel (secondes par km)
  static double _calculateCurrentPace(double speedKmh) {
    if (speedKmh <= 0) return 0.0;
    return 3600.0 / speedKmh; // secondes par km
  }

  /// Calculer le rythme moyen (secondes par km)
  static double _calculateAveragePace(double distanceKm, Duration elapsedTime) {
    if (distanceKm <= 0) return 0.0;
    return elapsedTime.inSeconds / distanceKm;
  }

  /// Calculer le pourcentage de progression
  static double _calculateProgress(double currentDistanceKm, double targetDistanceKm) {
    if (targetDistanceKm <= 0) return 0.0;
    return math.min(100.0, (currentDistanceKm / targetDistanceKm) * 100.0);
  }

  /// Estimer le temps restant
  static Duration _calculateEstimatedTimeRemaining(
    double currentDistanceKm,
    double targetDistanceKm,
    double averageSpeedKmh,
  ) {
    if (averageSpeedKmh <= 0 || targetDistanceKm <= currentDistanceKm) {
      return Duration.zero;
    }

    final remainingDistanceKm = targetDistanceKm - currentDistanceKm;
    final remainingTimeHours = remainingDistanceKm / averageSpeedKmh;
    return Duration(seconds: (remainingTimeHours * 3600).round());
  }

  /// Calculer la distance restante jusqu'à la fin du parcours original
  static double calculateDistanceToRouteEnd({
    required TrackingPoint currentPosition,
    required List<List<double>> originalRoute,
  }) {
    if (originalRoute.isEmpty) return 0.0;

    // Trouver le point le plus proche sur le parcours original
    final closestPointIndex = _findClosestRoutePoint(currentPosition, originalRoute);
    
    // Calculer la distance depuis ce point jusqu'à la fin
    double remainingDistance = 0.0;
    for (int i = closestPointIndex; i < originalRoute.length - 1; i++) {
      final point1 = originalRoute[i];
      final point2 = originalRoute[i + 1];
      remainingDistance += TrackingPoint.calculateDistance(
        point1[1], point1[0],
        point2[1], point2[0],
      );
    }

    return remainingDistance / 1000.0; // Convertir en km
  }

  /// Trouver l'index du point le plus proche sur le parcours original
  static int _findClosestRoutePoint(
    TrackingPoint currentPosition,
    List<List<double>> originalRoute,
  ) {
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < originalRoute.length; i++) {
      final routePoint = originalRoute[i];
      final distance = TrackingPoint.calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        routePoint[1], // latitude
        routePoint[0], // longitude
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// Vérifier si l'utilisateur suit bien le parcours (dans un rayon de tolérance)
  static bool isOnRoute({
    required TrackingPoint currentPosition,
    required List<List<double>> originalRoute,
    double toleranceMeters = 50.0,
  }) {
    if (originalRoute.isEmpty) return true;

    final closestIndex = _findClosestRoutePoint(currentPosition, originalRoute);
    final closestPoint = originalRoute[closestIndex];
    
    final distance = TrackingPoint.calculateDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      closestPoint[1], // latitude
      closestPoint[0], // longitude
    );

    return distance <= toleranceMeters;
  }

  /// Calculer les statistiques finales à la fin de la navigation
  static Map<String, dynamic> calculateFinalStats(NavigationSession session) {
    final metrics = session.metrics;
    final duration = session.totalDuration;
    
    // 🔧 FIX: Fonction helper pour gérer max/min avec nullables
    double safeMax(List<double?> values) {
      final nonNullValues = values.where((v) => v != null).map((v) => v!).toList();
      return nonNullValues.isNotEmpty ? nonNullValues.reduce(math.max) : 0.0;
    }
    
    double safeMin(List<double?> values) {
      final nonNullValues = values.where((v) => v != null).map((v) => v!).toList();
      return nonNullValues.isNotEmpty ? nonNullValues.reduce(math.min) : 0.0;
    }
    
    return {
      'total_distance_km': metrics.distanceKm,
      'total_duration_seconds': duration.inSeconds,
      'average_speed_kmh': metrics.averageSpeedKmh,
      'average_pace_sec_per_km': metrics.averagePaceSecPerKm,
      'total_elevation_gain_m': metrics.totalElevationGain,
      'max_altitude_m': session.trackingPoints.isNotEmpty 
          ? safeMax(session.trackingPoints.map((p) => p.altitude).toList())
          : 0.0,
      'min_altitude_m': session.trackingPoints.isNotEmpty
          ? safeMin(session.trackingPoints.map((p) => p.altitude).toList())
          : 0.0,
      'tracking_points_count': session.trackingPoints.length,
      'start_time': session.startTime.toIso8601String(),
      'end_time': session.endTime?.toIso8601String(),
    };
  }

  static double _calculateRemainingDistance({
    required List<TrackingPoint> trackingPoints,
    required List<List<double>> originalRoute,
    required double targetDistanceKm,
    required double travelledKm,
  }) {
    // 1️⃣ cible explicite (ex. footing 10 km)
    if (targetDistanceKm > 0) {
      return math.max(0, targetDistanceKm - travelledKm);
    }

    // 2️⃣ on suit un GPX : calculer la distance le long du tracé
    if (originalRoute.isNotEmpty) {
      return calculateDistanceToRouteEnd(
        currentPosition: trackingPoints.last,
        originalRoute: originalRoute,
      );
    }

    // 3️⃣ aucune info ➜ 0
    return 0.0;
  }
}