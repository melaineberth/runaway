class RouteInfoTracker {
  static final RouteInfoTracker _instance = RouteInfoTracker._internal();
  static RouteInfoTracker get instance => _instance;
  RouteInfoTracker._internal();

  bool _isRouteInfoActive = false;

  /// Marque RouteInfoCard comme actif
  void setRouteInfoActive(bool active) {
    _isRouteInfoActive = active;
  }

  /// Vérifie si RouteInfoCard est actuellement affiché
  bool get isRouteInfoActive => _isRouteInfoActive;
}