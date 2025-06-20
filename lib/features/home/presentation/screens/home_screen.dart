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
  mp.MapboxMap? mapboxMap;
  StreamSubscription? userPositionStream;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;

  mp.CircleAnnotationManager? markerCircleManager;
  List<mp.CircleAnnotation> locationMarkers = [];

  bool isGenerateEnabled = false;

  double? userLongitude;
  double? userLatitude;

  double? currentLongitude;
  double? currentLatitude;

  bool isTrackingUser = true;

  List<List<double>>? generatedRouteCoordinates;
  Map<String, dynamic>? generatedRouteStats;

  bool isNavigationMode = false;

  bool isNavigationCameraActive = false;

  @override
  void initState() {
    super.initState();

    _setupPositionTracking();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    userPositionStream?.cancel();

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
        break;
      default:
        break;
    }
  }

  Future<void> _setupPositionTracking() async {
    bool serviceEnabled;
    gl.LocationPermission permission;

    serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error(context.l10n.disabledLocation);
    }

    permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        return Future.error(context.l10n.deniedPermission);
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      return Future.error(context.l10n.disabledAndDenied);
    }

    gl.LocationSettings locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 2,
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((gl.Position? pos) {
      if (pos != null) {
        setState(() {
          userLongitude = pos.longitude;
          userLatitude = pos.latitude;

          if (currentLongitude == null || currentLatitude == null) {
            _setActiveLocation(
              latitude: pos.latitude,
              longitude: pos.longitude,
              userPosition: true,
              moveCamera: !isNavigationCameraActive, // FIX: Important !
              addMarker: false,
            );
          }
        });

        if (isNavigationCameraActive && mapboxMap != null) {
        } else if (mapboxMap != null && isTrackingUser && !isNavigationCameraActive) {
          // Mise à jour normale seulement si pas en navigation
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
        if (mapboxMap != null) {
          mapboxMap?.setCamera(
            mp.CameraOptions(
              center: mp.Point(coordinates: mp.Position(-98.0, 39.5)),
              zoom: 2,
              bearing: 0,
              pitch: 0,
            ),
          );
        }
      }
    });
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
      markerCircleManager ??= await mapboxMap!.annotations.createCircleAnnotationManager();
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

  _onMapCreated(mp.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

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
          generateRoute: () {},
        );
      },
    );
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
    } 
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
                                    onPressed: () {},
                                    iconColor:
                                        isTrackingUser
                                            ? Colors.white38
                                            : Colors.white,
                                  ),
                                  15.h,
                                  IconBtn(
                                    padding: 10.0,
                                    icon:
                                        isTrackingUser
                                            ? HugeIcons.solidRoundedLocationShare02
                                            : HugeIcons.strokeRoundedLocationShare02,
                                    onPressed: _goToUserLocation,
                                    iconColor:
                                        isTrackingUser
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
          if (generatedRouteCoordinates != null &&
              generatedRouteStats != null &&
              !isNavigationMode) // Masquer pendant la navigation
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
