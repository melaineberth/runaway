import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:hugeicons/hugeicons.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/loading_overlay.dart';
import 'package:runaway/features/home/data/services/navigation_service.dart';
import 'package:runaway/features/home/presentation/widgets/navigation_overlay.dart';
import 'package:runaway/features/home/presentation/widgets/route_info_card.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_gradient/smooth_gradient.dart';
import '../../../route_generator/data/services/graphhopper_api_service.dart';
import '../../../route_generator/domain/models/graphhopper_route_result.dart';
import '../../domain/config/navigation_camera_config.dart';
import '../blocs/map_style/map_style_bloc.dart';
import '../blocs/map_style/map_style_event.dart';
import '../blocs/map_style/map_style_state.dart';
import '../../../route_generator/presentation/screens/route_parameter.dart' as gen;
import '../../../../core/widgets/icon_btn.dart';
import '../blocs/route_parameters/route_parameters_bloc.dart';
import '../blocs/route_parameters/route_parameters_event.dart';
import '../widgets/location_search_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  NavigationCameraConfig navigationConfig = const NavigationCameraConfig();
  mp.MapboxMap? mapboxMap;
  StreamSubscription? userPositionStream;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;
  mp.PointAnnotation? selectedLocationMarker;
  mp.CircleAnnotation? radiusCircle;

  mp.CircleAnnotationManager? markerCircleManager;
  List<mp.CircleAnnotation> locationMarkers = [];

  bool isGenerateEnabled = false;

  // Position utilisateur
  double? userLongitude;
  double? userLatitude;

  // Position actuelle (utilisateur ou recherche)
  double? currentLongitude;
  double? currentLatitude;

  // État du suivi en temps réel
  bool isTrackingUser = true;

  // Variables pour la gestion des polylignes
  mp.PolylineAnnotation?
  routeToStartPolyline; // Polyligne vers le point de départ
  mp.PolylineAnnotation?
  originalRoutePolyline; // Polyligne du parcours original (sauvegardée)
  mp.PolylineAnnotationManager? polylineManager;
  mp.PolylineAnnotation? currentRoutePolyline;

  // État de la route générée
  List<List<double>>? generatedRouteCoordinates;
  Map<String, dynamic>? generatedRouteStats;
  File? generatedRouteFile;

  // Variables pour la navigation intégrée
  bool isNavigationMode = false;
  NavigationUpdate? currentNavUpdate;
  String currentInstruction = "";
  mp.CircleAnnotation? currentPositionMarker;

  // Variables pour la navigation intelligente
  bool isNavigatingToRoute = false; // Navigation vers le parcours
  String navigationMode = 'none'; // 'none', 'to_route', 'on_route'
  List<List<double>>?
  routeToStartPoint; // Coordonnées pour aller au point de départ

  // Variables pour la caméra de navigation
  List<List<double>> userPositionHistory = []; // Historique des positions pour calculer la direction
  double currentUserBearing = 0.0; // Direction actuelle de l'utilisateur
  bool isNavigationCameraActive = false;
  Timer? positionUpdateTimer;
  List<List<double>>? activeNavigationRoute; // Route actuellement suivie
  int currentRouteSegmentIndex = 0; // Index du segment actuel sur la route
  double lookAheadDistance = 100.0; // Distance pour anticiper (en mètres)
  List<List<double>>? routeToStartCoordinates;

  @override
  void initState() {
    super.initState();
    _setupPositionTracking();
    NavigationService.initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    NavigationService.dispose();
    WidgetsBinding.instance.removeObserver(this);

    positionUpdateTimer?.cancel();

    // NE PAS appeler _clearRoute() car elle contient setState()
    // Nettoyer seulement les ressources critiques
    try {
      if (isNavigationMode) {
        NavigationService.stopNavigation();
      }
    } catch (e) {
      print('⚠️ Erreur arrêt navigation: $e');
    }

    userPositionStream?.cancel();
    _clearLocationMarkers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Gérer la navigation selon l'état de l'app
    switch (state) {
      case AppLifecycleState.paused:
        // L'app passe en arrière-plan, la navigation continue
        print('📱 App en arrière-plan, navigation continue');
        break;
      case AppLifecycleState.resumed:
        // L'app revient au premier plan
        print('📱 App au premier plan');
        break;
      case AppLifecycleState.detached:
        // L'app est fermée, arrêter la navigation
        NavigationService.stopNavigation();
        break;
      default:
        break;
    }
  }

  void _startNavigation() {
    if (generatedRouteCoordinates == null ||
        userLongitude == null ||
        userLatitude == null) {
      _showErrorSnackBar('Position utilisateur ou parcours non disponible');
      return;
    }

    final startPoint = generatedRouteCoordinates!.first;
    final distanceToStart = _calculateDistance(
      userLatitude!,
      userLongitude!,
      startPoint[1], // latitude
      startPoint[0], // longitude
    );

    print('🎯 Distance au point de départ: ${distanceToStart.round()}m');

    // Si l'utilisateur est proche du parcours (moins de 100m)
    if (distanceToStart <= 100) {
      _showDirectNavigationDialog();
    } else {
      _showNavigationChoiceDialog(distanceToStart);
    }
  }

  void _showDirectNavigationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: Text(
              'Démarrer le parcours',
              style: context.titleMedium?.copyWith(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vous êtes au point de départ du parcours.',
                  style: context.bodyMedium?.copyWith(color: Colors.white70),
                ),
                16.h,
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                        color: Colors.green,
                        size: 16,
                      ),
                      8.w,
                      Expanded(
                        child: Text(
                          'Prêt à commencer la navigation du parcours',
                          style: context.bodySmall?.copyWith(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Annuler', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startRouteNavigation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: Text('Commencer'),
              ),
            ],
          ),
    );
  }

  void _showNavigationChoiceDialog(double distanceToStart) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: Text(
              'Navigation vers le parcours',
              style: context.titleMedium?.copyWith(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vous êtes à ${_formatDistance(distanceToStart)} du point de départ.',
                  style: context.bodyMedium?.copyWith(color: Colors.white70),
                ),
                16.h,
                Text(
                  'Que souhaitez-vous faire ?',
                  style: context.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                12.h,
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        color: Colors.blue,
                        size: 16,
                      ),
                      8.w,
                      Expanded(
                        child: Text(
                          'Navigation avec instructions vocales',
                          style: context.bodySmall?.copyWith(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Annuler', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startRouteNavigation(); // Démarrer directement le parcours
                },
                child: Text(
                  'Parcours direct',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startNavigationToRoute(distanceToStart);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: Text('Me guider'),
              ),
            ],
          ),
    );
  }

  void _startNavigationToRoute(double distance) async {
    try {
      setState(() {
        isNavigatingToRoute = true;
        navigationMode = 'to_route';
        currentInstruction = "Calcul de l'itinéraire vers le parcours...";
      });

      // Point de départ du parcours
      final startPoint = generatedRouteCoordinates!.first;

      // ✅ FIX: Générer un VRAI itinéraire routier via GraphHopper
      final routeToStart = await GraphHopperApiService.generateSimpleRoute(
        startLat: userLatitude!,
        startLon: userLongitude!,
        endLat: startPoint[1], // latitude du point de départ
        endLon: startPoint[0], // longitude du point de départ
        profile: 'foot', // Profil piéton pour la course
      );

      if (routeToStart.length < 2) {
        throw Exception(
          'Impossible de calculer l\'itinéraire vers le parcours',
        );
      }

      // ✅ FIX: Sauvegarder les coordonnées de l'itinéraire
      setState(() {
        routeToStartCoordinates = List.from(routeToStart);
      });

      print(
        '🗺️ Itinéraire calculé: ${routeToStart.length} points, ${_calculateTotalDistance(routeToStart).toStringAsFixed(1)}km',
      );

      // Sauvegarder la polyligne du parcours original et la masquer
      await _hideOriginalRoute();

      // Afficher la route vers le point de départ
      await _displayRouteToStart(routeToStart);

      bool success = await NavigationService.startCustomNavigation(
        coordinates: routeToStart,
        onUpdate: _handleNavigationToRouteUpdate,
      );

      if (success) {
        setState(() {
          isNavigationMode = true;
          currentInstruction = "Navigation vers le point de départ...";
        });

        await _switchToNavigationView();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Navigation vers le parcours démarrée !',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur complète: $e');

      setState(() {
        isNavigatingToRoute = false;
        navigationMode = 'none';
        routeToStartCoordinates = null; // ✅ FIX: Nettoyer en cas d'erreur
      });

      // Restaurer la polyligne originale en cas d'erreur
      await _showOriginalRoute();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur calcul itinéraire: ${e.toString()}',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _hideOriginalRoute() async {
    if (polylineManager != null && currentRoutePolyline != null) {
      // Sauvegarder la référence
      originalRoutePolyline = currentRoutePolyline;
      // Supprimer de l'affichage
      await polylineManager!.delete(currentRoutePolyline!);
      currentRoutePolyline = null;
    }
  }

  Future<void> _displayRouteToStart(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) {
      print('⚠️ Impossible d\'afficher la route vers le départ');
      return;
    }

    print(
      '🗺️ Affichage itinéraire vers le départ: ${coordinates.length} points',
    );

    try {
      // Créer un gestionnaire de polylignes si nécessaire
      polylineManager ??=
          await mapboxMap!.annotations.createPolylineAnnotationManager();

      // Supprimer l'ancienne route vers le départ si elle existe
      if (routeToStartPolyline != null) {
        await polylineManager!.delete(routeToStartPolyline!);
      }

      // Créer la nouvelle polyligne pour la route vers le départ
      routeToStartPolyline = await polylineManager!.create(
        mp.PolylineAnnotationOptions(
          geometry: mp.LineString(
            coordinates:
                coordinates
                    .map((coord) => mp.Position(coord[0], coord[1]))
                    .toList(),
          ),
          lineColor: Colors.blue.toARGB32(),
          lineWidth: 5.0,
          lineOpacity: 0.9,
          lineJoin: mp.LineJoin.ROUND,
        ),
      );

      // Ajouter des marqueurs pour le départ et l'arrivée de l'itinéraire
      await _addRouteToStartMarkers(coordinates);

      print('✅ Itinéraire vers le départ affiché');

      // Centrer la vue sur cette route
      await _centerMapOnRoute(coordinates);
    } catch (e) {
      print('❌ Erreur affichage itinéraire: $e');
      rethrow;
    }
  }

  Future<void> _addRouteToStartMarkers(List<List<double>> coordinates) async {
    if (coordinates.isEmpty || markerCircleManager == null) return;

    try {
      // Marqueur de départ (bleu - position utilisateur)
      await markerCircleManager!.create(
        mp.CircleAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(
              coordinates.first[0],
              coordinates.first[1],
            ),
          ),
          circleColor: Colors.blue.toARGB32(),
          circleRadius: 8.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.toARGB32(),
        ),
      );

      // Marqueur d'arrivée (vert - point de départ du parcours)
      await markerCircleManager!.create(
        mp.CircleAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(coordinates.last[0], coordinates.last[1]),
          ),
          circleColor: Colors.green.toARGB32(),
          circleRadius: 10.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.toARGB32(),
        ),
      );

      print('✅ Marqueurs itinéraire ajoutés');
    } catch (e) {
      print('⚠️ Erreur ajout marqueurs itinéraire: $e');
    }
  }

  Future<void> _showOriginalRoute() async {
    if (polylineManager == null || generatedRouteCoordinates == null) return;

    try {
      // Supprimer la route vers le départ
      if (routeToStartPolyline != null) {
        await polylineManager!.delete(routeToStartPolyline!);
        routeToStartPolyline = null;
      }

      // Recréer la polyligne du parcours original
      currentRoutePolyline = await polylineManager!.create(
        mp.PolylineAnnotationOptions(
          geometry: mp.LineString(
            coordinates:
                generatedRouteCoordinates!
                    .map((coord) => mp.Position(coord[0], coord[1]))
                    .toList(),
          ),
          lineColor: Theme.of(context).primaryColor.toARGB32(),
          lineWidth: 4.0,
          lineOpacity: 0.9,
          lineJoin: mp.LineJoin.ROUND,
        ),
      );

      print('✅ Polyligne du parcours original restaurée');
    } catch (e) {
      print('❌ Erreur restauration parcours original: $e');
    }
  }

  Future<void> _centerMapOnRoute(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) return;

    final bounds = _calculateBounds(coordinates);
    final centerLon =
        (bounds.southwest.coordinates.lng + bounds.northeast.coordinates.lng) /
        2;
    final centerLat =
        (bounds.southwest.coordinates.lat + bounds.northeast.coordinates.lat) /
        2;

    // Calculer le zoom approprié
    final latDiff =
        bounds.northeast.coordinates.lat - bounds.southwest.coordinates.lat;
    final lonDiff =
        bounds.northeast.coordinates.lng - bounds.southwest.coordinates.lng;
    final maxDiff = math.max(latDiff, lonDiff);

    double zoom = 13.0;
    if (maxDiff > 0.1) {
      zoom = 11.0;
    } else if (maxDiff > 0.05) {
      zoom = 12.0;
    } else if (maxDiff > 0.02) {
      zoom = 13.0;
    } else if (maxDiff > 0.01) {
      zoom = 14.0;
    } else {
      zoom = 15.0;
    }

    await mapboxMap!.flyTo(
      mp.CameraOptions(
        center: mp.Point(coordinates: mp.Position(centerLon, centerLat)),
        zoom: zoom,
        pitch: 0,
        bearing: 0,
      ),
      mp.MapAnimationOptions(duration: 1500),
    );
  }

  void _startRouteNavigation() async {
    try {
      // Restaurer l'affichage du parcours original
      await _showOriginalRoute();

      bool success = await NavigationService.startCustomNavigation(
        coordinates: generatedRouteCoordinates!,
        onUpdate: _handleRouteNavigationUpdate,
      );

      if (success) {
        setState(() {
          isNavigationMode = true;
          navigationMode = 'on_route';
          isNavigatingToRoute = false;
          currentInstruction = "Navigation du parcours démarrée...";
        });

        await _switchToNavigationView();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Navigation du parcours démarrée !',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur: ${e.toString()}',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<List<double>> _getRouteToStartCoordinates() {
    // ✅ FIX: Retourner les vraies coordonnées d'itinéraire
    if (routeToStartCoordinates != null &&
        routeToStartCoordinates!.isNotEmpty) {
      return routeToStartCoordinates!;
    }

    // Fallback: route simple si pas d'itinéraire calculé
    if (generatedRouteCoordinates != null &&
        userLongitude != null &&
        userLatitude != null) {
      final startPoint = generatedRouteCoordinates!.first;
      return [
        [userLongitude!, userLatitude!],
        [startPoint[0], startPoint[1]],
      ];
    }

    return [];
  }

  void _handleNavigationToRouteUpdate(NavigationUpdate update) {
    setState(() {
      currentNavUpdate = update;
      currentInstruction = update.instruction;
    });

    // ✅ FIX: Utiliser les vraies coordonnées d'itinéraire pour le bearing
    final routeCoords = _getRouteToStartCoordinates();
    if (routeCoords.isNotEmpty) {
      _setActiveNavigationRoute(routeCoords);
    }

    _updateNavigationCameraWithRoute(
      update.currentPosition[0],
      update.currentPosition[1],
    );

    // Si on arrive au point de départ du parcours
    if (update.isFinished) {
      _onArrivedAtRouteStart();
    }
  }

  void _handleRouteNavigationUpdate(NavigationUpdate update) {
    setState(() {
      currentNavUpdate = update;
      currentInstruction = update.instruction;
    });

    // ✅ FIX: Définir la route active pour le calcul de bearing
    if (generatedRouteCoordinates != null) {
      _setActiveNavigationRoute(generatedRouteCoordinates!);
    }

    _updateNavigationCameraWithRoute(
      update.currentPosition[0],
      update.currentPosition[1],
    );

    // Si le parcours est terminé
    if (update.isFinished) {
      _stopNavigation();
    }
  }

  void _setActiveNavigationRoute(List<List<double>> route) {
    setState(() {
      activeNavigationRoute = List.from(route);
      currentRouteSegmentIndex = 0;
    });

    print('🛣️ Route active définie: ${route.length} points');
  }

  void _onArrivedAtRouteStart() {
    // Arrêter la navigation vers le parcours
    NavigationService.stopNavigation();

    setState(() {
      isNavigatingToRoute = false;
      navigationMode = 'none';
      isNavigationMode = false;
      routeToStartCoordinates = null; // ✅ FIX: Nettoyer l'itinéraire
      activeNavigationRoute = null;
    });

    // Proposer de démarrer le parcours
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.black,
            title: Text(
              'Point de départ atteint !',
              style: context.titleMedium?.copyWith(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                        color: Colors.green,
                        size: 48,
                      ),
                      12.h,
                      Text(
                        'Vous êtes arrivé au point de départ du parcours !',
                        style: context.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showOriginalRoute(); // Restaurer l'affichage du parcours
                  _switchToNormalView();
                },
                child: Text(
                  'Plus tard',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startRouteNavigation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: Text('Commencer le parcours'),
              ),
            ],
          ),
    );
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  Future<void> _switchToNavigationView() async {
    if (mapboxMap == null) return;

    print('🎥 Activation du mode caméra navigation');

    setState(() {
      isNavigationCameraActive = true;
    });

    // FIX: Configuration initiale de la caméra pour la navigation
    await mapboxMap!.setCamera(
      mp.CameraOptions(
        zoom: 18.0, // Zoom rapproché pour la navigation
        pitch: 65.0, // Vue en perspective (derrière l'épaule)
        bearing: 0.0, // Sera mis à jour selon la direction
      ),
    );

    // Activer le suivi de position en temps réel avec haute précision
    await mapboxMap!.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        showAccuracyRing: false, // Masquer le cercle de précision en navigation
      ),
    );

    // Démarrer le timer de mise à jour de position
    _startNavigationPositionUpdates();
  }

  void _startNavigationPositionUpdates() {
    positionUpdateTimer?.cancel();

    positionUpdateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!isNavigationCameraActive || !isNavigationMode) {
        timer.cancel();
        return;
      }

      // Mettre à jour la position utilisateur si disponible
      if (userLongitude != null && userLatitude != null) {
        _updateNavigationCamera(userLongitude!, userLatitude!);
      }
    });
  }

  void _updateNavigationCamera(double longitude, double latitude) async {
    if (mapboxMap == null || !isNavigationCameraActive) return;

    // Ajouter la position actuelle à l'historique
    final currentPosition = [longitude, latitude];
    userPositionHistory.add(currentPosition);

    // Garder seulement les 10 dernières positions pour calculer la direction
    if (userPositionHistory.length > 10) {
      userPositionHistory.removeAt(0);
    }

    // Calculer la direction de déplacement
    double bearing = _calculateMovementBearing();

    // Lisser le changement de bearing pour éviter les mouvements brusques
    bearing = _smoothBearing(currentUserBearing, bearing);
    currentUserBearing = bearing;

    try {
      // FIX: Mettre à jour la caméra pour suivre l'utilisateur
      await mapboxMap!.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(longitude, latitude)),
          zoom: 18.0, // Zoom constant pour navigation
          pitch: 65.0, // Vue en perspective constante
          bearing: bearing, // Orientation selon le déplacement
        ),
        mp.MapAnimationOptions(
          duration: 800, // Animation fluide mais pas trop lente
        ),
      );

      print('🧭 Caméra mise à jour: bearing=${bearing.toStringAsFixed(1)}°');
    } catch (e) {
      print('❌ Erreur mise à jour caméra navigation: $e');
    }
  }

  double _calculateRouteBearing() {
    // Si pas de route active, utiliser l'ancien système
    if (activeNavigationRoute == null ||
        activeNavigationRoute!.isEmpty ||
        userLongitude == null ||
        userLatitude == null) {
      return _calculateMovementBearing();
    }

    try {
      // 1. Trouver le segment de route le plus proche
      final currentSegmentIndex = _findNearestRouteSegment();

      // 2. Calculer le bearing vers la suite de la route
      final routeBearing = _calculateBearingToNextRouteSegment(
        currentSegmentIndex,
      );

      print(
        '🧭 Route bearing calculé: segment=$currentSegmentIndex, bearing=${routeBearing.toStringAsFixed(1)}°',
      );

      return routeBearing;
    } catch (e) {
      print('❌ Erreur calcul route bearing: $e');
      return _calculateMovementBearing(); // Fallback
    }
  }

  int _findNearestRouteSegment() {
    if (activeNavigationRoute == null || activeNavigationRoute!.isEmpty) {
      return 0;
    }

    double minDistance = double.infinity;
    int nearestIndex = 0;

    for (int i = 0; i < activeNavigationRoute!.length; i++) {
      final routePoint = activeNavigationRoute![i];
      final distance = _calculateDistance(
        userLatitude!,
        userLongitude!,
        routePoint[1], // latitude
        routePoint[0], // longitude
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    // Sauvegarder l'index pour optimiser les prochaines recherches
    currentRouteSegmentIndex = nearestIndex;

    print(
      '📍 Segment le plus proche: $nearestIndex (distance: ${minDistance.toStringAsFixed(1)}m)',
    );

    return nearestIndex;
  }

  double _calculateBearingToNextRouteSegment(int currentIndex) {
    if (activeNavigationRoute == null ||
        activeNavigationRoute!.isEmpty ||
        currentIndex >= activeNavigationRoute!.length - 1) {
      return currentUserBearing; // Garder la direction actuelle
    }

    // Point de la route le plus proche
    final currentRoutePoint = activeNavigationRoute![currentIndex];

    // 1. Méthode simple : bearing vers le prochain point
    final nextPoint = activeNavigationRoute![currentIndex + 1];
    double bearing = _calculateBearing(
      currentRoutePoint[1],
      currentRoutePoint[0], // lat, lon du point actuel
      nextPoint[1],
      nextPoint[0], // lat, lon du point suivant
    );

    // 2. Méthode avancée : regarder plus loin pour anticiper les virages
    final lookAheadPoint = _findLookAheadPoint(currentIndex);
    if (lookAheadPoint != null) {
      // Calculer le bearing vers le point d'anticipation
      bearing = _calculateBearing(
        userLatitude!,
        userLongitude!, // Position actuelle de l'utilisateur
        lookAheadPoint[1],
        lookAheadPoint[0], // Point d'anticipation
      );

      print(
        '👀 Look-ahead activé vers point distant de ${_calculateDistance(userLatitude!, userLongitude!, lookAheadPoint[1], lookAheadPoint[0]).toStringAsFixed(1)}m',
      );
    }

    return bearing;
  }

  List<double>? _findLookAheadPoint(int currentIndex) {
    if (activeNavigationRoute == null ||
        currentIndex >= activeNavigationRoute!.length - 1) {
      return null;
    }

    double accumulatedDistance = 0.0;

    for (int i = currentIndex; i < activeNavigationRoute!.length - 1; i++) {
      final point1 = activeNavigationRoute![i];
      final point2 = activeNavigationRoute![i + 1];

      final segmentDistance = _calculateDistance(
        point1[1],
        point1[0],
        point2[1],
        point2[0],
      );

      accumulatedDistance += segmentDistance;

      // Si on a atteint la distance d'anticipation
      if (accumulatedDistance >= lookAheadDistance) {
        return point2;
      }
    }

    // Si la route est plus courte que la distance d'anticipation, retourner le dernier point
    return activeNavigationRoute!.last;
  }

  double _getAdaptiveZoom(double speedMps) {
    // Ajuster le zoom selon la vitesse
    if (speedMps < 1.5) return 19.0; // Marche lente
    if (speedMps < 3.0) return 18.0; // Marche rapide
    if (speedMps < 8.0) return 17.0; // Course
    return 16.0; // Vélo
  }

  double _getAdaptivePitch(double speedMps) {
    // Plus on va vite, plus on regarde loin (pitch moins prononcé)
    if (speedMps < 1.5) return 70.0; // Vue très inclinée pour marche
    if (speedMps < 3.0) return 65.0; // Vue normale pour course
    return 55.0; // Vue plus plate pour vélo
  }

  void _updateNavigationCameraWithRoute(
    double longitude,
    double latitude,
  ) async {
    if (mapboxMap == null || !isNavigationCameraActive) return;

    // Ajouter la position actuelle à l'historique
    final currentPosition = [longitude, latitude];
    userPositionHistory.add(currentPosition);

    if (userPositionHistory.length > navigationConfig.positionHistorySize) {
      userPositionHistory.removeAt(0);
    }

    // ✅ FIX: Utiliser le bearing basé sur la route au lieu du mouvement
    double bearing = _calculateRouteBearing();

    // Lisser le changement de bearing
    bearing = _smoothBearing(currentUserBearing, bearing);
    currentUserBearing = bearing;

    // Adapter selon la vitesse si disponible
    final adaptiveZoom = _getAdaptiveZoom(
      0.0,
    ); // TODO: intégrer la vitesse réelle
    final adaptivePitch = _getAdaptivePitch(0.0);

    try {
      await mapboxMap!.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(longitude, latitude)),
          zoom: adaptiveZoom,
          pitch: adaptivePitch,
          bearing: bearing,
        ),
        mp.MapAnimationOptions(duration: navigationConfig.updateIntervalMs),
      );

      print(
        '🧭 Caméra route: bearing=${bearing.toStringAsFixed(1)}° (vers route)',
      );
    } catch (e) {
      print('❌ Erreur caméra route: $e');
    }
  }

  double _calculateMovementBearing() {
    if (userPositionHistory.length < 2) {
      return currentUserBearing; // Garder la direction actuelle si pas assez de données
    }

    // Utiliser les 3 dernières positions pour une direction plus stable
    final recentPositions =
        userPositionHistory.length >= 3
            ? userPositionHistory.sublist(userPositionHistory.length - 3)
            : userPositionHistory;

    if (recentPositions.length < 2) {
      return currentUserBearing;
    }

    // Calculer la direction entre la première et dernière position récente
    final start = recentPositions.first;
    final end = recentPositions.last;

    // Vérifier que l'utilisateur s'est effectivement déplacé
    final distance = _calculateDistance(start[1], start[0], end[1], end[0]);

    if (distance < 5.0) {
      // Mouvement trop petit (moins de 5m), garder la direction actuelle
      return currentUserBearing;
    }

    // Calculer le bearing réel
    final bearing = _calculateBearing(start[1], start[0], end[1], end[0]);

    print(
      '📍 Mouvement détecté: ${distance.toStringAsFixed(1)}m, bearing=${bearing.toStringAsFixed(1)}°',
    );

    return bearing;
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final double dLon = (lon2 - lon1) * math.pi / 180;
    final double lat1Rad = lat1 * math.pi / 180;
    final double lat2Rad = lat2 * math.pi / 180;

    final double y = math.sin(dLon) * math.cos(lat2Rad);
    final double x =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    final double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  double _smoothBearing(double currentBearing, double targetBearing) {
    double diff = targetBearing - currentBearing;

    // Gérer le passage par 0° (nord)
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }

    // ✅ FIX: Ajuster la vitesse de changement selon l'angle
    double maxBearingChange = navigationConfig.maxBearingChange;

    // Pour les grands virages (>90°), permettre des changements plus rapides
    if (diff.abs() > 90) {
      maxBearingChange =
          25.0; // Changements plus rapides pour les virages serrés
    } else if (diff.abs() > 45) {
      maxBearingChange = 20.0; // Changements modérés pour les virages moyens
    }

    if (diff.abs() > maxBearingChange) {
      diff = diff.sign * maxBearingChange;
    }

    double newBearing = currentBearing + diff;

    // Normaliser entre 0-360
    if (newBearing < 0) {
      newBearing += 360;
    } else if (newBearing >= 360) {
      newBearing -= 360;
    }

    return newBearing;
  }

  void _stopNavigation() async {
    await NavigationService.stopNavigation();

    // Nettoyer les polylignes temporaires et restaurer l'original si nécessaire
    if (isNavigatingToRoute && routeToStartPolyline != null) {
      await polylineManager?.delete(routeToStartPolyline!);
      routeToStartPolyline = null;
      await _showOriginalRoute(); // Restaurer le parcours original
    }

    setState(() {
      isNavigationMode = false;
      isNavigatingToRoute = false;
      navigationMode = 'none';
      currentNavUpdate = null;
      currentInstruction = "";
    });

    await _switchToNormalView();

    final message =
        isNavigatingToRoute
            ? 'Navigation vers le parcours arrêtée'
            : 'Navigation du parcours terminée';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _switchToNormalView() async {
    if (mapboxMap == null) return;

    print('🎥 Désactivation du mode caméra navigation');

    setState(() {
      isNavigationCameraActive = false;
      activeNavigationRoute = null; // ✅ FIX: Nettoyer la route active
      currentRouteSegmentIndex = 0;
    });

    // Arrêter les mises à jour de position
    positionUpdateTimer?.cancel();

    // Remettre la vue normale
    await mapboxMap!.setCamera(
      mp.CameraOptions(
        pitch: 0.0, // Vue plate
        bearing: 0.0, // Nord vers le haut
        zoom: 13.0, // Zoom moins rapproché
      ),
    );

    // Remettre les paramètres de localisation normaux
    await mapboxMap!.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        showAccuracyRing: true, // Réafficher le cercle de précision
      ),
    );

    // Vider l'historique des positions
    userPositionHistory.clear();
    currentUserBearing = 0.0;
  }

  Future<void> _setActiveLocation({
    required double latitude,
    required double longitude,
    bool userPosition = false,
    bool moveCamera = true,
    bool addMarker = false,
  }) async {
    if (mapboxMap == null || circleAnnotationManager == null) return;

    // 1) Pause ou resume le suivi
    if (userPosition) {
      userPositionStream?.resume();
    } else {
      userPositionStream?.pause();
    }
    setState(() => isTrackingUser = userPosition);

    // 2) Nettoyage des anciens cercles + marqueurs si on en pose un nouveau
    await circleAnnotationManager!.deleteAll();
    if (addMarker && markerCircleManager != null) {
      for (final m in locationMarkers) {
        await markerCircleManager!.delete(m);
      }
      locationMarkers.clear();
    }

    // 3) Centrage caméra (si demandé)
    if (moveCamera) {
      await mapboxMap!.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(longitude, latitude)),
          zoom: userPosition ? 13 : 13,
          pitch: 0,
          bearing: 0,
        ),
        mp.MapAnimationOptions(duration: 1000),
      );
    }

    // 5) Marqueur rouge (facultatif)
    if (addMarker) {
      markerCircleManager ??=
          await mapboxMap!.annotations.createCircleAnnotationManager();
      final red = await markerCircleManager!.create(
        mp.CircleAnnotationOptions(
          geometry: mp.Point(coordinates: mp.Position(longitude, latitude)),
          circleColor: AppColors.primary.toARGB32(),
          circleRadius: 7,
          circleStrokeWidth: 2,
          circleStrokeColor: Colors.white.toARGB32(),
        ),
      );
      locationMarkers.add(red);
    }

    // 6) Mise à jour du state / BLoC
    setState(() {
      currentLatitude = latitude;
      currentLongitude = longitude;
    });
    context.read<RouteParametersBloc>().add(
      StartLocationUpdated(longitude: longitude, latitude: latitude),
    );
  }

  Future<void> _setupPositionTracking() async {
    bool serviceEnabled;
    gl.LocationPermission permission;

    serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permission.',
      );
    }

    gl.LocationSettings locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 2, // FIX: Réduire à 2m pour une navigation plus fluide
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((gl.Position? pos) {
      if (pos != null) {
        setState(() {
          userLongitude = pos.longitude;
          userLatitude = pos.latitude;

          // Si aucune position de recherche n'est définie, utiliser la position utilisateur
          if (currentLongitude == null || currentLatitude == null) {
            _setActiveLocation(
              latitude: pos.latitude,
              longitude: pos.longitude,
              userPosition: true,
              moveCamera:
                  !isNavigationCameraActive, // FIX: Ne pas bouger la caméra si en mode navigation
              addMarker: false,
            );
          }
        });

        // FIX: En mode navigation, utiliser la caméra spécialisée
        if (mapboxMap != null && isTrackingUser && !isNavigationCameraActive) {
          mapboxMap?.setCamera(
            mp.CameraOptions(
              zoom: 13,
              center: mp.Point(
                coordinates: mp.Position(pos.longitude, pos.latitude),
              ),
            ),
          );
        }
      } else {
        mapboxMap?.setCamera(
          mp.CameraOptions(
            center: mp.Point(coordinates: mp.Position(-98.0, 39.5)),
            zoom: 2,
            bearing: 0,
            pitch: 0,
          ),
        );
      }
    });
  }

  _onMapCreated(mp.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    // Enregistrer la carte dans le BLoC
    context.read<MapStyleBloc>().add(MapRegistered(mapboxMap));

    mapboxMap.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    // Créer le gestionnaire d'annotations
    pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    circleAnnotationManager =
        await mapboxMap.annotations.createCircleAnnotationManager();

    // Masquer les éléments d'interface
    await mapboxMap.compass.updateSettings(mp.CompassSettings(enabled: false));
    await mapboxMap.attribution.updateSettings(
      mp.AttributionSettings(enabled: false),
    );
    await mapboxMap.logo.updateSettings(mp.LogoSettings(enabled: false));
    await mapboxMap.scaleBar.updateSettings(
      mp.ScaleBarSettings(enabled: false),
    );

    // Configurer le listener de scroll pour désactiver le suivi
    mapboxMap.setOnMapMoveListener((context) {
      // Si le mouvement n'est pas causé par une mise à jour de position
      if (isTrackingUser) {
        setState(() {
          isTrackingUser = false;
        });
      }
    });
  }

  void _onLocationSelected(
    double longitude,
    double latitude,
    String placeName,
  ) async {
    if (mapboxMap == null) return;

    // désactive les mises à jour automatiques
    userPositionStream?.pause();
    setState(() => isTrackingUser = false);

    // nettoyer markers + ancien cercle (au cas où)
    await _clearLocationMarkers();
    await circleAnnotationManager?.deleteAll();

    // Si aucune position de recherche n'est définie, utiliser la position utilisateur
    if (currentLongitude == null || currentLatitude == null) {
      currentLongitude = longitude;
      currentLatitude = latitude;
    }

    // Centrer la carte sur la nouvelle position avec animation
    await mapboxMap!.flyTo(
      mp.CameraOptions(
        center: mp.Point(coordinates: mp.Position(longitude, latitude)),
        zoom: 13,
        pitch: 0,
        bearing: 0,
      ),
      mp.MapAnimationOptions(duration: 1500),
    );

    // Créer un CircleAnnotationManager si pas déjà fait
    markerCircleManager ??=
        await mapboxMap!.annotations.createCircleAnnotationManager();

    // Créer un cercle rouge comme marqueur
    final redMarker = await markerCircleManager!.create(
      mp.CircleAnnotationOptions(
        geometry: mp.Point(coordinates: mp.Position(longitude, latitude)),
        circleColor: AppColors.primary.toARGB32(),
        circleRadius: 7.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
    locationMarkers.add(redMarker);

    // Mettre à jour la position dans le BLoC
    context.read<RouteParametersBloc>().add(
      StartLocationUpdated(longitude: longitude, latitude: latitude),
    );
  }

  Future<void> _clearLocationMarkers() async {
    if (markerCircleManager != null && locationMarkers.isNotEmpty) {
      // Supprimer tous les marqueurs
      for (final marker in locationMarkers) {
        await markerCircleManager!.delete(marker);
      }
      locationMarkers.clear();
    }
  }

  void openGenerator() {
    showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      context: context,
      backgroundColor: Colors.black,
      builder: (modalCtx) {
        return gen.RouteParameterScreen(
          startLongitude: currentLongitude ?? userLongitude ?? 0.0,
          startLatitude: currentLatitude ?? userLatitude ?? 0.0,
          generateRoute: _handleRouteGeneration,
        );
      },
    );
  }

  void _onSearchCleared() async {
    // Supprimer les marqueurs de localisation
    await _clearLocationMarkers();

    // Réinitialiser la position actuelle à la position de l'utilisateur
    if (userLongitude != null && userLatitude != null) {
      setState(() {
        currentLongitude = userLongitude;
        currentLatitude = userLatitude;
      });

      // Mettre à jour la position dans le BLoC
      context.read<RouteParametersBloc>().add(
        StartLocationUpdated(
          longitude: userLongitude!,
          latitude: userLatitude!,
        ),
      );
    }
  }

  void _goToUserLocation() async {
    if (userLongitude != null && userLatitude != null && mapboxMap != null) {
      // Activer le suivi en temps réel
      userPositionStream?.resume();
      setState(() {
        isTrackingUser = true;
        currentLongitude = userLongitude;
        currentLatitude = userLatitude;
      });

      await mapboxMap!.flyTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(userLongitude!, userLatitude!),
          ),
          zoom: 13,
        ),
        mp.MapAnimationOptions(duration: 1000),
      );

      // Attendre la fin de l'animation
      await Future.delayed(Duration(milliseconds: 1100));

      _onSearchCleared();
    } else {
      // Si la position n'est pas disponible, essayer de l'obtenir
      _setupPositionTracking();
    }
  }

  void _handleRouteGeneration() async {
    setState(() {
      isGenerateEnabled = true;
    });

    try {
      final parameters = context.read<RouteParametersBloc>().state.parameters;

      print('🚀 Génération de parcours via API GraphHopper...');

      final result = await GraphHopperApiService.generateRoute(
        parameters: parameters,
      );

      if (!mounted) return;

      // Convertir pour l'affichage sur la carte
      final routeCoordinates = result.coordinatesForUI;

      // FIX: Vérification plus robuste
      if (routeCoordinates.isEmpty) {
        throw Exception('Aucune coordonnée reçue du serveur');
      }

      print('✅ Coordonnées reçues: ${routeCoordinates.length}');

      // FIX: Construction sécurisée des stats
      final routeStats = _buildStatsFromGraphHopper(result);
      print('📊 Stats générées: $routeStats');

      // FIX: Sauvegarde sécurisée
      File? routeFile;
      try {
        routeFile = await _saveRouteToGeoJson(routeCoordinates, parameters);
      } catch (e) {
        print('⚠️ Erreur sauvegarde fichier: $e');
        // Continuer sans fichier
      }

      // FIX: Mettre à jour l'état AVANT d'afficher la route
      setState(() {
        generatedRouteCoordinates = routeCoordinates;
        generatedRouteStats = routeStats;
        generatedRouteFile = routeFile; // Peut être null
        isGenerateEnabled = false;
      });

      // FIX: Affichage sécurisé de la route
      try {
        await _displayRoute(routeCoordinates);
      } catch (e) {
        print('⚠️ Erreur affichage route: $e');
        // Continuer même si l'affichage échoue
      }

      // FIX: Dialog sécurisé
      if (routeFile != null) {
        _showGraphHopperRouteResults(result, routeFile);
      }
    } catch (e) {
      print('❌ Erreur génération API: $e');

      if (!mounted) return;

      setState(() {
        isGenerateEnabled = false;
        generatedRouteCoordinates = null;
        generatedRouteStats = null;
        generatedRouteFile = null;
      });

      _showErrorSnackBar('Erreur lors de la génération: ${e.toString()}');
    }
  }

  Map<String, dynamic> _buildStatsFromGraphHopper(
    GraphHopperRouteResult result,
  ) {
    final stats = {
      'distance_km': result.distanceKm, // FIX: Garder comme double, pas string
      'is_loop': result.metadata['route_type'] == 'loop' || true,
      'points_count': result.coordinates.length,
      'generation_method': 'graphhopper_api',
      'duration_minutes': result.durationMinutes,
      'elevation_gain': result.elevationGain.round(),
      'instructions_count': result.instructions.length,
    };

    print('🔍 Building stats: $stats');
    return stats;
  }

  void _showGraphHopperRouteResults(
    GraphHopperRouteResult result,
    File routeFile,
  ) {
    showDialog(
      useRootNavigator: true,
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedRoute03,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Parcours généré !', style: context.titleMedium),
                      Text(
                        '${result.distanceKm.toStringAsFixed(2)} km • GraphHopper API • ${result.durationMinutes}min',
                        style: context.bodySmall?.copyWith(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informations sur la route
                  _buildStatsCard('Parcours généré', [
                    '📏 ${result.distanceKm.toStringAsFixed(2)} km',
                    '⏱️ ~${result.durationMinutes} minutes',
                    '⛰️ ${result.elevationGain.round()}m de dénivelé',
                    '📍 ${result.coordinates.length} points GPS',
                    '🧭 ${result.instructions.length} instructions',
                  ]),

                  16.h,

                  // Métadonnées techniques
                  if (result.metadata.isNotEmpty)
                    _buildStatsCard('Détails techniques', [
                      for (final entry in result.metadata.entries)
                        '• ${entry.key}: ${entry.value}',
                    ]),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Fermer'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _shareCurrentRoute();
                },
                child: Text('Partager'),
              ),
            ],
          ),
    );
  }

  Future<void> _displayRoute(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) {
      print(
        '⚠️ Impossible d\'afficher la route: carte non initialisée ou coordonnées vides',
      );
      return;
    }

    print('🗺️ Affichage de la route: ${coordinates.length} points');

    // Sauvegarder les coordonnées
    setState(() {
      generatedRouteCoordinates = coordinates;
    });

    // Créer un gestionnaire de polylignes si nécessaire
    try {
      polylineManager ??=
          await mapboxMap!.annotations.createPolylineAnnotationManager();
    } catch (e) {
      print('❌ Erreur création polyline manager: $e');
      return;
    }

    // Supprimer l'ancienne route si elle existe
    if (currentRoutePolyline != null) {
      try {
        await polylineManager!.delete(currentRoutePolyline!);
      } catch (e) {
        print('⚠️ Erreur suppression ancienne route: $e');
      }
    }

    try {
      // Créer la nouvelle polyligne
      currentRoutePolyline = await polylineManager!.create(
        mp.PolylineAnnotationOptions(
          geometry: mp.LineString(
            coordinates:
                coordinates
                    .map((coord) => mp.Position(coord[0], coord[1]))
                    .toList(),
          ),
          lineColor: Theme.of(context).primaryColor.toARGB32(),
          lineWidth: 4.0,
          lineOpacity: 0.9,
          lineJoin: mp.LineJoin.ROUND,
        ),
      );

      print('✅ Polyligne créée avec succès');

      // Ajuster la vue pour montrer toute la route
      final bounds = _calculateBounds(coordinates);
      final centerLon =
          (bounds.southwest.coordinates.lng +
              bounds.northeast.coordinates.lng) /
          2;
      final centerLat =
          (bounds.southwest.coordinates.lat +
              bounds.northeast.coordinates.lat) /
          2;

      // Calculer le zoom approprié
      final latDiff =
          bounds.northeast.coordinates.lat - bounds.southwest.coordinates.lat;
      final lonDiff =
          bounds.northeast.coordinates.lng - bounds.southwest.coordinates.lng;
      final maxDiff = math.max(latDiff, lonDiff);

      double zoom = 13.0;
      if (maxDiff > 0.1) {
        zoom = 11.0;
      } else if (maxDiff > 0.05) {
        zoom = 12.0;
      } else if (maxDiff > 0.02) {
        zoom = 13.0;
      } else if (maxDiff > 0.01) {
        zoom = 14.0;
      } else {
        zoom = 15.0;
      }

      await mapboxMap!.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(centerLon, centerLat)),
          zoom: zoom - 0.5,
          pitch: 0,
          bearing: 0,
        ),
        mp.MapAnimationOptions(duration: 1500),
      );

      print('✅ Vue ajustée à la route');

      // Ajouter des marqueurs pour le début et la fin
      await _addRouteMarkers(coordinates);
    } catch (e) {
      print('❌ Erreur affichage route: $e');
      rethrow;
    }
  }

  mp.CoordinateBounds _calculateBounds(List<List<double>> coordinates) {
    double minLon = coordinates.first[0];
    double maxLon = coordinates.first[0];
    double minLat = coordinates.first[1];
    double maxLat = coordinates.first[1];

    for (final coord in coordinates) {
      minLon = math.min(minLon, coord[0]);
      maxLon = math.max(maxLon, coord[0]);
      minLat = math.min(minLat, coord[1]);
      maxLat = math.max(maxLat, coord[1]);
    }

    return mp.CoordinateBounds(
      southwest: mp.Point(coordinates: mp.Position(minLon, minLat)),
      northeast: mp.Point(coordinates: mp.Position(maxLon, maxLat)),
      infiniteBounds: false, // Ajout du paramètre requis
    );
  }

  Future<void> _addRouteMarkers(List<List<double>> coordinates) async {
    if (coordinates.isEmpty) return;

    try {
      // FIX: Initialiser le manager si nécessaire
      markerCircleManager ??=
          await mapboxMap!.annotations.createCircleAnnotationManager();

      // Marqueur de départ (vert)
      await markerCircleManager!.create(
        mp.CircleAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(
              coordinates.first[0],
              coordinates.first[1],
            ),
          ),
          circleColor: Colors.green.toARGB32(),
          circleRadius: 10.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.toARGB32(),
        ),
      );

      // Marqueur d'arrivée (rouge) si différent du départ
      final isLoop =
          (coordinates.first[0] - coordinates.last[0]).abs() < 0.0001 &&
          (coordinates.first[1] - coordinates.last[1]).abs() < 0.0001;

      if (!isLoop) {
        await markerCircleManager!.create(
          mp.CircleAnnotationOptions(
            geometry: mp.Point(
              coordinates: mp.Position(
                coordinates.last[0],
                coordinates.last[1],
              ),
            ),
            circleColor: Colors.red.toARGB32(),
            circleRadius: 10.0,
            circleStrokeWidth: 3.0,
            circleStrokeColor: Colors.white.toARGB32(),
          ),
        );
      }

      print('✅ Marqueurs ajoutés');
    } catch (e) {
      print('⚠️ Erreur ajout marqueurs: $e');
      // Ne pas faire échouer le processus pour les marqueurs
    }
  }

  double _parseDistance(dynamic distanceValue) {
    if (distanceValue == null) return 0.0;
    if (distanceValue is double) return distanceValue;
    if (distanceValue is int) return distanceValue.toDouble();
    if (distanceValue is String) return double.tryParse(distanceValue) ?? 0.0;
    return 0.0;
  }

  Future<File> _saveRouteToGeoJson(
    List<List<double>> coordinates,
    RouteParameters parameters,
  ) async {
    final routeGeoJson = {
      'type': 'FeatureCollection',
      'metadata': {
        'generated_at': DateTime.now().toIso8601String(),
        'generator': 'RunAway App - Generated Route',
        'parameters': {
          'activity': parameters.activityType.title,
          'distance_km': parameters.distanceKm,
          'terrain': parameters.terrainType.title,
          'urban_density': parameters.urbanDensity.title,
          'elevation_gain': parameters.elevationGain,
          'is_loop': parameters.isLoop,
        },
      },
      'features': [
        {
          'type': 'Feature',
          'properties': {
            'name': 'Generated Route',
            'distance_km': _calculateTotalDistance(
              coordinates,
            ).toStringAsFixed(2),
          },
          'geometry': {'type': 'LineString', 'coordinates': coordinates},
        },
      ],
    };

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/generated_route_$timestamp.geojson');

    final jsonString = JsonEncoder.withIndent('  ').convert(routeGeoJson);
    await file.writeAsString(jsonString);

    return file;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371000; // Rayon de la Terre en mètres
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _calculateTotalDistance(List<List<double>> coords) {
    if (coords.isEmpty || coords.length < 2) return 0.0;

    double total = 0;
    for (int i = 0; i < coords.length - 1; i++) {
      if (coords[i].length >= 2 && coords[i + 1].length >= 2) {
        total += _calculateDistance(
          coords[i][1], // lat1
          coords[i][0], // lon1
          coords[i + 1][1], // lat2
          coords[i + 1][0], // lon2
        );
      }
    }
    return total / 1000; // Convertir en km
  }

  Widget _buildStatsCard(String title, List<String> stats) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
          ),
          8.h,
          ...stats.map(
            (stat) => Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text(
                stat,
                style: context.bodySmall?.copyWith(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              color: Colors.white,
              size: 24,
            ),
            12.w,
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Réessayez avec un rayon plus petit',
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _lockPositionOnScreenCenter() async {
    if (mapboxMap == null) return;

    final cam = await mapboxMap!.getCameraState(); // CameraState
    final mp.Position pos = cam.center.coordinates; // <-- Position

    final double lon = pos.lng.toDouble(); // getter `lng`
    final double lat = pos.lat.toDouble(); // getter `lat`

    setState(() {
      currentLongitude = lon;
      currentLatitude = lat;
    });

    // Supprimer les marqueurs précédents s'ils existent
    await _clearLocationMarkers();

    // Créer un CircleAnnotationManager si pas déjà fait
    markerCircleManager ??=
        await mapboxMap!.annotations.createCircleAnnotationManager();

    // Créer un cercle rouge comme marqueur
    final redMarker = await markerCircleManager!.create(
      mp.CircleAnnotationOptions(
        geometry: mp.Point(coordinates: mp.Position(lon, lat)),
        circleColor: AppColors.primary.toARGB32(),
        circleRadius: 7.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
    locationMarkers.add(redMarker);

    // Mettre à jour la position dans le BLoC
    context.read<RouteParametersBloc>().add(
      StartLocationUpdated(longitude: lon, latitude: lat),
    );
  }

  Future<void> _clearRoute() async {
    // Arrêter la navigation si active
    if (isNavigationMode) {
      _stopNavigation();
    }

    // Nettoyer toutes les polylignes
    if (polylineManager != null) {
      if (currentRoutePolyline != null) {
        await polylineManager!.delete(currentRoutePolyline!);
        currentRoutePolyline = null;
      }
      if (routeToStartPolyline != null) {
        await polylineManager!.delete(routeToStartPolyline!);
        routeToStartPolyline = null;
      }
      originalRoutePolyline = null;
    }

    // Nettoyer les marqueurs de début/fin
    if (markerCircleManager != null) {
      await markerCircleManager!.deleteAll();
      locationMarkers.clear();
    }

    // FIX: Seulement faire setState si le widget est encore monté
    if (mounted) {
      setState(() {
        generatedRouteCoordinates = null;
        generatedRouteStats = null;
        generatedRouteFile = null;
        isNavigatingToRoute = false;
        navigationMode = 'none';

        // Nettoyer les variables de navigation
        routeToStartCoordinates = null;
        activeNavigationRoute = null;
        currentRouteSegmentIndex = 0;
      });

      // Réafficher le marqueur de position si nécessaire
      if (currentLongitude != null &&
          currentLatitude != null &&
          !isTrackingUser) {
        _onLocationSelected(
          currentLongitude!,
          currentLatitude!,
          "Position actuelle",
        );
      }
    }
  }

  void _shareCurrentRoute() async {
    if (generatedRouteFile == null) {
      final distance = _parseDistance(generatedRouteStats?['distance_km']);
      final params = ShareParams(
        text: 'Mon parcours RunAway de ${distance.toStringAsFixed(1)} km généré avec l\'application RunAway',
        files: [XFile('${generatedRouteFile!.path}/image.jpg')],
      );

      final result = await SharePlus.instance.share(params);

      if (result.status == ShareResultStatus.success) {
        print('Thank you for sharing the picture!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapStyleBloc, MapStyleState>(
      builder: (context, mapStyleState) {
        return Scaffold(
          extendBody: true,
          resizeToAvoidBottomInset: false,
          body: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Carte
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: mp.MapWidget(
                  key: ValueKey("mapWidget"),
                  onMapCreated: _onMapCreated,
                  styleUri: MapboxStyles.DARK,
                ),
              ),
        
              if (!isNavigationMode) // Masquer en mode navigation
                IgnorePointer(
                  ignoring: true,
                  child: Container(
                    height: MediaQuery.of(context).size.height / 3,
                    decoration: BoxDecoration(
                      gradient: SmoothGradient(
                        from: Colors.black.withValues(alpha: 0),
                        to: Colors.black,
                        curve: Curves.linear,
                        steps: 25,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
        
              // Interface de navigation (overlay)
              if (isNavigationMode)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 15,
                  right: 15,
                  child: NavigationOverlay(
                    instruction: currentInstruction,
                    navUpdate: currentNavUpdate,
                    routeStats: generatedRouteStats!,
                    onStop: _stopNavigation,
                    navigationMode: navigationMode, // Nouveau paramètre
                    isNavigatingToRoute: isNavigatingToRoute, // Nouveau paramètre
                  ),
                ),
        
              // Interface normale (masquée en mode navigation)
              if (!isNavigationMode)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15.0,
                            ),
                            child: LocationSearchBar(
                              onLocationSelected: _onLocationSelected,
                              userLongitude: userLongitude,
                              userLatitude: userLatitude,
                            ),
                          ),
        
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 15.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconBtn(
                                        padding: 10.0,
                                        icon: HugeIcons.strokeRoundedGpsOff02,
                                        onPressed: !isTrackingUser
                                          ? () async => await _lockPositionOnScreenCenter()
                                          : null,
                                        iconColor: isTrackingUser
                                          ? Colors.white38
                                          : Colors.white,
                                      ),
                                      15.h,
                                      IconBtn(
                                        padding: 10.0,
                                        icon: isTrackingUser
                                          ? HugeIcons.solidRoundedLocationShare02
                                          : HugeIcons.strokeRoundedLocationShare02,
                                        onPressed: _goToUserLocation,
                                        iconColor: isTrackingUser
                                          ? AppColors.primary
                                          : Colors.white,
                                      ),
                                      15.h,
                                      IconBtn(
                                        padding: 10.0,
                                        icon: HugeIcons.strokeRoundedAiMagic,
                                        onPressed: openGenerator,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        
              if (isGenerateEnabled) LoadingOverlay(),
        
              // RouteInfoCard (masqué en mode navigation)
              if (generatedRouteCoordinates != null && generatedRouteStats != null && !isNavigationMode) // Masquer pendant la navigation
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  left: 15,
                  right: 15,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          spreadRadius: 3,
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: RouteInfoCard(
                      distance: _parseDistance(
                        generatedRouteStats!['distance_km'],
                      ),
                      isLoop: generatedRouteStats!['is_loop'] as bool? ?? true,
                      waypointCount: generatedRouteStats!['points_count'] as int? ?? 0,
                      onClear: _clearRoute,
                      onNavigate: _startNavigation,
                      onShare: _shareCurrentRoute,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
