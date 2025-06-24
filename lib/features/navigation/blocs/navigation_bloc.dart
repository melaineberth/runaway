// lib/features/navigation/presentation/blocs/navigation/navigation_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runaway/features/navigation/data/services/navigation_metrics_service.dart';
import 'package:runaway/features/navigation/domain/models/navigation_models.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  bool _hasReceivedFirstPosition = false; // 🆕 Flag pour première position

  NavigationBloc() : super(NavigationState.initial) {
    on<NavigationStarted>(_onNavigationStarted);
    on<NavigationPaused>(_onNavigationPaused);
    on<NavigationResumed>(_onNavigationResumed);
    on<NavigationStopped>(_onNavigationStopped);
    on<NavigationPositionUpdated>(_onNavigationPositionUpdated);
    on<NavigationTimerTick>(_onNavigationTimerTick);
    on<NavigationReset>(_onNavigationReset);
    on<NavigationSessionSaved>(_onNavigationSessionSaved);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    return super.close();
  }

  /// Démarrer la navigation
  Future<void> _onNavigationStarted(
    NavigationStarted event,
    Emitter<NavigationState> emit,
  ) async {
    try {
      print('🚀 === DÉBUT NAVIGATION ===');
      print('📍 Route: ${event.originalRoute.length} points');
      print('📏 Distance cible: ${event.targetDistanceKm}km');

      // Réinitialiser le flag de première position
      _hasReceivedFirstPosition = false;

      // Créer une nouvelle session
      final session = NavigationSession.initial(
        originalRoute: event.originalRoute,
      ).copyWith(
        status: NavigationStatus.starting,
      );

      emit(state.copyWith(
        currentSession: session,
        isTracking: true,
        isPaused: false,
        targetDistanceKm: event.targetDistanceKm,
        routeName: event.routeName,
        errorMessage: null,
      ));

      // 🔧 DÉMARRER LE GPS EN PREMIER
      await _startLocationTracking();

      // 🔧 ATTENDRE LA PREMIÈRE POSITION AVANT DE MARQUER COMME ACTIF
      // Le passage à "active" se fera dans _onNavigationPositionUpdated

      print('✅ Navigation en attente de première position GPS');

    } catch (e) {
      print('❌ Erreur démarrage navigation: $e');
      emit(state.copyWith(
        errorMessage: 'Erreur lors du démarrage: $e',
        isTracking: false,
      ));
    }
  }

  /// Mettre en pause
  void _onNavigationPaused(
    NavigationPaused event,
    Emitter<NavigationState> emit,
  ) {
    print('⏸️ Navigation mise en pause');
    
    _timer?.cancel();
    _positionSubscription?.cancel();

    if (state.currentSession != null) {
      final pausedSession = state.currentSession!.copyWith(
        status: NavigationStatus.paused,
      );
      emit(state.copyWith(
        currentSession: pausedSession,
        isPaused: true,
      ));
    }
  }

  /// Reprendre
  Future<void> _onNavigationResumed(
    NavigationResumed event,
    Emitter<NavigationState> emit,
  ) async {
    print('▶️ Navigation reprise');

    _startTimer();
    await _startLocationTracking();

    if (state.currentSession != null) {
      final activeSession = state.currentSession!.copyWith(
        status: NavigationStatus.active,
      );
      emit(state.copyWith(
        currentSession: activeSession,
        isPaused: false,
      ));
    }
  }

  /// Arrêter/terminer
  void _onNavigationStopped(
    NavigationStopped event,
    Emitter<NavigationState> emit,
  ) {
    print('🏁 === NAVIGATION TERMINÉE ===');

    _timer?.cancel();
    _positionSubscription?.cancel();
    _hasReceivedFirstPosition = false; // 🔧 Reset du flag

    if (state.currentSession != null) {
      final finishedSession = state.currentSession!.copyWith(
        status: NavigationStatus.finished,
        endTime: DateTime.now(),
      );

      emit(state.copyWith(
        currentSession: finishedSession,
        isTracking: false,
        isPaused: false,
      ));

      // Afficher les statistiques finales
      final finalStats = NavigationMetricsService.calculateFinalStats(finishedSession);
      print('📊 Statistiques finales: $finalStats');
    }
  }

  /// Nouvelle position GPS
  void _onNavigationPositionUpdated(
    NavigationPositionUpdated event,
    Emitter<NavigationState> emit,
  ) {
    if (!state.isTracking || state.currentSession == null) return;

    final position = event.position;
    
    // Créer un nouveau point de tracking
    final trackingPoint = TrackingPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: position.speed,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
    );

    // Ajouter le point à la session
    final updatedPoints = List<TrackingPoint>.from(state.trackingPoints)
      ..add(trackingPoint);

    // 🔧 GESTION SPÉCIALE PREMIÈRE POSITION
    if (!_hasReceivedFirstPosition) {
      print('📍 === PREMIÈRE POSITION REÇUE ===');
      print('📍 Latitude: ${position.latitude.toStringAsFixed(6)}');
      print('📍 Longitude: ${position.longitude.toStringAsFixed(6)}');
      print('📍 Précision: ${position.accuracy.toStringAsFixed(1)}m');
      
      _hasReceivedFirstPosition = true;
      
      // Marquer la session comme active maintenant qu'on a une position
      final activeSession = state.currentSession!.copyWith(
        status: NavigationStatus.active,
        trackingPoints: updatedPoints,
      );

      // Démarrer le timer maintenant
      _startTimer();

      emit(state.copyWith(currentSession: activeSession));
      
      print('✅ Navigation activée avec première position');
      return;
    }

    // Calculer les nouvelles métriques pour les positions suivantes
    final newMetrics = NavigationMetricsService.calculateMetrics(
      trackingPoints: updatedPoints,
      originalRoute: state.originalRoute,
      startTime: state.currentSession!.startTime,
      targetDistanceKm: state.targetDistanceKm,
    );

    // Mettre à jour la session
    final updatedSession = state.currentSession!.copyWith(
      trackingPoints: updatedPoints,
      metrics: newMetrics,
    );

    emit(state.copyWith(currentSession: updatedSession));

    // Debug des métriques (moins verbose après la première position)
    if (updatedPoints.length % 10 == 0) { // Log toutes les 10 positions
      print('📍 Distance: ${newMetrics.distanceKm.toStringAsFixed(2)}km, Vitesse: ${newMetrics.currentSpeedKmh.toStringAsFixed(1)}km/h');
    }
  }

  /// Tick du timer (chaque seconde)
  void _onNavigationTimerTick(
    NavigationTimerTick event,
    Emitter<NavigationState> emit,
  ) {
    if (!state.isNavigating || state.currentSession == null) return;

    // Recalculer les métriques avec le temps écoulé mis à jour
    final newMetrics = NavigationMetricsService.calculateMetrics(
      trackingPoints: state.trackingPoints,
      originalRoute: state.originalRoute,
      startTime: state.currentSession!.startTime,
      targetDistanceKm: state.targetDistanceKm,
    );

    final updatedSession = state.currentSession!.copyWith(metrics: newMetrics);
    emit(state.copyWith(currentSession: updatedSession));
  }

  /// Réinitialiser
  void _onNavigationReset(
    NavigationReset event,
    Emitter<NavigationState> emit,
  ) {
    print('🔄 Réinitialisation navigation');
    
    _timer?.cancel();
    _positionSubscription?.cancel();
    _hasReceivedFirstPosition = false; // 🔧 Reset du flag

    emit(NavigationState.initial);
  }

  /// Sauvegarder la session
  Future<void> _onNavigationSessionSaved(
    NavigationSessionSaved event,
    Emitter<NavigationState> emit,
  ) async {
    if (state.currentSession == null) return;

    try {
      emit(state.copyWith(isSaving: true));

      // TODO: Implémenter la sauvegarde en base de données
      // await _saveSessionToDatabase(state.currentSession!, event.sessionName);

      print('💾 Session sauvegardée: ${event.sessionName}');
      
      emit(state.copyWith(isSaving: false));

    } catch (e) {
      print('❌ Erreur sauvegarde session: $e');
      emit(state.copyWith(
        isSaving: false,
        errorMessage: 'Erreur de sauvegarde: $e',
      ));
    }
  }

  /// Démarrer le timer de mise à jour
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isNavigating) { // Seulement si navigation active
        add(const NavigationTimerTick());
      }
    });
    print('⏱️ Timer de navigation démarré');
  }

  /// Démarrer le tracking GPS
  Future<void> _startLocationTracking() async {
    try {
      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permissions de localisation refusées';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Permissions de localisation définitivement refusées';
      }

      // 🔧 CONFIGURATION OPTIMISÉE POUR PREMIÈRE POSITION
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1, // Plus sensible pour capturer la première position rapidement
        timeLimit: Duration(seconds: 30), // Timeout pour éviter d'attendre indéfiniment
      );

      print('📡 Démarrage tracking GPS avec configuration optimisée...');

      // Démarrer le stream de positions
      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) {
          // Vérifier la précision de la position
          if (position.accuracy > 100) {
            print('⚠️ Position imprécise (${position.accuracy.toStringAsFixed(1)}m), attente meilleure précision...');
            return;
          }
          
          add(NavigationPositionUpdated(position));
        },
        onError: (error) {
          print('❌ Erreur GPS: $error');
          add(NavigationStopped());
        },
      );

      // 🆕 OBTENIR UNE POSITION IMMÉDIATE POUR DÉMARRER PLUS VITE
      try {
        print('🎯 Tentative d\'obtention d\'une position immédiate...');
        final currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 10),
        );
        
        if (currentPosition.accuracy <= 50) { // Seulement si précision acceptable
          print('✅ Position immédiate obtenue avec bonne précision');
          add(NavigationPositionUpdated(currentPosition));
        }
      } catch (e) {
        print('⚠️ Impossible d\'obtenir position immédiate: $e');
        // Pas grave, on attend le stream
      }

      print('📡 Tracking GPS démarré');

    } catch (e) {
      print('❌ Erreur démarrage GPS: $e');
      throw 'Impossible de démarrer le GPS: $e';
    }
  }
}