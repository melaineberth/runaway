import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class NavigationService {
  static FlutterTts? _tts;
  static StreamSubscription<Position>? _positionStream;
  static List<List<double>> _routeCoordinates = [];
  static int _currentWaypointIndex = 0;
  static bool _isNavigating = false;
  static Function(NavigationUpdate)? _onNavigationUpdate;
  
  static const double _waypointThreshold = 15.0; // 15 mètres pour considérer un waypoint atteint

  /// Initialise le service de navigation
  static Future<void> initialize() async {
    _tts = FlutterTts();
    await _setupTTS();
  }

  /// Configure le TTS (Text-To-Speech)
  static Future<void> _setupTTS() async {
    if (_tts == null) return;
    
    await _tts!.setLanguage("fr-FR");
    await _tts!.setSpeechRate(0.8);
    await _tts!.setVolume(0.8);
    await _tts!.setPitch(1.0);
  }

  /// Démarre la navigation custom
  static Future<bool> startCustomNavigation({
    required List<List<double>> coordinates,
    required Function(NavigationUpdate) onUpdate,
  }) async {
    try {
      // Vérifier les permissions
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        throw Exception('Permission de localisation requise');
      }

      _routeCoordinates = List.from(coordinates);
      _currentWaypointIndex = 0;
      _isNavigating = true;
      _onNavigationUpdate = onUpdate;

      await _speak("Navigation démarrée. Suivez les instructions.");

      // Démarrer le suivi de position
      _startPositionTracking();

      return true;
    } catch (e) {
      print('❌ Erreur démarrage navigation custom: $e');
      return false;
    }
  }

  /// Démarre le suivi de position
  static void _startPositionTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Mise à jour tous les 5 mètres
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (_isNavigating) {
        _handlePositionUpdate(position);
      }
    });
  }

  /// Gère les mises à jour de position
  static void _handlePositionUpdate(Position position) {
    if (_routeCoordinates.isEmpty || _currentWaypointIndex >= _routeCoordinates.length) {
      _finishNavigation();
      return;
    }

    final currentTarget = _routeCoordinates[_currentWaypointIndex];
    final distanceToTarget = _calculateDistance(
      position.latitude,
      position.longitude,
      currentTarget[1], // latitude
      currentTarget[0], // longitude
    );

    // Calculer la direction
    final bearing = _calculateBearing(
      position.latitude,
      position.longitude,
      currentTarget[1],
      currentTarget[0],
    );

    final instruction = _generateInstruction(
      distanceToTarget,
      bearing,
      _currentWaypointIndex,
    );

    // Envoyer une mise à jour
    if (_onNavigationUpdate != null) {
      _onNavigationUpdate!(NavigationUpdate(
        currentPosition: [position.longitude, position.latitude],
        targetPosition: currentTarget,
        distanceToTarget: distanceToTarget,
        bearing: bearing,
        instruction: instruction,
        waypointIndex: _currentWaypointIndex,
        totalWaypoints: _routeCoordinates.length,
        isFinished: false,
      ));
    }

    // Vérifier si on a atteint le waypoint
    if (distanceToTarget <= _waypointThreshold) {
      _currentWaypointIndex++;
      
      if (_currentWaypointIndex >= _routeCoordinates.length) {
        _finishNavigation();
      } else {
        _speak("Point intermédiaire atteint. Continuez.");
      }
    } else if (distanceToTarget > 200) {
      // Instruction de direction si on est loin
      final directionInstruction = _getDirectionInstruction(bearing);
      if (directionInstruction.isNotEmpty) {
        _speak(directionInstruction);
      }
    }
  }

  /// Génère une instruction de navigation
  static String _generateInstruction(double distance, double bearing, int waypointIndex) {
    if (distance <= _waypointThreshold) {
      return waypointIndex == _routeCoordinates.length - 1 
          ? "Vous êtes arrivé à destination !"
          : "Point intermédiaire atteint";
    }

    final distanceText = distance < 1000 
        ? "${distance.round()} mètres"
        : "${(distance / 1000).toStringAsFixed(1)} kilomètres";

    final direction = _getDirectionText(bearing);
    
    return "Continuez $direction sur $distanceText";
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
    _positionStream?.cancel();
    
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
      ));
    }
    
    _speak("Félicitations ! Vous êtes arrivé à destination.");
  }

  /// Arrête la navigation manuellement
  static Future<void> stopNavigation() async {
    if (_isNavigating) {
      _isNavigating = false;
      _positionStream?.cancel();
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
        ));
      }
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

  /// Dispose les ressources
  static Future<void> dispose() async {
    await stopNavigation();
    await _tts?.stop();
    _tts = null;
  }
}

/// Classe pour les mises à jour de navigation
class NavigationUpdate {
  final List<double> currentPosition;
  final List<double> targetPosition;
  final double distanceToTarget;
  final double bearing;
  final String instruction;
  final int waypointIndex;
  final int totalWaypoints;
  final bool isFinished;

  NavigationUpdate({
    required this.currentPosition,
    required this.targetPosition,
    required this.distanceToTarget,
    required this.bearing,
    required this.instruction,
    required this.waypointIndex,
    required this.totalWaypoints,
    required this.isFinished,
  });
}