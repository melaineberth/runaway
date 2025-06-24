import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:hugeicons/hugeicons.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/loading_overlay.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/home/domain/enums/tracking_mode.dart';
import 'package:runaway/features/home/presentation/widgets/export_format_dialog.dart';
import 'package:runaway/features/home/presentation/widgets/route_info_card.dart';
import 'package:runaway/features/navigation/blocs/navigation_bloc.dart';
import 'package:runaway/features/navigation/presentation/screens/live_navigation_screen.dart';
import 'package:runaway/features/navigation/presentation/screens/navigation_screen.dart';
import 'package:runaway/features/route_generator/data/services/route_export_service.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_event.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_state.dart';
import 'package:smooth_gradient/smooth_gradient.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../../route_generator/presentation/screens/route_parameter.dart' as gen;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
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

  // Mode de tracking avant génération pour le restore
  TrackingMode? _trackingModeBeforeGeneration;

  // === ROUTE GENERATION ===
  bool isGenerateEnabled = false;
  List<List<double>>? generatedRouteCoordinates;
  Map<String, dynamic>? routeMetadata;
  mp.PolylineAnnotationManager? routeLineManager;

  // === NAVIGATION ===
  bool isNavigationMode = false;
  bool isNavigationCameraActive = false;
  bool _isInNavigationMode = false;

  bool _hasAutoSaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLocationTracking();
    _setupRouteGenerationListener();
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

        // Réinitialiser le mode navigation si on revient
        if (_isInNavigationMode) {
          setState(() {
            _isInNavigationMode = false;
          });
        }
        break;
      default:
        break;
    }
  }

  // Configuration de l'écoute de génération
  void _setupRouteGenerationListener() {
    // Écouter les changements du bloc de génération
    context.read<RouteGenerationBloc>().stream.listen((state) {
      if (mounted) {
        _handleRouteGenerationStateChange(state);
      }
    });
  }

  // Gestion des changements d'état
  void _handleRouteGenerationStateChange(RouteGenerationState state) async {
    
    // 🆕 Cas 1: Parcours chargé depuis l'historique
    if (state.hasGeneratedRoute && state.isLoadedFromHistory) {
      print('📂 Parcours chargé depuis l\'historique - pas de sauvegarde automatique');
      
      setState(() {
        generatedRouteCoordinates = state.generatedRoute;
        routeMetadata = state.routeMetadata;
        // Pas de changement de _hasAutoSaved car c'est un parcours existant
      });
      
      // Afficher la route sur la carte
      await _displayRouteOnMap(state.generatedRoute!);
            
      return; // 🔑 IMPORTANT : Sortir ici pour éviter la double sauvegarde
    }
    
    // 🆕 Cas 2: Nouveau parcours généré (pas depuis l'historique)
    if (state.isNewlyGenerated && !_hasAutoSaved) {
      print('🆕 Nouveau parcours généré - sauvegarde automatique');
      
      // AJOUTER : Sauvegarder le mode de tracking avant génération
      _trackingModeBeforeGeneration = _trackingMode;
      
      // Route générée avec succès
      setState(() {
        generatedRouteCoordinates = state.generatedRoute;
        routeMetadata = state.routeMetadata;
        _hasAutoSaved = true; // 🔧 FIX : Marquer comme sauvegardé
      });
      
      // DEBUG : Afficher les données reçues
      print('🔍 DEBUG routeMetadata keys: ${routeMetadata?.keys}');
      print('🔍 DEBUG distance calculée: ${_getGeneratedRouteDistance()}km');
      
      // Afficher la route sur la carte
      await _displayRouteOnMap(state.generatedRoute!);
      
      // 🆕 AUTO-SAUVEGARDE : Sauvegarder automatiquement le parcours généré
      await _autoSaveGeneratedRoute(state);
            
    } else if (state.errorMessage != null) {
      // Erreur lors de la génération ou du chargement
      _showRouteGenerationError(state.errorMessage!);
      // 🔧 FIX : Reset du flag en cas d'erreur
      _hasAutoSaved = false;
    }
  }

  Future<void> _autoSaveGeneratedRoute(RouteGenerationState state) async {
    // 1️⃣  Annuler si l’utilisateur n’est pas connecté
    if (sb.Supabase.instance.client.auth.currentUser == null) {
      print('🚫 Auto-save annulé : aucun utilisateur connecté');
      _hasAutoSaved = false; // permet une nouvelle tentative si besoin
      return; // on s’arrête là
    }

    // 2️⃣  Procédure normale (inchangée)
    if (!state.hasGeneratedRoute || state.usedParameters == null) {
      print('⚠️ Pas de sauvegarde automatique: parcours non nouveau ou paramètres manquants');
      return;
    }

    try {
      // Utiliser la vraie distance générée au lieu de la distance demandée
      final realDistance = _getGeneratedRouteDistance();
      final routeName = _generateAutoRouteName(state.usedParameters!, realDistance);
      
      // 🆕 Sauvegarder via le RouteGenerationBloc avec la GlobalKey pour la screenshot
      context.read<RouteGenerationBloc>().add(
        GeneratedRouteSaved(
          routeName,
          map: mapboxMap!,
        ),
      );

      print('✅ Parcours auto-sauvegardé avec screenshot: $routeName (distance réelle: ${realDistance.toStringAsFixed(1)}km)');

    } catch (e) {
      print('❌ Erreur auto-sauvegarde: $e');
      // Ne pas afficher d'erreur à l'utilisateur pour une sauvegarde automatique
    }
  }

  // Génération du nom avec vraie distance
  String _generateAutoRouteName(RouteParameters parameters, double realDistanceKm) {
    final now = DateTime.now();
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateString = '${now.day}/${now.month}';
    
    return '${parameters.activityType.title} ${realDistanceKm.toStringAsFixed(0)}km - $timeString ($dateString)';
  }

  // Calcul de la distance réelle du parcours généré
  double _getGeneratedRouteDistance() {
    if (routeMetadata == null) return 0.0;
    
    // Essayer d'abord avec la clé 'distanceKm'
    final distanceKm = routeMetadata!['distanceKm'];
    if (distanceKm != null) {
      return (distanceKm as num).toDouble();
    }
    
    // Fallback : essayer avec 'distance' en mètres
    final distanceMeters = routeMetadata!['distance'];
    if (distanceMeters != null) {
      return ((distanceMeters as num) / 1000).toDouble();
    }
    
    // Dernier fallback : calculer à partir des coordonnées
    if (generatedRouteCoordinates != null && generatedRouteCoordinates!.isNotEmpty) {
      return _calculateDistanceFromCoordinates(generatedRouteCoordinates!);
    }
    
    return 0.0;
  }
  
  // Méthode de calcul de distance à partir des coordonnées
  double _calculateDistanceFromCoordinates(List<List<double>> coordinates) {
    if (coordinates.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    
    for (int i = 1; i < coordinates.length; i++) {
      final prev = coordinates[i - 1];
      final current = coordinates[i];
      
      // Utiliser la formule de Haversine pour calculer la distance
      final distance = _haversineDistance(
        prev[1], prev[0], // lat, lon précédent
        current[1], current[0], // lat, lon actuel
      );
      
      totalDistance += distance;
    }
    
    return totalDistance; // Retourner en kilomètres
  }

  // Formule de Haversine pour calculer la distance entre deux points GPS
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Rayon de la Terre en kilomètres
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return R * c; // Distance en kilomètres
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  // Fonction onClear pour supprimer le parcours et revenir à l'état précédent
  Future<void> _clearGeneratedRoute() async {
    print('🧹 === DÉBUT NETTOYAGE COMPLET DU PARCOURS ===');
    
    // 1. Supprimer la route de la carte
    if (routeLineManager != null && mapboxMap != null) {
      try {
        await routeLineManager!.deleteAll();
        await mapboxMap!.annotations.removeAnnotationManager(routeLineManager!);
        routeLineManager = null;
        print('✅ Route supprimée de la carte');
      } catch (e) {
        print('❌ Erreur lors de la suppression de la route: $e');
      }
    }

    // 2. 🔧 CRUCIAL : Utiliser le nouvel événement de reset pour nettoyer l'état du bloc
    if (mounted) {
      context.read<RouteGenerationBloc>().add(const RouteStateReset());
      print('✅ État du bloc RouteGeneration reseté complètement');
    }

    // 3. Réinitialiser toutes les variables locales liées au parcours
    setState(() {
      generatedRouteCoordinates = null;
      routeMetadata = null;
      _hasAutoSaved = false;
      
      // 🔧 CRUCIAL : Réinitialiser les positions sélectionnées
      _selectedLatitude = null;
      _selectedLongitude = null;
      
      print('✅ Variables locales réinitialisées');
    });

    // 4. Supprimer tous les marqueurs de position manuelle
    await _clearLocationMarkers();

    // 5. 🔧 IMPORTANT : Revenir systématiquement au tracking utilisateur
    print('🔄 Retour au tracking utilisateur');
    
    setState(() {
      _trackingMode = TrackingMode.userTracking;
      // Synchroniser avec la position utilisateur actuelle
      _selectedLatitude = _userLatitude;
      _selectedLongitude = _userLongitude;
    });

    // 6. Recentrer sur la position utilisateur si disponible
    if (_userLatitude != null && _userLongitude != null && mapboxMap != null) {
      await mapboxMap!.flyTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(_userLongitude!, _userLatitude!),
          ),
          zoom: 15,
        ),
        mp.MapAnimationOptions(duration: 1000),
      );
      print('📍 Caméra recentrée sur la position utilisateur');
    }

    // 7. Réinitialiser le mode de tracking sauvegardé
    _trackingModeBeforeGeneration = null;

    print('✅ === FIN NETTOYAGE COMPLET DU PARCOURS ===');
  }

  // Affichage de la route sur la carte
  Future<void> _displayRouteOnMap(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) return;

    try {
      print('🎬 Début animation d\'affichage de route...');

      // ÉTAPE 1 : Animation vers le point de départ
      await _animateToRouteStart(coordinates);

      // ÉTAPE 2 : Afficher progressivement le tracé
      await _drawRouteProgressively(coordinates);

      // ÉTAPE 3 : Animation finale pour montrer toute la route
      await _animateToFullRoute(coordinates);

      print('✅ Animation d\'affichage terminée');

    } catch (e) {
      print('❌ Erreur lors de l\'affichage animé de la route: $e');
      // Fallback : affichage direct
      await _displayRouteDirectly(coordinates);
    }
  }

  // Animation smooth vers le point de départ
  Future<void> _animateToRouteStart(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) return;

    final startCoord = coordinates.first;
    
    await mapboxMap!.flyTo(
      mp.CameraOptions(
        center: mp.Point(
          coordinates: mp.Position(startCoord[0], startCoord[1]),
        ),
        zoom: 15.0, // Zoom intermédiaire
        pitch: 0,
        bearing: 0,
      ),
      mp.MapAnimationOptions(
        duration: 1200, // 1.2 secondes
        startDelay: 0,
      ),
    );

    // Attendre la fin de l'animation
    await Future.delayed(Duration(milliseconds: 1300));
  }

  // Dessiner le tracé progressivement 
  Future<void> _drawRouteProgressively(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) return;

    // Crée le manager une seule fois
    routeLineManager ??=
        await mapboxMap!.annotations.createPolylineAnnotationManager();

    // Efface l’éventuel tracé précédent
    await routeLineManager!.deleteAll();

    // Puis dessine la nouvelle polyline
    await _drawRoute(coordinates);
  }

  // Création du tracé
  Future<void> _drawRoute(List<List<double>> coordinates) async {
    print('🎨 _drawRouteSimple: ${coordinates.length} coordonnées');

      if (coordinates.isEmpty) {
        print('❌ Aucune coordonnée à afficher');
        return;
      }

      try {
        // Convertir les coordonnées
        final lineCoordinates = coordinates.map((coord) => 
          mp.Position(coord[0], coord[1])
        ).toList();

        // Créer une ligne simple et visible
        final routeLine = mp.PolylineAnnotationOptions(
          geometry: mp.LineString(coordinates: lineCoordinates),
          lineColor: AppColors.primary.toARGB32(), // Rouge vif pour le debug
          lineWidth: 4.0,
          lineOpacity: 1.0,
        );

        await routeLineManager!.create(routeLine);
        print('✅ Route simple créée (rouge, 8px, opacité 1.0)');

      } catch (e) {
        print('❌ Erreur _drawRouteSimple: $e');
      }
  }

  // Animation finale pour montrer toute la route
  Future<void> _animateToFullRoute(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) return;

    // Calculer les limites de la route
    double minLat = coordinates.first[1];
    double maxLat = coordinates.first[1];
    double minLon = coordinates.first[0];
    double maxLon = coordinates.first[0];

    for (final coord in coordinates) {
      minLon = math.min(minLon, coord[0]);
      maxLon = math.max(maxLon, coord[0]);
      minLat = math.min(minLat, coord[1]);
      maxLat = math.max(maxLat, coord[1]);
    }

    // Ajouter une marge
    const margin = 0.002; // Marge légèrement plus grande pour un meilleur effet
    final bounds = mp.CoordinateBounds(
      southwest: mp.Point(coordinates: mp.Position(minLon - margin, minLat - margin)),
      northeast: mp.Point(coordinates: mp.Position(maxLon + margin, maxLat + margin)),
      infiniteBounds: false,
    );

    // Animation smooth vers la vue complète
    final camera = await mapboxMap!.cameraForCoordinateBounds(
      bounds,
      mp.MbxEdgeInsets(top: 120, left: 60, bottom: 220, right: 60),
      null, // bearing
      null, // pitch
      null, // maxZoom
      null, // offset
    );

    // Utiliser flyTo au lieu de setCamera pour une animation smooth
    await mapboxMap!.flyTo(
      camera,
      mp.MapAnimationOptions(
        duration: 1800, // 1.8 secondes pour l'animation finale
        startDelay: 300, // Petit délai avant l'animation
      ),
    );

    // Attendre la fin de l'animation
    await Future.delayed(Duration(milliseconds: 2200));
  }

  // Fallback : affichage direct (en cas d'erreur)
  Future<void> _displayRouteDirectly(List<List<double>> coordinates) async {
    // Supprimer l'ancienne route si elle existe
    if (routeLineManager != null) {
      await mapboxMap!.annotations.removeAnnotationManager(routeLineManager!);
    }

    // Créer le gestionnaire de lignes
    routeLineManager = await mapboxMap!.annotations.createPolylineAnnotationManager();

    // Convertir les coordonnées pour Mapbox
    final lineCoordinates = coordinates.map((coord) => 
      mp.Position(coord[0], coord[1])
    ).toList();

    // Créer la ligne de parcours
    final routeLine = mp.PolylineAnnotationOptions(
      geometry: mp.LineString(coordinates: lineCoordinates),
      lineColor: AppColors.primary.toARGB32(),
      lineWidth: 4.0,
      lineOpacity: 0.8,
    );

    await routeLineManager!.create(routeLine);
    await _fitMapToRoute(coordinates);
  }

  // Ajustement de la vue de la carte
  Future<void> _fitMapToRoute(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) return;

    try {
      // Calculer les limites de la route
      double minLat = coordinates.first[1];
      double maxLat = coordinates.first[1];
      double minLon = coordinates.first[0];
      double maxLon = coordinates.first[0];

      for (final coord in coordinates) {
        minLon = math.min(minLon, coord[0]);
        maxLon = math.max(maxLon, coord[0]);
        minLat = math.min(minLat, coord[1]);
        maxLat = math.max(maxLat, coord[1]);
      }

      const margin = 0.001;
      final bounds = mp.CoordinateBounds(
        southwest: mp.Point(coordinates: mp.Position(minLon - margin, minLat - margin)),
        northeast: mp.Point(coordinates: mp.Position(maxLon + margin, maxLat + margin)),
        infiniteBounds: false,
      );

      final camera = await mapboxMap!.cameraForCoordinateBounds(
        bounds,
        mp.MbxEdgeInsets(top: 100, left: 50, bottom: 200, right: 50),
        null, null, null, null,
      );

      // Utiliser flyTo au lieu de setCamera
      await mapboxMap!.flyTo(
        camera,
        mp.MapAnimationOptions(duration: 1500),
      );

    } catch (e) {
      print('❌ Erreur lors de l\'ajustement smooth de la vue: $e');
    }
  }

  // Affichage des erreurs
  void _showRouteGenerationError(String error) {
    if (!mounted) return;

    showTopSnackBar(
      Overlay.of(context),
      TopSnackBar(
        title: error,
        icon: HugeIcons.solidRoundedAlert02,
      ),
    );
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
        !isNavigationCameraActive && !_isInNavigationMode) {
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
  Future<void> _activateManualSelection() async {
    if (mapboxMap == null) {
      print('❌ Carte non initialisée pour sélection manuelle');
      return;
    }

    try {
      // 🔧 CRUCIAL : Récupérer le centre actuel de la carte
      final cameraState = await mapboxMap!.getCameraState();
      final center = cameraState.center;
      final longitude = center.coordinates.lng.toDouble();
      final latitude = center.coordinates.lat.toDouble();
      
      print('📍 === POSITIONNEMENT MANUEL AU CENTRE CARTE ===');
      print('📍 Centre carte: ($latitude, $longitude)');
      
      // 🔧 CRUCIAL : Si un parcours existe, le nettoyer d'abord
      if (generatedRouteCoordinates != null) {
        print('🧹 Nettoyage du parcours existant avant nouveau positionnement');
        
        // Nettoyer seulement la route, pas la position
        if (routeLineManager != null && mapboxMap != null) {
          try {
            await routeLineManager!.deleteAll();
            await mapboxMap!.annotations.removeAnnotationManager(routeLineManager!);
            routeLineManager = null;
          } catch (e) {
            print('❌ Erreur suppression route: $e');
          }
        }
        
        // Nettoyer l'état du bloc mais garder la nouvelle position
        if (mounted) {
          context.read<RouteGenerationBloc>().add(const RouteStateReset());
        }
        
        setState(() {
          generatedRouteCoordinates = null;
          routeMetadata = null;
          _hasAutoSaved = false;
        });
      }
      
      // Mettre à jour le mode et les positions avec le centre de la carte
      setState(() {
        _trackingMode = TrackingMode.manual;
        _selectedLatitude = latitude;
        _selectedLongitude = longitude;
      });

      // Supprimer les anciens marqueurs et ajouter le nouveau au centre
      await _clearLocationMarkers();
      await _addLocationMarker(longitude, latitude);

      // Mettre à jour le BLoC avec la nouvelle position
      if (mounted) {
        context.read<RouteParametersBloc>().add(
          StartLocationUpdated(longitude: longitude, latitude: latitude),
        );
      }

      print('✅ Position manuelle définie au centre de la carte: ($latitude, $longitude)');
      
    } catch (e) {
      print('❌ Erreur lors de l\'activation manuelle: $e');
      
      // Fallback : utiliser la position utilisateur si erreur
      if (_userLatitude != null && _userLongitude != null) {
        await _setManualPositionFallback(_userLongitude!, _userLatitude!);
      }
    }
  }

  // 🔧 MÉTHODE FALLBACK : En cas d'erreur, utiliser la position utilisateur
  Future<void> _setManualPositionFallback(double longitude, double latitude) async {
    print('⚠️ Fallback: Position manuelle à la position utilisateur');
    
    setState(() {
      _trackingMode = TrackingMode.manual;
      _selectedLatitude = latitude;
      _selectedLongitude = longitude;
    });

    await _clearLocationMarkers();
    await _addLocationMarker(longitude, latitude);

    if (mounted) {
      context.read<RouteParametersBloc>().add(
        StartLocationUpdated(longitude: longitude, latitude: latitude),
      );
    }
  }

  /// Sélection via recherche d'adresse
  Future<void> _onLocationSelected(double longitude, double latitude, String placeName) async {
    print('🔍 === POSITION SÉLECTIONNÉE VIA RECHERCHE ===');
    print('🔍 Lieu: $placeName ($latitude, $longitude)');
    
    // 🔧 CRUCIAL : Nettoyer l'ancien parcours si il existe
    if (generatedRouteCoordinates != null) {
      print('🧹 Nettoyage du parcours existant avant nouvelle recherche');
      
      // Nettoyer seulement la route, pas la position
      if (routeLineManager != null && mapboxMap != null) {
        try {
          await routeLineManager!.deleteAll();
          await mapboxMap!.annotations.removeAnnotationManager(routeLineManager!);
          routeLineManager = null;
        } catch (e) {
          print('❌ Erreur suppression route: $e');
        }
      }
      
      // Nettoyer l'état du bloc
      if (mounted) {
        context.read<RouteGenerationBloc>().add(const RouteStateReset());
      }
      
      setState(() {
        generatedRouteCoordinates = null;
        routeMetadata = null;
        _hasAutoSaved = false;
      });
    }
    
    // Mettre à jour le mode et les positions
    setState(() {
      _trackingMode = TrackingMode.searchSelected;
      _selectedLatitude = latitude;
      _selectedLongitude = longitude;
    });

    // Supprimer les anciens marqueurs et ajouter le nouveau
    await _clearLocationMarkers();
    await _addLocationMarker(longitude, latitude);

    // Centrer la caméra sur la nouvelle position
    if (mapboxMap != null) {
      await mapboxMap!.flyTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(longitude, latitude),
          ),
          zoom: 15,
        ),
        mp.MapAnimationOptions(duration: 1000),
      );
    }

    print('✅ Position de recherche définie: $placeName');
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
  }

  void _showLocationError(String message) {
    if (mounted) {
      showTopSnackBar(
        Overlay.of(context),
        TopSnackBar(
          title: message,
          icon: HugeIcons.solidRoundedAlert02,
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
        return BlocProvider.value(
          value: context.read<RouteParametersBloc>(),
          child: BlocProvider.value(
            value: context.read<RouteGenerationBloc>(),
            child: gen.RouteParameterScreen(
              startLongitude: _selectedLongitude ?? _userLongitude ?? 0.0,
              startLatitude: _selectedLatitude ?? _userLatitude ?? 0.0,
              generateRoute: _handleGenerateRoute, // NOUVEAU CALLBACK
            ),
          ),
        );
      },
    );
  }

  // Gestionnaire de génération de route
  void _handleGenerateRoute() {
    // 🔧 FIX : Reset du flag avant nouvelle génération
    _hasAutoSaved = false;

    final parametersState = context.read<RouteParametersBloc>().state;
    final parameters = parametersState.parameters;

    // Vérifier la validité des paramètres
    if (!parameters.isValid) {
      _showRouteGenerationError('Paramètres invalides');
      return;
    }

    // Déclencher la génération via le RouteGenerationBloc
    context.read<RouteGenerationBloc>().add(
      RouteGenerationRequested(parameters),
    );

    print('🚀 Génération de route demandée: ${parameters.distanceKm}km, ${parameters.activityType.name}');
  }

  void _showExportDialog() {
    if (generatedRouteCoordinates == null || routeMetadata == null) {
      showTopSnackBar(
        Overlay.of(context),
        TopSnackBar(
          title: 'Aucun parcours à exporter',
          icon: HugeIcons.solidRoundedAlert02,
        ),
      );
      return;
    }

    showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      context: context,
      backgroundColor: Colors.black,
      builder: (context) => ExportFormatDialog(
        onGpxSelected: () => _exportRoute(RouteExportFormat.gpx),
        onKmlSelected: () => _exportRoute(RouteExportFormat.kml),
        onJsonSelected: () => _exportRoute(RouteExportFormat.json),
      ),
    );
  }

  Future<void> _exportRoute(RouteExportFormat format) async {
    if (generatedRouteCoordinates == null || routeMetadata == null) return;

    final Completer<void> completer = Completer<void>();

    try {
      // Exporter la route
      await RouteExportService.exportRoute(
        coordinates: generatedRouteCoordinates!,
        metadata: routeMetadata!,
        format: format,
      );

      // Succès
      completer.complete();

      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: 'Parcours exporté en ${format.displayName}',
            icon: HugeIcons.solidRoundedTick04,
            color: Colors.lightGreen,
          ),
        );
      }

    } catch (e) {
      completer.completeError(e);

      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: 'Erreur d\'export: $e',
            icon: HugeIcons.solidRoundedAlert02,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
                height: MediaQuery.of(context).size.height / 3.5,
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

            // Interface normale (masquée en mode navigation OU navigation live)
            if (!isNavigationMode && !_isInNavigationMode)
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
                                    icon: _trackingMode != TrackingMode.userTracking
                                        ? HugeIcons.solidRoundedGpsOff02
                                        : HugeIcons.strokeRoundedGpsOff02,
                                    onPressed: _activateManualSelection,
                                    iconColor: _trackingMode != TrackingMode.userTracking
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
          if (generatedRouteCoordinates != null && routeMetadata != null && !isNavigationMode & !_isInNavigationMode)
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
                  distance: _getGeneratedRouteDistance(), // MODIFICATION : Vraie distance
                  isLoop: routeMetadata!['is_loop'] as bool? ?? true,
                  waypointCount: routeMetadata!['points_count'] as int? ?? generatedRouteCoordinates!.length,
                  onClear: _clearGeneratedRoute, // MODIFICATION : Vraie fonction onClear
                  onNavigate: () {
                    if (generatedRouteCoordinates != null && routeMetadata != null) {
                      final args = LiveNavigationArgs(
                        route: generatedRouteCoordinates!,
                        targetDistanceKm: _getGeneratedRouteDistance(),
                        routeName: 'Parcours ${DateTime.now().day}/${DateTime.now().month}',
                      );
                      
                      context.push('/live-navigation', extra: args);
                    }
                  },
                  onShare: _showExportDialog,
                ),
              ),
            ),
        ],
      ),
    );
  }
}