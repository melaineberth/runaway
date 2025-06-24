import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/navigation/blocs/navigation_bloc.dart';
import 'package:runaway/features/navigation/blocs/navigation_event.dart';
import 'package:runaway/features/navigation/blocs/navigation_state.dart';
import 'package:sensors_plus/sensors_plus.dart';
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
  Color _arrowBlue      = Color(0xFF1E88E5);          // material blue-600
  Color _haloBlue       = Color(0xFF1E88E5);          // même teinte
  double _strokeWidthPx  = 4.0;                        // contour blanc
  double _bodyRatio      = 0.54;                       // largeur/base ↔️ hauteur
  double _haloRadiusPct  = 0.60;                       // halo = 60 % du canvas

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
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  double _currentHeading = 0.0;
  bool _cameraFollowsOrientation = true; // 🆕 Mode caméra orientée

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

    _startOrientationTracking();

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
    _magnetometerSubscription?.cancel();
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

  /// 🎨 CRÉER L'IMAGE DE LA FLÈCHE PROFESSIONNELLE
  void _drawExactPhotoArrow(Canvas canvas, Size size) {
  final c   = Offset(size.width / 2, size.height / 2);
  final R   = size.width * _haloRadiusPct;          // rayon du halo
  final h   = size.height * 0.50;                   // demi-hauteur de la flèche
  final bW  = h * _bodyRatio;                       // demi-largeur (base)

  // --- HALO ---
  final haloPaint = Paint()
    ..color = _haloBlue.withOpacity(0.16)           // même opacité que Google Maps (~16 %)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(c, R, haloPaint);

  // --- CONTOUR BLANC ---
  final stroke = Paint()
    ..color       = Colors.white
    ..style       = PaintingStyle.stroke
    ..strokeWidth = _strokeWidthPx
    ..strokeJoin  = StrokeJoin.round
    ..strokeCap   = StrokeCap.round;

  // --- REMPLISSAGE ---
  final fill = Paint()
    ..color = _arrowBlue
    ..style = PaintingStyle.fill;

  // --- PATH ---
  final p = Path()
    ..moveTo(c.dx,           c.dy - h)              // pointe
    ..lineTo(c.dx - bW,      c.dy + h * 0.10)       // flanc G
    ..lineTo(c.dx - bW * .55,c.dy + h)              // bas G avant arrondi

    ..arcToPoint(
      Offset(c.dx + bW * .55, c.dy + h),             // bas D après arrondi
      radius: Radius.circular(bW * .55),
      clockwise: false,
    )

    ..lineTo(c.dx + bW,      c.dy + h * 0.10)       // flanc D
    ..close();

  canvas.drawPath(p, stroke);
  canvas.drawPath(p, fill);
}

  /// 🆕 DÉMARRER LE TRACKING D'ORIENTATION
  void _startOrientationTracking() {
    try {
      _magnetometerSubscription = magnetometerEvents.listen((MagnetometerEvent event) {
        // Calculer l'angle en degrés (0° = Nord)
        final heading = (math.atan2(event.y, event.x) * 180 / math.pi + 360) % 360;
        
        // Filtrer les petits changements pour éviter les tremblements
        if ((heading - _currentHeading).abs() > 5 || (heading - _currentHeading).abs() > 355) {
          setState(() {
            _currentHeading = heading;
          });
        }
      });
      
      print('🧭 Tracking d\'orientation démarré');
    } catch (e) {
      print('⚠️ Orientation non disponible: $e');
      // Pas grave, on continue sans orientation
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
    if (userArrowManager == null || state.trackingPoints.isEmpty || mapboxMap == null) return;

    try {
      // Obtenir la dernière position
      final lastPoint = state.trackingPoints.last;

      // Supprimer l'ancienne flèche si elle existe
      if (_currentUserArrow != null) {
        await userArrowManager!.delete(_currentUserArrow!);
        _currentUserArrow = null;
      }

      // 🎯 CRÉER LA NOUVELLE FLÈCHE ORIENTÉE
      final arrowOptions = mp.PointAnnotationOptions(
        geometry: mp.Point(
          coordinates: mp.Position(lastPoint.longitude, lastPoint.latitude),
        ),
        iconImage: 'navigation_arrow',
        iconSize: 1.0,
        iconRotate: _currentHeading, // 🔄 Rotation selon l'orientation
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
            bearing: _cameraFollowsOrientation ? _currentHeading : 0.0, // 🔄 Orientation initiale
          ),
        );
        
        _isFirstPositionReceived = true;
        print('✅ Caméra centrée avec flèche et orientation');
        
      } else if (state.isNavigating) {
        // Suivi fluide avec orientation
        await mapboxMap!.flyTo(
          mp.CameraOptions(
            center: mp.Point(
              coordinates: mp.Position(lastPoint.longitude, lastPoint.latitude),
            ),
            zoom: 17.0,
            pitch: 0.0,
            bearing: _cameraFollowsOrientation ? _currentHeading : 0.0, // 🔄 Maintenir orientation
          ),
          mp.MapAnimationOptions(duration: 1000),
        );
      }

    } catch (e) {
      print('❌ Erreur mise à jour flèche utilisateur: $e');
    }
  }

  /// 🎛️ BASCULER LE MODE ORIENTATION CAMÉRA
  void _toggleCameraOrientation() {
    setState(() {
      _cameraFollowsOrientation = !_cameraFollowsOrientation;
    });
    
    if (!_cameraFollowsOrientation) {
      // Remettre la caméra vers le nord
      _resetCameraBearing();
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
          bearing: 0.0, // Nord
        ),
        mp.MapAnimationOptions(duration: 800),
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
            color: _cameraFollowsOrientation 
                ? AppColors.primary.withOpacity(0.9)
                : Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            HugeIcons.strokeRoundedCompass,
            color: Colors.white,
            size: 20,
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
      // Créer l'image de la flèche
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(96, 96);
      
      _drawExactPhotoArrow(canvas, size);
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final imageBytes = byteData.buffer.asUint8List();
        
        // 🔧 CRÉER MbxImage AVEC LES BONS PARAMÈTRES
        final mbxImage = mp.MbxImage(
          width: size.width.toInt(),
          height: size.height.toInt(),
          data: imageBytes,
        );
        
        // 🚀 UTILISER addStyleImage AVEC LA NOUVELLE API
        await mapboxMap!.style.addStyleImage(
          'navigation_arrow',     // imageId
          1.0,                   // scale
          mbxImage,              // image
          false,                 // sdf (pas de distance field)
          [],                    // stretchX (pas d'étirement)
          [],                    // stretchY (pas d'étirement) 
          null,                  // content (pas de contenu spécial)
        );
        
        print('✅ Image flèche ajoutée avec addStyleImage');
      }
    } catch (e) {
      print('❌ Erreur addStyleImage: $e');
    }
  }

  /// 🔄 METTRE À JOUR LA ROTATION DE LA FLÈCHE
  Future<void> _updateArrowRotation() async {
    if (_currentUserArrow == null || userArrowManager == null) return;

    try {
      // Supprimer l'ancienne flèche
      await userArrowManager!.delete(_currentUserArrow!);
      
      // Créer la nouvelle flèche avec rotation
      final arrowOptions = mp.PointAnnotationOptions(
        geometry: _currentUserArrow!.geometry,
        iconImage: 'navigation_arrow',
        iconSize: 1.0,
        iconRotate: _currentHeading, // 🔄 Rotation selon l'orientation
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
      // Obtenir l'état actuel de la caméra
      final currentCamera = await mapboxMap!.getCameraState();
      
      // Créer nouvelle caméra avec bearing mis à jour
      final newCamera = mp.CameraOptions(
        center: currentCamera.center,
        zoom: currentCamera.zoom,
        pitch: currentCamera.pitch,
        bearing: _currentHeading, // 🔄 Orienter la caméra selon le téléphone
      );

      // Animation fluide vers la nouvelle orientation
      await mapboxMap!.easeTo(
        newCamera,
        mp.MapAnimationOptions(duration: 500), // Animation courte et fluide
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