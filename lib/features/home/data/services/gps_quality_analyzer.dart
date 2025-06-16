import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:runaway/features/home/domain/models/filtered_position.dart';

/// Service d'analyse de qualité GPS et détection d'anomalies
class GPSQualityAnalyzer {
  static const int _maxHistorySize = 20;
  static const double _maxReasonableSpeed = 50.0; // m/s (180 km/h)
  static const double _maxAccuracyThreshold = 100.0; // mètres
// mètres
  
  final List<FilteredPosition> _positionHistory = [];
  final List<double> _speedHistory = [];
  final List<double> _accuracyHistory = [];
  
  // Statistiques de qualité
  int _totalPositions = 0;
  int _rejectedPositions = 0;
  int _filteredPositions = 0;
  
  /// Analyse une position GPS et détermine sa qualité
  PositionAnalysis analyzePosition(Position position) {
    _totalPositions++;
    
    final quality = _determineQuality(position);
    final isAnomalous = _detectAnomalies(position);
    final confidence = _calculateConfidence(position, quality, isAnomalous);
    
    // Mettre à jour les historiques
    _updateHistories(position);
    
    final analysis = PositionAnalysis(
      position: position,
      quality: quality,
      confidence: confidence,
      isAnomalous: isAnomalous,
      shouldReject: _shouldRejectPosition(position, quality, isAnomalous),
      anomalyReasons: _getAnomalyReasons(position),
      qualityMetrics: _getQualityMetrics(position),
    );
    
    if (analysis.shouldReject) {
      _rejectedPositions++;
      print('🚫 Position GPS rejetée: ${analysis.anomalyReasons.join(", ")}');
    } else if (analysis.isAnomalous) {
      _filteredPositions++;
      print('⚠️ Position GPS suspecte: ${analysis.anomalyReasons.join(", ")}');
    }
    
    return analysis;
  }

  /// Détermine la qualité GPS basée sur la précision et d'autres facteurs
  GPSQuality _determineQuality(Position position) {
    final accuracy = position.accuracy;
    
    // Facteurs de qualité
    final accuracyScore = _scoreAccuracy(accuracy);
    final speedScore = _scoreSpeed(position.speed);
    final consistencyScore = _scoreConsistency(position);
    
    // Score global (moyenne pondérée)
    final totalScore = (accuracyScore * 0.5) + 
                      (speedScore * 0.2) + 
                      (consistencyScore * 0.3);
    
    if (totalScore >= 0.9) return GPSQuality.excellent;
    if (totalScore >= 0.7) return GPSQuality.good;
    if (totalScore >= 0.5) return GPSQuality.fair;
    if (totalScore >= 0.3) return GPSQuality.poor;
    return GPSQuality.unreliable;
  }

  /// Détecte les anomalies dans la position
  bool _detectAnomalies(Position position) {
    return _hasSpeedAnomaly(position) ||
           _hasAccuracyAnomaly(position) ||
           _hasJumpAnomaly(position) ||
           _hasTimestampAnomaly(position);
  }

  /// Détecte les anomalies de vitesse
  bool _hasSpeedAnomaly(Position position) {
    final speed = position.speed;
    
    // Vitesse impossibly élevée
    if (speed > _maxReasonableSpeed) {
      return true;
    }
    
    // Variation de vitesse trop importante
    if (_speedHistory.isNotEmpty) {
      final lastSpeed = _speedHistory.last;
      final speedDelta = (speed - lastSpeed).abs();
      final maxDelta = _maxReasonableSpeed * 0.5; // 50% de variation max
      
      if (speedDelta > maxDelta) {
        return true;
      }
    }
    
    return false;
  }

  /// Détecte les anomalies de précision
  bool _hasAccuracyAnomaly(Position position) {
    return position.accuracy > _maxAccuracyThreshold;
  }

  /// Détecte les sauts de position anormaux
  bool _hasJumpAnomaly(Position position) {
    if (_positionHistory.isEmpty) return false;
    
    final lastPosition = _positionHistory.last;
    final distance = Geolocator.distanceBetween(
      lastPosition.latitude,
      lastPosition.longitude,
      position.latitude,
      position.longitude,
    );
    
    final timeDelta = position.timestamp.difference(lastPosition.timestamp).inSeconds;
    if (timeDelta <= 0) return true;
    
    // Vitesse théorique basée sur le déplacement
    final theoreticalSpeed = distance / timeDelta;
    
    // Saut trop important par rapport au temps écoulé
    return theoreticalSpeed > _maxReasonableSpeed;
  }

  /// Détecte les anomalies de timestamp
  bool _hasTimestampAnomaly(Position position) {
    if (_positionHistory.isEmpty) return false;
    
    final lastPosition = _positionHistory.last;
    final timeDelta = position.timestamp.difference(lastPosition.timestamp);
    
    // Timestamp dans le futur ou trop ancien
    if (timeDelta.inSeconds < 0 || timeDelta.inSeconds > 60) {
      return true;
    }
    
    return false;
  }

  /// Calcule la confiance globale
  double _calculateConfidence(Position position, GPSQuality quality, bool isAnomalous) {
    double confidence = quality.confidence;
    
    // Réduire la confiance si anomalous
    if (isAnomalous) {
      confidence *= 0.5;
    }
    
    // Ajuster selon l'historique de qualité
    if (_positionHistory.isNotEmpty) {
      final recentQualityAvg = _getRecentQualityAverage();
      confidence = (confidence + recentQualityAvg) / 2;
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  /// Détermine si la position doit être rejetée
  bool _shouldRejectPosition(Position position, GPSQuality quality, bool isAnomalous) {
    // Rejeter si qualité trop faible
    if (quality == GPSQuality.unreliable) {
      return true;
    }
    
    // Rejeter si multiples anomalies
    final anomalyCount = _countAnomalies(position);
    if (anomalyCount >= 2) {
      return true;
    }
    
    // Rejeter si vitesse impossible
    if (position.speed > _maxReasonableSpeed) {
      return true;
    }
    
    return false;
  }

  /// Compte le nombre d'anomalies
  int _countAnomalies(Position position) {
    int count = 0;
    if (_hasSpeedAnomaly(position)) count++;
    if (_hasAccuracyAnomaly(position)) count++;
    if (_hasJumpAnomaly(position)) count++;
    if (_hasTimestampAnomaly(position)) count++;
    return count;
  }

  /// Obtient les raisons des anomalies
  List<String> _getAnomalyReasons(Position position) {
    final reasons = <String>[];
    
    if (_hasSpeedAnomaly(position)) {
      reasons.add('Vitesse anormale (${position.speed.toStringAsFixed(1)}m/s)');
    }
    if (_hasAccuracyAnomaly(position)) {
      reasons.add('Précision faible (${position.accuracy.toStringAsFixed(1)}m)');
    }
    if (_hasJumpAnomaly(position)) {
      reasons.add('Saut de position détecté');
    }
    if (_hasTimestampAnomaly(position)) {
      reasons.add('Timestamp anormal');
    }
    
    return reasons;
  }

  /// Obtient les métriques de qualité
  QualityMetrics _getQualityMetrics(Position position) {
    return QualityMetrics(
      accuracy: position.accuracy,
      speed: position.speed,
      satelliteCount: 0, // Non disponible dans Position standard
      signalStrength: _estimateSignalStrength(position.accuracy),
      hdop: _estimateHDOP(position.accuracy),
    );
  }

  /// Met à jour les historiques
  void _updateHistories(Position position) {
    final filteredPos = FilteredPosition.fromRawPosition(position);
    
    _positionHistory.add(filteredPos);
    _speedHistory.add(position.speed);
    _accuracyHistory.add(position.accuracy);
    
    // Limiter la taille des historiques
    if (_positionHistory.length > _maxHistorySize) {
      _positionHistory.removeAt(0);
    }
    if (_speedHistory.length > _maxHistorySize) {
      _speedHistory.removeAt(0);
    }
    if (_accuracyHistory.length > _maxHistorySize) {
      _accuracyHistory.removeAt(0);
    }
  }

  // === Fonctions de scoring ===

  double _scoreAccuracy(double accuracy) {
    if (accuracy <= 5) return 1.0;
    if (accuracy <= 10) return 0.8;
    if (accuracy <= 20) return 0.6;
    if (accuracy <= 50) return 0.4;
    return 0.2;
  }

  double _scoreSpeed(double speed) {
    if (speed < 0) return 0.0;
    if (speed > _maxReasonableSpeed) return 0.0;
    return 1.0; // Vitesse raisonnable
  }

  double _scoreConsistency(Position position) {
    if (_positionHistory.length < 3) return 0.5;
    
    // Calculer la cohérence avec les positions précédentes
    final recent = _positionHistory.take(3).toList();
    double consistency = 0.0;
    
    for (int i = 1; i < recent.length; i++) {
      final prev = recent[i - 1];
      final curr = recent[i];
      
      final distance = Geolocator.distanceBetween(
        prev.latitude, prev.longitude,
        curr.latitude, curr.longitude,
      );
      
      final timeDelta = curr.timestamp.difference(prev.timestamp).inSeconds;
      if (timeDelta > 0) {
        final speed = distance / timeDelta;
        if (speed <= _maxReasonableSpeed) {
          consistency += 1.0;
        }
      }
    }
    
    return consistency / (recent.length - 1);
  }

  /// Obtient la moyenne de qualité récente
  double _getRecentQualityAverage() {
    if (_positionHistory.length < 3) return 0.5;
    
    final recent = _positionHistory.take(5);
    final total = recent.fold(0.0, (sum, pos) => sum + pos.confidence);
    return total / recent.length;
  }

  /// Estime la force du signal basée sur la précision
  double _estimateSignalStrength(double accuracy) {
    if (accuracy <= 5) return 5.0;
    if (accuracy <= 10) return 4.0;
    if (accuracy <= 20) return 3.0;
    if (accuracy <= 50) return 2.0;
    return 1.0;
  }

  /// Estime le HDOP basé sur la précision
  double _estimateHDOP(double accuracy) {
    // HDOP approximatif basé sur la précision
    return math.max(1.0, accuracy / 5.0);
  }

  // === Getters pour les statistiques ===

  GPSStatistics get statistics => GPSStatistics(
    totalPositions: _totalPositions,
    rejectedPositions: _rejectedPositions,
    filteredPositions: _filteredPositions,
    rejectionRate: _totalPositions > 0 ? _rejectedPositions / _totalPositions : 0.0,
    averageAccuracy: _accuracyHistory.isNotEmpty 
        ? _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length 
        : 0.0,
    averageSpeed: _speedHistory.isNotEmpty 
        ? _speedHistory.reduce((a, b) => a + b) / _speedHistory.length 
        : 0.0,
  );

  /// Réinitialise l'analyseur
  void reset() {
    _positionHistory.clear();
    _speedHistory.clear();
    _accuracyHistory.clear();
    _totalPositions = 0;
    _rejectedPositions = 0;
    _filteredPositions = 0;
    print('🔄 GPS Quality Analyzer réinitialisé');
  }
}

/// Résultat de l'analyse d'une position
class PositionAnalysis {
  final Position position;
  final GPSQuality quality;
  final double confidence;
  final bool isAnomalous;
  final bool shouldReject;
  final List<String> anomalyReasons;
  final QualityMetrics qualityMetrics;

  PositionAnalysis({
    required this.position,
    required this.quality,
    required this.confidence,
    required this.isAnomalous,
    required this.shouldReject,
    required this.anomalyReasons,
    required this.qualityMetrics,
  });
}

/// Métriques de qualité GPS
class QualityMetrics {
  final double accuracy;
  final double speed;
  final int satelliteCount;
  final double signalStrength;
  final double hdop;

  QualityMetrics({
    required this.accuracy,
    required this.speed,
    required this.satelliteCount,
    required this.signalStrength,
    required this.hdop,
  });
}

/// Statistiques GPS globales
class GPSStatistics {
  final int totalPositions;
  final int rejectedPositions;
  final int filteredPositions;
  final double rejectionRate;
  final double averageAccuracy;
  final double averageSpeed;

  GPSStatistics({
    required this.totalPositions,
    required this.rejectedPositions,
    required this.filteredPositions,
    required this.rejectionRate,
    required this.averageAccuracy,
    required this.averageSpeed,
  });

  @override
  String toString() {
    return 'GPS Stats: $totalPositions total, '
           '$rejectedPositions rejetées (${(rejectionRate * 100).toStringAsFixed(1)}%), '
           'précision moy: ${averageAccuracy.toStringAsFixed(1)}m';
  }
}