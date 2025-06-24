// lib/features/navigation/presentation/blocs/navigation/navigation_event.dart
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

abstract class NavigationEvent extends Equatable {
  const NavigationEvent();

  @override
  List<Object?> get props => [];
}

/// Démarrer une nouvelle session de navigation
class NavigationStarted extends NavigationEvent {
  final List<List<double>> originalRoute;
  final double targetDistanceKm;
  final String? routeName;

  const NavigationStarted({
    required this.originalRoute,
    required this.targetDistanceKm,
    this.routeName,
  });

  @override
  List<Object?> get props => [originalRoute, targetDistanceKm, routeName];
}

/// Mettre en pause la navigation
class NavigationPaused extends NavigationEvent {
  const NavigationPaused();
}

/// Reprendre la navigation
class NavigationResumed extends NavigationEvent {
  const NavigationResumed();
}

/// Arrêter/terminer la navigation
class NavigationStopped extends NavigationEvent {
  const NavigationStopped();
}

/// Nouvelle position GPS reçue
class NavigationPositionUpdated extends NavigationEvent {
  final Position position;

  const NavigationPositionUpdated(this.position);

  @override
  List<Object?> get props => [position];
}

/// Mise à jour du timer (chaque seconde)
class NavigationTimerTick extends NavigationEvent {
  const NavigationTimerTick();
}

/// Réinitialiser complètement l'état de navigation
class NavigationReset extends NavigationEvent {
  const NavigationReset();
}

/// Sauvegarder la session actuelle
class NavigationSessionSaved extends NavigationEvent {
  final String sessionName;

  const NavigationSessionSaved(this.sessionName);

  @override
  List<Object?> get props => [sessionName];
}