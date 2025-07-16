// lib/core/config/navigation_config.dart
// 🚀 CONFIGURATION GLOBALE POUR NAVIGATION ULTRA-FLUIDE

class NavigationConfig {
  // === RÉGLAGES GPS HAUTE PERFORMANCE ===
  
  /// 🎯 Distance minimale entre mises à jour GPS (mètres)
  /// 0 = capture chaque mouvement pour fluidité maximale
  static const double GPS_DISTANCE_FILTER = 0;
  
  /// ⏱️ Timeout acquisition position initiale
  static const Duration GPS_INITIAL_TIMEOUT = Duration(seconds: 10);
  
  /// 🎯 Précision GPS maximale acceptée (mètres)
  /// Positions moins précises sont ignorées pour éviter les saccades
  static const double GPS_MAX_ACCURACY = 30.0;
  
  /// 🚀 Intervalle minimum entre positions pour éviter spam
  static const Duration GPS_MIN_INTERVAL = Duration(milliseconds: 100);
  
  /// 📏 Distance minimale de mouvement pour calculer direction (mètres)
  static const double MIN_MOVEMENT_DISTANCE = 0.5;
  
  // === RÉGLAGES COMPASS & ORIENTATION ===
  
  /// 🧭 Fréquence mise à jour orientation (20 FPS)
  static const Duration COMPASS_UPDATE_INTERVAL = Duration(milliseconds: 50);
  
  /// 🎯 Seuil changement orientation minimum (degrés)
  /// Plus bas = plus sensible, plus fluide
  static const double COMPASS_HEADING_THRESHOLD = 0.5;
  
  /// 🌀 Facteur lissage orientation (0.0-1.0)
  /// Plus bas = plus fluide, plus haut = plus réactif
  static const double COMPASS_SMOOTHING_FACTOR = 0.15;
  
  /// ⏱️ Fréquence timer lissage (60 FPS)
  static const Duration SMOOTHING_TIMER_INTERVAL = Duration(milliseconds: 16);
  
  /// ⏰ Timeout détection compass indisponible
  static const Duration COMPASS_DETECTION_TIMEOUT = Duration(seconds: 3);
  
  // === RÉGLAGES CAMÉRA & ANIMATIONS ===
  
  /// 🎬 Durée animation reset orientation
  static const Duration CAMERA_RESET_DURATION = Duration(milliseconds: 400);
  
  /// 📹 Zoom par défaut pour navigation
  static const double NAVIGATION_ZOOM_LEVEL = 18.0;
  
  /// 🎯 Pitch caméra pour navigation
  static const double NAVIGATION_CAMERA_PITCH = 0.0;
  
  /// 🚀 Utiliser setCamera au lieu de flyTo pour performance max
  static const bool USE_INSTANT_CAMERA_UPDATES = true;
  
  /// ⏱️ Fréquence maximum mise à jour caméra (30 FPS)
  static const Duration CAMERA_UPDATE_INTERVAL = Duration(milliseconds: 33);
  
  // === RÉGLAGES FLÈCHE UTILISATEUR ===
  
  /// 📏 Taille flèche utilisateur
  static const double ARROW_SIZE = 1.2;
  
  /// 🎯 Ancrage flèche
  static const String ARROW_ANCHOR = 'CENTER';
  
  /// 🖼️ ID image flèche dans style Mapbox
  static const String ARROW_IMAGE_ID = 'navigation_arrow';
  
  /// 🚀 Seuil minimum vitesse pour orienter flèche (km/h)
  /// En dessous, la flèche garde sa dernière orientation
  static const double MIN_SPEED_FOR_ARROW_ROTATION = 1.0;
  
  // === RÉGLAGES TRACÉ UTILISATEUR ===
  
  /// 🎨 Largeur ligne tracé utilisateur
  static const double USER_TRACK_WIDTH = 6.0;
  
  /// 🌈 Opacité ligne tracé utilisateur
  static const double USER_TRACK_OPACITY = 0.9;
  
  /// 📏 Points minimum pour afficher tracé
  static const int MIN_POINTS_FOR_TRACK = 2;
  
  // === RÉGLAGES PARCOURS ===
  
  /// 🎨 Largeur ligne parcours
  static const double ROUTE_LINE_WIDTH = 5.0;
  
  /// 🌈 Opacité ligne parcours
  static const double ROUTE_LINE_OPACITY = 0.8;
  
  /// 📐 Marge pour ajustement vue parcours
  static const double ROUTE_BOUNDS_MARGIN = 0.002;
  
  // === RÉGLAGES UI & ANIMATIONS ===
  
  /// 🎬 Durée animations métriques
  static const Duration METRICS_ANIMATION_DURATION = Duration(milliseconds: 200);
  
  /// 💫 Durée animation pulse
  static const Duration PULSE_ANIMATION_DURATION = Duration(milliseconds: 1200);
  
  /// ⏰ Délai initialisation carte
  static const Duration MAP_INITIALIZATION_DELAY = Duration(milliseconds: 300);
  
  /// 🎯 Délai démarrage navigation après init carte
  static const Duration NAVIGATION_START_DELAY = Duration(milliseconds: 500);
  
  // === RÉGLAGES PERFORMANCE ===
  
  /// 🚀 Cache positions identiques pour éviter recalculs
  static const bool ENABLE_POSITION_CACHING = true;
  
  /// 📊 Nombre maximum points tracking en mémoire
  static const int MAX_TRACKING_POINTS = 10000;
  
  /// 🧹 Nettoyage automatique anciens points
  static const Duration TRACKING_CLEANUP_INTERVAL = Duration(minutes: 5);
  
  /// ⚡ Throttling intelligent mises à jour
  static const bool ENABLE_INTELLIGENT_THROTTLING = true;
  
  // === RÉGLAGES DEBUG ===
  
  /// 🐛 Afficher logs debug navigation
  static const bool DEBUG_NAVIGATION = true;
  
  /// 📍 Afficher logs positions GPS
  static const bool DEBUG_GPS_POSITIONS = true;
  
  /// 🧭 Afficher logs orientation compass
  static const bool DEBUG_COMPASS = true;
  
  /// 📹 Afficher logs mises à jour caméra
  static const bool DEBUG_CAMERA_UPDATES = false; // Peut être verbeux
  
  // === MÉTHODES UTILITAIRES ===
  
  /// 🎯 Vérifier si une précision GPS est acceptable
  static bool isGpsAccuracyAcceptable(double accuracy) {
    return accuracy <= GPS_MAX_ACCURACY;
  }
  
  /// 🧭 Normaliser un angle 0-360°
  static double normalizeHeading(double heading) {
    double normalized = heading % 360;
    if (normalized < 0) normalized += 360;
    return normalized;
  }
  
  /// 🌀 Calculer différence angulaire circulaire
  static double calculateAngularDifference(double angle1, double angle2) {
    double diff = (angle2 - angle1).abs();
    if (diff > 180) diff = 360 - diff;
    return diff;
  }
  
  /// ⏱️ Vérifier si assez de temps écoulé pour mise à jour
  static bool shouldUpdatePosition(DateTime lastUpdate) {
    return DateTime.now().difference(lastUpdate) >= GPS_MIN_INTERVAL;
  }
  
  /// 🎯 Vérifier si mouvement suffisant pour calculer direction
  static bool isMovementSignificant(double distance) {
    return distance >= MIN_MOVEMENT_DISTANCE;
  }
  
  /// 🚀 Vérifier si vitesse suffisante pour orientation flèche
  static bool shouldRotateArrow(double speedKmh) {
    return speedKmh >= MIN_SPEED_FOR_ARROW_ROTATION;
  }
  
  /// 📐 Convertir degrés en radians
  static double degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180.0);
  }
  
  /// 📐 Convertir radians en degrés
  static double radiansToDegrees(double radians) {
    return radians * (180.0 / 3.14159265359);
  }
  
  /// 🎨 Obtenir configuration EdgeInsets pour bounds carte
  static Map<String, double> getMapBoundsInsets() {
    return {
      'top': 120.0,
      'left': 60.0,
      'bottom': 220.0,
      'right': 60.0,
    };
  }
  
  /// 📱 Configuration LocationSettings optimisée
  static Map<String, dynamic> getOptimizedLocationSettings() {
    return {
      'accuracy': 'bestForNavigation',
      'distanceFilter': GPS_DISTANCE_FILTER,
      'timeLimit': GPS_INITIAL_TIMEOUT.inSeconds,
    };
  }
  
  /// 🎯 Configuration caméra navigation optimisée
  static Map<String, dynamic> getOptimizedCameraConfig() {
    return {
      'zoom': NAVIGATION_ZOOM_LEVEL,
      'pitch': NAVIGATION_CAMERA_PITCH,
      'useInstantUpdates': USE_INSTANT_CAMERA_UPDATES,
      'updateInterval': CAMERA_UPDATE_INTERVAL.inMilliseconds,
    };
  }
}