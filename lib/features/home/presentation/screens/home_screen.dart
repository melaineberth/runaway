import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:hugeicons/hugeicons.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:path_provider/path_provider.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/loading_overlay.dart';
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
  
  // Rayon par défaut en mètres
  double defaultRadius = 10000.0; // 10km

  // État du suivi en temps réel
  bool isTrackingUser = true;

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
    setState(() {
      isGenerateEnabled = true;
    });
    
    try {
      // Utiliser le service optimisé
      final optimizedService = GeoJsonService();
            
      // Générer le réseau optimisé
      final networkFile = await optimizedService.generateOptimizedNetworkGeoJson(
        currentLatitude ?? userLatitude ?? 0.0,
        currentLongitude ?? userLongitude ?? 0.0,
        defaultRadius,
      );

      // Récupérer les POIs en parallèle (plus rapide)
      final poisFuture = OverpassPoiService.fetchPoisInRadius(
        latitude: currentLatitude ?? userLatitude ?? 0.0,
        longitude: currentLongitude ?? userLongitude ?? 0.0,
        radiusInMeters: defaultRadius,
      );

      final pois = await poisFuture;
      final poisFile = await _savePoisToGeoJson(pois);

      // Analyser le réseau généré
      final networkStats = await _analyzeNetworkFile(networkFile);

      if (!mounted) return;

      // Afficher les résultats optimisés
      _showOptimizedResults(networkFile, poisFile, pois, networkStats);

      setState(() {
        isGenerateEnabled = false;
      });

    } catch (e) {      
      print('❌ Erreur : $e');
      
      if (!mounted) return;

      setState(() {
        isGenerateEnabled = false;
      });
      
      _showErrorSnackBar('Erreur lors de la génération du réseau');
    }
  }

  Future<Map<String, dynamic>> _analyzeNetworkFile(File networkFile) async {
    try {
      final jsonString = await networkFile.readAsString();
      final data = json.decode(jsonString);
      return data['metadata']['statistics'] ?? {};
    } catch (e) {
      return {};
    }
  }

  Future<File> _savePoisToGeoJson(List<Map<String, dynamic>> pois) async {
    final poisGeoJson = {
      'type': 'FeatureCollection',
      'metadata': {
        'generated_at': DateTime.now().toIso8601String(),
        'generator': 'RunAway App - POIs',
        'total_features': pois.length,
      },
      'features': pois.map((poi) => {
        'type': 'Feature',
        'properties': {
          'id': poi['id'],
          'name': poi['name'],
          'type': poi['type'],
          'distance_from_center': poi['distance']?.round(),
          'amenity': poi['tags']?['amenity'],
          'leisure': poi['tags']?['leisure'],
          'natural': poi['tags']?['natural'],
          'tourism': poi['tags']?['tourism'],
        },
        'geometry': {
          'type': 'Point',
          'coordinates': poi['coordinates'],
        }
      }).toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/route_pois_$timestamp.geojson');
    
    final jsonString = JsonEncoder.withIndent('  ').convert(poisGeoJson);
    await file.writeAsString(jsonString);
    
    return file;
  }

  void _showOptimizedResults(
    File networkFile, 
    File poisFile, 
    List<Map<String, dynamic>> pois,
    Map<String, dynamic> networkStats) {
  
    final parksCount = pois.where((p) => p['type'] == 'Parc').length;
    final waterCount = pois.where((p) => p['type'] == 'Point d\'eau').length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: Colors.green,
                size: 24,
              ),
            ),
            12.w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Réseau optimisé !', style: context.titleMedium),
                  Text(
                    'Prêt pour génération de parcours',
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
              // Statistiques du réseau
              _buildStatsCard('Réseau de chemins', [
                '📏 ${networkStats['total_length_km'] ?? 'N/A'} km total',
                '🛤️ ${networkStats['total_features'] ?? 'N/A'} segments',
                '🏃‍♂️ ${networkStats['running_segments'] ?? 'N/A'} adaptés course',
                '🚴‍♂️ ${networkStats['cycling_segments'] ?? 'N/A'} adaptés vélo',
                '⭐ Score qualité: ${networkStats['average_quality_score'] ?? 'N/A'}/20',
              ]),
              
              16.h,
              
              // Statistiques des POIs
              _buildStatsCard('Points d\'intérêt', [
                if (parksCount > 0) '🌳 $parksCount parc${parksCount > 1 ? "s" : ""}',
                if (waterCount > 0) '💧 $waterCount point${waterCount > 1 ? "s" : ""} d\'eau',
                '📍 ${pois.length} POIs au total',
                if (pois.isEmpty) '⚠️ Zone peu fournie en POIs',
              ]),
              
              16.h,
              
              // Fichiers créés
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📁 Fichiers générés:', 
                        style: context.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    4.h,
                    Text('• ${networkFile.path.split('/').last}', 
                        style: context.bodySmall?.copyWith(fontSize: 12)),
                    Text('• ${poisFile.path.split('/').last}', 
                        style: context.bodySmall?.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Fermer'),
          ),
          if (networkStats['total_features'] != null && 
              (networkStats['total_features'] as int) > 0) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _shareNetworkFiles(networkFile, poisFile);
              },
              child: Text('Partager'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openGenerator(); // Ouvrir directement le générateur
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('Créer un parcours'),
            ),
          ],
        ],
      ),
    );
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
          ...stats.map((stat) => Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text(
              stat,
              style: context.bodySmall?.copyWith(fontSize: 14),
            ),
          )).toList(),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Réduire zone',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              defaultRadius = defaultRadius * 0.7; // Réduire de 30%
            });
            if (currentLongitude != null && currentLatitude != null) {
              _updateRadiusCircle(currentLongitude!, currentLatitude!);
            }
          },
        ),
      ),
    );
  }

  void _shareNetworkFiles(File networkFile, File poisFile) async {
    try {
      final shareParams = ShareParams(
        text: 'Réseau de chemins et POIs générés par RunAway',
        files: [
          XFile(networkFile.path),
          XFile(poisFile.path),
        ],
      );

      await SharePlus.instance.share(shareParams);
    } catch (e) {
      print('Erreur partage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du partage: $e')),
      );
    }
  }

  Future<void> _lockPositionOnScreenCenter() async {
    if (mapboxMap == null) return;

    final cam = await mapboxMap!.getCameraState();     // CameraState
    final mp.Position pos = cam.center.coordinates;    // <-- Position

    final double lon = pos.lng.toDouble();             // getter `lng`
    final double lat = pos.lat.toDouble();             // getter `lat`

    setState(() {
      currentLongitude = lon;
      currentLatitude  = lat;
    });

    // Supprimer les marqueurs précédents s'ils existent
    await _clearLocationMarkers();

    // redessiner le cercle
    await _updateRadiusCircle(lon, lat);

        // Créer un CircleAnnotationManager si pas déjà fait
    markerCircleManager ??= await mapboxMap!.annotations.createCircleAnnotationManager();

    // Créer un cercle rouge comme marqueur
    final redMarker = await markerCircleManager!.create(
      mp.CircleAnnotationOptions(
        geometry: mp.Point(coordinates: mp.Position(lon, lat)),
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
        geometry: mp.Point(coordinates: mp.Position(lon, lat)),
        circleColor: Colors.white.toARGB32(),
        circleRadius: 4.0,
      ),
    );
    locationMarkers.add(whiteCenter);

    // Mettre à jour la position dans le BLoC
    context.read<RouteParametersBloc>().add(
      StartLocationUpdated(
        longitude: lon,
        latitude: lat,
      ),
    );
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
                // Carte
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: mp.MapWidget(
                    key: ValueKey("mapWidget"),
                    onMapCreated: _onMapCreated,
                    styleUri: mapStyleState.style.style,
                  ),
                ),

                // Overlays (boutons, recherche, etc.)
                if (!isTrackingUser) 
                Positioned(
                  top: MediaQuery.of(context).size.height - kToolbarHeight * 3,
                  child: GestureDetector(
                    onTap: () async {
                      await _lockPositionOnScreenCenter();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(100)
                      ),
                      child: Text(
                        "Pointer ici",
                        style: context.bodySmall?.copyWith(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
                          label: isGenerateEnabled ? "Génération en cours..." : "Créer un parcours",
                          onPressed: () => _handleRouteGeneration(),
                        ),
                      ],
                    ),
                  ),
                ),            
              
                if (isGenerateEnabled)
                LoadingOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }
}