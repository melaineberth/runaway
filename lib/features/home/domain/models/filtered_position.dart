import 'package:geolocator/geolocator.dart';

/// Position GPS filtrée avec métadonnées de qualité
class FilteredPosition {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speed;
  final double heading;
  final DateTime timestamp;
  
  // Métadonnées de filtrage
  final double confidence; // 0.0 à 1.0
  final bool isFiltered; // true si la position a été filtrée
  final bool isRejected; // true si la position était aberrante
  final double smoothedSpeed;
  final double smoothedHeading;
  final GPSQuality quality;
  
  // Données brutes pour comparaison
  final Position rawPosition;

  const FilteredPosition({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.timestamp,
    required this.confidence,
    required this.isFiltered,
    required this.isRejected,
    required this.smoothedSpeed,
    required this.smoothedHeading,
    required this.quality,
    required this.rawPosition,
  });

  /// Crée une FilteredPosition à partir d'une Position brute
  factory FilteredPosition.fromRawPosition(
    Position position, {
    double confidence = 1.0,
    bool isFiltered = false,
    bool isRejected = false,
    double? smoothedSpeed,
    double? smoothedHeading,
    GPSQuality quality = GPSQuality.good,
  }) {
    return FilteredPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      timestamp: position.timestamp,
      confidence: confidence,
      isFiltered: isFiltered,
      isRejected: isRejected,
      smoothedSpeed: smoothedSpeed ?? position.speed,
      smoothedHeading: smoothedHeading ?? position.heading,
      quality: quality,
      rawPosition: position,
    );
  }

  /// Convertit en Position standard pour compatibilité
  Position toPosition() {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      accuracy: accuracy,
      altitude: altitude,
      altitudeAccuracy: rawPosition.altitudeAccuracy,
      heading: smoothedHeading,
      headingAccuracy: rawPosition.headingAccuracy,
      speed: smoothedSpeed,
      speedAccuracy: rawPosition.speedAccuracy,
    );
  }

  /// Copie avec de nouveaux paramètres
  FilteredPosition copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    double? speed,
    double? heading,
    DateTime? timestamp,
    double? confidence,
    bool? isFiltered,
    bool? isRejected,
    double? smoothedSpeed,
    double? smoothedHeading,
    GPSQuality? quality,
  }) {
    return FilteredPosition(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
      isFiltered: isFiltered ?? this.isFiltered,
      isRejected: isRejected ?? this.isRejected,
      smoothedSpeed: smoothedSpeed ?? this.smoothedSpeed,
      smoothedHeading: smoothedHeading ?? this.smoothedHeading,
      quality: quality ?? this.quality,
      rawPosition: rawPosition,
    );
  }

  /// Calcule la distance par rapport à une autre position
  double distanceTo(FilteredPosition other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  /// Calcule le bearing vers une autre position
  double bearingTo(FilteredPosition other) {
    return Geolocator.bearingBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  @override
  String toString() {
    return 'FilteredPosition(lat: ${latitude.toStringAsFixed(6)}, '
           'lon: ${longitude.toStringAsFixed(6)}, '
           'confidence: ${confidence.toStringAsFixed(2)}, '
           'quality: $quality, '
           'speed: ${smoothedSpeed.toStringAsFixed(1)}m/s)';
  }
}

/// Énumération pour la qualité GPS
enum GPSQuality {
  excellent(confidence: 0.95, description: 'Signal excellent'),
  good(confidence: 0.8, description: 'Signal bon'),
  fair(confidence: 0.6, description: 'Signal correct'),
  poor(confidence: 0.4, description: 'Signal faible'),
  unreliable(confidence: 0.2, description: 'Signal non fiable');

  const GPSQuality({
    required this.confidence,
    required this.description,
  });

  final double confidence;
  final String description;

  /// Détermine la qualité basée sur la précision
  static GPSQuality fromAccuracy(double accuracy) {
    if (accuracy <= 5) return GPSQuality.excellent;
    if (accuracy <= 10) return GPSQuality.good;
    if (accuracy <= 20) return GPSQuality.fair;
    if (accuracy <= 50) return GPSQuality.poor;
    return GPSQuality.unreliable;
  }
}