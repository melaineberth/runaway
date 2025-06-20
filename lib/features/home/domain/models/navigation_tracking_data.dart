import 'package:geolocator/geolocator.dart';

/// Données de tracking en temps réel pour la navigation
class NavigationTrackingData {
  final DateTime startTime;
  final DateTime? currentTime;
  final double distanceTraveled; // en km
  final double totalRouteDistance; // en km
  final double currentSpeed; // en km/h
  final double averageSpeed; // en km/h
  final double currentElevation; // en mètres
  final double elevationGain; // en mètres
  final double elevationLoss; // en mètres
  final Duration elapsedTime;
  final Duration estimatedTimeRemaining;
  final double averagePaceMinutesPerKm; // en minutes par km
  final double currentPaceMinutesPerKm; // en minutes par km
  final List<Position> trackedPositions;
  final List<List<double>> trackedCoordinates; // Pour la polyligne
  final bool isPaused;
  final DateTime? pauseStartTime;
  final Duration totalPauseTime;

  const NavigationTrackingData({
    required this.startTime,
    this.currentTime,
    this.distanceTraveled = 0.0,
    this.totalRouteDistance = 0.0,
    this.currentSpeed = 0.0,
    this.averageSpeed = 0.0,
    this.currentElevation = 0.0,
    this.elevationGain = 0.0,
    this.elevationLoss = 0.0,
    this.elapsedTime = Duration.zero,
    this.estimatedTimeRemaining = Duration.zero,
    this.averagePaceMinutesPerKm = 0.0,
    this.currentPaceMinutesPerKm = 0.0,
    this.trackedPositions = const [],
    this.trackedCoordinates = const [],
    this.isPaused = false,
    this.pauseStartTime,
    this.totalPauseTime = Duration.zero,
  });

  /// Distance restante en km
  double get remainingDistance => (totalRouteDistance - distanceTraveled).clamp(0.0, double.infinity);

  /// Pourcentage de progression
  double get progressPercentage => totalRouteDistance > 0 
      ? (distanceTraveled / totalRouteDistance * 100).clamp(0.0, 100.0) 
      : 0.0;

  /// Temps d'activité (sans les pauses)
  Duration get activeTime => isPaused 
      ? elapsedTime - totalPauseTime - (DateTime.now().difference(pauseStartTime ?? DateTime.now()))
      : elapsedTime - totalPauseTime;

  NavigationTrackingData copyWith({
    DateTime? startTime,
    DateTime? currentTime,
    double? distanceTraveled,
    double? totalRouteDistance,
    double? currentSpeed,
    double? averageSpeed,
    double? currentElevation,
    double? elevationGain,
    double? elevationLoss,
    Duration? elapsedTime,
    Duration? estimatedTimeRemaining,
    double? averagePaceMinutesPerKm,
    double? currentPaceMinutesPerKm,
    List<Position>? trackedPositions,
    List<List<double>>? trackedCoordinates,
    bool? isPaused,
    DateTime? pauseStartTime,
    Duration? totalPauseTime,
  }) {
    return NavigationTrackingData(
      startTime: startTime ?? this.startTime,
      currentTime: currentTime ?? this.currentTime,
      distanceTraveled: distanceTraveled ?? this.distanceTraveled,
      totalRouteDistance: totalRouteDistance ?? this.totalRouteDistance,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      currentElevation: currentElevation ?? this.currentElevation,
      elevationGain: elevationGain ?? this.elevationGain,
      elevationLoss: elevationLoss ?? this.elevationLoss,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      estimatedTimeRemaining: estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      averagePaceMinutesPerKm: averagePaceMinutesPerKm ?? this.averagePaceMinutesPerKm,
      currentPaceMinutesPerKm: currentPaceMinutesPerKm ?? this.currentPaceMinutesPerKm,
      trackedPositions: trackedPositions ?? this.trackedPositions,
      trackedCoordinates: trackedCoordinates ?? this.trackedCoordinates,
      isPaused: isPaused ?? this.isPaused,
      pauseStartTime: pauseStartTime ?? this.pauseStartTime,
      totalPauseTime: totalPauseTime ?? this.totalPauseTime,
    );
  }

  /// Créer une instance initiale
  factory NavigationTrackingData.initial({
    required double totalRouteDistance,
  }) {
    return NavigationTrackingData(
      startTime: DateTime.now(),
      totalRouteDistance: totalRouteDistance,
    );
  }

  @override
  String toString() {
    return 'NavigationTrackingData('
           'distance: ${distanceTraveled.toStringAsFixed(2)}km, '
           'speed: ${currentSpeed.toStringAsFixed(1)}km/h, '
           'pace: ${averagePaceMinutesPerKm.toStringAsFixed(1)}min/km, '
           'elapsed: ${_formatDuration(elapsedTime)}, '
           'paused: $isPaused)';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}m${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${minutes}m${seconds.toString().padLeft(2, '0')}s';
    }
  }
}