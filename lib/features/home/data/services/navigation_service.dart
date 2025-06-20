import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:runaway/config/extensions.dart';

class NavigationService {
  static NavigationService? _instance;
  static bool _isInitialized = false;
  
  // FIX: Utiliser nullable au lieu de late pour éviter l'erreur
  List<List<double>>? _currentRoute;
  Function(NavigationUpdate)? _onUpdate;
  bool _isNavigating = false;

  NavigationService._();

  static NavigationService get instance {
    _instance ??= NavigationService._();
    return _instance!;
  }
  

  // FIX: Méthode d'initialisation sécurisée
  static void initialize() {
    if (!_isInitialized) {
      print('🧭 Initialisation NavigationService');
      _isInitialized = true;
    } else {
      print('🧭 NavigationService déjà initialisé');
    }
  }

  // FIX: Méthode pour réinitialiser si nécessaire
  static void reinitialize() {
    print('🧭 Réinitialisation NavigationService');
    _isInitialized = false;
    _instance = null;
    initialize();
  }

  static void dispose() {
    print('🧭 Disposal NavigationService');
    if (_instance != null) {
      _instance!._isNavigating = false;
      _instance!._currentRoute = null;
      _instance!._onUpdate = null;
    }
    _isInitialized = false;
    _instance = null;
  }

  static Future<bool> startCustomNavigation({
    required BuildContext context,
    required List<List<double>> coordinates,
    required Function(NavigationUpdate) onUpdate,
  }) async {
    try {
      // FIX: S'assurer que le service est initialisé
      if (!_isInitialized) {
        initialize();
      }

      final service = instance;
      
      // FIX: Arrêter la navigation précédente si elle existe
      if (service._isNavigating) {
        print('🧭 Arrêt de la navigation précédente');
        service._isNavigating = false;
      }

      print('🧭 Démarrage navigation personnalisée: ${coordinates.length} points');
      
      service._currentRoute = coordinates;
      service._onUpdate = onUpdate;
      service._isNavigating = true;

      // Simuler des mises à jour de navigation
      _simulateNavigation(context, service);

      return true;
    } catch (e) {
      print('❌ Erreur démarrage navigation: $e');
      return false;
    }
  }

  static void _simulateNavigation(BuildContext context, NavigationService service) async {
    if (service._currentRoute == null || !service._isNavigating) return;

    final route = service._currentRoute!;
    int currentIndex = 0;

    while (service._isNavigating && currentIndex < route.length - 1) {
      await Future.delayed(Duration(seconds: 2));
      
      if (!service._isNavigating) break;

      final currentPoint = route[currentIndex];
      final nextPoint = route[currentIndex + 1];
      
      // Calculer la distance restante
      double remainingDistance = 0;
      for (int i = currentIndex; i < route.length - 1; i++) {
        remainingDistance += _calculateDistance(
          route[i][1], route[i][0],
          route[i + 1][1], route[i + 1][0],
        );
      }

      final update = NavigationUpdate(
        currentPosition: currentPoint,
        nextWaypoint: nextPoint,
        distanceToTarget: remainingDistance,
        instruction: _generateInstruction(context, currentPoint, nextPoint, remainingDistance),
        waypointIndex: currentIndex,
        totalWaypoints: route.length,
        isFinished: currentIndex >= route.length - 2,
      );

      service._onUpdate?.call(update);

      if (update.isFinished) {
        service._isNavigating = false;
        break;
      }

      currentIndex++;
    }
  }

  static String _generateInstruction(
    BuildContext context,
    List<double> current,
    List<double> next,
    double remainingDistance,
  ) {
    if (remainingDistance < 50) {
      return context.l10n.arriveAtDestination;
    } else if (remainingDistance < 100) {
      return context.l10n.continueOn(remainingDistance.round());
    } else {
      return context.l10n.followPath((remainingDistance / 1000).toStringAsFixed(1));
    }
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Rayon de la Terre en mètres
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static void stopNavigation() {
    print('🧭 Arrêt de la navigation');
    if (_instance != null) {
      _instance!._isNavigating = false;
    }
  }

  static bool get isNavigating => _instance?._isNavigating ?? false;
}

// FIX: Classes de support avec des valeurs par défaut
class NavigationConfig {
  final int updateIntervalMs;
  final double proximityThreshold;
  final double maxBearingChange;
  final int positionHistorySize;

  const NavigationConfig({
    this.updateIntervalMs = 1000,
    this.proximityThreshold = 10.0,
    this.maxBearingChange = 15.0,
    this.positionHistorySize = 10,
  });
}

class NavigationUpdate {
  final List<double> currentPosition;
  final List<double> nextWaypoint;
  final double distanceToTarget;
  final String instruction;
  final int waypointIndex;
  final int totalWaypoints;
  final bool isFinished;

  NavigationUpdate({
    required this.currentPosition,
    required this.nextWaypoint,
    required this.distanceToTarget,
    required this.instruction,
    required this.waypointIndex,
    required this.totalWaypoints,
    required this.isFinished,
  });
}