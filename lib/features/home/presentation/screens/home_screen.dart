import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/services/conversion_triggers.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:hugeicons/hugeicons.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/services/location_preload_service.dart';
import 'package:runaway/core/widgets/location_aware_map_widget.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/home/data/services/map_state_service.dart';
import 'package:runaway/features/home/domain/enums/tracking_mode.dart';
import 'package:runaway/features/home/domain/models/mapbox_style_constants.dart';
import 'package:runaway/features/home/presentation/widgets/export_format_dialog.dart';
import 'package:runaway/features/home/presentation/widgets/map_style_selector.dart';
import 'package:runaway/features/home/presentation/widgets/route_info_card.dart';
import 'package:runaway/features/navigation/presentation/screens/live_navigation_screen.dart';
import 'package:runaway/features/route_generator/data/services/route_export_service.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_event.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_state.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  // 🆕 Service de persistance
  final MapStateService _mapStateService = MapStateService();
  
  // === MAPBOX ===
  mp.MapboxMap? mapboxMap;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.CircleAnnotationManager? circleAnnotationManager;
  mp.PointAnnotationManager? markerPointManager;
  List<mp.PointAnnotation> locationMarkers = [];

  // Style de carte
  String _currentMapStyleId = 'outdoors';

  // === LOTTIE MARKER ===
  late final AnimationController _lottieController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _showLottieMarker = false; // 🆕 Contrôle l'affichage du Lottie
  double? _lottieMarkerLat; // 🆕 Position du marqueur Lottie
  double? _lottieMarkerLng; // 🆕 Position du marqueur Lottie
  final double _markerSize = 70.0;

  // === INTERACTIONS MAPBOX ===
  mp.LongTapInteraction? longTapInteraction;

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
  Map<String, dynamic>? routeMetadata;
  mp.PolylineAnnotationManager? routeLineManager;

  // === NAVIGATION ===
  bool isNavigationMode = false;
  bool isNavigationCameraActive = false;
  bool _isInNavigationMode = false;

  bool _hasAutoSaved = false;

  // Variable dans la classe _HomeScreenState
  bool _isSaveDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initializeAnimationControllers();
    _restoreStateFromService();

    // Restaurer le style depuis le service
    _restoreMapStyleFromService();

    _preloadLocationInBackground();

    _setupRouteGenerationListener();

    _initializeMapStyle();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        print('📱 App en arrière-plan');
        _saveStateToService(); // 💾 Sauvegarder lors de la mise en arrière-plan
        break;
      case AppLifecycleState.resumed:
        print('📱 App au premier plan');
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

  /// 🎨 Initialiser le style de carte au démarrage
  Future<void> _initializeMapStyle() async {
    try {
      // Charger le style depuis SharedPreferences
      await _mapStateService.loadMapStyleFromPreferences();
      
      // Mettre à jour l'état local
      setState(() {
        _currentMapStyleId = _mapStateService.selectedMapStyleId;
      });
      
      print('🎨 Style de carte initialisé: $_currentMapStyleId');
      
    } catch (e) {
      print('❌ Erreur initialisation style: $e');
      // En cas d'erreur, utiliser le style par défaut
      setState(() {
        _currentMapStyleId = MapboxStyleConstants.getDefaultStyleId();
      });
    }
  }

  void _initializeAnimationControllers() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _fadeController.forward();

    _lottieController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  /// 🔄 Restaurer l'état depuis le service
  void _restoreStateFromService() {
    print('🔄 Restauration de l\'état depuis le service...');
    
    // Restaurer les positions
    _userLatitude = _mapStateService.lastUserLatitude;
    _userLongitude = _mapStateService.lastUserLongitude;
    _selectedLatitude = _mapStateService.selectedLatitude;
    _selectedLongitude = _mapStateService.selectedLongitude;
    
    // Restaurer le mode de tracking
    _trackingMode = _mapStateService.trackingMode;

    // Restaurer le style de carte
    _currentMapStyleId = _mapStateService.selectedMapStyleId;
    
    // Restaurer le parcours
    generatedRouteCoordinates = _mapStateService.generatedRouteCoordinates;
    routeMetadata = _mapStateService.routeMetadata;
    _hasAutoSaved = _mapStateService.hasAutoSaved;
    
    print('✅ État restauré: positions=${_userLatitude != null}, mode=$_trackingMode, route=${generatedRouteCoordinates != null}');
  }

  /// 🆕 Pré-charge la géolocalisation en arrière-plan (sans démarrer le tracking)
  Future<void> _preloadLocationInBackground() async {
    try {
      print('🌍 Pré-chargement de la géolocalisation en arrière-plan...');
      final position = await LocationPreloadService.instance.initializeLocation();
      
      // Mettre à jour les variables locales
      _userLatitude = position.latitude;
      _userLongitude = position.longitude;
      
      // Si on n'a pas de position sélectionnée, utiliser la position utilisateur
      if (_selectedLatitude == null || _selectedLongitude == null) {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
      }
      
      print('✅ Géolocalisation pré-chargée en arrière-plan');
      
    } catch (e) {
      print('⚠️ Erreur pré-chargement géolocalisation: $e');
      // Continuer sans géolocalisation
    }
  }

  /// 💾 Sauvegarder l'état dans le service
  void _saveStateToService() {
    print('💾 Sauvegarde de l\'état dans le service...');
    
    // Sauvegarder les positions
    if (_userLatitude != null && _userLongitude != null) {
      _mapStateService.saveUserPosition(_userLatitude!, _userLongitude!);
    }
    
    if (_selectedLatitude != null && _selectedLongitude != null) {
      _mapStateService.saveSelectedPosition(_selectedLatitude!, _selectedLongitude!);
    }

    // Sauvegarder le style de carte
    _mapStateService.saveMapStyleId(_currentMapStyleId);
    
    // Sauvegarder le mode de tracking
    _mapStateService.saveTrackingMode(_trackingMode);
    
    // Sauvegarder le parcours
    _mapStateService.saveGeneratedRoute(generatedRouteCoordinates, routeMetadata, _hasAutoSaved);
    
    // Sauvegarder l'état des marqueurs
    _mapStateService.saveMarkerState(
      locationMarkers.isNotEmpty,
      _selectedLatitude,
      _selectedLongitude,
    );
    
    // Sauvegarder l'état de la caméra
    if (mapboxMap != null) {
      _mapStateService.saveCameraState(mapboxMap!);
    }
    
    print('✅ État sauvegardé dans le service');
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

  Future<void> _startLocationTrackingWhenMapReady() async {
    try {
      // La carte est déjà prête car on vient de _onMapCreated
      if (mapboxMap == null) {
        print('❌ Erreur: mapboxMap est null');
        return;
      }

      print('🗺️ Démarrage du tracking de position...');
      
      const locationSettings = gl.LocationSettings(
        accuracy: gl.LocationAccuracy.high,
        distanceFilter: 1,
      );

      _positionStream = gl.Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onLocationUpdate,
        onError: (e) {
          print('❌ Erreur stream position: $e');
        },
      );

      print('✅ Stream de position démarré');
      
    } catch (e) {
      print('❌ Erreur démarrage tracking: $e');
    }
  }

  void _onLocationUpdate(gl.Position position) {
    // Logique existante conservée
    if (!mounted) return;
    
    final newLat = position.latitude;
    final newLng = position.longitude;
    
    // Éviter les mises à jour redondantes
    if (_userLatitude == newLat && _userLongitude == newLng) return;
    
    setState(() {
      _userLatitude = newLat;
      _userLongitude = newLng;
    });

    // Mettre à jour la position sélectionnée si on est en mode user tracking
    if (_trackingMode == TrackingMode.userTracking) {
      setState(() {
        _selectedLatitude = newLat;
        _selectedLongitude = newLng;
      });
      
      // Centrer la caméra sur la nouvelle position
      _centerOnUserLocation(animate: false);
    }

    // Mettre à jour le BLoC
    if (mounted) {
      context.read<RouteParametersBloc>().add(
        StartLocationUpdated(longitude: newLng, latitude: newLat),
      );
    }
  }

  // Gestion des changements d'état
  void _handleRouteGenerationStateChange(RouteGenerationState state) async {
    // Cas 1: Historique
    if (state.hasGeneratedRoute && state.isLoadedFromHistory) {
      setState(() {
        generatedRouteCoordinates = state.generatedRoute;
        routeMetadata = state.routeMetadata;
      });
      _mapStateService.saveGeneratedRoute(state.generatedRoute, state.routeMetadata, _hasAutoSaved);
      await _displayRouteOnMap(state.generatedRoute!);
      return;
    }
    
    // Cas 2: Nouveau parcours (déjà sauvegardé automatiquement)
    if (state.isNewlyGenerated && !state.isGeneratingRoute) {
      setState(() {
        generatedRouteCoordinates = state.generatedRoute;
        routeMetadata = state.routeMetadata;
        _hasAutoSaved = true;
      });
      _mapStateService.saveGeneratedRoute(state.generatedRoute, state.routeMetadata, _hasAutoSaved);
      await _displayRouteOnMap(state.generatedRoute!);
      // 🚫 PLUS BESOIN : await _autoSaveGeneratedRoute(state);
    } else if (state.errorMessage != null) {
      _showRouteGenerationError(state.errorMessage!);
      _hasAutoSaved = false;
    }
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

  /// 🆕 Gestion de la sauvegarde manuelle
  void _handleSaveRoute() {
    final overlay = Overlay.of(context, rootOverlay: true);
    
    // 🔧 Éviter les appels multiples
    if (_isSaveDialogOpen) {
      print('⚠️ Dialogue de sauvegarde déjà ouvert');
      return;
    }

    // Vérifier qu'un parcours est généré
    if (generatedRouteCoordinates == null || routeMetadata == null) {
      showTopSnackBar(
        overlay,
        TopSnackBar(
          title: 'Aucun parcours à sauvegarder',
          icon: HugeIcons.solidRoundedAlert02,
        ),
      );
      return;
    }

    // Vérifier si déjà en cours de sauvegarde
    if (_isSavingRoute) {
      showTopSnackBar(
        overlay,
        TopSnackBar(
          title: 'Sauvegarde en cours...',
          icon: HugeIcons.strokeRoundedLoading03,
          color: Colors.orange,
        ),
      );
      return;
    }

    // Vérifier que l'utilisateur est connecté
    try {
      final currentUser = sb.Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _showLoginRequiredDialog();
        return;
      }
    } catch (e) {
      print('❌ Erreur vérification auth: $e');
      showTopSnackBar(
        overlay,
        TopSnackBar(
          title: 'Erreur de connexion',
          icon: HugeIcons.solidRoundedAlert02,
        ),
      );
      return;
    }

    // Afficher le dialogue de sauvegarde
    _showSaveRouteDialog();
  }

  Future<void> _showSaveRouteDialog() async {
    if (_isSaveDialogOpen) return;
    _isSaveDialogOpen = true;

    final defaultName = generateAutoRouteName(
      context.read<RouteParametersBloc>().state.parameters,
      _getGeneratedRouteDistance(),
    );

    final routeName = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaveRouteSheet(initialValue: defaultName),
    );

    _isSaveDialogOpen = false;

    if (!mounted || routeName == null || routeName.isEmpty) return;
    _performSaveRoute(routeName);
  }
  
  /// 🆕 Exécution de la sauvegarde
  void _performSaveRoute(String routeName) {
    final overlay = Overlay.of(context, rootOverlay: true);

    // Vérifications finales
    if (mapboxMap == null) {
      showTopSnackBar(
        overlay,
        TopSnackBar(
          title: 'Carte non disponible',
          icon: HugeIcons.solidRoundedAlert02,
        ),
      );
      return;
    }

    if (generatedRouteCoordinates == null || routeMetadata == null) {
      showTopSnackBar(
        overlay,
        TopSnackBar(
          title: 'Aucun parcours à sauvegarder',
          icon: HugeIcons.solidRoundedAlert02,
        ),
      );
      return;
    }

    // Récupérer les paramètres utilisés
    final routeState = context.read<RouteGenerationBloc>().state;
    if (routeState.usedParameters == null) {
      showTopSnackBar(
        overlay,
        TopSnackBar(
          title: 'Paramètres de parcours manquants',
          icon: HugeIcons.solidRoundedAlert02,
        ),
      );
      return;
    }

    // 🔥 UTILISER AppDataBloc AU LIEU DE RouteGenerationBloc
    context.read<AppDataBloc>().add(
      SavedRouteAddedToAppData(
        name: routeName,
        parameters: routeState.usedParameters!,
        coordinates: generatedRouteCoordinates!,
        actualDistance: _getGeneratedRouteDistance(),
        estimatedDuration: routeMetadata!['durationMinutes'] as int?,
        map: mapboxMap!,
      ),
    );

    print('🚀 Sauvegarde via AppDataBloc démarrée: $routeName');
    
    // Afficher feedback immédiat
    showTopSnackBar(
      overlay,
      TopSnackBar(
        title: 'Sauvegarde en cours...',
        icon: HugeIcons.strokeRoundedLoading03,
        color: Colors.blue,
      ),
    );
  }

  /// 🆕 Dialogue pour demander la connexion
  void _showLoginRequiredDialog() {
    showModalSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      child: ModalDialog(
        isDestructive: true,
        title: 'Connexion requise',
        subtitle: 'Vous devez être connecté pour sauvegarder vos parcours.',
        validLabel: 'Se connecter',
        onValid: () {
          HapticFeedback.mediumImpact();
          
          context.pop; // 🔧 Fermer le dialogue d'abord
          context.go('/profile'); // 🔧 Puis naviguer
        },
      ),
    );
  }

  // Fonction onClear pour supprimer le parcours et revenir à l'état précédent
  Future<void> _clearGeneratedRoute() async {
  print('🧹 === DÉBUT NETTOYAGE COMPLET DU PARCOURS ===');
  
  // Sauvegarder les positions avant nettoyage
  final double? lastSelectedLat = _selectedLatitude;
  final double? lastSelectedLng = _selectedLongitude;
  
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

  // 2. Réinitialiser l'état du bloc
  if (mounted) {
    context.read<RouteGenerationBloc>().add(const RouteStateReset());
    print('✅ État du bloc RouteGeneration reseté');
  }

  // 3. Réinitialiser les variables locales du parcours
  setState(() {
    generatedRouteCoordinates = null;
    routeMetadata = null;
    _hasAutoSaved = false;
  });

  // 4. 🆕 DÉTECTION INTELLIGENTE DU MODE À RESTAURER
  final bool shouldRestoreToUserTracking = _shouldRestoreToUserTracking(lastSelectedLat, lastSelectedLng);
  
  print('🔍 Analyse situation:');
  print('   Position user: $_userLatitude, $_userLongitude');
  print('   Position selected: $lastSelectedLat, $lastSelectedLng');
  print('   Markers actifs: ${locationMarkers.isNotEmpty || _showLottieMarker}');
  print('   Mode actuel: $_trackingMode');
  print('   → Restaurer UserTracking: $shouldRestoreToUserTracking');

  // 5. Appliquer le mode et les actions appropriées
  if (shouldRestoreToUserTracking) {
    await _restoreToUserTrackingMode();
  } else {
    await _restoreToManualMode(lastSelectedLat, lastSelectedLng);
  }

  // 6. Nettoyer le helper de restauration

  // 7. Sauvegarder l'état final
  _mapStateService.saveTrackingMode(_trackingMode);
  _mapStateService.saveGeneratedRoute(null, null, false);

  print('✅ === FIN NETTOYAGE COMPLET DU PARCOURS ===');
}

  /// 🆕 Détermine intelligemment si on doit restaurer vers UserTracking
  bool _shouldRestoreToUserTracking(double? lastSelectedLat, double? lastSelectedLng) {
    // Cas 1: Pas de position sélectionnée différente → UserTracking
    if (lastSelectedLat == null || lastSelectedLng == null) {
      return true;
    }
    
    // Cas 2: Position sélectionnée = position utilisateur → UserTracking  
    if (_userLatitude != null && _userLongitude != null) {
      final double latDiff = (lastSelectedLat - _userLatitude!).abs();
      final double lngDiff = (lastSelectedLng - _userLongitude!).abs();
      
      // Si les positions sont très proches (moins de 10m environ)
      if (latDiff < 0.0001 && lngDiff < 0.0001) {
        return true;
      }
    }
    
    // Cas 3: Pas de markers visibles → UserTracking
    if (!_showLottieMarker && locationMarkers.isEmpty) {
      return true;
    }
    
    // Cas 4: Mode actuel est UserTracking ET pas de markers → UserTracking
    if (_trackingMode == TrackingMode.userTracking && !_showLottieMarker && locationMarkers.isEmpty) {
      return true;
    }
    
    // Sinon → Conserver mode Manual/SearchSelected
    return false;
  }

  /// 🎯 Restaure vers le mode UserTracking (supprime markers, focus user)
  Future<void> _restoreToUserTrackingMode() async {
    print('🎯 === RESTAURATION MODE USER TRACKING ===');
    
    // 1. Changer le mode
    setState(() {
      _trackingMode = TrackingMode.userTracking;
      _selectedLatitude = _userLatitude;
      _selectedLongitude = _userLongitude;
    });

    // 2. Supprimer TOUS les markers (inutiles en mode GPS)
    await _clearLocationMarkers();
    setState(() {
      _showLottieMarker = false;
      _lottieMarkerLat = null;
      _lottieMarkerLng = null;
    });
    
    // 3. FlyTo vers la position utilisateur
    if (mapboxMap != null && _userLatitude != null && _userLongitude != null) {
      await mapboxMap!.flyTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(_userLongitude!, _userLatitude!)
          ),
          zoom: 15,
        ),
        mp.MapAnimationOptions(duration: 1200),
      );
      print('📍 FlyTo position utilisateur: $_userLatitude, $_userLongitude');
    }

    // 4. Sauvegarder l'état
    _mapStateService.saveSelectedPosition(_userLatitude ?? 0, _userLongitude ?? 0);
    _mapStateService.saveMarkerState(false, null, null);
    
    print('✅ Mode UserTracking restauré');
  }

  /// 📍 Restaure vers le mode Manual (conserve markers, focus marker)
  Future<void> _restoreToManualMode(double? lastSelectedLat, double? lastSelectedLng) async {
    print('📍 === RESTAURATION MODE MANUAL ===');
    
    if (lastSelectedLat == null || lastSelectedLng == null) {
      print('❌ Pas de position à restaurer, fallback UserTracking');
      await _restoreToUserTrackingMode();
      return;
    }

    // 1. Changer le mode (garder le mode actuel s'il est déjà manual/searchSelected)
    setState(() {
      if (_trackingMode == TrackingMode.userTracking) {
        _trackingMode = TrackingMode.manual; // Passer en manual si on était en user tracking
      }
      // Sinon garder le mode actuel (manual ou searchSelected)
      
      _selectedLatitude = lastSelectedLat;
      _selectedLongitude = lastSelectedLng;
    });

    // 2. S'assurer qu'un marker est visible
    await _ensureMarkerAtPosition(lastSelectedLng, lastSelectedLat);
    
    // 3. FlyTo vers le marker
    if (mapboxMap != null) {
      await mapboxMap!.flyTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(lastSelectedLng, lastSelectedLat)
          ),
          zoom: 15,
        ),
        mp.MapAnimationOptions(duration: 1200),
      );
      print('📍 FlyTo marker: $lastSelectedLat, $lastSelectedLng');
    }

    // 4. Sauvegarder l'état avec marker
    _mapStateService.saveSelectedPosition(lastSelectedLat, lastSelectedLng);
    _mapStateService.saveMarkerState(true, lastSelectedLat, lastSelectedLng);
    
    print('✅ Mode Manual restauré avec marker');
  }

  /// 🆕 S'assure qu'un marker est présent à la position donnée
  Future<void> _ensureMarkerAtPosition(double longitude, double latitude) async {
    print('🔍 Vérification marker à: $latitude, $longitude');
    
    // Si on a déjà un marker Lottie à cette position, c'est bon
    if (_showLottieMarker && 
        _lottieMarkerLat != null && _lottieMarkerLng != null &&
        (_lottieMarkerLat! - latitude).abs() < 0.0001 && 
        (_lottieMarkerLng! - longitude).abs() < 0.0001) {
      print('✅ Marker Lottie déjà présent à la bonne position');
      return;
    }

    // Si on a des markers classiques à peu près à cette position
    bool hasNearbyMarker = false;
    if (locationMarkers.isNotEmpty) {
      // Pour simplifier, on considère qu'on a un marker s'il y en a
      hasNearbyMarker = true;
    }

    if (!hasNearbyMarker && !_showLottieMarker) {
      print('📍 Création marker manquant');
      await _placeMarkerWithLottie(longitude, latitude);
    } else {
      print('✅ Marker présent (classique ou Lottie)');
    }
  }

  // Affichage de la route sur la carte
  Future<void> _displayRouteOnMap(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) return;

    try {
      print('🎬 Début animation d\'affichage de route...');

      // // ÉTAPE 1 : Animation vers le point de départ
      // await _animateToRouteStart(coordinates);

      // // ÉTAPE 2 : Afficher progressivement le tracé
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

    // 💾 Sauvegarder dans le service
    _mapStateService.saveSelectedPosition(latitude, longitude);

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

    print('🎯 Ajout marqueur à: ($latitude, $longitude)');
    
    // 🔧 FIX : Utiliser la nouvelle méthode corrigée
    await _placeMarkerWithLottie(longitude, latitude);
  }

  Future<void> _ensureCustomMarkerImage() async {
    if (mapboxMap == null) return;
    if (await mapboxMap!.style.hasStyleImage('custom-pin')) return;

    final bytes   = await rootBundle.load('assets/img/pin.png');
    final codec   = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame   = await codec.getNextFrame();
    final img     = frame.image;

    await mapboxMap!.style.addStyleImage(
      'custom-pin',
      1.0,
      mp.MbxImage(
        width:  img.width,
        height: img.height,
        data:   bytes.buffer.asUint8List(),
      ),
      false, /* sdf ? */ [], [], null,
    );
  }

  Future<void> _placeMarkerWithLottie(double lon, double lat) async {
    if (mapboxMap == null) return;

    try {
      print('🎯 Placement du marqueur Lottie à: ($lat, $lon)');
            
      // Retour haptique immédiat
      HapticFeedback.mediumImpact(); 

      // 1️⃣ Positionner / lancer l'animation Lottie (overlay)
      setState(() {
        _showLottieMarker = true;
        _lottieMarkerLng = lon;
        _lottieMarkerLat = lat;
      });
      
      print('✅ Lottie affiché à: ($lat, $lon)');
      
      // Démarrer l'animation
      _lottieController
        ..reset()
        ..forward();

      // 2️⃣ Attendre la fin de l'animation
      await Future.delayed(
        _lottieController.duration ?? const Duration(seconds: 1),
      );

      if (!mounted) return;

      // 3️⃣ Masquer Lottie
      setState(() => _showLottieMarker = false);

      // 4️⃣ Créer un *vrai* marqueur Mapbox – parfaitement stable
      await _ensureCustomMarkerImage();
      markerPointManager ??= await mapboxMap!.annotations.createPointAnnotationManager();

      final marker = await markerPointManager!.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(coordinates: mp.Position(lon, lat)),
          iconImage: 'custom-pin',
          iconSize: 1,
          iconOffset: [0, -_markerSize / 2],
        ),
      );
      
      // 🔧 FIX : Ajouter le marqueur à la liste pour le tracking
      locationMarkers.add(marker);

      // 💾 Sauvegarder l'état du marqueur
      _mapStateService.saveMarkerState(true, lat, lon);

      print('✅ Marqueur personnalisé ajouté et Lottie masqué');
      
    } catch (e) {
      print('❌ Erreur ajout marqueur personnalisé: $e');
      
      // Fallback: utiliser l'icône par défaut de Mapbox
      try {
        markerPointManager ??= await mapboxMap!.annotations.createPointAnnotationManager();
        final marker = await markerPointManager!.create(
          mp.PointAnnotationOptions(
            geometry: mp.Point(coordinates: mp.Position(lon, lat)),
            iconSize: 1.0,
          ),
        );
        locationMarkers.add(marker);
        print('✅ Marqueur par défaut ajouté en fallback');
      } catch (fallbackError) {
        print('❌ Erreur fallback marqueur: $fallbackError');
      }
    }
  }

  Future<void> _clearLocationMarkers() async {
    print('🧹 Nettoyage des marqueurs...');
    
    // 1️⃣ Masquer le marqueur Lottie
    if (_showLottieMarker) {
      setState(() {
        _showLottieMarker = false;
        _lottieMarkerLat = null;
        _lottieMarkerLng = null;
      });
      print('✅ Lottie marqueur masqué');
    }
    
    // 2️⃣ Supprimer les PointAnnotations
    try {
      if (markerPointManager != null) {
        await markerPointManager!.deleteAll();
        locationMarkers.clear();
        print('✅ PointAnnotations supprimés');
      }
    } catch (e) {
      print('❌ Erreur suppression PointAnnotations: $e');
    }

    // 3️⃣ Supprimer les cercles (si utilisés)
    try {
      if (circleAnnotationManager != null) {
        await circleAnnotationManager!.deleteAll();
        print('✅ CircleAnnotations supprimés');
      }
    } catch (e) {
      print('❌ Erreur suppression CircleAnnotations: $e');
    }

    // 💾 Sauvegarder l'absence de marqueurs
    _mapStateService.saveMarkerState(false, null, null);
    
    print('✅ Nettoyage des marqueurs terminé');
  }

  Future<Offset?> _getScreenPosition(double lat, double lng) async {
    if (mapboxMap == null) return null;
    
    try {
      final point = mp.Point(coordinates: mp.Position(lng, lat));
      final screenCoordinate = await mapboxMap!.pixelForCoordinate(point);
      return Offset(screenCoordinate.x, screenCoordinate.y);
    } catch (e) {
      print('❌ Erreur conversion coordonnées: $e');
      return null;
    }
  }

  // === ACTIONS UTILISATEUR ===
  /// Active le mode suivi utilisateur
  void _activateUserTracking() {
    if (_userLatitude != null && _userLongitude != null) {
      setState(() {
        _trackingMode = TrackingMode.userTracking;
      });

      // 💾 Sauvegarder le mode
      _mapStateService.saveTrackingMode(_trackingMode);

      _updateSelectedPosition(
        latitude: _userLatitude!,
        longitude: _userLongitude!,
        updateCamera: true,
      );

      // Nettoyer les marqueurs car on suit la position en temps réel
      _clearLocationMarkers();
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
    await _placeMarkerWithLottie(longitude, latitude);

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
    
    // Nettoyer parcours existant
    if (generatedRouteCoordinates != null) {
      print('🧹 Nettoyage du parcours existant avant nouvelle recherche');
      
      if (routeLineManager != null && mapboxMap != null) {
        try {
          await routeLineManager!.deleteAll();
          await mapboxMap!.annotations.removeAnnotationManager(routeLineManager!);
          routeLineManager = null;
        } catch (e) {
          print('❌ Erreur suppression route: $e');
        }
      }
      
      if (mounted) {
        context.read<RouteGenerationBloc>().add(const RouteStateReset());
      }
      
      setState(() {
        generatedRouteCoordinates = null;
        routeMetadata = null;
        _hasAutoSaved = false;
      });
      
      // 💾 Nettoyer dans le service
      _mapStateService.clearMarkersAndRoute();
    }
    
    // Mettre à jour la position
    setState(() {
      _trackingMode = TrackingMode.searchSelected;
      _selectedLatitude = latitude;
      _selectedLongitude = longitude;
    });

    // 💾 Sauvegarder le nouveau mode et position
    _mapStateService.saveTrackingMode(_trackingMode);
    _mapStateService.saveSelectedPosition(latitude, longitude);

    // Placer le marqueur
    await _clearLocationMarkers();
    await _placeMarkerWithLottie(longitude, latitude);

    // Centrer la caméra
    if (mapboxMap != null) {
      await mapboxMap!.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(longitude, latitude)),
          zoom: 15,
        ),
        mp.MapAnimationOptions(duration: 1000),
      );
    }

    print('✅ Position de recherche définie avec sauvegarde: $placeName');
  }

  // === GESTION DE LA CARTE ===
  Future<void> _onMapCreated(mp.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    
    print('🗺️ === CARTE CRÉÉE - POSITION DÉJÀ DÉFINIE ===');
    print('🗺️ Première initialisation: ${!_mapStateService.isMapInitialized}');

    // Configuration de base
    await _setupMapboxSettings();
    await _setupLongTapInteraction();
    await _setupMapMoveListener();

    // 🔄 Gestion intelligente de l'initialisation
    if (!_mapStateService.isMapInitialized) {
      // === PREMIÈRE INITIALISATION ===
      print('🆕 Première initialisation de la carte');
      await _performInitialSetup();
      _mapStateService.markMapAsInitialized();
    } else {
      // === RETOUR SUR LA PAGE ===
      print('🔄 Retour sur la page - restauration de l\'état');
      await _restoreMapState();
    }
  }

  /// 🆕 Configuration initiale (première fois)
  Future<void> _performInitialSetup() async {
    print('🆕 Configuration initiale de la carte');
    
    // 🎯 La position est déjà définie par LocationAwareMapWidget !
    // On récupère juste la position pour nos variables locales
    await _syncPositionFromLocationService();
    
    // Démarrer le tracking en temps réel
    await _startLocationTrackingWhenMapReady();
    
    // Définir le mode de suivi initial
    setState(() {
      _trackingMode = TrackingMode.userTracking;
    });
    _mapStateService.saveTrackingMode(_trackingMode);

    print('✅ Configuration initiale terminée');
  }

  /// 🆕 Synchroniser notre position depuis le service de géolocalisation
  Future<void> _syncPositionFromLocationService() async {
    try {
      final position = LocationPreloadService.instance.lastKnownPosition;
      if (position != null) {
        setState(() {
          _userLatitude = position.latitude;
          _userLongitude = position.longitude;
          _selectedLatitude = position.latitude;
          _selectedLongitude = position.longitude;
        });
        
        // Sauvegarder dans le service
        _mapStateService.saveUserPosition(position.latitude, position.longitude);
        _mapStateService.saveSelectedPosition(position.latitude, position.longitude);
        
        print('✅ Position synchronisée: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      print('⚠️ Erreur synchronisation position: $e');
    }
  }

  /// 🔄 Restauration de l'état (retour)
  Future<void> _restoreMapState() async {
    print('🔄 Restauration de l\'état de la carte');
    
    // Restaurer l'état depuis le service
    _restoreStateFromService();
    
    // Restaurer les marqueurs si nécessaire
    if (_mapStateService.hasActiveMarker && 
        _selectedLatitude != null && 
        _selectedLongitude != null) {
      await _placeMarkerWithLottie(_selectedLongitude!, _selectedLatitude!);
    }
    
    // Restaurer la route si elle existe
    if (generatedRouteCoordinates != null) {
      await _displayRouteOnMap(generatedRouteCoordinates!);
    }
    
    // Redémarrer le tracking de position
    await _startLocationTrackingWhenMapReady();
    
    print('✅ État de la carte restauré');
  }

  /// 🎯 Centrer sur la position utilisateur
  Future<void> _centerOnUserLocation({required bool animate}) async {
    if (mapboxMap == null || _userLatitude == null || _userLongitude == null) return;

    try {
      final cameraOptions = mp.CameraOptions(
        center: mp.Point(coordinates: mp.Position(_userLongitude!, _userLatitude!)),
        zoom: 15,
        pitch: 0,
        bearing: 0,
      );

      if (animate) {
        await mapboxMap!.flyTo(cameraOptions, mp.MapAnimationOptions(duration: 1500));
        print('🎬 Centrage animé sur position utilisateur');
      } else {
        await mapboxMap!.setCamera(cameraOptions);
        print('📷 Centrage instantané sur position utilisateur');
      }
      
    } catch (e) {
      print('❌ Erreur centrage position utilisateur: $e');
    }
  }

  /// ⚙️ Configuration des paramètres Mapbox
  Future<void> _setupMapboxSettings() async {
    if (mapboxMap == null) return;

    try {
      // Configuration de la localisation
      mapboxMap!.location.updateSettings(
        mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
      );

      // Créer les gestionnaires d'annotations
      pointAnnotationManager = await mapboxMap!.annotations.createPointAnnotationManager();
      circleAnnotationManager = await mapboxMap!.annotations.createCircleAnnotationManager();
      markerPointManager = await mapboxMap!.annotations.createPointAnnotationManager();

      // Masquer les éléments d'interface
      await mapboxMap!.compass.updateSettings(mp.CompassSettings(enabled: false));
      await mapboxMap!.attribution.updateSettings(mp.AttributionSettings(enabled: false));
      await mapboxMap!.logo.updateSettings(mp.LogoSettings(enabled: false));
      await mapboxMap!.scaleBar.updateSettings(mp.ScaleBarSettings(enabled: false));
      
      print('⚙️ Paramètres Mapbox configurés');
      
    } catch (e) {
      print('❌ Erreur configuration Mapbox: $e');
    }
  }

  /// 🤏 Configuration du listener de déplacement
  Future<void> _setupMapMoveListener() async {
    if (mapboxMap == null) return;

    mapboxMap!.setOnMapMoveListener((context) {
      // Si on était en mode suivi utilisateur, passer en mode manuel
      if (_trackingMode == TrackingMode.userTracking) {
        setState(() {
          _trackingMode = TrackingMode.manual;
        });
        _mapStateService.saveTrackingMode(_trackingMode);
      }

      // Mettre à jour la position du marqueur Lottie lors du déplacement
      if (_showLottieMarker) {
        setState(() {}); // Force rebuild pour recalculer la position
      }
    });
    
    print('🤏 Listener de déplacement configuré');
  }

  /// 🆕 CONFIGURATION DE L'INTERACTION LONGTAP
  Future<void> _setupLongTapInteraction() async {
    if (mapboxMap == null) return;
    
    try {
      // Créer l'interaction LongTap pour la carte entière
      longTapInteraction = mp.LongTapInteraction.onMap(
        (context) {
          // Récupérer les coordonnées du point tapé
          final point = context.point;
          final longitude = point.coordinates.lng.toDouble();
          final latitude = point.coordinates.lat.toDouble();
          
          print('🔗 LongTap détecté à: ($latitude, $longitude)');
          
          // Activer le mode manuel à cette position
          _activateManualSelectionAtPosition(longitude, latitude);
        },
        stopPropagation: true, // Arrêter la propagation de l'événement
      );
      
      // Ajouter l'interaction à la carte (sans cibler de layer spécifique)
      mapboxMap!.addInteraction(longTapInteraction!);
      
      print('✅ LongTapInteraction configurée sur la carte');
      
    } catch (e) {
      print('❌ Erreur lors de la configuration LongTapInteraction: $e');
    }
  }

  Future<void> _activateManualSelectionAtPosition(double longitude, double latitude) async {
    if (mapboxMap == null) {
      print('❌ Carte non initialisée pour sélection manuelle');
      return;
    }

    try {
      print('📍 === POSITIONNEMENT MANUEL VIA LONGTAP ===');
      print('📍 Position: ($latitude, $longitude)');
      
      // Nettoyer parcours existant
      if (generatedRouteCoordinates != null) {
        print('🧹 Nettoyage du parcours existant');
        
        if (routeLineManager != null && mapboxMap != null) {
          try {
            await routeLineManager!.deleteAll();
            await mapboxMap!.annotations.removeAnnotationManager(routeLineManager!);
            routeLineManager = null;
          } catch (e) {
            print('❌ Erreur suppression route: $e');
          }
        }
        
        if (mounted) {
          context.read<RouteGenerationBloc>().add(const RouteStateReset());
        }
        
        setState(() {
          generatedRouteCoordinates = null;
          routeMetadata = null;
          _hasAutoSaved = false;
        });
        
        // 💾 Nettoyer dans le service
        _mapStateService.clearMarkersAndRoute();
      }
      
      // Mettre à jour la position
      setState(() {
        _trackingMode = TrackingMode.manual;
        _selectedLatitude = latitude;
        _selectedLongitude = longitude;
      });

      // 💾 Sauvegarder le nouveau mode et position
      _mapStateService.saveTrackingMode(_trackingMode);
      _mapStateService.saveSelectedPosition(latitude, longitude);

      // Placer le marqueur avec transition fluide
      await _clearLocationMarkers();
      await _placeMarkerWithLottie(longitude, latitude);

      // Centrer la caméra
      if (mapboxMap != null) {
        await mapboxMap!.flyTo(
          mp.CameraOptions(
            center: mp.Point(coordinates: mp.Position(longitude, latitude)),
            zoom: 15,
          ),
          mp.MapAnimationOptions(duration: 1000),
        );
      }

      // Mettre à jour le BLoC
      if (mounted) {
        context.read<RouteParametersBloc>().add(
          StartLocationUpdated(longitude: longitude, latitude: latitude),
        );
      }

      print('✅ Position manuelle définie avec sauvegarde d\'état');
      
    } catch (e) {
      print('❌ Erreur lors de l\'activation manuelle: $e');
      
      if (_userLatitude != null && _userLongitude != null) {
        await _setManualPositionFallback(_userLongitude!, _userLatitude!);
      }
    }
  }

  /// 🎨 Changement de style de carte
  Future<void> _onMapStyleSelected(String styleId) async {
    if (styleId == _currentMapStyleId || mapboxMap == null) return;

    try {
      print('🎨 Changement de style vers: $styleId');
      
      // Sauvegarder le nouvel ID de style
      setState(() {
        _currentMapStyleId = styleId;
      });
      
      // Sauvegarder dans le service
      _mapStateService.saveMapStyleId(styleId);
      
      // Obtenir l'URI du nouveau style
      final newStyle = MapboxStyleConstants.getStyleById(styleId);
      
      // Changer le style de la carte
      await mapboxMap!.style.setStyleURI(newStyle.uri);
      
      // Feedback haptique
      HapticFeedback.lightImpact();
      
      print('✅ Style de carte mis à jour: ${newStyle.name}');
      
    } catch (e) {
      print('❌ Erreur changement de style: $e');
    }
  }

  /// 🔄 Restaurer le style depuis le service
  void _restoreMapStyleFromService() {
    _currentMapStyleId = _mapStateService.selectedMapStyleId;
    print('🎨 Style restauré depuis le service: $_currentMapStyleId');
  }

  // === INTERFACE UTILISATEUR ===
  /// 🎨 Ouvrir le sélecteur de style de carte
  void _openMapStyleSelector() {
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: MapStyleSelector(
        currentStyleId: _currentMapStyleId,
        onStyleSelected: _onMapStyleSelected,
      ),
    );
  }
  
  void openGenerator() {
    showModalSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      child: BlocProvider.value(
        value: context.read<RouteParametersBloc>(),
        child: BlocProvider.value(
          value: context.read<RouteGenerationBloc>(),
          child: gen.RouteParameterScreen(
            startLongitude: _selectedLongitude ?? _userLongitude ?? 0.0,
            startLatitude: _selectedLatitude ?? _userLatitude ?? 0.0,
            generateRoute: _handleGenerateRoute, // NOUVEAU CALLBACK
          ),
        ),
      ),
    );
  }

  // Gestionnaire de génération de route
  void _handleGenerateRoute() {
    setState(() {
      _hasAutoSaved = false;
    });

    final parametersState = context.read<RouteParametersBloc>().state;
    final parameters = parametersState.parameters;

    if (!parameters.isValid) {
      _showRouteGenerationError('Paramètres invalides');
      return;
    }

    // 🆕 Passer mapboxMap pour la sauvegarde automatique
    context.read<RouteGenerationBloc>().add(
      RouteGenerationRequested(
        parameters,
        mapboxMap: mapboxMap,
      ),
    );

    if (mounted) {
      ConversionTriggers.onRouteGenerated(context);
    }

    print('🚀 Génération demandée: ${parameters.distanceKm}km, ${parameters.activityType.name}');
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

    showModalSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      child: ExportFormatDialog(
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
        context: context,
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

  bool _isCurrentRouteAlreadySaved() {
    // Vérifier qu'on a bien un parcours généré
    if (generatedRouteCoordinates == null || routeMetadata == null) {
      return false;
    }

    // Vérifier qu'on a accès à AppDataBloc
    try {
      final appDataState = context.read<AppDataBloc>().state;
      if (!appDataState.hasHistoricData) {
        return false;
      }

      final savedRoutes = appDataState.savedRoutes;
      final currentDistance = _getGeneratedRouteDistance();
      final routeState = context.read<RouteGenerationBloc>().state;
      
      // Si le parcours vient de l'historique, il est déjà sauvegardé par définition
      if (routeState.isLoadedFromHistory) {
        return true;
      }

      // Vérifier s'il existe un parcours similaire
      return _findSimilarRoute(savedRoutes, currentDistance, routeState.usedParameters) != null;
      
    } catch (e) {
      print('❌ Erreur lors de la vérification du parcours: $e');
      return false;
    }
  }

  /// Trouve un parcours similaire dans la liste sauvegardée
  SavedRoute? _findSimilarRoute(
    List<SavedRoute> savedRoutes, 
    double currentDistance, 
    RouteParameters? currentParams,
  ) {
    if (currentParams == null) return null;

    // Tolérance pour la comparaison de distance (100m)
    const double distanceTolerance = 0.1; // km

    for (final savedRoute in savedRoutes) {
      final savedDistance = savedRoute.actualDistance ?? savedRoute.parameters.distanceKm;
      
      // Vérifier la distance avec tolérance
      if ((currentDistance - savedDistance).abs() <= distanceTolerance) {
        // Vérifier les paramètres principaux
        if (_areParametersSimilar(currentParams, savedRoute.parameters)) {
          return savedRoute;
        }
      }
    }

    return null;
  }

  /// Compare si deux ensembles de paramètres sont similaires
  bool _areParametersSimilar(RouteParameters current, RouteParameters saved) {
    return current.activityType == saved.activityType &&
           current.terrainType == saved.terrainType &&
           current.urbanDensity == saved.urbanDensity &&
           current.isLoop == saved.isLoop &&
           current.avoidTraffic == saved.avoidTraffic;
  }

  /// Getter pour vérifier si on sauvegarde actuellement
  bool get _isSavingRoute {
    try {
      final appDataState = context.read<AppDataBloc>().state;
      return appDataState.isLoading && 
             appDataState.lastError != null && 
             appDataState.lastError!.contains('sauvegarde');
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _saveStateToService();

    _fadeController.dispose();
    _positionStream?.cancel();
    _lottieController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocListener<RouteGenerationBloc, RouteGenerationState>(
      // 🆕 Écouter les changements d'état pour la sauvegarde avec protection
      listener: (context, state) {
        // 🔧 Vérifier que le widget est encore monté
        if (!mounted) return;
        
        // Gérer les messages de sauvegarde
        if (state.stateId.contains('success') && 
            !state.stateId.contains('no-auto-save') && 
            !state.isLoadedFromHistory) {
          // Sauvegarde manuelle réussie
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showTopSnackBar(
                Overlay.of(context),
                TopSnackBar(
                  title: 'Parcours sauvegardé',
                  icon: HugeIcons.solidRoundedCheckmarkCircle02,
                  color: Colors.green,
                ),
              );
            }
          });
        } else if (state.stateId.contains('save-error')) {
          // Erreur de sauvegarde
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showTopSnackBar(
                Overlay.of(context),
                TopSnackBar(
                  title: state.errorMessage ?? 'Erreur de sauvegarde',
                  icon: HugeIcons.solidRoundedAlert02,
                  color: Colors.red,
                ),
              );
            }
          });
        }
      },
      child: BlocListener<AppDataBloc, AppDataState>(
        listener: (context, appDataState) {
          if (!mounted) return;
          
          // Gérer les messages de sauvegarde de parcours
          if (appDataState.lastError != null && appDataState.lastError!.contains('sauvegarde')) {
            // Erreur de sauvegarde
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showTopSnackBar(
                  Overlay.of(context),
                  TopSnackBar(
                    title: 'Erreur de sauvegarde',
                    icon: HugeIcons.solidRoundedAlert02,
                    color: Colors.red,
                  ),
                );
              }
            });
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
                child: LocationAwareMapWidget(
                  key: ValueKey("locationAwareMapWidget"),
                  styleUri: _mapStateService.getCurrentStyleUri(),
                  onMapCreated: _onMapCreated,
                  mapKey: ValueKey("mapWidget"),
                  restoreFromCache: _mapStateService.isMapInitialized,
                ),
              ),
        
              // 🆕 MARQUEUR LOTTIE ANIMÉ
              if (_showLottieMarker && _lottieMarkerLat != null && _lottieMarkerLng != null)
                _buildLottieMarker(),
        
                // Interface normale (masquée en mode navigation OU navigation live)
                if (!isNavigationMode && !_isInNavigationMode)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: LocationSearchBar(
                              onLocationSelected: _onLocationSelected,
                              userLongitude: _userLongitude,
                              userLatitude: _userLatitude,
                            ),
                          ),
        
                          40.h,
        
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 20.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    spacing: 12.0,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Map style
                                      IconBtn(
                                        padding: 15.0,
                                        backgroundColor: context.adaptiveBackground,
                                        icon: HugeIcons.strokeRoundedMaterialAndTexture,
                                        iconColor: context.adaptiveTextSecondary,
                                        onPressed: _openMapStyleSelector,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.18),
                                            spreadRadius: 2,
                                            blurRadius: 30,
                                            offset: Offset(0, 0), // changes position of shadow
                                          ),
                                        ]
                                      ),
        
                                      // Bouton retour position utilisateur
                                      IconBtn(
                                        padding: 15.0,
                                        backgroundColor: context.adaptiveBackground,
                                        icon: _trackingMode == TrackingMode.userTracking
                                            ? HugeIcons.solidRoundedLocationShare02
                                            : HugeIcons.strokeRoundedLocationShare02,
                                        onPressed: _activateUserTracking,
                                        iconColor: _trackingMode == TrackingMode.userTracking
                                            ? AppColors.primary
                                            : context.adaptiveTextSecondary,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.18),
                                            spreadRadius: 2,
                                            blurRadius: 30,
                                            offset: Offset(0, 0), // changes position of shadow
                                          ),
                                        ]
                                      ),
                                      
                                      // Bouton générateur
                                      IconBtn(
                                        padding: 15.0,
                                        backgroundColor: context.adaptiveBackground,
                                        icon: HugeIcons.strokeRoundedAiMagic,
                                        iconColor: context.adaptiveTextSecondary,
                                        onPressed: openGenerator,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.18),
                                            spreadRadius: 2,
                                            blurRadius: 30,
                                            offset: Offset(0, 0), // changes position of shadow
                                          ),
                                        ]
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
        
              // if (_isLoading) LoadingOverlay(),
        
              // RouteInfoCard (masqué en mode navigation)
              if (generatedRouteCoordinates != null && routeMetadata != null && !isNavigationMode & !_isInNavigationMode)
              Positioned(
                top: kToolbarHeight * 1.5,
                left: 15,
                right: 15,
                child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                      child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                spreadRadius: 2,
                                blurRadius: 30,
                                offset: Offset(0, 0), // changes position of shadow
                              ),
                            ],
                          ),
                          child: BlocBuilder<AppDataBloc, AppDataState>(
                            builder: (context, appDataState) {
                              return RouteInfoCard(
                                routeName : generateAutoRouteName(
                                  context.read<RouteParametersBloc>().state.parameters,
                                  _getGeneratedRouteDistance(),
                                ),
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
                                onSave: _handleSaveRoute, // 🆕 Nouveau callback
                                isSaving: _isSavingRoute, // 🆕 État de sauvegarde
                                onShare: _showExportDialog,
                                isAlreadySaved: _isCurrentRouteAlreadySaved(),
                              );
                            }
                          ),
                        ),
                      ),
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLottieMarker() {
    if (!_showLottieMarker ||
        _lottieMarkerLat == null ||
        _lottieMarkerLng == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Offset?>(
      future: _getScreenPosition(_lottieMarkerLat!, _lottieMarkerLng!),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final pos = snap.data!;

        return Positioned(
          left: pos.dx - _markerSize / 2,
          top:  pos.dy - _markerSize,
          child: IgnorePointer(
            child: SizedBox(
              width: _markerSize,
              height: _markerSize,
              child: Lottie.network(
                'https://cdn.lottielab.com/l/7h3oieuvwUgm9B.json',
                controller: _lottieController,
                fit: BoxFit.contain,
                onLoaded: (c) => _lottieController
                  ..duration = c.duration
                  ..forward(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SaveRouteSheet extends StatefulWidget {
  final String initialValue;                // <-- seulement la valeur
  const SaveRouteSheet({required this.initialValue, super.key});

  @override
  State<SaveRouteSheet> createState() => _SaveRouteSheetState();
}

class _SaveRouteSheetState extends State<SaveRouteSheet> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctl.dispose();                         // <-- libéré au bon moment
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return ModalSheet(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Choisissez un nom",
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextPrimary,
              ),
            ),
            2.h,
            Text(
              "Vous pourrez le modifier ultérieurement",
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500
              ),
            ),
            20.h,
            AuthTextField(
              controller: _ctl,
              hint: 'Nom du parcours',
              maxLines: 1,
            ),
              
            40.h,
              
            SquircleContainer(
              width: double.infinity,
              onTap: () {
                final name = _ctl.text.trim();
                if (name.isEmpty) return;
                context.pop(name);
              }, // 🆕 Désactiver si loading
              padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
              radius: 40.0,
              color: context.adaptivePrimary, // 🆕 Style différent si loading
              child: Center(
                child: Text(
                  context.l10n.save,
                  style: context.bodySmall?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}