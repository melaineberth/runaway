import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:runaway/features/home/domain/models/navigation_tracking_data.dart';

/// Service de tracking en temps réel pour la navigation
class NavigationTrackingService {
  static NavigationTrackingService? _instance;
  static NavigationTrackingService get instance => _instance ??= NavigationTrackingService._();
  
  NavigationTrackingService._();

  // État du tracking
  NavigationTrackingData? _trackingData;
  Timer? _updateTimer;
  
  // Stream controller pour émettre les mises à jour
  final StreamController<NavigationTrackingData> _trackingController = 
      StreamController<NavigationTrackingData>.broadcast();
  
  // Configuration
  static const Duration _updateInterval = Duration(seconds: 1);
  static const double _minMovementDistance = 2.0; // mètres minimum pour considérer un mouvement
  
  /// Stream des données de tracking
  Stream<NavigationTrackingData> get trackingStream => _trackingController.stream;
  
  /// Données actuelles de tracking
  NavigationTrackingData? get currentData => _trackingData;
  
  /// Indique si le tracking est actif
  bool get isTracking => _trackingData != null && !_trackingData!.isPaused;
  
  /// Démarre le tracking pour une navigation
  void startTracking({
    required double totalRouteDistance,
  }) {
    print('🎯 Démarrage du tracking navigation (${totalRouteDistance.toStringAsFixed(1)}km)');
    
    // Créer les données initiales
    _trackingData = NavigationTrackingData.initial(
      totalRouteDistance: totalRouteDistance,
    );
    
    // Démarrer les mises à jour périodiques
    _startPeriodicUpdates();
    
    // Émettre l'état initial
    _emitUpdate();
  }
  
  /// Met à jour la position actuelle
  void updatePosition(Position position) {
    if (_trackingData == null || _trackingData!.isPaused) return;
    
    final updatedData = _calculateTrackingMetrics(position);
    _trackingData = updatedData;
    _emitUpdate();
  }
  
  /// Met en pause ou reprend le tracking
  void togglePause() {
    if (_trackingData == null) return;
    
    if (_trackingData!.isPaused) {
      // Reprendre
      final now = DateTime.now();
      final pauseDuration = _trackingData!.pauseStartTime != null 
          ? now.difference(_trackingData!.pauseStartTime!)
          : Duration.zero;
      
      _trackingData = _trackingData!.copyWith(
        isPaused: false,
        pauseStartTime: null,
        totalPauseTime: _trackingData!.totalPauseTime + pauseDuration,
      );
      
      print('▶️ Navigation reprise (pause: ${_formatDuration(pauseDuration)})');
    } else {
      // Mettre en pause
      _trackingData = _trackingData!.copyWith(
        isPaused: true,
        pauseStartTime: DateTime.now(),
      );
      
      print('⏸️ Navigation mise en pause');
    }
    
    _emitUpdate();
  }
  
  /// Arrête le tracking
  void stopTracking() {
    print('🛑 Arrêt du tracking navigation');
    
    _updateTimer?.cancel();
    _updateTimer = null;
    
    if (_trackingData != null) {
      print('📊 Résumé final: ${_trackingData!}');
    }
    
    _trackingData = null;
  }
  
  /// Calcule toutes les métriques de tracking
  NavigationTrackingData _calculateTrackingMetrics(Position currentPosition) {
    final data = _trackingData!;
    final now = DateTime.now();
    
    // Copier les positions existantes et ajouter la nouvelle
    final updatedPositions = List<Position>.from(data.trackedPositions)..add(currentPosition);
    final updatedCoordinates = List<List<double>>.from(data.trackedCoordinates)
      ..add([currentPosition.longitude, currentPosition.latitude]);
    
    // Calculer la distance parcourue
    double newDistanceTraveled = data.distanceTraveled;
    if (data.trackedPositions.isNotEmpty) {
      final lastPosition = data.trackedPositions.last;
      final segmentDistance = Geolocator.distanceBetween(
        lastPosition.latitude,
        lastPosition.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );
      
      // Seulement ajouter si le mouvement est significatif
      if (segmentDistance >= _minMovementDistance) {
        newDistanceTraveled += segmentDistance / 1000; // Convertir en km
      }
    }
    
    // Calculer le temps écoulé (sans les pauses)
    final totalElapsed = now.difference(data.startTime);
    
    // Calculer l'élévation
    final currentElevation = currentPosition.altitude;
    double elevationGain = data.elevationGain;
    double elevationLoss = data.elevationLoss;
    
    if (data.trackedPositions.isNotEmpty) {
      final lastElevation = data.trackedPositions.last.altitude;
      final elevationDiff = currentElevation - lastElevation;
      
      if (elevationDiff > 1.0) { // Gain significatif
        elevationGain += elevationDiff;
      } else if (elevationDiff < -1.0) { // Perte significative
        elevationLoss += elevationDiff.abs();
      }
    }
    
    // Calculer les vitesses et rythmes
    final activeTime = totalElapsed - data.totalPauseTime;
    final activeHours = activeTime.inMilliseconds / (1000 * 60 * 60);
    
    double averageSpeed = 0.0;
    double averagePace = 0.0;
    double currentSpeed = currentPosition.speed * 3.6; // Convertir m/s en km/h
    double currentPace = 0.0;
    
    if (activeHours > 0 && newDistanceTraveled > 0) {
      averageSpeed = newDistanceTraveled / activeHours;
      averagePace = activeHours * 60 / newDistanceTraveled; // minutes par km
    }
    
    if (currentSpeed > 0.5) { // Seulement si on bouge
      currentPace = 60 / currentSpeed; // minutes par km
    }
    
    // Estimer le temps restant
    Duration estimatedTimeRemaining = Duration.zero;
    final remainingDistance = data.totalRouteDistance - newDistanceTraveled;
    if (averageSpeed > 0 && remainingDistance > 0) {
      final remainingHours = remainingDistance / averageSpeed;
      estimatedTimeRemaining = Duration(
        milliseconds: (remainingHours * 60 * 60 * 1000).round(),
      );
    }
    
    return data.copyWith(
      currentTime: now,
      distanceTraveled: newDistanceTraveled,
      currentSpeed: currentSpeed,
      averageSpeed: averageSpeed,
      currentElevation: currentElevation,
      elevationGain: elevationGain,
      elevationLoss: elevationLoss,
      elapsedTime: totalElapsed,
      estimatedTimeRemaining: estimatedTimeRemaining,
      averagePaceMinutesPerKm: averagePace,
      currentPaceMinutesPerKm: currentPace,
      trackedPositions: updatedPositions,
      trackedCoordinates: updatedCoordinates,
    );
  }
  
  /// Démarre les mises à jour périodiques
  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_updateInterval, (timer) {
      if (_trackingData != null && !_trackingData!.isPaused) {
        // Mettre à jour le temps écoulé même sans nouvelle position
        final now = DateTime.now();
        _trackingData = _trackingData!.copyWith(
          currentTime: now,
          elapsedTime: now.difference(_trackingData!.startTime),
        );
        _emitUpdate();
      }
    });
  }
  
  /// Émet une mise à jour via le stream
  void _emitUpdate() {
    if (_trackingData != null) {
      _trackingController.add(_trackingData!);
    }
  }
  
  /// Formate une durée pour l'affichage
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}m';
    } else {
      return '${minutes}m${seconds.toString().padLeft(2, '0')}s';
    }
  }
  
  /// Dispose le service
  void dispose() {
    _updateTimer?.cancel();
    _trackingController.close();
    _trackingData = null;
    print('🗑️ NavigationTrackingService disposé');
  }
  
  /// Réinitialise le service
  void reset() {
    stopTracking();
    print('🔄 NavigationTrackingService réinitialisé');
  }
}