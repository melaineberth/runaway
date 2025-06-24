// lib/features/navigation/domain/models/navigation_models.dart
import 'package:equatable/equatable.dart';
import 'dart:math' as math;

/// Point de tracking GPS avec timestamp
class TrackingPoint extends Equatable {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed; // m/s
  final double accuracy;
  final DateTime timestamp;

  const TrackingPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.accuracy,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    altitude,
    speed,
    accuracy,
    timestamp,
  ];

  /// Convertir en liste de coordonnées pour affichage
  List<double> get coordinates => [longitude, latitude];

  /// Distance en mètres depuis un autre point
  double distanceFrom(TrackingPoint other) {
    return calculateDistance(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  /// Calcul de distance Haversine
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Rayon de la Terre en mètres
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return R * c;
  }

  static double _toRadians(double degree) => degree * math.pi / 180;
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

  const NavigationSession({
    required this.id,
    required this.originalRoute,
    required this.trackingPoints,
    required this.metrics,
    required this.status,
    required this.startTime,
    this.endTime,
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
  }) {
    return NavigationSession(
      id: id ?? this.id,
      originalRoute: originalRoute ?? this.originalRoute,
      trackingPoints: trackingPoints ?? this.trackingPoints,
      metrics: metrics ?? this.metrics,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
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