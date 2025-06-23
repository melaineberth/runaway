import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:hugeicons/hugeicons.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/loading_overlay.dart';
import 'package:runaway/features/home/domain/enums/tracking_mode.dart';
import 'package:runaway/features/home/presentation/widgets/route_info_card.dart';
import 'package:smooth_gradient/smooth_gradient.dart';
import '../../../route_generator/presentation/screens/route_parameter.dart' as gen;
import '../../../../core/widgets/icon_btn.dart';
import '../blocs/route_parameters_bloc.dart';
import '../blocs/route_parameters_event.dart';
import '../widgets/location_search_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // === MAPBOX ===
  mp.MapboxMap? mapboxMap;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;
  mp.CircleAnnotationManager? markerCircleManager;
  List<mp.CircleAnnotation> locationMarkers = [];

  // === POSITIONS ===
  StreamSubscription? _positionStream;
  
  // Position GPS réelle de l'utilisateur (toujours à jour)
  double? _userLatitude;
  double? _userLongitude;
  
  // Position actuellement sélectionnée pour les parcours
  double? _selectedLatitude;
  double? _selectedLongitude;
  
  // Mode de tracking actuel
  TrackingMode _trackingMode = TrackingMode.userTracking;

  // === ROUTE GENERATION ===
  bool isGenerateEnabled = false;
  List<List<double>>? generatedRouteCoordinates;
  Map<String, dynamic>? generatedRouteStats;

  // === NAVIGATION ===
  bool isNavigationMode = false;
  bool isNavigationCameraActive = false;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        print('📱 App en arrière-plan, navigation continue');
        break;
      case AppLifecycleState.resumed:
        print('📱 App au premier plan');
        break;
      default:
        break;
    }
  }

  // === INITIALISATION GÉOLOCALISATION ===
  Future<void> _initializeLocationTracking() async {
    bool serviceEnabled;
    gl.LocationPermission permission;

    // Vérifier si le service de localisation est activé
    serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationError(context.l10n.disabledLocation);
      return;
    }

    // Vérifier les permissions
    permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        _showLocationError(context.l10n.deniedPermission);
        return;
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      _showLocationError(context.l10n.disabledAndDenied);
      return;
    }

    // Configuration du stream de géolocalisation
    gl.LocationSettings locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 2, // Mise à jour tous les 2 mètres
    );

    // Démarrer le stream de position
    _positionStream = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        print('❌ Erreur géolocalisation: $error');
        _showLocationError('Erreur de géolocalisation: $error');
      },
    );
  }

  void _onPositionUpdate(gl.Position position) {
    // Toujours mettre à jour la position utilisateur
    setState(() {
      _userLatitude = position.latitude;
      _userLongitude = position.longitude;
    });

    // Si on est en mode suivi utilisateur, mettre à jour la position sélectionnée
    if (_trackingMode == TrackingMode.userTracking) {
      _updateSelectedPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        updateCamera: true,
      );
    }

    // Mise à jour de la caméra uniquement en mode suivi et si pas en navigation
    if (_trackingMode == TrackingMode.userTracking && 
        mapboxMap != null && 
        !isNavigationCameraActive) {
      mapboxMap?.setCamera(
        mp.CameraOptions(
          zoom: 13,
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
        ),
      );
    }
  }

  // === GESTION DES POSITIONS ===
  void _updateSelectedPosition({
    required double latitude,
    required double longitude,
    bool updateCamera = false,
    bool addMarker = false,
  }) {
    setState(() {
      _selectedLatitude = latitude;
      _selectedLongitude = longitude;
    });

    // Mettre à jour le BLoC
    context.read<RouteParametersBloc>().add(
      StartLocationUpdated(longitude: longitude, latitude: latitude),
    );

    // Mise à jour optionnelle de la caméra
    if (updateCamera && mapboxMap != null) {
      mapboxMap?.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(longitude, latitude)),
          zoom: 13,
          pitch: 0,
          bearing: 0,
        ),
        mp.MapAnimationOptions(duration: 1000),
      );
    }

    // Ajout optionnel d'un marqueur
    if (addMarker) {
      _addLocationMarker(longitude, latitude);
    }
  }

  Future<void> _addLocationMarker(double longitude, double latitude) async {
    if (mapboxMap == null) return;

    // Nettoyer les anciens marqueurs
    await _clearLocationMarkers();

    // Créer le gestionnaire de marqueurs si nécessaire
    markerCircleManager ??= await mapboxMap!.annotations.createCircleAnnotationManager();

    // Ajouter le nouveau marqueur
    final marker = await markerCircleManager!.create(
      mp.CircleAnnotationOptions(
        geometry: mp.Point(coordinates: mp.Position(longitude, latitude)),
        circleColor: AppColors.primary.toARGB32(),
        circleRadius: 7.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
    locationMarkers.add(marker);
  }

  Future<void> _clearLocationMarkers() async {
    if (markerCircleManager != null) {
      for (final marker in locationMarkers) {
        await markerCircleManager!.delete(marker);
      }
      locationMarkers.clear();
    }
    await circleAnnotationManager?.deleteAll();
  }

  // === ACTIONS UTILISATEUR ===
  
  /// Active le mode suivi utilisateur
  void _activateUserTracking() {
    if (_userLatitude != null && _userLongitude != null) {
      setState(() {
        _trackingMode = TrackingMode.userTracking;
      });

      _updateSelectedPosition(
        latitude: _userLatitude!,
        longitude: _userLongitude!,
        updateCamera: true,
      );

      // Nettoyer les marqueurs car on suit la position en temps réel
      _clearLocationMarkers();
    }
  }

  /// Active le mode sélection manuelle
  void _activateManualSelection() async {
    // Ne rien faire si on est déjà en mode suivi utilisateur
    if (_trackingMode == TrackingMode.userTracking) return;
    
    setState(() {
      _trackingMode = TrackingMode.manual;
    });

    // Placer un marqueur au centre de l'écran (caméra actuelle)
    if (mapboxMap != null) {
      try {
        final cameraState = await mapboxMap!.getCameraState();
        final centerCoordinate = cameraState.center;
        
        _updateSelectedPosition(
          latitude: centerCoordinate.coordinates.lat.toDouble(),
          longitude: centerCoordinate.coordinates.lng.toDouble(),
          updateCamera: false,
          addMarker: true,
        );
      } catch (e) {
        print('❌ Erreur récupération centre caméra: $e');
        // Fallback : utiliser la position actuelle si erreur
        if (_selectedLatitude != null && _selectedLongitude != null) {
          _addLocationMarker(_selectedLongitude!, _selectedLatitude!);
        } else if (_userLatitude != null && _userLongitude != null) {
          _updateSelectedPosition(
            latitude: _userLatitude!,
            longitude: _userLongitude!,
            updateCamera: false,
            addMarker: true,
          );
        }
      }
    }
  }

  /// Sélection via recherche d'adresse
  void _onLocationSelected(double longitude, double latitude, String placeName) {
    setState(() {
      _trackingMode = TrackingMode.searchSelected;
    });

    _updateSelectedPosition(
      latitude: latitude,
      longitude: longitude,
      updateCamera: true,
      addMarker: true,
    );
  }

  // === GESTION DE LA CARTE ===
  _onMapCreated(mp.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    mapboxMap.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    // Créer les gestionnaires d'annotations
    pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    circleAnnotationManager = await mapboxMap.annotations.createCircleAnnotationManager();

    // Masquer les éléments d'interface
    await mapboxMap.compass.updateSettings(mp.CompassSettings(enabled: false));
    await mapboxMap.attribution.updateSettings(mp.AttributionSettings(enabled: false));
    await mapboxMap.logo.updateSettings(mp.LogoSettings(enabled: false));
    await mapboxMap.scaleBar.updateSettings(mp.ScaleBarSettings(enabled: false));

    // Configurer le listener de déplacement de carte
    mapboxMap.setOnMapMoveListener((context) {
      // Si on était en mode suivi utilisateur, passer en mode manuel
      if (_trackingMode == TrackingMode.userTracking) {
        setState(() {
          _trackingMode = TrackingMode.manual;
        });
      }
    });

    // Activer la sélection par clic
  }

  void _showLocationError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // === INTERFACE UTILISATEUR ===
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
          startLongitude: _selectedLongitude ?? _userLongitude ?? 0.0,
          startLatitude: _selectedLatitude ?? _userLatitude ?? 0.0,
          generateRoute: () {},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        padding: const EdgeInsets.symmetric(horizontal: 15.0),
                        child: LocationSearchBar(
                          onLocationSelected: _onLocationSelected,
                          userLongitude: _userLongitude,
                          userLatitude: _userLatitude,
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
                                  // Bouton sélection manuelle
                                  IconBtn(
                                    padding: 10.0,
                                    icon: _trackingMode == TrackingMode.manual
                                        ? HugeIcons.solidRoundedGpsOff02
                                        : HugeIcons.strokeRoundedGpsOff02,
                                    onPressed: _activateManualSelection,
                                    iconColor: _trackingMode == TrackingMode.manual
                                        ? Colors.white
                                        : Colors.white38,
                                  ),
                                  15.h,
                                  // Bouton retour position utilisateur
                                  IconBtn(
                                    padding: 10.0,
                                    icon: _trackingMode == TrackingMode.userTracking
                                        ? HugeIcons.solidRoundedLocationShare02
                                        : HugeIcons.strokeRoundedLocationShare02,
                                    onPressed: _activateUserTracking,
                                    iconColor: _trackingMode == TrackingMode.userTracking
                                        ? AppColors.primary
                                        : Colors.white,
                                  ),
                                  15.h,
                                  // Bouton générateur
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
          if (generatedRouteCoordinates != null && generatedRouteStats != null && !isNavigationMode)
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
                  distance: 10,
                  isLoop: generatedRouteStats!['is_loop'] as bool? ?? true,
                  waypointCount: generatedRouteStats!['points_count'] as int? ?? 0,
                  onClear: () {},
                  onNavigate: () {},
                  onShare: () {},
                ),
              ),
            ),
        ],
      ),
    );
  }
}