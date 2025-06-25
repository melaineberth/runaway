import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/navigation/blocs/navigation_bloc.dart';
import 'package:runaway/features/navigation/blocs/navigation_event.dart';
import 'package:runaway/features/navigation/blocs/navigation_state.dart';
import '../../../../config/colors.dart';
import '../../../../config/extensions.dart';
import '../../domain/models/navigation_models.dart';

class LiveNavigationArgs {
  final List<List<double>> route;
  final double targetDistanceKm;
  final String? routeName;

  LiveNavigationArgs({
    required this.route,
    required this.targetDistanceKm,
    this.routeName,
  });
}

class LiveNavigationScreen extends StatefulWidget {
  final LiveNavigationArgs args;

  const LiveNavigationScreen({
    super.key,
    required this.args,
  });

  @override
  State<LiveNavigationScreen> createState() => _LiveNavigationScreenState();
}

class _LiveNavigationScreenState extends State<LiveNavigationScreen> with TickerProviderStateMixin {
  // === MAPBOX ===
  mp.MapboxMap? mapboxMap;
  mp.PolylineAnnotationManager? routeLineManager;
  mp.PolylineAnnotationManager? userTrackManager;
  mp.PointAnnotationManager? userArrowManager;
  mp.PointAnnotation? _currentUserArrow;

  // === ANIMATIONS ===
  late AnimationController _metricsAnimationController;
  late AnimationController _pulseAnimationController;

  // === ORIENTATION ===
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _currentHeading = 0.0;
  bool _cameraFollowsOrientation = true;
  bool _isCompassAvailable = false;
  
  // Gestion des mises à jour
  Timer? _orientationUpdateTimer;
  DateTime _lastOrientationUpdate = DateTime.now();
  static const Duration _updateInterval = Duration(milliseconds: 200);
  static const double _headingThreshold = 2.0;

  // === GESTION CAMÉRA ===
  bool _isFirstPositionReceived = false;
  bool _isMapInitialized = false;
  bool _hasStartedTracking = false;


  @override
  void initState() {
    super.initState();
    
    // Initialiser les animations
    _metricsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _startCompassTracking();

    // 🔧 ATTENDRE que la carte soit prête avant de démarrer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // On attend un peu que la carte soit complètement initialisée
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isMapInitialized) {
          _startNavigation();
        }
      });
    });
  }

  @override
  void dispose() {
    _metricsAnimationController.dispose();
    _pulseAnimationController.dispose();
    _compassSubscription?.cancel();
    _orientationUpdateTimer?.cancel();
    super.dispose();
  }

  void _startNavigation() {
    context.read<NavigationBloc>().add(
      NavigationStarted(
        originalRoute: widget.args.route,
        targetDistanceKm: widget.args.targetDistanceKm,
        routeName: widget.args.routeName,
      ),
    );
  }

  /// 🆕 DÉMARRER LE TRACKING D'ORIENTATION
  void _startCompassTracking() {
    try {
      // 🔧 PAS DE VÉRIFICATION PRÉALABLE - Essayer directement d'écouter
      final compassStream = FlutterCompass.events;
      
      if (compassStream != null) {
        _compassSubscription = compassStream.listen(
          (CompassEvent event) {
            // Premier événement reçu = compass disponible
            if (!_isCompassAvailable) {
              _isCompassAvailable = true;
              print('✅ Compass disponible et actif');
            }
            
            if (event.heading != null && !event.heading!.isNaN) {
              _onCompassEvent(event.heading!);
            }
          },
          onError: (error) {
            print('❌ Erreur compass: $error');
            _isCompassAvailable = false;
          },
          onDone: () {
            print('🔚 Stream compass terminé');
            _isCompassAvailable = false;
          },
        );
        
        print('🧭 Écoute du compass démarrée...');
        
        // 🔧 TIMEOUT pour détecter si compass indisponible
        Timer(const Duration(seconds: 5), () {
          if (!_isCompassAvailable && mounted) {
            print('⚠️ Compass probablement indisponible (timeout 5s)');
            _compassSubscription?.cancel();
          }
        });
        
      } else {
        print('⚠️ Stream compass null - indisponible');
        _isCompassAvailable = false;
      }
    } catch (e) {
      print('❌ Erreur démarrage compass: $e');
      _isCompassAvailable = false;
    }
  }

  /// 📡 TRAITEMENT DES ÉVÉNEMENTS COMPASS
  void _onCompassEvent(double heading) {
    // Normaliser l'angle (0-360°)
    double normalizedHeading = heading;
    if (normalizedHeading < 0) {
      normalizedHeading += 360;
    }
    
    // Filtrer les changements minimes et throttling
    if (_shouldUpdateHeading(normalizedHeading)) {
      _scheduleOrientationUpdate(normalizedHeading);
    }
  }

  /// 🔧 VÉRIFIER SI MISE À JOUR NÉCESSAIRE
  bool _shouldUpdateHeading(double newHeading) {
    // Calculer la différence en tenant compte du passage 359°→0°
    double difference = (newHeading - _currentHeading).abs();
    if (difference > 180) {
      difference = 360 - difference;
    }
    
    // Seuil + délai minimum
    final timeSinceLastUpdate = DateTime.now().difference(_lastOrientationUpdate);
    return difference >= _headingThreshold && 
           timeSinceLastUpdate >= _updateInterval;
  }

  /// ⏰ PROGRAMMER LA MISE À JOUR
  void _scheduleOrientationUpdate(double newHeading) {
    _orientationUpdateTimer?.cancel();
    
    _orientationUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _currentHeading = newHeading;
        });
        
        _lastOrientationUpdate = DateTime.now();
        
        // Mettre à jour l'UI si activé
        if (_cameraFollowsOrientation && _isCompassAvailable) {
          _updateOrientationUI();
        }
      }
    });
  }

  /// 🆕 METTRE À JOUR L'INTERFACE selon l'orientation
  Future<void> _updateOrientationUI() async {
    try {      
      // Mettre à jour la caméra
      if (_isFirstPositionReceived && mapboxMap != null) {
        await _updateCameraBearing();
      }
      
    } catch (e) {
      print('❌ Erreur mise à jour orientation UI: $e');
    }

  }

  void _pauseNavigation() {
    context.read<NavigationBloc>().add(const NavigationPaused());
  }

  void _resumeNavigation() {
    context.read<NavigationBloc>().add(const NavigationResumed());
  }

  void _stopNavigation() {
    context.read<NavigationBloc>().add(const NavigationStopped());
    context.pop();
  }

  /// 🔧 GESTION AMÉLIORÉE des changements d'état de navigation
  Future<void> _handleNavigationStateChange(NavigationState state) async {
    // Démarrage du tracking
    if (state.isNavigating && !_hasStartedTracking) {
      _hasStartedTracking = true;
    }

    // Mise à jour du tracé utilisateur
    if (state.userTrackCoordinates.isNotEmpty) {
      await _updateUserTrack(state);
    }

    // Mise à jour de la position avec gestion spéciale pour la première position
    if (state.trackingPoints.isNotEmpty) {
      await _updateUserPosition(state);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
        
        // 🔧 GESTION AMÉLIORÉE des mises à jour de position
        _handleNavigationStateChange(state);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black,
        body: BlocBuilder<NavigationBloc, NavigationState>(
          builder: (context, navigationState) {
            return Stack(
              children: [
                // === CARTE ===
                _buildMap(navigationState),
                
                // === OVERLAY MÉTRIQUES ===
                _buildMetricsOverlay(navigationState),

                // 🆕 BOUTON ORIENTATION CAMÉRA
                _buildOrientationToggle(),

                // 🆕 INDICATEUR D'ORIENTATION
                _buildOrientationIndicator(),
                                
                // === INDICATEUR DE STATUT ===
                if (navigationState.isPaused)
                  _buildPausedIndicator(),

                // 🆕 INDICATEUR DE DÉMARRAGE
                if (!_hasStartedTracking)
                  _buildStartingIndicator(),

              ],
            );
          },
        ),
      ),
    );
  }

  /// Mettre à jour le tracé utilisateur en temps réel
  Future<void> _updateUserTrack(NavigationState state) async {
    if (userTrackManager == null || state.userTrackCoordinates.length < 2) return;

    try {
      // Effacer l'ancien tracé
      await userTrackManager!.deleteAll();

      // Créer le nouveau tracé utilisateur
      final trackCoordinates = state.userTrackCoordinates.map((coord) => 
        mp.Position(coord[0], coord[1])
      ).toList();

      final userTrackLine = mp.PolylineAnnotationOptions(
        geometry: mp.LineString(coordinates: trackCoordinates),
        lineColor: AppColors.primary.value,
        lineWidth: 6.0,
        lineOpacity: 0.9,
      );

      await userTrackManager!.create(userTrackLine);

    } catch (e) {
      print('❌ Erreur mise à jour tracé utilisateur: $e');
    }
  }

  /// 🆕 INDICATEUR DE DÉMARRAGE GPS
  Widget _buildStartingIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Recherche position GPS...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mettre à jour la position actuelle de l'utilisateur
  Future<void> _updateUserPosition(NavigationState state) async {
    if (userArrowManager == null || state.trackingPoints.isEmpty) return;

    try {
      final lastPoint = state.trackingPoints.last;

      if (_currentUserArrow != null) {
        await userArrowManager!.delete(_currentUserArrow!);
        _currentUserArrow = null;
      }

      final arrowOptions = mp.PointAnnotationOptions(
        geometry: mp.Point(
          coordinates: mp.Position(lastPoint.longitude, lastPoint.latitude),
        ),
        iconImage: 'navigation_arrow',
        iconSize: 1.0,
        iconRotate: 0.0, // 🧭 Rotation selon compass
        iconAnchor: mp.IconAnchor.CENTER,
      );

      _currentUserArrow = await userArrowManager!.create(arrowOptions);

      // Gestion de la caméra
      if (!_isFirstPositionReceived) {
        print('📍 Première position reçue - centrage caméra initial');
        
        await mapboxMap!.setCamera(
          mp.CameraOptions(
            center: mp.Point(
              coordinates: mp.Position(lastPoint.longitude, lastPoint.latitude),
            ),
            zoom: 17.0,
            pitch: 0.0,
            bearing: (_cameraFollowsOrientation && _isCompassAvailable) ? _currentHeading : 0.0,
          ),
        );
        
        _isFirstPositionReceived = true;
        print('✅ Caméra centrée avec orientation: ${_currentHeading.toStringAsFixed(1)}°');
        
      } else if (state.isNavigating && _cameraFollowsOrientation && _isCompassAvailable) {
        // Suivi fluide avec orientation temps réel
        await mapboxMap!.flyTo(
          mp.CameraOptions(
            center: mp.Point(
              coordinates: mp.Position(lastPoint.longitude, lastPoint.latitude),
            ),
            zoom: 17.0,
            pitch: 0.0,
            bearing: _currentHeading,
          ),
          mp.MapAnimationOptions(duration: 300),
        );
      }

    } catch (e) {
      print('❌ Erreur mise à jour position: $e');
    }
  }

  // 🆕 INDICATEUR D'ORIENTATION dans l'UI
  Widget _buildOrientationIndicator() {
    if (!_cameraFollowsOrientation || !_isCompassAvailable) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 200,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              HugeIcons.strokeRoundedCompass01,
              color: Colors.blue,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${_currentHeading.round()}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎛️ BASCULER LE MODE ORIENTATION CAMÉRA
  void _toggleCameraOrientation() {
    if (!_isCompassAvailable) {
      // Afficher un message si compass non disponible
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compass non disponible sur cet appareil'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _cameraFollowsOrientation = !_cameraFollowsOrientation;
    });
    
    if (!_cameraFollowsOrientation) {
      _resetCameraBearing();
    } else {
      _updateCameraBearing();
    }
    
    print('📹 Mode orientation caméra: ${_cameraFollowsOrientation ? 'ON' : 'OFF'}');
  }

  /// 🧭 REMETTRE LA CAMÉRA VERS LE NORD
  Future<void> _resetCameraBearing() async {
    if (mapboxMap == null) return;

    try {
      final currentCamera = await mapboxMap!.getCameraState();
      
      await mapboxMap!.easeTo(
        mp.CameraOptions(
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          pitch: currentCamera.pitch,
          bearing: 0.0,
        ),
        mp.MapAnimationOptions(duration: 600),
      );
    } catch (e) {
      print('❌ Erreur reset caméra: $e');
    }
  }

  // 🎮 AJOUTER UN BOUTON POUR BASCULER L'ORIENTATION CAMÉRA
  Widget _buildOrientationToggle() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 140,
      right: 16,
      child: GestureDetector(
        onTap: _toggleCameraOrientation,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (_cameraFollowsOrientation && _isCompassAvailable)
                ? Colors.blue.withOpacity(0.9)
                : _isCompassAvailable 
                    ? Colors.black.withOpacity(0.7)
                    : Colors.red.withOpacity(0.7), // Rouge si compass indisponible
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _isCompassAvailable
                ? (_cameraFollowsOrientation 
                    ? HugeIcons.strokeRoundedCompass01
                    : HugeIcons.strokeRoundedCompass)
                : HugeIcons.solidSharpAlert02,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// Indicateur de pause
  Widget _buildPausedIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 0,
      right: 0,
      child: Center(
        child: SquircleContainer(
          radius: 30,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.orange.withValues(alpha: 0.9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                HugeIcons.solidRoundedPause,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Navigation en pause',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construire la carte
  Widget _buildMap(NavigationState state) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: mp.MapWidget(
        key: const ValueKey("navigationMapWidget"),
        onMapCreated: _onMapCreated,
        styleUri: mp.MapboxStyles.DARK,
      ),
    );
  }

  /// Création de la carte
  Future<void> _onMapCreated(mp.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    // Configuration de la carte pour navigation
    await mapboxMap.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: false, // On gère notre propre indicateur
        pulsingEnabled: false,
      ),
    );

    // Masquer les éléments d'interface
    await mapboxMap.compass.updateSettings(mp.CompassSettings(enabled: false));
    await mapboxMap.attribution.updateSettings(mp.AttributionSettings(enabled: false));
    await mapboxMap.logo.updateSettings(mp.LogoSettings(enabled: false));
    await mapboxMap.scaleBar.updateSettings(mp.ScaleBarSettings(enabled: false));

// Créer les gestionnaires d'annotations
    routeLineManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    userTrackManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    userArrowManager = await mapboxMap.annotations.createPointAnnotationManager();

    // 🔧 AJOUTER L'IMAGE DE LA FLÈCHE AVEC LA NOUVELLE API
    await _addArrowImageToStyle();

    // D'abord afficher le parcours sans centrer la caméra dessus
    await _displayOriginalRouteWithoutFocus();
    
    // Marquer la carte comme initialisée
    _isMapInitialized = true;
    
    print('✅ Carte initialisée, prête pour la navigation');
  }

  /// 🎯 AJOUTER L'IMAGE AVEC LA NOUVELLE API addStyleImage
  Future<void> _addArrowImageToStyle() async {
    if (mapboxMap == null) return;

    try {
      // 1. lire le fichier PNG
      final bytes = await rootBundle.load('assets/img/arrow.png');
      final buffer = bytes.buffer;

      // 2. récupérer la taille du PNG pour MbxImage
      final codec = await ui.instantiateImageCodec(buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final img   = frame.image;

      // 3. créer le MbxImage
      final mbxImg = mp.MbxImage(
        width : img.width,
        height: img.height,
        data  : buffer.asUint8List(),
      );

      // 4. l’injecter dans le style
      await mapboxMap!.style.addStyleImage(
        'navigation_arrow',   // ⬅️ même id que celui déclaré dans PointAnnotation
        1.0,                  // scale
        mbxImg,
        false,                // sdf
        [], [], null,
      );

      debugPrint('✅ PNG flèche ajouté');
    } catch (e) {
      debugPrint('❌ Impossible de charger l’icône PNG : $e');
    }
  }

  /// 🔄 METTRE À JOUR LA ROTATION DE LA FLÈCHE
  Future<void> _updateArrowRotation() async {
    if (_currentUserArrow == null || userArrowManager == null) return;

    try {
      final currentGeometry = _currentUserArrow!.geometry;
      
      await userArrowManager!.delete(_currentUserArrow!);
      
      final arrowOptions = mp.PointAnnotationOptions(
        geometry: currentGeometry,
        iconImage: 'navigation_arrow',
        iconSize: 1.0,
        iconRotate: 0.0,
        iconAnchor: mp.IconAnchor.CENTER,
      );

      _currentUserArrow = await userArrowManager!.create(arrowOptions);

    } catch (e) {
      print('❌ Erreur rotation flèche: $e');
    }
  }

  /// 📹 METTRE À JOUR L'ORIENTATION DE LA CAMÉRA
  Future<void> _updateCameraBearing() async {
    if (mapboxMap == null || !_isFirstPositionReceived) return;

    try {
      final currentCamera = await mapboxMap!.getCameraState();
      
      // 🔧 ANIMATION FLUIDE vers la nouvelle orientation
      await mapboxMap!.easeTo(
        mp.CameraOptions(
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          pitch: currentCamera.pitch,
          bearing: _currentHeading, // 🧭 Orientation compass
        ),
        mp.MapAnimationOptions(duration: 150), // Animation très fluide
      );

    } catch (e) {
      print('❌ Erreur orientation caméra: $e');
    }
  }

  /// 🔧 AFFICHAGE DU PARCOURS SANS CENTRER LA CAMÉRA
  Future<void> _displayOriginalRouteWithoutFocus() async {
    if (routeLineManager == null || widget.args.route.isEmpty) return;

    try {
      // Convertir les coordonnées
      final lineCoordinates = widget.args.route.map((coord) => 
        mp.Position(coord[0], coord[1])
      ).toList();

      // Créer la ligne du parcours original (en gris)
      final routeLine = mp.PolylineAnnotationOptions(
        geometry: mp.LineString(coordinates: lineCoordinates),
        lineColor: Colors.grey.withValues(alpha: 0.6).toARGB32(),
        lineWidth: 5.0,
        lineOpacity: 0.6,
      );

      await routeLineManager!.create(routeLine);

      // 🔧 PAS DE CENTRAGE AUTOMATIQUE - on attend la position utilisateur
      print('✅ Parcours original affiché (sans centrage caméra)');

    } catch (e) {
      print('❌ Erreur affichage parcours: $e');
    }
  }

  /// Construire l'overlay des métriques
  Widget _buildMetricsOverlay(NavigationState state) {
    return Positioned(
      bottom: 30,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _metricsAnimationController,
        builder: (context, child) {
          return SquircleContainer(
            padding: const EdgeInsets.all(20),
            color: Colors.black,
            child: Column(
              children: [
                // === MÉTRIQUES PRINCIPALES ===
                _buildMainMetrics(state.metrics),
                
                15.h,
                
                // === MÉTRIQUES SECONDAIRES ===
                _buildSecondaryMetrics(state.metrics),

                30.h,

                _buildControls(state, context)
                
                // if (state.targetDistanceKm > 0) ...[
                //   const SizedBox(height: 12),
                //   // === BARRE DE PROGRESSION ===
                //   _buildProgressBar(state.metrics.progressPercent),
                // ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls(NavigationState state, BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: SquircleContainer(
              onTap: state.isPaused ? _resumeNavigation : _pauseNavigation,
              radius: 30.0,
              color: Colors.white10,
              padding: EdgeInsets.symmetric(vertical: 15.0),
              child: Center(
                child: Text(
                  state.isPaused ? "Reprendre" : "Pause", 
                  style: context.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          10.w,
          Expanded(
            child: SquircleContainer(
              onTap: () {
                _showStopConfirmation();
              },
              radius: 30.0,
              color: AppColors.primary,
              padding: EdgeInsets.symmetric(vertical: 15.0),
              child: Center(
                child: Text(
                  "Terminer", 
                  style: context.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Métriques principales (temps, distance, dénivelé)
  Widget _buildMainMetrics(NavigationMetrics metrics) {
    return Row(
      children: [
        // TEMPS ÉCOULÉ
        Expanded(
          child: _buildMetricCard(
            value: metrics.formattedElapsedTime,
            label: 'Temps',
            icon: HugeIcons.strokeRoundedClock01,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // DISTANCE
        Expanded(
          child: _buildMetricCard(
            value: metrics.distanceKm.toStringAsFixed(1),
            unit: 'km',
            label: 'Distance',
            icon: HugeIcons.strokeRoundedRoute01,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // DÉNIVELÉ
        Expanded(
          child: _buildMetricCard(
            value: '${metrics.currentAltitude.toStringAsFixed(0)}',
            unit: 'm',
            label: 'Dénivelé +',
            icon: HugeIcons.solidSharpMountain,
          ),
        ),
      ],
    );
  }

  /// Métriques secondaires (rythme, temps restant, vitesse)
  Widget _buildSecondaryMetrics(NavigationMetrics metrics) {
    return Row(
      children: [
        // RYTHME
        Expanded(
          child: _buildMetricCard(
            value: metrics.formattedPace,
            unit: '/km',
            label: 'Rythme',
            icon: HugeIcons.strokeRoundedTimer01,
            isSecondary: true,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // TEMPS RESTANT
        Expanded(
          child: _buildMetricCard(
            value: metrics.formattedTimeRemaining,
            label: 'Restant',
            icon: HugeIcons.strokeRoundedHourglassOff,
            isSecondary: true,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // VITESSE
        Expanded(
          child: _buildMetricCard(
            value: metrics.currentSpeedKmh.toStringAsFixed(1),
            unit: 'km/h',
            label: 'Vitesse',
            icon: HugeIcons.strokeRoundedSpeedTrain01,
            isSecondary: true,
          ),
        ),
      ],
    );
  }

  /// Carte métrique individuelle
  Widget _buildMetricCard({
    required String value,
    String? unit,
    required String label,
    required IconData icon,
    bool isSecondary = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: context.bodyMedium?.copyWith(
                color: Colors.white,
                fontSize: 30,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: context.bodySmall,
              ),
            ],
          ],
        ),
        Text(
          label,
          style: context.bodySmall?.copyWith(
            color: Colors.white54,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  /// Afficher la confirmation d'arrêt
  void _showStopConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Arrêter la navigation ?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Voulez-vous vraiment arrêter la navigation en cours ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _stopNavigation();
            },
            child: const Text(
              'Arrêter',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}