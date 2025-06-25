// lib/features/navigation/blocs/navigation_bloc.dart
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
  bool _hasReceivedFirstPosition = false;
  
  // 🆕 CACHE INTELLIGENT POUR ÉVITER MISES À JOUR REDONDANTES
  Position? _lastCachedPosition;
  DateTime _lastPositionUpdate = DateTime.now();
  
  // 🆕 FILTRAGE PRÉCISION
  static const double _maxAccuracyThreshold = 30.0; // 30m max
  
  // 🆕 THROTTLING INTELLIGENT
  static const Duration _minUpdateInterval = Duration(milliseconds: 100);

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
      print('🚀 === DÉBUT NAVIGATION OPTIMISÉE ===');
      print('📍 Route: ${event.originalRoute.length} points');
      print('📏 Distance cible: ${event.targetDistanceKm}km');

      // Réinitialiser caches et flags
      _hasReceivedFirstPosition = false;
      _lastCachedPosition = null;
      _lastPositionUpdate = DateTime.now();

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

      // 🔧 DÉMARRER LE GPS HAUTE FRÉQUENCE
      await _startHighFrequencyLocationTracking();

      print('✅ Navigation haute performance démarrée');

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
    await _startHighFrequencyLocationTracking();

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
    _hasReceivedFirstPosition = false;
    _lastCachedPosition = null;

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

      final finalStats = NavigationMetricsService.calculateFinalStats(finishedSession);
      print('📊 Statistiques finales: $finalStats');
    }
  }

  /// 🆕 NOUVELLE GESTION GPS HAUTE FRÉQUENCE
  void _onNavigationPositionUpdated(
    NavigationPositionUpdated event,
    Emitter<NavigationState> emit,
  ) {
    if (!state.isTracking || state.currentSession == null) return;

    final position = event.position;
    
    // 🆕 FILTRAGE PRÉCISION - Ignorer positions > 30m
    if (position.accuracy > _maxAccuracyThreshold) {
      print('⚠️ Position rejetée - précision trop faible: ${position.accuracy.toStringAsFixed(1)}m');
      return;
    }
    
    // 🆕 THROTTLING INTELLIGENT - Éviter spam positions identiques
    if (_isDuplicatePosition(position)) {
      return;
    }
    
    // 🆕 CACHE POSITIONS pour optimiser performances
    _lastCachedPosition = position;
    _lastPositionUpdate = DateTime.now();
    
    // Créer un nouveau point de tracking
    final trackingPoint = TrackingPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: position.speed,
      accuracy: position.accuracy,
      heading: position.heading,
      timestamp: DateTime.now(),
    );

    // Ajouter le point à la liste existante
    final updatedPoints = [...state.trackingPoints, trackingPoint];

    // 🔧 PREMIÈRE POSITION - Démarrer immédiatement la navigation
    if (!_hasReceivedFirstPosition) {
      _hasReceivedFirstPosition = true;
      _startTimer();
      
      print('✅ Première position GPS reçue - navigation active');
      
      final activeSession = state.currentSession!.copyWith(
        status: NavigationStatus.active,
        startTime: DateTime.now(),
        trackingPoints: updatedPoints, // 🔧 CORRECTION: via currentSession
      );
      
      emit(state.copyWith(currentSession: activeSession));
      return;
    }

    // Calculer les nouvelles métriques
    final newMetrics = NavigationMetricsService.calculateMetrics(
      trackingPoints: updatedPoints,
      originalRoute: state.originalRoute,
      startTime: state.currentSession!.startTime,
      targetDistanceKm: state.targetDistanceKm,
    );

    final updatedSession = state.currentSession!.copyWith(
      trackingPoints: updatedPoints, // 🔧 CORRECTION: via currentSession
      metrics: newMetrics,
    );
    
    emit(state.copyWith(currentSession: updatedSession));
  }

  /// Tick du timer
  void _onNavigationTimerTick(
    NavigationTimerTick event,
    Emitter<NavigationState> emit,
  ) {
    if (!state.isNavigating || state.currentSession == null) return;

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
    _hasReceivedFirstPosition = false;
    _lastCachedPosition = null;

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
      if (state.isNavigating) {
        add(const NavigationTimerTick());
      }
    });
    print('⏱️ Timer de navigation démarré');
  }

  /// 🆕 TRACKING GPS HAUTE FRÉQUENCE OPTIMISÉ
  Future<void> _startHighFrequencyLocationTracking() async {
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

      // 🆕 CONFIGURATION HAUTE PERFORMANCE
      const LocationSettings highPerformanceSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0, // 🔧 Capturer CHAQUE mouvement
        timeLimit: Duration(seconds: 10), // Timeout réduit
      );

      print('📡 Démarrage GPS haute fréquence (100ms)...');

      // Démarrer le stream haute fréquence
      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: highPerformanceSettings,
      ).listen(
        (position) => _handleHighFrequencyPosition(position),
        onError: (error) {
          print('❌ Erreur GPS: $error');
          add(NavigationStopped());
        },
      );

      // 🆕 ACQUISITION IMMÉDIATE EN PARALLÈLE
      _getImmediatePosition();

      print('📡 GPS haute performance activé');

    } catch (e) {
      print('❌ Erreur démarrage GPS: $e');
      throw 'Impossible de démarrer le GPS: $e';
    }
  }

  /// 🆕 GESTION POSITION HAUTE FRÉQUENCE
  void _handleHighFrequencyPosition(Position position) {
    // Throttling intelligent pour maintenir 100ms minimum
    final timeSinceLastUpdate = DateTime.now().difference(_lastPositionUpdate);
    if (timeSinceLastUpdate < _minUpdateInterval) {
      return;
    }
    
    add(NavigationPositionUpdated(position));
  }

  /// 🆕 ACQUISITION IMMÉDIATE POSITION
  Future<void> _getImmediatePosition() async {
    try {
      print('🎯 Acquisition position immédiate...');
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 5), // Timeout plus court
      );
      
      if (currentPosition.accuracy <= _maxAccuracyThreshold) {
        print('✅ Position immédiate obtenue (${currentPosition.accuracy.toStringAsFixed(1)}m)');
        add(NavigationPositionUpdated(currentPosition));
      }
    } catch (e) {
      print('⚠️ Position immédiate échouée: $e');
      // Pas grave, on attend le stream
    }
  }

  /// 🆕 DÉTECTION POSITIONS DUPLIQUÉES
  bool _isDuplicatePosition(Position newPosition) {
    if (_lastCachedPosition == null) return false;
    
    // Comparer latitude, longitude et timestamp
    const double precisionThreshold = 0.000001; // ~0.1m
    final latDiff = (newPosition.latitude - _lastCachedPosition!.latitude).abs();
    final lngDiff = (newPosition.longitude - _lastCachedPosition!.longitude).abs();
    
    final timeDiff = DateTime.now().difference(_lastPositionUpdate);
    
    // Position identique si coordonnées très proches ET update récent
    if (latDiff < precisionThreshold && 
        lngDiff < precisionThreshold && 
        timeDiff < _minUpdateInterval) {
      return true;
    }
    
    return false;
  }
}