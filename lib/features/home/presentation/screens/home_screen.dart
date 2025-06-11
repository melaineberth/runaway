import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:hugeicons/hugeicons.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:path_provider/path_provider.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/loading_overlay.dart';
import 'package:runaway/features/home/presentation/widgets/route_info_card.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_gradient/smooth_gradient.dart';
import '../../../route_generator/data/services/ai_configuration_service.dart';
import '../../../route_generator/data/services/integrated_route_generation_service.dart';
import '../blocs/map_style/map_style_bloc.dart';
import '../blocs/map_style/map_style_event.dart';
import '../blocs/map_style/map_style_state.dart';
import '../../../route_generator/presentation/screens/route_parameter.dart' as gen;
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

  // État de la route générée
  IntegratedRouteResult? generatedRouteResult;
  List<List<double>>? generatedRouteCoordinates;
  Map<String, dynamic>? generatedRouteStats;
  File? generatedRouteFile;
  // Configuration IA
  bool useAIGeneration = true;
  AIGenerationConfig? customAIConfig;

  @override
  void initState() {
    super.initState();
    _setupPositionTracking();
    _checkAIAvailability();
  }

  @override
  void dispose() {
    _clearRoute(); // Nettoyer la route
    userPositionStream?.cancel();
    _clearLocationMarkers();
    super.dispose();
  }

  // Vérifier la disponibilité de l'IA
  void _checkAIAvailability() {
    final status = AIConfigurationService.checkAIAvailability();
    if (!status.isAvailable) {
      print('⚠️ IA non disponible: ${status.reason}');
      setState(() {
        useAIGeneration = false;
      });
    } else {
      print('✅ IA disponible: ${status.reason}');
    }
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

    // 4) Dessin du halo
    final camState = await mapboxMap!.getCameraState();
    final zoom = camState.zoom;
    final radiusPx = _calculateCircleRadiusForZoom(zoom);
    await circleAnnotationManager!.create(
      mp.CircleAnnotationOptions(
        geometry: mp.Point(coordinates: mp.Position(longitude, latitude)),
        circleRadius: radiusPx,
        circleColor: AppColors.primary.withAlpha(50).toARGB32(),
        circleOpacity: 0.3,
      ),
    );

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
      .listen((gl.Position? pos) {
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
                moveCamera: true,
                addMarker: false,
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
                    pos.longitude, 
                    pos.latitude,
                  )
                ),
              ),
            );
            
            // Mettre à jour le cercle de rayon
            _updateRadiusCircle(pos.longitude, pos.latitude);
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

    // 1) supprimer **tous** les anciens cercles
    await circleAnnotationManager!.deleteAll();

    // 2) recalc du zoom / pixel → radius
    final cameraState = await mapboxMap!.getCameraState();
    final currentZoom = cameraState.zoom;
    double radiusInPixels = _calculateCircleRadiusForZoom(currentZoom);

    // 3) recréer le cercle UNIQUE
    radiusCircle = await circleAnnotationManager!.create(
      mp.CircleAnnotationOptions(
        geometry: mp.Point(
          coordinates: mp.Position(longitude, latitude),
        ),
        circleRadius: radiusInPixels,
        circleColor: AppColors.primary.withAlpha(100).toARGB32(),
        circleOpacity: 0.3,
      ),
    );

    setState(() {
      currentLongitude = longitude;
      currentLatitude = latitude;
    });
  }

  void _onLocationSelected(double longitude, double latitude, String placeName) async {
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

    // Mettre à jour le cercle de rayon
    await _updateRadiusCircle(longitude, latitude);

    // Créer un CircleAnnotationManager si pas déjà fait
    markerCircleManager ??= await mapboxMap!.annotations.createCircleAnnotationManager();

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

  // void openMapsStyles() {
  //   showModalBottomSheet(
  //     isScrollControlled: true,
  //     isDismissible: true,
  //     enableDrag: true,
  //     context: context, 
  //     builder: (modalCtx) {
  //       return MapsStylesScreen();
  //     }
  //   );
  // }

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
      
      // Forcer la mise à jour du cercle après l'animation
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
      final parameters = context.read<RouteParametersBloc>().state.parameters;
      
      print('🚀 Génération ${useAIGeneration ? "IA" : "classique"} du parcours...');
      
      // NOUVEAU: Utiliser le service intégré
      final result = await IntegratedRouteGenerationService.generateOptimalRoute(
        parameters: parameters,
        latitude: currentLatitude ?? userLatitude ?? 0.0,
        longitude: currentLongitude ?? userLongitude ?? 0.0,
        forceClassicAlgorithm: !useAIGeneration,
        customConfig: customAIConfig,
      );

      if (!mounted) return;

      // Vérifier la qualité du résultat
      if (!result.isSuccessful) {
        throw Exception('Qualité de route insuffisante (score: ${result.qualityScore}/10)');
      }

      // Afficher la route sur la carte
      await _displayRoute(result.coordinates);
      
      // Sauvegarder les résultats
      final routeFile = await _saveRouteToGeoJson(result.coordinates, parameters);
      
      setState(() {
        generatedRouteResult = result;
        generatedRouteCoordinates = result.coordinates;
        generatedRouteStats = _buildUIStats(result);
        generatedRouteFile = routeFile;
        isGenerateEnabled = false;
      });
      
      // Afficher les résultats avec informations IA
      _showEnhancedRouteResults(result, routeFile);

    } catch (e) {      
      print('❌ Erreur génération: $e');
      
      if (!mounted) return;

      setState(() {
        isGenerateEnabled = false;
      });
      
      _showErrorSnackBar('Erreur lors de la génération: ${e.toString()}');
    }
  }

  // Construction des stats pour l'UI
  Map<String, dynamic> _buildUIStats(IntegratedRouteResult result) {
    final distance = result.actualDistanceKm.toStringAsFixed(2);
    final isLoop = result.metadata['route_type'] == 'loop';
    final duration = result.metadata['estimated_duration_minutes'] ?? 0;
    
    return {
      'distance_km': distance,
      'is_loop': isLoop,
      'points_count': result.coordinates.length,
      'generation_method': result.generationMethod.name,
      'ai_model': result.aiModel,
      'quality_score': result.qualityScore,
      'generation_time_ms': result.totalGenerationTime ?? 0,
      'fallback_used': result.fallbackUsed,
      'validation_passed': result.validationResult?.isValid ?? true,
    };
  }

  // Dialogue de résultats amélioré avec infos IA
  void _showEnhancedRouteResults(IntegratedRouteResult result, File routeFile) {
    showDialog(
      useRootNavigator: true,
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: result.generationMethod == RouteGenerationMethod.ai 
                    ? Colors.purple.withAlpha(30)
                    : Colors.green.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: HugeIcon(
                icon: result.generationMethod == RouteGenerationMethod.ai 
                    ? HugeIcons.strokeRoundedAiInnovation03
                    : HugeIcons.strokeRoundedRoute03,
                color: result.generationMethod == RouteGenerationMethod.ai 
                    ? Colors.purple
                    : Colors.green,
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
                    '${result.actualDistanceKm.toStringAsFixed(2)} km • ${result.generationMethod == RouteGenerationMethod.ai ? "IA" : "Algorithme"} • ⭐${result.qualityScore.toStringAsFixed(1)}/10',
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
              // Informations sur la génération
              _buildStatsCard('Méthode de génération', [
                '🤖 ${result.generationMethod == RouteGenerationMethod.ai ? "Intelligence Artificielle" : "Algorithme classique"}',
                if (result.aiModel != null) '🧠 Modèle: ${result.aiModel}',
                '⏱️ Généré en ${result.totalGenerationTime ?? 0}ms',
                if (result.fallbackUsed) '🔄 Fallback utilisé',
                '✅ Qualité: ${result.qualityScore.toStringAsFixed(1)}/10',
              ]),
              
              16.h,
              
              // Statistiques du parcours
              _buildStatsCard('Parcours généré', [
                '📏 ${result.actualDistanceKm.toStringAsFixed(2)} km',
                '📍 ${result.coordinates.length} points GPS',
                '${result.metadata['route_type'] == 'loop' ? "🔄" : "➡️"} ${result.metadata['route_type'] == 'loop' ? "Parcours en boucle" : "Aller simple"}',
                '⏰ ~${result.metadata['estimated_duration_minutes'] ?? 0} minutes',
              ]),
              
              // Raisonnement IA si disponible
              if (result.aiReasoning != null) ...[
                16.h,
                _buildStatsCard('Raisonnement IA', [
                  result.aiReasoning!,
                ]),
              ],
              
              // Avertissements de validation
              if (result.validationResult?.hasWarnings == true) ...[
                16.h,
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⚠️ Avertissements:', 
                          style: context.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                      4.h,
                      ...result.validationResult!.warnings.map((w) => 
                        Text('• $w', style: context.bodySmall?.copyWith(fontSize: 12))),
                    ],
                  ),
                ),
              ],
              
              16.h,
              
              // Rappel des paramètres
              _buildStatsCard('Paramètres utilisés', [
                '🏃‍♂️ ${context.read<RouteParametersBloc>().state.parameters.activityType.title}',
                '⛰️ ${context.read<RouteParametersBloc>().state.parameters.terrainType.title}',
                '🏙️ ${context.read<RouteParametersBloc>().state.parameters.urbanDensity.title}',
                '📐 ${context.read<RouteParametersBloc>().state.parameters.elevationGain.toStringAsFixed(0)}m de dénivelé',
              ]),
              
              16.h,
              
              // Fichier généré
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
                    Text('📁 Fichier généré:', 
                        style: context.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    4.h,
                    Text('• ${routeFile.path.split('/').last}', 
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
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _shareRouteFiles(routeFile);
            },
            child: Text('Partager'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNavigation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Commencer'),
          ),
        ],
      ),
    );
  }

  Future<void> _displayRoute(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) return;

    // Sauvegarder les coordonnées
    setState(() {
      generatedRouteCoordinates = coordinates;
    });

    // Créer un gestionnaire de polylignes si nécessaire
    polylineManager ??= await mapboxMap!.annotations.createPolylineAnnotationManager();

    // Supprimer l'ancienne route si elle existe
    if (currentRoutePolyline != null) {
      await polylineManager!.delete(currentRoutePolyline!);
    }

    // Créer la nouvelle polyligne
    currentRoutePolyline = await polylineManager!.create(
      mp.PolylineAnnotationOptions(
        geometry: mp.LineString(
          coordinates: coordinates.map((coord) => 
            mp.Position(coord[0], coord[1])
          ).toList(),
        ),
        lineColor: Theme.of(context).primaryColor.toARGB32(),
        lineWidth: 4.0,
        lineOpacity: 0.9,
        lineJoin: mp.LineJoin.ROUND,
        // Retirer lineCap qui n'existe pas
      ),
    );

    // Ajuster la vue pour montrer toute la route
    final bounds = _calculateBounds(coordinates);

    // Calculer le centre et le zoom approprié
    final centerLon = (bounds.southwest.coordinates.lng + bounds.northeast.coordinates.lng) / 2;
    final centerLat = (bounds.southwest.coordinates.lat + bounds.northeast.coordinates.lat) / 2;

    // Calculer le zoom pour afficher toute la route
    final latDiff = bounds.northeast.coordinates.lat - bounds.southwest.coordinates.lat;
    final lonDiff = bounds.northeast.coordinates.lng - bounds.southwest.coordinates.lng;
    final maxDiff = math.max(latDiff, lonDiff);

    // Estimation du zoom basée sur la différence max
    double zoom = 13.0;
    if (maxDiff > 0.1) zoom = 11.0;
    else if (maxDiff > 0.05) zoom = 12.0;
    else if (maxDiff > 0.02) zoom = 13.0;
    else if (maxDiff > 0.01) zoom = 14.0;
    else zoom = 15.0;

    await mapboxMap!.flyTo(
      mp.CameraOptions(
        center: mp.Point(coordinates: mp.Position(centerLon, centerLat)),
        zoom: zoom - 0.5, // Un peu de marge pour voir toute la route
        pitch: 0,
        bearing: 0,
      ),
      mp.MapAnimationOptions(duration: 1500),
    );

    // Ajouter des marqueurs pour le début et la fin
    await _addRouteMarkers(coordinates);
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

    // Marqueur de départ (vert)
    await markerCircleManager!.create(
      mp.CircleAnnotationOptions(
        geometry: mp.Point(coordinates: mp.Position(
          coordinates.first[0], 
          coordinates.first[1]
        )),
        circleColor: Colors.green.toARGB32(),
        circleRadius: 10.0,
        circleStrokeWidth: 3.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );

    // Marqueur d'arrivée (rouge) si différent du départ
    final isLoop = (coordinates.first[0] - coordinates.last[0]).abs() < 0.0001 &&
                  (coordinates.first[1] - coordinates.last[1]).abs() < 0.0001;
                  
    if (!isLoop) {
      await markerCircleManager!.create(
        mp.CircleAnnotationOptions(
          geometry: mp.Point(coordinates: mp.Position(
            coordinates.last[0], 
            coordinates.last[1]
          )),
          circleColor: Colors.red.toARGB32(),
          circleRadius: 10.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.toARGB32(),
        ),
      );
    }
  }

  Future<File> _saveRouteToGeoJson(List<List<double>> coordinates, RouteParameters parameters) async {
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
            'distance_km': _calculateTotalDistance(coordinates).toStringAsFixed(2),
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': coordinates,
          }
        }
      ],
    };

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/generated_route_$timestamp.geojson');
    
    final jsonString = JsonEncoder.withIndent('  ').convert(routeGeoJson);
    await file.writeAsString(jsonString);
    
    return file;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Rayon de la Terre en mètres
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  void _shareRouteFiles(File routeFile) async {
    try {
      final shareParams = ShareParams(
        text: 'Parcours généré par RunAway',
        files: [
          XFile(routeFile.path),
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

  double _calculateTotalDistance(List<List<double>> coords) {
    double total = 0;
    for (int i = 0; i < coords.length - 1; i++) {
      total += _calculateDistance(
        coords[i][1], coords[i][0],
        coords[i + 1][1], coords[i + 1][0],
      );
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
          ...stats.map((stat) => Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text(
              stat,
              style: context.bodySmall?.copyWith(fontSize: 14),
            ),
          )),
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
        circleColor: AppColors.primary.toARGB32(),
        circleRadius: 7.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
    locationMarkers.add(redMarker);

    // Mettre à jour la position dans le BLoC
    context.read<RouteParametersBloc>().add(
      StartLocationUpdated(
        longitude: lon,
        latitude: lat,
      ),
    );
  }

  Future<void> _clearRoute() async {
    if (polylineManager != null && currentRoutePolyline != null) {
      await polylineManager!.delete(currentRoutePolyline!);
      currentRoutePolyline = null;
    }
    
    // Nettoyer les marqueurs de début/fin
    if (markerCircleManager != null) {
      await markerCircleManager!.deleteAll();
      locationMarkers.clear();
    }
    
    setState(() {
      generatedRouteCoordinates = null;
      generatedRouteStats = null;
      generatedRouteFile = null;
    });
    
    // Réafficher le marqueur de position si nécessaire
    if (currentLongitude != null && currentLatitude != null && !isTrackingUser) {
      _onLocationSelected(currentLongitude!, currentLatitude!, "Position actuelle");
    }
  }

  void _startNavigation() {
    if (generatedRouteCoordinates == null) return;
    
    // TODO: Implémenter la navigation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation à venir dans une prochaine version'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _shareCurrentRoute() {
    if (generatedRouteFile == null) return;
    
    Share.shareXFiles(
      [XFile(generatedRouteFile!.path)],
      text: 'Mon parcours RunAway de ${generatedRouteStats?['distance_km'] ?? '?'} km',
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
                    styleUri: mapStyleState.style.style,
                  ),
                ),

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
                
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 30.0,
                  ),
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
                                        onPressed: !isTrackingUser ? () async => await _lockPositionOnScreenCenter() : null, 
                                        iconColor: isTrackingUser ? Colors.white38 : Colors.white,
                                      ),
                                      15.h,
                                      IconBtn(
                                        padding: 10.0,
                                        icon: isTrackingUser 
                                            ? HugeIcons.solidRoundedLocationShare02 
                                            : HugeIcons.strokeRoundedLocationShare02, 
                                        onPressed: _goToUserLocation,
                                        iconColor: isTrackingUser ? AppColors.primary : Colors.white,
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
                          // 20.h,
                          // IconBtn(
                          //   icon: HugeIcons.strokeRoundedAppleIntelligence, 
                          //   label: isGenerateEnabled 
                          //       ? "Génération en cours..." 
                          //       : generatedRouteCoordinates != null 
                          //           ? "Effacer d'abord la route" 
                          //           : "Créer un parcours",
                          //   onPressed: generatedRouteCoordinates != null 
                          //       ? null 
                          //       : () => _handleRouteGeneration(),
                          // ),
                        ],
                      ),
                    ),
                  ),
                ),            
              
                if (isGenerateEnabled)
                LoadingOverlay(),

                // Info sur la route générée
                if (generatedRouteCoordinates != null && generatedRouteStats != null)
                Positioned(
                  bottom: 40,
                  left: 15,
                  right: 15,
                  child: RouteInfoCard(
                    distance: double.parse(generatedRouteStats!['distance_km'] ?? '0'),
                    isLoop: generatedRouteStats!['is_loop'] ?? false,
                    waypointCount: generatedRouteStats!['points_count'] ?? 0,
                    onClear: _clearRoute,
                    onNavigate: _startNavigation,
                    onShare: _shareCurrentRoute,
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