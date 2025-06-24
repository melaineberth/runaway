// lib/features/navigation/presentation/blocs/navigation/navigation_state.dart
import 'package:equatable/equatable.dart';
import 'package:runaway/features/navigation/domain/models/navigation_models.dart';

class NavigationState extends Equatable {
  final NavigationSession? currentSession;
  final bool isTracking;
  final bool isPaused;
  final String? errorMessage;
  final bool isSaving;
  final double targetDistanceKm;
  final String? routeName;

  const NavigationState({
    this.currentSession,
    this.isTracking = false,
    this.isPaused = false,
    this.errorMessage,
    this.isSaving = false,
    this.targetDistanceKm = 0.0,
    this.routeName,
  });

  @override
  List<Object?> get props => [
    currentSession,
    isTracking,
    isPaused,
    errorMessage,
    isSaving,
    targetDistanceKm,
    routeName,
  ];

  /// État initial
  static const NavigationState initial = NavigationState();

  /// Getter pour vérifier si une navigation est active
  bool get isNavigating => isTracking && !isPaused;

  /// Getter pour les métriques actuelles
  NavigationMetrics get metrics => currentSession?.metrics ?? NavigationMetrics.zero;

  /// Getter pour le statut de navigation
  NavigationStatus get status => currentSession?.status ?? NavigationStatus.idle;

  /// Getter pour vérifier si la navigation est terminée
  bool get isFinished => status == NavigationStatus.finished;

  /// Getter pour les points de tracking de l'utilisateur
  List<TrackingPoint> get trackingPoints => currentSession?.trackingPoints ?? [];

  /// Getter pour le parcours original
  List<List<double>> get originalRoute => currentSession?.originalRoute ?? [];

  /// Getter pour les coordonnées du tracé utilisateur
  List<List<double>> get userTrackCoordinates => currentSession?.userTrackCoordinates ?? [];

  /// Copier avec modifications
  NavigationState copyWith({
    NavigationSession? currentSession,
    bool? isTracking,
    bool? isPaused,
    String? errorMessage,
    bool? isSaving,
    double? targetDistanceKm,
    String? routeName,
  }) {
    return NavigationState(
      currentSession: currentSession ?? this.currentSession,
      isTracking: isTracking ?? this.isTracking,
      isPaused: isPaused ?? this.isPaused,
      errorMessage: errorMessage ?? this.errorMessage,
      isSaving: isSaving ?? this.isSaving,
      targetDistanceKm: targetDistanceKm ?? this.targetDistanceKm,
      routeName: routeName ?? this.routeName,
    );
  }

  /// Copier en effaçant l'erreur
  NavigationState clearError() {
    return copyWith(errorMessage: null);
  }

  /// Copier en réinitialisant complètement
  NavigationState reset() {
    return const NavigationState();
  }
}