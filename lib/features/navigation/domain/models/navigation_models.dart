import 'package:equatable/equatable.dart';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// Point de tracking GPS avec timestamp
class TrackingPoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? accuracy;
  final double? heading;
  final DateTime timestamp;
  final double? bearing;
  final double? distance;

  const TrackingPoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.accuracy,
    this.heading,
    required this.timestamp,
    this.bearing,
    this.distance,
  });

  /// Créer à partir d'une position GPS
  factory TrackingPoint.fromPosition(Position position) {
    return TrackingPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: position.speed,
      accuracy: position.accuracy,
      heading: position.heading,
      timestamp: DateTime.now(),
    );
  }

  /// 🆕 COPIER AVEC NOUVELLES VALEURS CALCULÉES
  TrackingPoint copyWithCalculated({
    double? bearing,
    double? distance,
  }) {
    return TrackingPoint(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      speed: speed,
      accuracy: accuracy,
      heading: heading,
      timestamp: timestamp,
      bearing: bearing ?? this.bearing,
      distance: distance ?? this.distance,
    );
  }

  // 🔧 CORRECTION: Ajouter getter coordinates
  List<double> get coordinates => [longitude, latitude];

  /// 🆕 CALCULER DISTANCE VERS UN AUTRE POINT
  double distanceTo(TrackingPoint other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  /// 🆕 MÉTHODE distanceFrom - Distance vers un autre point
  double distanceFrom(TrackingPoint other) {
    return calculateDistance(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  /// 🆕 MÉTHODE calculateDistance statique - Calcul distance entre coordonnées
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // Rayon de la Terre en mètres
    const double degreesToRadians = math.pi / 180.0;

    final double lat1Rad = lat1 * degreesToRadians;
    final double lat2Rad = lat2 * degreesToRadians;
    final double deltaLatRad = (lat2 - lat1) * degreesToRadians;
    final double deltaLngRad = (lng2 - lng1) * degreesToRadians;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c; // Distance en mètres
  }

  /// 🆕 CALCULER BEARING VERS UN AUTRE POINT
  double bearingTo(TrackingPoint other) {
    const double degreesToRadians = math.pi / 180.0;
    const double radiansToDegrees = 180.0 / math.pi;

    final double lat1Rad = latitude * degreesToRadians;
    final double lat2Rad = other.latitude * degreesToRadians;
    final double deltaLngRad = (other.longitude - longitude) * degreesToRadians;

    final double y = math.sin(deltaLngRad) * math.cos(lat2Rad);
    final double x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLngRad);

    final double bearingRad = math.atan2(y, x);
    final double bearingDegrees = bearingRad * radiansToDegrees;

    return (bearingDegrees + 360) % 360;
  }

  /// 🆕 VÉRIFIER SI POSITION VALIDE
  bool get isValid {
    return latitude >= -90 && 
           latitude <= 90 && 
           longitude >= -180 && 
           longitude <= 180 &&
           (accuracy == null || accuracy! <= 100); // Précision acceptable
  }

  /// 🆕 OBTENIR VITESSE EN KM/H
  double get speedKmh => (speed ?? 0.0) * 3.6;

  /// 🆕 OBTENIR HEADING PRÉFÉRÉ (GPS ou calculé)
  double? getPreferredHeading(TrackingPoint? previousPoint) {
    // Préférer heading GPS si disponible et fiable
    if (heading != null && !heading!.isNaN && (speed ?? 0) > 1.0) {
      return heading;
    }
    
    // Sinon calculer depuis mouvement
    if (previousPoint != null) {
      return previousPoint.bearingTo(this);
    }
    
    return null;
  }

  @override
  String toString() {
    return 'TrackingPoint(lat: ${latitude.toStringAsFixed(6)}, '
           'lng: ${longitude.toStringAsFixed(6)}, '
           'speed: ${(speed ?? 0).toStringAsFixed(1)} m/s, '
           'accuracy: ${(accuracy ?? 0).toStringAsFixed(1)}m, '
           'heading: ${heading?.toStringAsFixed(1)}°)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrackingPoint &&
           other.latitude == latitude &&
           other.longitude == longitude &&
           other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^ 
           longitude.hashCode ^ 
           timestamp.hashCode;
  }
}

/// Métriques de navigation en temps réel
class NavigationMetrics extends Equatable {
  final Duration elapsedTime;
  final double distanceKm;
  final double currentSpeedKmh;
  final double averageSpeedKmh;
  final double currentAltitude;
  final double totalElevationGain;
  final double currentPaceSecPerKm;
  final double averagePaceSecPerKm;
  final Duration estimatedTimeRemaining;
  final double progressPercent;
  final double remainingDistanceKm;

  const NavigationMetrics({
    required this.elapsedTime,
    required this.distanceKm,
    required this.currentSpeedKmh,
    required this.averageSpeedKmh,
    required this.currentAltitude,
    required this.totalElevationGain,
    required this.currentPaceSecPerKm,
    required this.averagePaceSecPerKm,
    required this.estimatedTimeRemaining,
    required this.progressPercent,
    required this.remainingDistanceKm,
  });

  @override
  List<Object?> get props => [
    elapsedTime,
    distanceKm,
    currentSpeedKmh,
    averageSpeedKmh,
    currentAltitude,
    totalElevationGain,
    currentPaceSecPerKm,
    averagePaceSecPerKm,
    estimatedTimeRemaining,
    progressPercent,
    remainingDistanceKm,
  ];

  /// Métriques initiales (zéro)
  static const NavigationMetrics zero = NavigationMetrics(
    elapsedTime: Duration.zero,
    distanceKm: 0.0,
    currentSpeedKmh: 0.0,
    averageSpeedKmh: 0.0,
    currentAltitude: 0.0,
    totalElevationGain: 0.0,
    currentPaceSecPerKm: 0.0,
    averagePaceSecPerKm: 0.0,
    estimatedTimeRemaining: Duration.zero,
    progressPercent: 0.0,
    remainingDistanceKm: 0,
  );

  /// Formatage du temps écoulé
  String get formattedElapsedTime {
    final hours = elapsedTime.inHours;
    final minutes = elapsedTime.inMinutes.remainder(60);
    final seconds = elapsedTime.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Formatage du rythme (min:sec/km)
  String get formattedPace {
    if (currentPaceSecPerKm == 0 || currentPaceSecPerKm.isInfinite) {
      return '--:--';
    }
    
    final minutes = (currentPaceSecPerKm / 60).floor();
    final seconds = (currentPaceSecPerKm % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formatage du temps restant estimé
  String get formattedTimeRemaining {
    if (estimatedTimeRemaining == Duration.zero) {
      return '--:--';
    }
    
    final hours = estimatedTimeRemaining.inHours;
    final minutes = estimatedTimeRemaining.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }
}

/// État du statut de navigation
enum NavigationStatus {
  idle,      // Pas de navigation
  starting,  // Préparation de la navigation
  active,    // Navigation en cours
  paused,    // Navigation en pause
  finished,  // Navigation terminée
}

/// Données complètes de session de navigation
class NavigationSession extends Equatable {
  final String id;
  final List<List<double>> originalRoute; // Parcours original à suivre
  final List<TrackingPoint> trackingPoints; // Points trackés par l'utilisateur
  final NavigationMetrics metrics;
  final NavigationStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final double targetDistanceKm;

  const NavigationSession({
    required this.id,
    required this.originalRoute,
    required this.trackingPoints,
    required this.metrics,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.targetDistanceKm,
  });

  @override
  List<Object?> get props => [
    id,
    originalRoute,
    trackingPoints,
    metrics,
    status,
    startTime,
    endTime,
  ];

  /// Session initiale
  factory NavigationSession.initial({
    required List<List<double>> originalRoute,
  }) {
    return NavigationSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      originalRoute: originalRoute,
      trackingPoints: [],
      metrics: NavigationMetrics.zero,
      status: NavigationStatus.idle,
      startTime: DateTime.now(),
      targetDistanceKm: _polylineDistanceKm(originalRoute),
    );
  }

  /// Copier avec modifications
  NavigationSession copyWith({
    String? id,
    List<List<double>>? originalRoute,
    List<TrackingPoint>? trackingPoints,
    NavigationMetrics? metrics,
    NavigationStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    double? targetDistanceKm,
  }) {
    return NavigationSession(
      id: id ?? this.id,
      originalRoute: originalRoute ?? this.originalRoute,
      trackingPoints: trackingPoints ?? this.trackingPoints,
      metrics: metrics ?? this.metrics,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      targetDistanceKm: targetDistanceKm ?? this.targetDistanceKm
    );
  }

  // --- calcule la distance d'une polyline en km ---
  static double _polylineDistanceKm(List<List<double>> coords) {
    if (coords.length < 2) return 0;
    double m = 0;
    for (var i = 1; i < coords.length; i++) {
      m += TrackingPoint.calculateDistance(
        coords[i - 1][1], coords[i - 1][0],   // lat, lon
        coords[i][1],     coords[i][0],
      );
    }
    return m / 1000.0;
  }

  /// Coordonnées du tracé utilisateur pour affichage
  List<List<double>> get userTrackCoordinates {
    return trackingPoints.map((point) => point.coordinates).toList();
  }

  /// Durée totale de la session
  Duration get totalDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Distance totale en km
  double get totalDistanceKm => metrics.distanceKm;

  /// Vérifier si la navigation est active
  bool get isActive => status == NavigationStatus.active;

  /// Vérifier si la navigation est terminée
  bool get isFinished => status == NavigationStatus.finished;
}