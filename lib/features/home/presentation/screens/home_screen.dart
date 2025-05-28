import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:hugeicons/hugeicons.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:runaway/config/extensions.dart';
import 'package:runaway/features/home/presentation/screens/maps_styles_screen.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/geojson_service.dart';
import '../blocs/map_style/map_style_bloc.dart';
import '../blocs/map_style/map_style_event.dart';
import '../blocs/map_style/map_style_state.dart';

import '../../../route_generator/data/services/overpass_poi_service.dart';
import '../../../route_generator/presentation/screens/generator_screen.dart' as gen;

import '../../../../core/widgets/icon_btn.dart';
import '../blocs/route_parameters/route_parameters_bloc.dart';
import '../blocs/route_parameters/route_parameters_event.dart';
import '../blocs/route_parameters/route_parameters_state.dart';
import '../widgets/location_search_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {  
  final _geoJsonService = GeoJsonService();
  mp.MapboxMap? mapboxMap;
  StreamSubscription? userPositionStream;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;
  mp.PointAnnotation? selectedLocationMarker;
  mp.CircleAnnotation? radiusCircle;

  mp.CircleAnnotationManager? markerCircleManager;
  List<mp.CircleAnnotation> locationMarkers = [];
  
  // Position utilisateur
  double? userLongitude;
  double? userLatitude;

  // Position actuelle (utilisateur ou recherche)
  double? currentLongitude;
  double? currentLatitude;
  
  // Rayon par défaut en mètres
  double defaultRadius = 10000.0; // 10km

  // État du suivi en temps réel
  bool isTrackingUser = true;

  // Variables pour stocker les POIs sans les afficher
  List<Map<String, dynamic>> _cachedPois = [];
  bool _poisLoaded = false;

  mp.PolylineAnnotationManager? polylineManager;
  mp.PolylineAnnotation? currentRoutePolyline;

  @override
  void initState() {
    super.initState();
    _setupPositionTracking();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    _clearLocationMarkers();
    
    // Désenregistrer la carte du BLoC
    // if (mapboxMap != null) {
    //   context.read<MapStyleBloc>().add(MapUnregistered());
    // }
    
    super.dispose();
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
      return Future.error('Location permissions are permanently denied, we cannot request permission.');
    }

    gl.LocationSettings locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 100,
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(locationSettings: locationSettings)
      .listen((gl.Position? position) {
        if (position != null) {
          setState(() {
            userLongitude = position.longitude;
            userLatitude = position.latitude;
            
            // Si aucune position de recherche n'est définie, utiliser la position utilisateur
            if (currentLongitude == null || currentLatitude == null) {
              currentLongitude = position.longitude;
              currentLatitude = position.latitude;
              
              // Mettre à jour la position dans le BLoC
              context.read<RouteParametersBloc>().add(
                StartLocationUpdated(
                  longitude: position.longitude,
                  latitude: position.latitude,
                ),
              );
            }
          });
          
          // Si le suivi est activé et que la carte est prête
          if (mapboxMap != null && isTrackingUser) {
            mapboxMap?.setCamera(
              mp.CameraOptions(
                zoom: 13,
                center: mp.Point(
                  coordinates: mp.Position(
                    position.longitude, 
                    position.latitude,
                  )
                ),
              ),
            );
            
            // Mettre à jour le cercle de rayon
            _updateRadiusCircle(position.longitude, position.latitude);
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
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
      ),
    );

    // Créer le gestionnaire d'annotations
    pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    circleAnnotationManager = await mapboxMap.annotations.createCircleAnnotationManager();

    // Masquer les éléments d'interface
    await mapboxMap.compass.updateSettings(mp.CompassSettings(enabled: false));
    await mapboxMap.attribution.updateSettings(mp.AttributionSettings(enabled: false));
    await mapboxMap.logo.updateSettings(mp.LogoSettings(enabled: false));
    await mapboxMap.scaleBar.updateSettings(mp.ScaleBarSettings(enabled: false));

    // Configurer le listener de zoom pour adapter le rayon
    mapboxMap.setOnMapZoomListener((context) {
      if (currentLongitude != null && currentLatitude != null) {
        _updateRadiusCircle(currentLongitude!, currentLatitude!);
      }
    });
    
    // Configurer le listener de scroll pour désactiver le suivi
    mapboxMap.setOnMapMoveListener((context) {
      // Si le mouvement n'est pas causé par une mise à jour de position
      if (isTrackingUser) {
        setState(() {
          isTrackingUser = false;
        });
      }
    });
    
    // Si on a déjà une position, afficher le cercle
    if (currentLongitude != null && currentLatitude != null) {
      _updateRadiusCircle(currentLongitude!, currentLatitude!);
    }
  }

  double _calculateCircleRadiusForZoom(double zoom) {
    // Le rayon en pixels doit augmenter avec le zoom pour représenter toujours la distance en km
    final parameters = context.read<RouteParametersBloc>().state.parameters;
    double baseRadius = parameters.searchRadius;
    double metersPerPixel = 156543.03392 * math.cos((currentLatitude ?? 0) * math.pi / 180) / math.pow(2, zoom);
    return baseRadius / metersPerPixel;
  }

  Future<void> _updateRadiusCircle(double longitude, double latitude) async {
    if (circleAnnotationManager == null || mapboxMap == null) return;

    // Obtenir le zoom actuel
    final cameraState = await mapboxMap!.getCameraState();
    final currentZoom = cameraState.zoom;

    // Supprimer l'ancien cercle s'il existe
    if (radiusCircle != null) {
      await circleAnnotationManager!.delete(radiusCircle!);
    }

    // Calculer le rayon en pixels basé sur le zoom
    double radiusInPixels = _calculateCircleRadiusForZoom(currentZoom);

    // Créer le nouveau cercle de rayon
    radiusCircle = await circleAnnotationManager!.create(
      mp.CircleAnnotationOptions(
        geometry: mp.Point(coordinates: mp.Position(longitude, latitude)),
        circleRadius: radiusInPixels,
        circleColor: Colors.green.withAlpha(50).toARGB32(),
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.green.shade700.toARGB32(),
        circleStrokeOpacity: 0.8,
        circleOpacity: 0.3,
      ),
    );
    
    // Mettre à jour la position actuelle
    setState(() {
      currentLongitude = longitude;
      currentLatitude = latitude;
    });
  }

  void _onLocationSelected(double longitude, double latitude, String placeName) async {
    if (mapboxMap == null) return;

    // Désactiver le suivi automatique lors de la sélection d'une adresse
    setState(() {
      isTrackingUser = false;
    });

    // Supprimer les marqueurs précédents s'ils existent
    await _clearLocationMarkers();

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

    // Mettre à jour le cercle de rayon
    await _updateRadiusCircle(longitude, latitude);

    // Créer un CircleAnnotationManager si pas déjà fait
    markerCircleManager ??= await mapboxMap!.annotations.createCircleAnnotationManager();

    // Créer un cercle rouge comme marqueur
    final redMarker = await markerCircleManager!.create(
      mp.CircleAnnotationOptions(
        geometry: mp.Point(coordinates: mp.Position(longitude, latitude)),
        circleColor: Colors.red.toARGB32(),
        circleRadius: 12.0,
        circleStrokeWidth: 3.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
    locationMarkers.add(redMarker);

    // Créer un cercle plus petit au centre pour l'effet de pin
    final whiteCenter = await markerCircleManager!.create(
      mp.CircleAnnotationOptions(
        geometry: mp.Point(coordinates: mp.Position(longitude, latitude)),
        circleColor: Colors.white.toARGB32(),
        circleRadius: 4.0,
      ),
    );
    locationMarkers.add(whiteCenter);

    // Mettre à jour la position dans le BLoC
    context.read<RouteParametersBloc>().add(
      StartLocationUpdated(
        longitude: longitude,
        latitude: latitude,
      ),
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      context: context, 
      builder: (modalCtx) {
        return gen.GeneratorScreen(
          startLongitude: currentLongitude ?? userLongitude ?? 0.0,
          startLatitude: currentLatitude ?? userLatitude ?? 0.0,
          onRadiusChanged: (newRadius) async {
            setState(() {
              defaultRadius = newRadius;
            });
            // Mettre à jour le cercle
            if (currentLongitude != null && currentLatitude != null) {
              await _updateRadiusCircle(currentLongitude!, currentLatitude!);
            }
          },
        );
      },
    );
  }

  void openMapsStyles() {
    showModalBottomSheet(
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      context: context, 
      builder: (modalCtx) {
        return MapsStylesScreen();
      }
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
      
      // Mettre à jour le cercle autour de la position utilisateur
      await _updateRadiusCircle(userLongitude!, userLatitude!);
      
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

      _onSearchCleared();
      
      // Mettre à jour le cercle autour de la position utilisateur
      await _updateRadiusCircle(userLongitude!, userLatitude!);
    } else {
      // Si la position n'est pas disponible, essayer de l'obtenir
      _setupPositionTracking();
    }
  }
  
  void _handleRouteGeneration() async {
    OverlayEntry? loadingOverlay;
    
    try {
      // Créer l'overlay de chargement
      loadingOverlay = OverlayEntry(
        builder: (context) => Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  16.h,
                  Text(
                    'Analyse de la zone...',
                    style: context.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      // Afficher l'overlay
      Overlay.of(context).insert(loadingOverlay);

      await _onGenerateGeoJson();

      // Récupérer les POIs essentiels
      final pois = await OverpassPoiService.fetchPoisInRadius(
        latitude: currentLatitude ?? userLatitude ?? 0.0,
        longitude: currentLongitude ?? userLongitude ?? 0.0,
        radiusInMeters: defaultRadius,
      );

      // Stocker les POIs pour la génération de parcours
      _cachedPois = pois;
      _poisLoaded = true;

      // Supprimer l'overlay
      loadingOverlay.remove();
      loadingOverlay = null;

      if (!mounted) return;

      if (pois.isEmpty) {
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
                Text('Zone peu adaptée aux parcours'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      // Afficher un résumé simple sans afficher les POIs
      final parksCount = pois.where((p) => p['type'] == 'Parc').length;
      final waterCount = pois.where((p) => p['type'] == 'Point d\'eau').length;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
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
                      'Zone analysée!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (parksCount > 0 || waterCount > 0)
                      Text(
                        '${parksCount > 0 ? "$parksCount parc${parksCount > 1 ? "s" : ""}" : ""}'
                        '${parksCount > 0 && waterCount > 0 ? ", " : ""}'
                        '${waterCount > 0 ? "$waterCount point${waterCount > 1 ? "s" : ""} d\'eau" : ""}',
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
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Générer',
            textColor: Colors.white,
            onPressed: () {
              _generateRouteWithPois();
            },
          ),
        ),
      );

    } catch (e) {
      // Supprimer l'overlay en cas d'erreur
      loadingOverlay?.remove();
      
      print('❌ Erreur : $e');
      
      if (!mounted) return;
      
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
                child: Text(
                  'Erreur lors de l\'analyse',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _onGenerateGeoJson() async {
    try {
      final params = context.read<RouteParametersBloc>().state.parameters;
      final file = await _geoJsonService.generateNetworkGeoJson(
        params.startLatitude,
        params.startLongitude,
        params.searchRadius,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GeoJSON généré: \${file.path}')),
      );
      final shareParams = ShareParams(
        text: 'Voici le réseau GeoJSON',
        files: [XFile('${file.path}/image.jpg')], 
      );

      final result = await SharePlus.instance.share(shareParams);

      if (result.status == ShareResultStatus.success) {
          print('Thank you for sharing the picture!');
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur génération GeoJSON: $e')),
      );
    }
  }

  void _generateRouteWithPois() {
    if (!_poisLoaded || _cachedPois.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez d\'abord analyser la zone'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('🚀 Génération du parcours avec ${_cachedPois.length} POIs');
    
    // Ouvrir le générateur de paramètres
    openGenerator();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapStyleBloc, MapStyleState>(
      builder: (context, mapStyleState) {
        return BlocListener<RouteParametersBloc, RouteParametersState>(
          listenWhen: (previous, current) => previous.parameters.searchRadius != current.parameters.searchRadius,
          listener: (context, state) {
            if (currentLongitude != null && currentLatitude != null) {
              _updateRadiusCircle(currentLongitude!, currentLatitude!);
            }
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: mp.MapWidget(
                    key: ValueKey("mapWidget"),
                    onMapCreated: _onMapCreated,
                    styleUri: mapStyleState.style.style,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height - kToolbarHeight,
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          child: LocationSearchBar(
                            onLocationSelected: _onLocationSelected,
                            onSearchCleared: _onSearchCleared,
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
                                      icon: HugeIcons.strokeRoundedMaping, 
                                      onPressed: openMapsStyles,
                                    ),
                                    15.h,
                                    IconBtn(
                                      icon: HugeIcons.strokeRoundedSettings02, 
                                      onPressed: openGenerator,
                                    ),
                                    15.h,
                                    IconBtn(
                                      icon: isTrackingUser 
                                          ? HugeIcons.solidRoundedLocationShare02 
                                          : HugeIcons.strokeRoundedLocationShare02, 
                                      onPressed: _goToUserLocation,
                                      iconColor: isTrackingUser ? Colors.blue : Colors.black,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        20.h,
                        IconBtn(
                          icon: HugeIcons.strokeRoundedAppleIntelligence, 
                          label: "Créer un parcours",
                          onPressed: () => _handleRouteGeneration(),
                        ),
                      ],
                    ),
                  ),
                ),            
              ],
            ),
          ),
        );
      },
    );
  }
}