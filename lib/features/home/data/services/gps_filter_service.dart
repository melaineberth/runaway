import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:runaway/features/home/domain/models/filtered_position.dart';
import 'kalman_filter.dart';
import 'gps_quality_analyzer.dart';

/// Service principal de filtrage GPS intégré
/// Combine le filtre de Kalman et l'analyse de qualité
class GPSFilterService {
  static GPSFilterService? _instance;
  static GPSFilterService get instance => _instance ??= GPSFilterService._();
  
  GPSFilterService._();

  // Composants de filtrage
  late final GPSKalmanFilter _kalmanFilter;
  late final GPSQualityAnalyzer _qualityAnalyzer;
  
  // Configuration
  late final GPSFilterConfig _config;
  
  // État du service
  bool _isInitialized = false;
  FilteredPosition? _lastFilteredPosition;
  
  // Stream controller pour les positions filtrées
  final StreamController<FilteredPosition> _positionController = 
      StreamController<FilteredPosition>.broadcast();
  
  // Statistiques en temps réel
  int _processedPositions = 0;
  int _rejectedPositions = 0;

  /// Stream des positions GPS filtrées
  Stream<FilteredPosition> get filteredPositionStream => _positionController.stream;

  /// Initialise le service de filtrage
  void initialize({GPSFilterConfig? config}) {
    _config = config ?? GPSFilterConfig.defaultConfig();
    _kalmanFilter = GPSKalmanFilter(processNoise: _config.processNoise);
    _qualityAnalyzer = GPSQualityAnalyzer();
    _isInitialized = true;
    
    print('🔧 GPS Filter Service initialisé avec config: $_config');
  }

  /// Traite une nouvelle position GPS brute
  FilteredPosition? processPosition(Position rawPosition) {
    if (!_isInitialized) {
      throw StateError('GPSFilterService doit être initialisé avant utilisation');
    }

    _processedPositions++;
    
    try {
      // 1. Analyse de qualité et détection d'anomalies
      final analysis = _qualityAnalyzer.analyzePosition(rawPosition);
      
      // 2. Décision de rejet
      if (analysis.shouldReject) {
        _rejectedPositions++;
        print('🚫 Position GPS rejetée: ${analysis.anomalyReasons.join(", ")}');
        
        // Retourner la dernière position valide si disponible
        return _lastFilteredPosition;
      }
      
      // 3. Filtrage Kalman
      final kalmanState = _kalmanFilter.update(
        rawPosition.latitude,
        rawPosition.longitude,
        rawPosition.accuracy,
        rawPosition.timestamp,
      );
      
      // 4. Création de la position filtrée
      final filteredPosition = FilteredPosition(
        // Position filtrée par Kalman
        latitude: kalmanState.filteredLatitude,
        longitude: kalmanState.filteredLongitude,
        altitude: rawPosition.altitude,
        accuracy: rawPosition.accuracy,
        speed: rawPosition.speed,
        heading: rawPosition.heading,
        timestamp: rawPosition.timestamp,
        
        // Métadonnées de filtrage
        confidence: analysis.confidence,
        isFiltered: analysis.isAnomalous,
        isRejected: false,
        smoothedSpeed: kalmanState.speed,
        smoothedHeading: kalmanState.heading,
        quality: analysis.quality,
        rawPosition: rawPosition,
      );
      
      // 5. Validation finale
      if (_isPositionValid(filteredPosition)) {
        _lastFilteredPosition = filteredPosition;
        
        // Émettre la position filtrée
        _positionController.add(filteredPosition);
        
        // Log périodique
        if (_processedPositions % 10 == 0) {
          final stats = _qualityAnalyzer.statistics;
          print('📊 GPS Stats: $stats');
        }
        
        return filteredPosition;
      } else {
        print('⚠️ Position filtrée invalide, retour à la dernière valide');
        return _lastFilteredPosition;
      }
      
    } catch (e) {
      print('❌ Erreur lors du filtrage GPS: $e');
      return _lastFilteredPosition;
    }
  }

  /// Traite un stream de positions GPS
  Stream<FilteredPosition> processPositionStream(Stream<Position> rawStream) {
    return rawStream
        .map((position) => processPosition(position))
        .where((position) => position != null)
        .cast<FilteredPosition>();
  }

  /// Valide qu'une position filtrée est cohérente
  bool _isPositionValid(FilteredPosition position) {
    // Vérifications de base
    if (position.latitude.abs() > 90 || position.longitude.abs() > 180) {
      return false;
    }
    
    // Vérification de cohérence avec la position précédente
    if (_lastFilteredPosition != null) {
      final distance = position.distanceTo(_lastFilteredPosition!);
      final timeDelta = position.timestamp
          .difference(_lastFilteredPosition!.timestamp)
          .inSeconds;
      
      if (timeDelta > 0) {
        final theoreticalSpeed = distance / timeDelta;
        // Vitesse théorique raisonnable
        if (theoreticalSpeed > _config.maxReasonableSpeed) {
          return false;
        }
      }
    }
    
    return true;
  }

  /// Obtient la dernière position filtrée
  FilteredPosition? get lastPosition => _lastFilteredPosition;

  /// Obtient les statistiques du service
  GPSFilterStatistics get statistics {
    final qualityStats = _qualityAnalyzer.statistics;
    
    return GPSFilterStatistics(
      processedPositions: _processedPositions,
      rejectedPositions: _rejectedPositions,
      filteredPositions: qualityStats.filteredPositions,
      rejectionRate: _processedPositions > 0 
          ? _rejectedPositions / _processedPositions 
          : 0.0,
      averageConfidence: _lastFilteredPosition?.confidence ?? 0.0,
      kalmanInitialized: _kalmanFilter.isInitialized,
      qualityStatistics: qualityStats,
    );
  }

  /// Obtient l'état actuel du filtre
  GPSFilterState get state {
    return GPSFilterState(
      isInitialized: _isInitialized,
      isTracking: _lastFilteredPosition != null,
      currentQuality: _lastFilteredPosition?.quality ?? GPSQuality.poor,
      currentConfidence: _lastFilteredPosition?.confidence ?? 0.0,
      lastUpdate: _lastFilteredPosition?.timestamp,
    );
  }

  /// Réinitialise le service
  void reset() {
    _kalmanFilter.reset();
    _qualityAnalyzer.reset();
    _lastFilteredPosition = null;
    _processedPositions = 0;
    _rejectedPositions = 0;
    print('🔄 GPS Filter Service réinitialisé');
  }

  /// Dispose le service
  void dispose() {
    _positionController.close();
    print('🗑️ GPS Filter Service fermé');
  }

  /// Configure les paramètres de filtrage en temps réel
  void updateConfig(GPSFilterConfig newConfig) {
    _config = newConfig;
    print('⚙️ Configuration GPS mise à jour: $_config');
  }

  /// Force une recalibration du filtre de Kalman
  void recalibrateKalman() {
    if (_lastFilteredPosition != null) {
      _kalmanFilter.initialize(
        _lastFilteredPosition!.latitude,
        _lastFilteredPosition!.longitude,
        _lastFilteredPosition!.accuracy,
      );
      print('🎯 Kalman Filter recalibré');
    }
  }
}

/// Configuration du service de filtrage GPS
class GPSFilterConfig {
  final double processNoise;
  final double maxReasonableSpeed;
  final double maxAccuracyThreshold;
  final double minMovementThreshold;
  final bool enableAnomalyDetection;
  final bool enableKalmanFiltering;

  const GPSFilterConfig({
    required this.processNoise,
    required this.maxReasonableSpeed,
    required this.maxAccuracyThreshold,
    required this.minMovementThreshold,
    required this.enableAnomalyDetection,
    required this.enableKalmanFiltering,
  });

  /// Configuration par défaut optimisée pour la navigation sportive
  factory GPSFilterConfig.defaultConfig() {
    return const GPSFilterConfig(
      processNoise: 0.1,
      maxReasonableSpeed: 50.0, // 180 km/h max
      maxAccuracyThreshold: 100.0, // 100m max
      minMovementThreshold: 2.0, // 2m min
      enableAnomalyDetection: true,
      enableKalmanFiltering: true,
    );
  }

  /// Configuration pour la course à pied
  factory GPSFilterConfig.forRunning() {
    return const GPSFilterConfig(
      processNoise: 0.05, // Plus précis pour la course
      maxReasonableSpeed: 15.0, // 54 km/h max pour course
      maxAccuracyThreshold: 50.0, // Plus strict
      minMovementThreshold: 1.0, // Plus sensible
      enableAnomalyDetection: true,
      enableKalmanFiltering: true,
    );
  }

  /// Configuration pour le vélo
  factory GPSFilterConfig.forCycling() {
    return const GPSFilterConfig(
      processNoise: 0.15, // Moins strict pour vitesses variables
      maxReasonableSpeed: 30.0, // 108 km/h max pour vélo
      maxAccuracyThreshold: 75.0,
      minMovementThreshold: 3.0,
      enableAnomalyDetection: true,
      enableKalmanFiltering: true,
    );
  }

  /// Configuration pour la marche
  factory GPSFilterConfig.forWalking() {
    return const GPSFilterConfig(
      processNoise: 0.02, // Très précis pour la marche
      maxReasonableSpeed: 8.0, // 28.8 km/h max pour marche
      maxAccuracyThreshold: 30.0, // Très strict
      minMovementThreshold: 0.5, // Très sensible
      enableAnomalyDetection: true,
      enableKalmanFiltering: true,
    );
  }

  @override
  String toString() {
    return 'GPSFilterConfig(noise: $processNoise, '
           'maxSpeed: ${maxReasonableSpeed}m/s, '
           'maxAccuracy: ${maxAccuracyThreshold}m)';
  }
}

/// Statistiques du service de filtrage
class GPSFilterStatistics {
  final int processedPositions;
  final int rejectedPositions;
  final int filteredPositions;
  final double rejectionRate;
  final double averageConfidence;
  final bool kalmanInitialized;
  final GPSStatistics qualityStatistics;

  GPSFilterStatistics({
    required this.processedPositions,
    required this.rejectedPositions,
    required this.filteredPositions,
    required this.rejectionRate,
    required this.averageConfidence,
    required this.kalmanInitialized,
    required this.qualityStatistics,
  });

  @override
  String toString() {
    return 'Filter Stats: $processedPositions traitées, '
           '$rejectedPositions rejetées (${(rejectionRate * 100).toStringAsFixed(1)}%), '
           'confiance moy: ${(averageConfidence * 100).toStringAsFixed(1)}%';
  }
}

/// État actuel du filtre GPS
class GPSFilterState {
  final bool isInitialized;
  final bool isTracking;
  final GPSQuality currentQuality;
  final double currentConfidence;
  final DateTime? lastUpdate;

  GPSFilterState({
    required this.isInitialized,
    required this.isTracking,
    required this.currentQuality,
    required this.currentConfidence,
    required this.lastUpdate,
  });

  /// Indique si le GPS est dans un état fiable
  bool get isReliable => 
      isTracking && 
      currentQuality != GPSQuality.unreliable && 
      currentConfidence > 0.5;

  @override
  String toString() {
    return 'GPS State: ${isTracking ? "tracking" : "stopped"}, '
           'quality: $currentQuality, '
           'confidence: ${(currentConfidence * 100).toStringAsFixed(1)}%';
  }
}