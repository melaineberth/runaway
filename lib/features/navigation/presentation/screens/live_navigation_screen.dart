import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/navigation/blocs/navigation_bloc.dart';
import 'package:runaway/features/navigation/blocs/navigation_event.dart';
import 'package:runaway/features/navigation/blocs/navigation_state.dart';
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

  // === ORIENTATION HAUTE PERFORMANCE ===
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _currentHeading = 0.0;
  double _smoothedHeading = 0.0;
  bool _cameraFollowsOrientation = true;
  bool _isCompassAvailable = false;
  
  // 🆕 LISSAGE TEMPS RÉEL 60 FPS
  Timer? _smoothingTimer;
  static const Duration _smoothingInterval = Duration(milliseconds: 16); // 60 FPS
  static const double _smoothingFactor = 0.15; // Facteur de lissage exponentiel
  
  // 🆕 COMPASS HAUTE FRÉQUENCE (20 FPS)
  Timer? _compassUpdateTimer;
  DateTime _lastCompassUpdate = DateTime.now();
  static const Duration _compassUpdateInterval = Duration(milliseconds: 50); // 20 FPS
  static const double _headingThreshold = 0.5; // 🔧 Sensibilité augmentée

  // === GESTION CAMÉRA OPTIMISÉE ===
  bool _isFirstPositionReceived = false;
  bool _isMapInitialized = false;
  bool _hasStartedTracking = false;
  
  // 🆕 CACHE CAMÉRA pour éviter mises à jour redondantes
  double? _lastCameraBearing;
  mp.Point? _lastCameraCenter;
  
  // 🆕 CALCUL DIRECTION DYNAMIQUE
  TrackingPoint? _previousPoint;
  double _movementBearing = 0.0;
  double _currentSpeed = 0.0;
  static const double _minSpeedForRotation = 1.0; // m/s (3.6 km/h)

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

    // 🆕 DÉMARRER ORIENTATION INTELLIGENTE
    _startIntelligentCompassTracking();
    
    // 🆕 DÉMARRER LISSAGE TEMPS RÉEL 60 FPS
    _startRealtimeSmoothing();

    // Attendre que la carte soit prête
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
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
    _compassUpdateTimer?.cancel();
    _smoothingTimer?.cancel();
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

  /// 🆕 ORIENTATION INTELLIGENTE avec détection automatique
  void _startIntelligentCompassTracking() {
    try {
      final compassStream = FlutterCompass.events;
      
      if (compassStream != null) {
        _compassSubscription = compassStream.listen(
          (CompassEvent event) {
            if (!_isCompassAvailable) {
              _isCompassAvailable = true;
              print('✅ Compass détecté et actif');
            }
            
            if (event.heading != null && !event.heading!.isNaN) {
              _onHighFrequencyCompassEvent(event.heading!);
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
        
        print('🧭 Écoute compass haute fréquence démarrée...');
        
        // Timeout pour détecter indisponibilité
        Timer(const Duration(seconds: 3), () {
          if (!_isCompassAvailable && mounted) {
            print('⚠️ Compass indisponible - utilisation orientation mouvement');
            _compassSubscription?.cancel();
          }
        });
        
      } else {
        print('⚠️ Stream compass null - mode mouvement uniquement');
        _isCompassAvailable = false;
      }
    } catch (e) {
      print('❌ Erreur démarrage compass: $e');
      _isCompassAvailable = false;
    }
  }

  /// 🆕 TRAITEMENT COMPASS HAUTE FRÉQUENCE
  void _onHighFrequencyCompassEvent(double heading) {
    // Normaliser l'angle (0-360°)
    double normalizedHeading = heading;
    if (normalizedHeading < 0) {
      normalizedHeading += 360;
    }
    
    // Throttling 20 FPS
    final timeSinceLastUpdate = DateTime.now().difference(_lastCompassUpdate);
    if (timeSinceLastUpdate < _compassUpdateInterval) {
      return;
    }
    
    // Filtrer changements minimes avec seuil réduit
    if (_shouldUpdateHeading(normalizedHeading)) {
      _updateCompassHeading(normalizedHeading);
      _lastCompassUpdate = DateTime.now();
    }
  }

  /// 🆕 VÉRIFICATION MISE À JOUR NÉCESSAIRE
  bool _shouldUpdateHeading(double newHeading) {
    // Calculer différence en tenant compte 359°→0°
    double difference = (newHeading - _currentHeading).abs();
    if (difference > 180) {
      difference = 360 - difference;
    }
    
    return difference >= _headingThreshold;
  }

  /// 🆕 MISE À JOUR COMPASS DIRECTE
  void _updateCompassHeading(double newHeading) {
    if (mounted) {
      setState(() {
        _currentHeading = newHeading;
      });
    }
  }

  /// 🆕 LISSAGE TEMPS RÉEL 60 FPS
  void _startRealtimeSmoothing() {
    _smoothingTimer?.cancel();
    _smoothingTimer = Timer.periodic(_smoothingInterval, (_) {
      if (mounted) {
        _performSmoothing();
      }
    });
  }

  /// 🆕 LISSAGE EXPONENTIEL TEMPS RÉEL
  void _performSmoothing() {
    // Lissage orientation
    final targetHeading = _isCompassAvailable ? _currentHeading : _movementBearing;
    
    // Gérer passage 359°→0°
    double headingDifference = targetHeading - _smoothedHeading;
    if (headingDifference > 180) {
      headingDifference -= 360;
    } else if (headingDifference < -180) {
      headingDifference += 360;
    }
    
    _smoothedHeading += headingDifference * _smoothingFactor;
    
    // Normaliser
    if (_smoothedHeading < 0) {
      _smoothedHeading += 360;
    } else if (_smoothedHeading >= 360) {
      _smoothedHeading -= 360;
    }
    
    // Appliquer orientation lissée si mode actif
    if (_cameraFollowsOrientation && _isFirstPositionReceived) {
      _applySmoothOrientation();
    }
  }

  /// 🆕 CALCULER DIRECTION MOUVEMENT
  void _calculateMovementBearing(TrackingPoint currentPoint) {
    if (_previousPoint == null) {
      _previousPoint = currentPoint;
      return;
    }
    
    _currentSpeed = currentPoint.speed ?? 0.0;
    
    // Calculer bearing pour DEBUG et informations uniquement
    // La flèche reste TOUJOURS orientée vers le nord (0°)
    if (_currentSpeed >= _minSpeedForRotation) {
      final bearing = _calculateBearing(
        _previousPoint!.latitude,
        _previousPoint!.longitude,
        currentPoint.latitude,
        currentPoint.longitude,
      );
      
      _movementBearing = bearing;
      print('🧭 Direction mouvement: ${bearing.toStringAsFixed(1)}° | '
            'Vitesse: ${_currentSpeed.toStringAsFixed(1)} m/s | '
            'Flèche: 0° (nord fixe)');
    }
    
    _previousPoint = currentPoint;
  }

  /// 🆕 CALCUL BEARING ENTRE DEUX POINTS GPS
  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * math.pi / 180;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    
    final y = math.sin(dLng) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) - 
              math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLng);
    
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// 🆕 APPLIQUER ORIENTATION LISSÉE
  Future<void> _applySmoothOrientation() async {
    if (mapboxMap == null) return;
    
    try {
      final currentCamera = await mapboxMap!.getCameraState();
      
      // 🆕 CACHE CAMÉRA - Éviter mises à jour identiques
      final newCenter = currentCamera.center;
      final newBearing = _smoothedHeading;
      
      if (_isCameraUpdateRedundant(newCenter, newBearing)) {
        return;
      }
      
      // 🆕 MODE HAUTE PERFORMANCE - setCamera instantané
      await mapboxMap!.setCamera(
        mp.CameraOptions(
          center: newCenter,
          zoom: 17.0,
          pitch: 0.0,
          bearing: newBearing,
        ),
      );
      
      // Mettre à jour cache
      _lastCameraCenter = newCenter;
      _lastCameraBearing = newBearing;
      
    } catch (e) {
      print('❌ Erreur orientation lissée: $e');
    }
  }

  /// 🆕 VÉRIFIER REDONDANCE CAMÉRA
  bool _isCameraUpdateRedundant(mp.Point? newCenter, double newBearing) {
    if (_lastCameraCenter == null || _lastCameraBearing == null) {
      return false;
    }
    
    // Vérifier différence bearing
    double bearingDiff = (newBearing - _lastCameraBearing!).abs();
    if (bearingDiff > 180) {
      bearingDiff = 360 - bearingDiff;
    }
    
    return bearingDiff < 1.0; // Seuil très faible pour éviter updates inutiles
  }

  /// 🎯 AJOUTER IMAGE FLÈCHE avec rotation dynamique
  Future<void> _addArrowImageToStyle() async {
    if (mapboxMap == null) return;

    try {
      final bytes = await rootBundle.load('assets/img/arrow.png');
      final buffer = bytes.buffer;

      final codec = await ui.instantiateImageCodec(buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final img = frame.image;

      final mbxImg = mp.MbxImage(
        width: img.width,
        height: img.height,
        data: buffer.asUint8List(),
      );

      await mapboxMap!.style.addStyleImage(
        'navigation_arrow',
        1.0,
        mbxImg,
        false,
        [], [], null,
      );

      debugPrint('✅ PNG flèche ajouté');
    } catch (e) {
      debugPrint('❌ Impossible de charger l\'icône PNG : $e');
    }
  }

  /// 🆕 METTRE À JOUR FLÈCHE avec direction dynamique
  Future<void> _updateArrowWithDynamicRotation(TrackingPoint currentPoint) async {
    if (_currentUserArrow == null || userArrowManager == null) return;

    try {
      // 🆕 CALCULER DIRECTION MOUVEMENT pour debug uniquement
      _calculateMovementBearing(currentPoint);
      
      // 🔧 FIX: La flèche doit TOUJOURS pointer vers le nord (0°)
      // C'est la caméra qui tourne, pas la flèche !
      const double arrowRotation = 0.0; // TOUJOURS vers le nord
      
      final currentGeometry = _currentUserArrow!.geometry;
      
      await userArrowManager!.delete(_currentUserArrow!);
      
      final arrowOptions = mp.PointAnnotationOptions(
        geometry: currentGeometry,
        iconImage: 'navigation_arrow',
        iconSize: 1.0,
        iconRotate: arrowRotation, // 🔧 FIX: TOUJOURS 0° (nord)
        iconAnchor: mp.IconAnchor.CENTER,
      );

      _currentUserArrow = await userArrowManager!.create(arrowOptions);

      // 🆕 DEBUG: Afficher infos orientation
      if (_currentSpeed >= _minSpeedForRotation) {
        print('🧭 Mouvement: ${_movementBearing.toStringAsFixed(1)}° | '
              'Flèche: 0° (nord) | '
              'Caméra: ${_smoothedHeading.toStringAsFixed(1)}°');
      }

    } catch (e) {
      print('❌ Erreur rotation flèche fixe: $e');
    }
  }

  /// 🆕 MISE À JOUR POSITION HAUTE PERFORMANCE
  Future<void> _updateUserPosition(NavigationState state) async {
    if (state.trackingPoints.isEmpty || mapboxMap == null) return;
    
    final lastPoint = state.trackingPoints.last;
    
    try {
      // Mettre à jour flèche avec orientation FIXE vers le nord
      if (userArrowManager != null) {
        final userPoint = mp.Point(
          coordinates: mp.Position(lastPoint.longitude, lastPoint.latitude),
        );

        if (_currentUserArrow == null) {
          final arrowOptions = mp.PointAnnotationOptions(
            geometry: userPoint,
            iconImage: 'navigation_arrow',
            iconSize: 1.0,
            iconRotate: 0.0, // 🔧 FIX: TOUJOURS 0° (nord)
            iconAnchor: mp.IconAnchor.CENTER,
          );
          _currentUserArrow = await userArrowManager!.create(arrowOptions);
        } else {
          // 🆕 MISE À JOUR avec rotation FIXE vers le nord
          await _updateArrowWithDynamicRotation(lastPoint);
        }
      }

      // 🔧 PREMIÈRE POSITION - Centrage instantané
      if (!_isFirstPositionReceived) {
        await mapboxMap!.setCamera(
          mp.CameraOptions(
            center: mp.Point(
              coordinates: mp.Position(lastPoint.longitude, lastPoint.latitude),
            ),
            zoom: 17.0,
            pitch: 0.0,
            bearing: _smoothedHeading, // 🔧 Caméra suit orientation téléphone
          ),
        );
        
        _isFirstPositionReceived = true;
        print('✅ Position initiale centrée - Flèche nord, Caméra ${_smoothedHeading.toStringAsFixed(1)}°');
        
      } else if (state.isNavigating && _cameraFollowsOrientation) {
        // 🆕 SUIVI FLUIDE - Caméra suit orientation, flèche reste nord
        await mapboxMap!.setCamera(
          mp.CameraOptions(
            center: mp.Point(
              coordinates: mp.Position(lastPoint.longitude, lastPoint.latitude),
            ),
            zoom: 17.0,
            pitch: 0.0,
            bearing: _smoothedHeading, // 🔧 Seule la caméra tourne
          ),
        );
      }

    } catch (e) {
      print('❌ Erreur mise à jour position avec flèche fixe: $e');
    }
  }

  /// Construire la carte
  Widget _buildMap(NavigationState state) {
    return mp.MapWidget(
      key: const ValueKey("navigation_mapWidget"),
      styleUri: "mapbox://styles/mapbox/dark-v11",
      cameraOptions: mp.CameraOptions(
        center: mp.Point(coordinates: mp.Position(2.3522, 48.8566)),
        zoom: 14.0,
      ),
      onMapCreated: (mp.MapboxMap mapboxMap) async {
        this.mapboxMap = mapboxMap;
        await _initializeMap();
        _isMapInitialized = true;
        print('🗺️ Carte initialisée haute performance');
      },
    );
  }

  /// Initialiser la carte
  Future<void> _initializeMap() async {
    if (mapboxMap == null) return;

    try {
      // Créer managers d'annotations
      routeLineManager = await mapboxMap!.annotations.createPolylineAnnotationManager();
      userTrackManager = await mapboxMap!.annotations.createPolylineAnnotationManager();
      userArrowManager = await mapboxMap!.annotations.createPointAnnotationManager();

      await mapboxMap!.compass.updateSettings(mp.CompassSettings(enabled: false));
      await mapboxMap!.attribution.updateSettings(mp.AttributionSettings(enabled: false));
      await mapboxMap!.logo.updateSettings(mp.LogoSettings(enabled: false));
      await mapboxMap!.scaleBar.updateSettings(mp.ScaleBarSettings(enabled: false));

      // Ajouter l'image de la flèche
      await _addArrowImageToStyle();

      // Afficher le parcours original sans centrage
      await _displayOriginalRouteWithoutFocus();

      print('🗺️ Carte initialisée, prête pour navigation haute performance');
    } catch (e) {
      print('❌ Erreur initialisation carte: $e');
    }
  }

  /// Afficher parcours original sans centrage
  Future<void> _displayOriginalRouteWithoutFocus() async {
    if (routeLineManager == null || widget.args.route.isEmpty) return;

    try {
      final lineCoordinates = widget.args.route.map((coord) => 
        mp.Position(coord[0], coord[1])
      ).toList();

      final routeLine = mp.PolylineAnnotationOptions(
        geometry: mp.LineString(coordinates: lineCoordinates),
        lineColor: Colors.grey.withValues(alpha: 0.6).toARGB32(),
        lineWidth: 5.0,
        lineOpacity: 0.6,
      );

      await routeLineManager!.create(routeLine);
      print('✅ Parcours original affiché (sans centrage caméra)');

    } catch (e) {
      print('❌ Erreur affichage parcours: $e');
    }
  }

  /// Mettre à jour tracé utilisateur
  Future<void> _updateUserTrack(NavigationState state) async {
    if (userTrackManager == null || state.userTrackCoordinates.isEmpty) return;

    try {
      await userTrackManager!.deleteAll();

      // 🔧 FIX: Conversion List<List<double>> vers List<Position>
      final trackCoordinates = state.userTrackCoordinates.map((coord) => 
        mp.Position(coord[0], coord[1]) // longitude, latitude
      ).toList();

      final trackLine = mp.PolylineAnnotationOptions(
        geometry: mp.LineString(coordinates: trackCoordinates), // 🔧 FIX: List<Position>
        lineColor: Colors.blue.toARGB32(),
        lineWidth: 6.0,
        lineOpacity: 0.8,
      );

      await userTrackManager!.create(trackLine);

    } catch (e) {
      print('❌ Erreur mise à jour tracé: $e');
    }
  }

  /// Basculer mode orientation caméra
  void _toggleCameraOrientation() {
    if (!_isCompassAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compass non disponible - utilisation direction mouvement'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    setState(() {
      _cameraFollowsOrientation = !_cameraFollowsOrientation;
    });
    
    if (!_cameraFollowsOrientation) {
      _resetCameraBearing();
    }
    
    print('📹 Mode orientation: ${_cameraFollowsOrientation ? 'ON' : 'OFF'}');
  }

  /// Remettre caméra vers le nord
  Future<void> _resetCameraBearing() async {
    if (mapboxMap == null) return;

    try {
      final currentCamera = await mapboxMap!.getCameraState();
      
      await mapboxMap!.setCamera(
        mp.CameraOptions(
          center: currentCamera.center,
          zoom: currentCamera.zoom,
          pitch: currentCamera.pitch,
          bearing: 0.0,
        ),
      );
    } catch (e) {
      print('❌ Erreur reset caméra: $e');
    }
  }

  /// Bouton toggle orientation
  Widget _buildOrientationToggle() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + kToolbarHeight / 2,
      right: 16,
      child: IconBtn(
        onPressed: _toggleCameraOrientation,
        icon: _cameraFollowsOrientation 
          ? HugeIcons.solidRoundedLocationShare02
          : HugeIcons.strokeRoundedLocationShare02,
        iconColor: Colors.white,
        padding: 12,
        backgroundColor: _cameraFollowsOrientation
          ? Colors.blue.withValues(alpha: 0.9)
          : Colors.black.withValues(alpha: 0.7),
      ),
    );
  }

  /// Gestion changements d'état navigation
  Future<void> _handleNavigationStateChange(NavigationState state) async {
    if (state.isNavigating && !_hasStartedTracking) {
      _hasStartedTracking = true;
    }

    if (state.userTrackCoordinates.isNotEmpty) {
      await _updateUserTrack(state);
    }

    if (state.trackingPoints.isNotEmpty) {
      await _updateUserPosition(state);
    }
  }

  /// Construire overlay métriques
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
                _buildMainMetrics(state.metrics),
                15.h,
                _buildSecondaryMetrics(state.metrics),
                30.h,
                _buildControls(state, context),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Métriques principales
  Widget _buildMainMetrics(NavigationMetrics metrics) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricItem(
            'Temps',
            _formatDuration(metrics.elapsedTime),
            HugeIcons.strokeRoundedTime01,
          ),
        ),
        Expanded(
          child: _buildMetricItem(
            'Distance',
            metrics.distanceKm.toStringAsFixed(1), // 🔧 FIX: distanceKm
            HugeIcons.strokeRoundedTime01,
            indicator: " km",
          ),
        ),
        Expanded(
          child: _buildMetricItem(
            'Dénivelé',
            metrics.currentAltitude.toStringAsFixed(1), // 🔧 FIX: currentSpeedKmh
            HugeIcons.strokeRoundedDashboardSpeed01,
            indicator: " m",
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryMetrics(NavigationMetrics metrics) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricItem(
            'Rythme',
            _formatPace(metrics.averagePaceSecPerKm), // 🔧 FIX: averagePaceSecPerKm
            HugeIcons.strokeRoundedStopWatch,
            indicator: " /km",
          ),
        ),
        Expanded(
          child: _buildMetricItem(
            'Restant',
            metrics.remainingDistanceKm.toStringAsFixed(1), // 🔧 FIX: averageSpeedKmh
            HugeIcons.strokeRoundedDashboardSpeed02,
            indicator: " km",
          ),
        ),
        Expanded(
          child: _buildMetricItem(
            'Vitesse', 
            metrics.currentSpeedKmh.toStringAsFixed(1), // 🔧 FIX: Calculer calories
            HugeIcons.strokeRoundedFire,
            indicator: " km/h",
          ),
        ),
      ],
    );
  }

  /// Item métrique
  Widget _buildMetricItem(String label, String value, IconData icon, {String? indicator = ""}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            text: value,
            style: context.bodyMedium?.copyWith(
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
            children: <InlineSpan>[
              TextSpan(
                text: indicator,
                style: context.bodySmall?.copyWith(
                  fontSize: 15,
                ),
              )
            ]
          )
        ),
        Text(
          label,
          style: context.bodySmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  /// Contrôles
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
                state.isPaused ? 'Reprendre' : 'Pause',
                style: const TextStyle(
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
            onTap: _showStopConfirmation,
            radius: 30.0,
            color: AppColors.primary,
            padding: EdgeInsets.symmetric(vertical: 15.0),
            child: Center(
              child: Text(
                'Terminer',
                style: const TextStyle(
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

  /// Indicateur démarrage
  Widget _buildStartingIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
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
            const Text(
              'Acquisition GPS haute précision...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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

  /// Afficher la confirmation d'arrêt
  void _showStopConfirmation() {
    showModalSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      child: ModalDialog(
        title: 'Arrêter la navigation ?',
        subtitle: 'Voulez-vous vraiment arrêter la navigation en cours ?',
        validLabel: 'Arrêter',
        onValid: () {
          HapticFeedback.mediumImpact();
          
          Navigator.pop(context); // 🔧 Fermer le dialogue d'abord
          _stopNavigation();
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours.isNegative ? "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds" :  "$twoDigitMinutes:$twoDigitSeconds";
  }

  // 🆕 FONCTION POUR FORMATER LE PACE
  String _formatPace(double paceSecPerKm) {
    if (paceSecPerKm == 0 || paceSecPerKm.isInfinite || paceSecPerKm.isNaN) {
      return '--:--';
    }
    
    final minutes = (paceSecPerKm / 60).floor();
    final seconds = (paceSecPerKm % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
        
        _handleNavigationStateChange(state);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black,
        body: BlocBuilder<NavigationBloc, NavigationState>(
          builder: (context, navigationState) {
            return Stack(
              children: [
                _buildMap(navigationState),
                _buildMetricsOverlay(navigationState),
                _buildOrientationToggle(),
                
                if (!_hasStartedTracking)
                  _buildStartingIndicator(),
              ],
            );
          },
        ),
      ),
    );
  }
}