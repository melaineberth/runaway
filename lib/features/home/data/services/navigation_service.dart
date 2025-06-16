import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runaway/features/home/data/services/gps_filter_service.dart';
import 'package:runaway/features/home/domain/models/filtered_position.dart';
import 'dart:math' as math;

class NavigationService {
  static FlutterTts? _tts;
  static StreamSubscription<FilteredPosition>? _filteredPositionStream;
  static List<List<double>> _routeCoordinates = [];
  static int _currentWaypointIndex = 0;
  static bool _isNavigating = false;
  static Function(NavigationUpdate)? _onNavigationUpdate;
  
  static const double _waypointThreshold = 15.0; // 15 mètres pour considérer un waypoint atteint

  // Nouveau : Service de filtrage GPS
  static final GPSFilterService _gpsFilter = GPSFilterService.instance;

  /// Initialise le service de navigation
  static Future<void> initialize() async {
    _tts = FlutterTts();
    await _setupTTS();
    
    // Initialiser le service de filtrage GPS
    _gpsFilter.initialize();
    
    print('🧭 Navigation Service initialisé avec filtrage GPS avancé');
  }

  /// Configure le TTS (Text-To-Speech)
  static Future<void> _setupTTS() async {
    if (_tts == null) return;
    
    await _tts!.setLanguage("fr-FR");
    await _tts!.setSpeechRate(0.8);
    await _tts!.setVolume(0.8);
    await _tts!.setPitch(1.0);
  }

  /// Configure le filtrage GPS selon le type d'activité
  static void configureGPSFiltering({
    required String activityType,
    GPSFilterConfig? customConfig,
  }) {
    GPSFilterConfig config;
    
    if (customConfig != null) {
      config = customConfig;
    } else {
      switch (activityType.toLowerCase()) {
        case 'running':
          config = GPSFilterConfig.forRunning();
          break;
        case 'cycling':
          config = GPSFilterConfig.forCycling();
          break;
        case 'walking':
          config = GPSFilterConfig.forWalking();
          break;
        default:
          config = GPSFilterConfig.defaultConfig();
      }
    }
    
    _gpsFilter.updateConfig(config);
    
    print('⚙️ Filtrage GPS configuré pour: $activityType');
    print('📋 Config: $config');
  }

  /// Démarre la navigation custom avec filtrage GPS avancé
  static Future<bool> startCustomNavigation({
    required List<List<double>> coordinates,
    required Function(NavigationUpdate) onUpdate,
    String activityType = 'running',
  }) async {
    try {
      // Vérifier les permissions
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        throw Exception('Permission de localisation requise');
      }

      // Configurer le filtrage selon l'activité
      configureGPSFiltering(activityType: activityType);

      _routeCoordinates = List.from(coordinates);
      _currentWaypointIndex = 0;
      _isNavigating = true;
      _onNavigationUpdate = onUpdate;

      await _speak("Navigation démarrée avec GPS haute précision. Suivez les instructions.");

      // Démarrer le suivi de position avec filtrage
      _startFilteredPositionTracking();

      return true;
    } catch (e) {
      print('❌ Erreur démarrage navigation: $e');
      return false;
    }
  }

  /// Démarre le suivi de position avec filtrage GPS
  static void _startFilteredPositionTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // Très sensible pour le filtrage
    );

    // Stream des positions brutes
    final rawPositionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );

    // Traiter le stream avec le filtre GPS
    _filteredPositionStream = _gpsFilter
        .processPositionStream(rawPositionStream)
        .listen((FilteredPosition filteredPosition) {
      if (_isNavigating) {
        _handleFilteredPositionUpdate(filteredPosition);
      }
    });

    print('📡 Suivi GPS filtré démarré');
  }

  /// Gère les mises à jour de position filtrées
  static void _handleFilteredPositionUpdate(FilteredPosition filteredPosition) {
    if (_routeCoordinates.isEmpty || _currentWaypointIndex >= _routeCoordinates.length) {
      _finishNavigation();
      return;
    }

    final currentTarget = _routeCoordinates[_currentWaypointIndex];
    final distanceToTarget = _calculateDistance(
      filteredPosition.latitude,
      filteredPosition.longitude,
      currentTarget[1], // latitude
      currentTarget[0], // longitude
    );

    // Calculer la direction avec les données lissées
    final bearing = _calculateBearing(
      filteredPosition.latitude,
      filteredPosition.longitude,
      currentTarget[1],
      currentTarget[0],
    );

    final instruction = _generateInstruction(
      distanceToTarget,
      bearing,
      _currentWaypointIndex,
      filteredPosition,
    );

    // Envoyer une mise à jour enrichie
    if (_onNavigationUpdate != null) {
      _onNavigationUpdate!(NavigationUpdate(
        currentPosition: [filteredPosition.longitude, filteredPosition.latitude],
        targetPosition: currentTarget,
        distanceToTarget: distanceToTarget,
        bearing: bearing,
        instruction: instruction,
        waypointIndex: _currentWaypointIndex,
        totalWaypoints: _routeCoordinates.length,
        isFinished: false,
        // Nouvelles données de filtrage
        gpsQuality: filteredPosition.quality,
        confidence: filteredPosition.confidence,
        smoothedSpeed: filteredPosition.smoothedSpeed,
        smoothedHeading: filteredPosition.smoothedHeading,
        isFiltered: filteredPosition.isFiltered,
      ));
    }

    // Vérifier si on a atteint le waypoint (avec tolérance adaptative)
    final adaptiveThreshold = _calculateAdaptiveThreshold(filteredPosition);
    if (distanceToTarget <= adaptiveThreshold) {
      _currentWaypointIndex++;
      
      if (_currentWaypointIndex >= _routeCoordinates.length) {
        _finishNavigation();
      } else {
        _speak("Point intermédiaire atteint. Continuez.");
      }
    } else if (distanceToTarget > 200 && filteredPosition.confidence > 0.7) {
      // Instruction de direction seulement si confiance élevée
      final directionInstruction = _getDirectionInstruction(bearing);
      if (directionInstruction.isNotEmpty) {
        _speak(directionInstruction);
      }
    }

    // Log qualité GPS périodiquement
    if (_currentWaypointIndex % 10 == 0) {
      final stats = _gpsFilter.statistics;
      print('📊 $stats');
    }
  }

  /// Calcule un seuil adaptatif basé sur la qualité GPS
  static double _calculateAdaptiveThreshold(FilteredPosition position) {
    // Seuil de base
    double threshold = _waypointThreshold;
    
    // Ajuster selon la qualité GPS
    switch (position.quality) {
      case GPSQuality.excellent:
        threshold *= 0.8; // Plus strict avec excellent signal
        break;
      case GPSQuality.good:
        threshold *= 1.0; // Seuil normal
        break;
      case GPSQuality.fair:
        threshold *= 1.2; // Plus tolérant
        break;
      case GPSQuality.poor:
        threshold *= 1.5; // Très tolérant
        break;
      case GPSQuality.unreliable:
        threshold *= 2.0; // Extrêmement tolérant
        break;
    }
    
    // Ajuster selon la confiance
    threshold *= (2.0 - position.confidence); // Plus confiant = seuil plus strict
    
    return threshold.clamp(5.0, 50.0); // Entre 5m et 50m
  }

  /// Génère une instruction de navigation enrichie
  static String _generateInstruction(
    double distance,
    double bearing,
    int waypointIndex,
    FilteredPosition position,
  ) {
    if (distance <= _calculateAdaptiveThreshold(position)) {
      return waypointIndex == _routeCoordinates.length - 1 
          ? "Vous êtes arrivé à destination !"
          : "Point intermédiaire atteint";
    }

    final distanceText = distance < 1000 
        ? "${distance.round()} mètres"
        : "${(distance / 1000).toStringAsFixed(1)} kilomètres";

    final direction = _getDirectionText(bearing);
    
    // Ajouter info de qualité si GPS faible
    String qualityInfo = "";
    if (position.quality == GPSQuality.poor || position.quality == GPSQuality.unreliable) {
      qualityInfo = " (Signal GPS faible)";
    }
    
    return "Continuez $direction sur $distanceText$qualityInfo";
  }

  /// Convertit un bearing en instruction de direction
  static String _getDirectionText(double bearing) {
    final normalizedBearing = (bearing + 360) % 360;
    
    if (normalizedBearing >= 337.5 || normalizedBearing < 22.5) return "tout droit";
    if (normalizedBearing >= 22.5 && normalizedBearing < 67.5) return "au nord-est";
    if (normalizedBearing >= 67.5 && normalizedBearing < 112.5) return "à droite";
    if (normalizedBearing >= 112.5 && normalizedBearing < 157.5) return "au sud-est";
    if (normalizedBearing >= 157.5 && normalizedBearing < 202.5) return "en arrière";
    if (normalizedBearing >= 202.5 && normalizedBearing < 247.5) return "au sud-ouest";
    if (normalizedBearing >= 247.5 && normalizedBearing < 292.5) return "à gauche";
    if (normalizedBearing >= 292.5 && normalizedBearing < 337.5) return "au nord-ouest";
    
    return "tout droit";
  }

  /// Instruction vocale pour les grandes distances
  static String _getDirectionInstruction(double bearing) {
    final direction = _getDirectionText(bearing);
    return "Dirigez-vous $direction";
  }

  /// Termine la navigation
  static void _finishNavigation() {
    _isNavigating = false;
    _filteredPositionStream?.cancel();
    
    if (_onNavigationUpdate != null) {
      _onNavigationUpdate!(NavigationUpdate(
        currentPosition: [],
        targetPosition: [],
        distanceToTarget: 0,
        bearing: 0,
        instruction: "Navigation terminée !",
        waypointIndex: _routeCoordinates.length,
        totalWaypoints: _routeCoordinates.length,
        isFinished: true,
        gpsQuality: GPSQuality.good,
        confidence: 1.0,
        smoothedSpeed: 0.0,
        smoothedHeading: 0.0,
        isFiltered: false,
      ));
    }
    
    _speak("Félicitations ! Vous êtes arrivé à destination.");
    
    // Afficher statistiques finales
    final stats = _gpsFilter.statistics;
    print('📈 Navigation terminée - $stats');
  }

  /// Arrête la navigation manuellement
  static Future<void> stopNavigation() async {
    if (_isNavigating) {
      _isNavigating = false;
      _filteredPositionStream?.cancel();
      await _speak("Navigation arrêtée");
      
      if (_onNavigationUpdate != null) {
        _onNavigationUpdate!(NavigationUpdate(
          currentPosition: [],
          targetPosition: [],
          distanceToTarget: 0,
          bearing: 0,
          instruction: "Navigation arrêtée",
          waypointIndex: 0,
          totalWaypoints: 0,
          isFinished: true,
          gpsQuality: GPSQuality.good,
          confidence: 1.0,
          smoothedSpeed: 0.0,
          smoothedHeading: 0.0,
          isFiltered: false,
        ));
      }
      
      // Afficher statistiques
      final stats = _gpsFilter.statistics;
      print('🛑 Navigation arrêtée - $stats');
    }
  }

  /// Parle le texte donné
  static Future<void> _speak(String text) async {
    try {
      if (_tts != null) {
        await _tts!.speak(text);
      }
    } catch (e) {
      print('❌ Erreur TTS: $e');
    }
  }

  /// Vérifie les permissions de localisation
  static Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled;
  }

  /// Calcule la distance entre deux points (formule de Haversine)
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Rayon de la Terre en mètres
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// Calcule le bearing (direction) entre deux points
  static double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final double dLon = (lon2 - lon1) * math.pi / 180;
    final double lat1Rad = lat1 * math.pi / 180;
    final double lat2Rad = lat2 * math.pi / 180;
    
    final double y = math.sin(dLon) * math.cos(lat2Rad);
    final double x = math.cos(lat1Rad) * math.sin(lat2Rad) - 
                     math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    
    final double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  // Getters
  static bool get isNavigating => _isNavigating;
  static int get currentWaypointIndex => _currentWaypointIndex;
  static int get totalWaypoints => _routeCoordinates.length;
  
  // Nouveaux getters pour le filtrage GPS
  static GPSFilterState get gpsState => _gpsFilter.state;
  static GPSFilterStatistics get gpsStatistics => _gpsFilter.statistics;
  static FilteredPosition? get lastFilteredPosition => _gpsFilter.lastPosition;

  /// Recalibre le filtre GPS
  static void recalibrateGPS() {
    _gpsFilter.recalibrateKalman();
    print('🎯 GPS recalibré');
  }

  /// Dispose les ressources
  static Future<void> dispose() async {
    await stopNavigation();
    await _tts?.stop();
    _tts = null;
    _gpsFilter.dispose();
  }
}

/// Classe pour les mises à jour de navigation enrichie
class NavigationUpdate {
  final List<double> currentPosition;
  final List<double> targetPosition;
  final double distanceToTarget;
  final double bearing;
  final String instruction;
  final int waypointIndex;
  final int totalWaypoints;
  final bool isFinished;
  
  // Nouvelles propriétés GPS
  final GPSQuality gpsQuality;
  final double confidence;
  final double smoothedSpeed;
  final double smoothedHeading;
  final bool isFiltered;

  NavigationUpdate({
    required this.currentPosition,
    required this.targetPosition,
    required this.distanceToTarget,
    required this.bearing,
    required this.instruction,
    required this.waypointIndex,
    required this.totalWaypoints,
    required this.isFinished,
    required this.gpsQuality,
    required this.confidence,
    required this.smoothedSpeed,
    required this.smoothedHeading,
    required this.isFiltered,
  });

  /// Indique si la position GPS est fiable
  bool get isGPSReliable => 
      gpsQuality != GPSQuality.unreliable && 
      confidence > 0.5;

  /// Obtient un indicateur de qualité coloré
  String get qualityIndicator {
    switch (gpsQuality) {
      case GPSQuality.excellent:
        return '🟢'; // Vert
      case GPSQuality.good:
        return '🟡'; // Jaune
      case GPSQuality.fair:
        return '🟠'; // Orange
      case GPSQuality.poor:
        return '🔴'; // Rouge
      case GPSQuality.unreliable:
        return '⚫'; // Noir
    }
  }
}