import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/helper/extensions/monitoring_extensions.dart';
import 'package:runaway/core/helper/services/conversion_triggers.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/features/account/presentation/screens/account_screen.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/historic/presentation/screens/historic_screen.dart';
import 'package:runaway/features/home/presentation/widgets/floating_location_search_sheet.dart';
import 'package:runaway/features/home/presentation/widgets/generation_limit_widget.dart';
import 'package:runaway/core/widgets/loading_overlay.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/home/presentation/widgets/floating_route_info_panel.dart';
import 'package:runaway/features/home/presentation/widgets/guest_generation_indicator.dart';
import 'package:runaway/features/home/presentation/widgets/offline_generation_capability.dart';
import 'package:runaway/features/home/presentation/widgets/save_route_sheet.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/presentation/blocs/extensions/route_generation_bloc_extensions.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:hugeicons/hugeicons.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:runaway/core/styles/colors.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/location_preload_service.dart';
import 'package:runaway/core/widgets/location_aware_map_widget.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/home/data/services/map_state_service.dart';
import 'package:runaway/features/home/domain/enums/tracking_mode.dart';
import 'package:runaway/features/home/domain/models/mapbox_style_constants.dart';
import 'package:runaway/features/home/presentation/widgets/export_format_dialog.dart';
import 'package:runaway/features/home/presentation/widgets/map_style_selector.dart';
import 'package:runaway/features/route_generator/data/services/route_export_service.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_event.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as su;
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../../route_generator/presentation/screens/route_parameter_screen.dart'
    as gen;
import '../blocs/route_parameters_event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  // 🆕 Service de persistance
  final MapStateService _mapStateService = MapStateService();
  late String _screenLoadId;

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
  // late Animation<double> _fadeAnimation;

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
  final LoadingOverlay _loading = LoadingOverlay();
  OverlayEntry? _routeInfoEntry;

  // 🆕 Variables pour le loading avec temps minimum 
  Timer? _loadingMinimumTimer;
  DateTime? _loadingStartTime;
  bool _isMinimumLoadingTimeElapsed = false;
  bool _isPendingRouteInfoDisplay = false;
  bool _isLoadingOverlayVisible = false;
  bool _isHistoricRouteActive = false;

  // 🆕 Temps minimum de loading (configurable)
  static const Duration _minimumLoadingDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🆕 Démarrer le tracking de chargement d'écran
    _screenLoadId = context.trackScreenLoad('home_screen');
    
    _initializeAnimationControllers();
    _restoreStateFromService();
    _restoreMapStyleFromService();
    _preloadLocationInBackground();
    _setupRouteGenerationListener();
    _initializeMapStyle();

    // 🆕 Marquer l'écran comme chargé après l'initialisation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.finishScreenLoad(_screenLoadId);
      
      // 🆕 Métrique d'engagement utilisateur
      context.recordMetric('screen_view', 1, unit: 'count');
    });
  }

  @override
  void dispose() {
    _saveStateToService();
    _fadeController.dispose();
    _positionStream?.cancel();
    _lottieController.dispose();
    // 🆕 Nettoyer le timer
    _loadingMinimumTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        LogConfig.logInfo('📱 App en arrière-plan');
        _saveStateToService(); // 💾 Sauvegarder lors de la mise en arrière-plan
        break;
      case AppLifecycleState.resumed:
        LogConfig.logInfo('📱 App au premier plan');
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

      LogConfig.logInfo('🎨 Style de carte initialisé: $_currentMapStyleId');
    } catch (e) {
      LogConfig.logError('❌ Erreur initialisation style: $e');
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

    // _fadeAnimation = Tween<double>(
    //   begin: 0.0,
    //   end: 1.0,
    // ).animate(CurvedAnimation(
    //   parent: _fadeController,
    //   curve: Curves.easeOut,
    // ));

    _fadeController.forward();

    _lottieController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  /// 🔄 Restaurer l'état depuis le service
  void _restoreStateFromService() {
    LogConfig.logInfo('🔄 Restauration de l\'état depuis le service...');

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

    print(
      '✅ État restauré: positions=${_userLatitude != null}, mode=$_trackingMode, route=${generatedRouteCoordinates != null}',
    );
  }

  /// 🆕 Pré-charge la géolocalisation en arrière-plan (sans démarrer le tracking)
  Future<void> _preloadLocationInBackground() async {
    try {
      print('🌍 Pré-chargement de la géolocalisation en arrière-plan...');
      final position =
          await LocationPreloadService.instance.initializeLocation();

      // Mettre à jour les variables locales
      _userLatitude = position.latitude;
      _userLongitude = position.longitude;

      // Si on n'a pas de position sélectionnée, utiliser la position utilisateur
      if (_selectedLatitude == null || _selectedLongitude == null) {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
      }

      LogConfig.logInfo('Géolocalisation pré-chargée en arrière-plan');
    } catch (e) {
      LogConfig.logInfo('Erreur pré-chargement géolocalisation: $e');
      // Continuer sans géolocalisation
    }
  }

  /// 💾 Sauvegarder l'état dans le service
  void _saveStateToService() {
    LogConfig.logInfo('💾 Sauvegarde de l\'état dans le service...');

    // Sauvegarder les positions
    if (_userLatitude != null && _userLongitude != null) {
      _mapStateService.saveUserPosition(_userLatitude!, _userLongitude!);
    }

    if (_selectedLatitude != null && _selectedLongitude != null) {
      _mapStateService.saveSelectedPosition(
        _selectedLatitude!,
        _selectedLongitude!,
      );
    }

    // Sauvegarder le style de carte
    _mapStateService.saveMapStyleId(_currentMapStyleId);

    // Sauvegarder le mode de tracking
    _mapStateService.saveTrackingMode(_trackingMode);

    // Sauvegarder le parcours
    _mapStateService.saveGeneratedRoute(
      generatedRouteCoordinates,
      routeMetadata,
      _hasAutoSaved,
    );

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

    LogConfig.logInfo('État sauvegardé dans le service');
  }

  // Configuration de l'écoute de génération
  void _setupRouteGenerationListener() {
    // Écouter les changements du bloc de génération
    context.routeGenerationBloc.stream.listen((state) {
      if (mounted) {
        _handleRouteGenerationStateChange(state);
      }
    });
  }

  Future<void> _startLocationTrackingWhenMapReady() async {
    try {
      // La carte est déjà prête car on vient de _onMapCreated
      if (mapboxMap == null) {
        LogConfig.logError('❌ Erreur: mapboxMap est null');
        return;
      }

      LogConfig.logInfo('🗺️ Démarrage du tracking de position...');

      const locationSettings = gl.LocationSettings(
        accuracy: gl.LocationAccuracy.high,
        distanceFilter: 1,
      );

      _positionStream = gl.Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onLocationUpdate,
        onError: (e) {
          LogConfig.logError('❌ Erreur stream position: $e');
        },
      );

      LogConfig.logInfo('Stream de position démarré');
    } catch (e) {
      LogConfig.logError('❌ Erreur démarrage tracking: $e');
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

    // 💾 Sauvegarder toujours la position utilisateur dans le service
    _mapStateService.saveUserPosition(newLat, newLng);

    // Mettre à jour la position sélectionnée si on est en mode user tracking
    if (_trackingMode == TrackingMode.userTracking && !_isHistoricRouteActive) {
      setState(() {
        _selectedLatitude = newLat;
        _selectedLongitude = newLng;
      });

      // 💾 Sauvegarder aussi la position sélectionnée
      _mapStateService.saveSelectedPosition(newLat, newLng);

      // Centrer la caméra sur la nouvelle position
      _centerOnUserLocation(animate: false);

      // 🔧 CORRECTION : Ne mettre à jour le BLoC QUE en mode userTracking
      if (mounted) {
        context.routeParametersBloc.add(
          StartLocationUpdated(longitude: newLng, latitude: newLat),
        );
      }
    }
    // 🚫 En mode manual ou searchSelected, on ne touche PAS au BLoC !
  }

  // Gestion des changements d'état
  void _handleRouteGenerationStateChange(RouteGenerationState state) async {
    // Cas 1: Historique
    if (state.hasGeneratedRoute && state.isLoadedFromHistory) {
      setState(() {
        generatedRouteCoordinates = state.generatedRoute;
        routeMetadata = state.routeMetadata;
      });
      _mapStateService.saveGeneratedRoute(
        state.generatedRoute,
        state.routeMetadata,
        _hasAutoSaved,
      );
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
      _mapStateService.saveGeneratedRoute(
        state.generatedRoute,
        state.routeMetadata,
        _hasAutoSaved,
      );
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
    if (generatedRouteCoordinates != null &&
        generatedRouteCoordinates!.isNotEmpty) {
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
        prev[1],
        prev[0], // lat, lon précédent
        current[1],
        current[0], // lat, lon actuel
      );

      totalDistance += distance;
    }

    return totalDistance; // Retourner en kilomètres
  }

  // Formule de Haversine pour calculer la distance entre deux points GPS
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371; // Rayon de la Terre en kilomètres

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

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
      LogConfig.logInfo('Dialogue de sauvegarde déjà ouvert');
      return;
    }

    // Vérifier qu'un parcours est généré
    if (generatedRouteCoordinates == null || routeMetadata == null) {
      showTopSnackBar(
        overlay,
        TopSnackBar(title: context.l10n.emptyRouteForSave),
      );
      return;
    }

    // Vérifier si déjà en cours de sauvegarde
    if (_isSavingRoute) {
      showTopSnackBar(overlay, TopSnackBar(title: context.l10n.saving));
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
      LogConfig.logError('❌ Erreur vérification auth: $e');
      showTopSnackBar(
        overlay,
        TopSnackBar(isError: true, title: context.l10n.connectionError),
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
      context,
      context.routeParametersBloc.state.parameters,
      _getGeneratedRouteDistance(),
    );

    final routeName = await _presentModalSheet<String>(
      (_) => SaveRouteSheet(initialValue: defaultName),
    );

    _isSaveDialogOpen = false;

    if (!mounted || routeName == null || routeName.isEmpty) return;
    _performSaveRoute(routeName);
  }

  /// 🆕 Exécution de la sauvegarde
  void _performSaveRoute(String routeName) async {
    final overlay = Overlay.of(context, rootOverlay: true);

    // Vérifications finales
    if (mapboxMap == null) {
      showTopSnackBar(
        overlay,
        TopSnackBar(isError: true, title: context.l10n.notAvailableMap),
      );
      return;
    }

    if (generatedRouteCoordinates == null || routeMetadata == null) {
      showTopSnackBar(
        overlay,
        TopSnackBar(isError: true, title: context.l10n.emptyRouteForSave),
      );
      return;
    }

    // Récupérer les paramètres utilisés
    final routeState = context.routeGenerationBloc.state;
    if (routeState.usedParameters == null) {
      showTopSnackBar(
        overlay,
        TopSnackBar(isError: true, title: context.l10n.missingRouteSettings),
      );
      return;
    }

    // 🔥 UTILISER AppDataBloc AU LIEU DE RouteGenerationBloc
    context.appDataBloc.add(
      SavedRouteAddedToAppData(
        name: routeName,
        parameters: routeState.usedParameters!,
        coordinates: generatedRouteCoordinates!,
        actualDistance: _getGeneratedRouteDistance(),
        estimatedDuration: routeMetadata!['durationMinutes'] as int?,
        map: mapboxMap!,
      ),
    );

    LogConfig.logInfo('🚀 Sauvegarde via AppDataBloc démarrée: $routeName');

    // Afficher feedback immédiat
    showTopSnackBar(overlay, TopSnackBar(title: context.l10n.savedRoute));

    // 🆕 ACTIONS POST-SAUVEGARDE : fermer le panel et nettoyer le parcours
    // Attendre un petit délai pour que la sauvegarde se lance
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Vérifier que le widget est toujours monté
    if (!mounted) return;
    
    // 1. Fermer le RouteInfoPanel en premier
    _removeRouteInfoPanel();
    
    // 2. Attendre un petit délai pour éviter les conflits d'état
    await Future.delayed(const Duration(milliseconds: 50));
    
    // 3. Nettoyer le parcours actif si le widget est toujours monté
    if (mounted) {
      await _clearGeneratedRoute();
    }
  }

  /// 🆕 Dialogue pour demander la connexion
  void _showLoginRequiredDialog() {
    _presentModalSheet<void>(
      (_) => ModalDialog(
        title: context.l10n.loginRequiredTitle,
        subtitle: context.l10n.loginRequiredDesc,
        validLabel: context.l10n.logIn,
        onValid: () {
          HapticFeedback.mediumImpact();
          showSignModal(context, 1);
        },
      ),
    );
  }

  // Fonction onClear pour supprimer le parcours et revenir à l'état précédent
  Future<void> _clearGeneratedRoute() async {
    // Sauvegarder les positions avant nettoyage
    final double? lastSelectedLat = _selectedLatitude;
    final double? lastSelectedLng = _selectedLongitude;

    // Réinitialiser le flag de parcours historique
    _isHistoricRouteActive = false;

    // 1. Supprimer la route de la carte
    if (routeLineManager != null && mapboxMap != null) {
      try {
        await routeLineManager!.deleteAll();
        await mapboxMap!.annotations.removeAnnotationManager(routeLineManager!);
        routeLineManager = null;
        LogConfig.logInfo('Route supprimée de la carte');
      } catch (e) {
        LogConfig.logError('❌ Erreur lors de la suppression de la route: $e');
      }
    }

    // 2. Réinitialiser l'état du bloc
    if (mounted) {
      context.routeGenerationBloc.add(const RouteStateReset());
      LogConfig.logInfo('État du bloc RouteGeneration reseté');
    }

    // 3. Réinitialiser les variables locales du parcours
    setState(() {
      generatedRouteCoordinates = null;
      routeMetadata = null;
      _hasAutoSaved = false;
    });

    // 4. 🆕 DÉTECTION INTELLIGENTE DU MODE À RESTAURER
    final bool shouldRestoreToUserTracking = _shouldRestoreToUserTracking(
      lastSelectedLat,
      lastSelectedLng,
    );

    // 5. Appliquer le mode et les actions appropriées
    if (shouldRestoreToUserTracking) {
      await _restoreToUserTrackingMode();
    } else {
      await _restoreToManualMode(lastSelectedLat, lastSelectedLng);
    }

    // 7. Sauvegarder l'état final
    _mapStateService.saveTrackingMode(_trackingMode);
    _mapStateService.saveGeneratedRoute(null, null, false);
  }

  /// 🆕 Détermine intelligemment si on doit restaurer vers UserTracking
  bool _shouldRestoreToUserTracking(
    double? lastSelectedLat,
    double? lastSelectedLng,
  ) {
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
    if (_trackingMode == TrackingMode.userTracking &&
        !_showLottieMarker &&
        locationMarkers.isEmpty) {
      return true;
    }

    // Sinon → Conserver mode Manual/SearchSelected
    return false;
  }

  Future<void> _clearRouteOnUserTrackingActivation() async {
    // Vérifier s'il y a un parcours à nettoyer
    if (generatedRouteCoordinates != null && routeMetadata != null) {
      LogConfig.logInfo('🧹 Nettoyage parcours lors activation suivi utilisateur');
      
      // 1. Supprimer la route de la carte
      if (routeLineManager != null && mapboxMap != null) {
        try {
          await routeLineManager!.deleteAll();
          await mapboxMap!.annotations.removeAnnotationManager(routeLineManager!);
          routeLineManager = null;
        } catch (e) {
          LogConfig.logError('❌ Erreur suppression route: $e');
        }
      }

      // 2. Réinitialiser l'état du bloc
      if (mounted) {
        context.routeGenerationBloc.add(const RouteStateReset());
      }

      // 3. Réinitialiser les variables locales
      setState(() {
        generatedRouteCoordinates = null;
        routeMetadata = null;
        _hasAutoSaved = false;
      });

      // 4. Fermer le RouteInfoCard s'il est ouvert
      _removeRouteInfoPanel();

      // 5. Sauvegarder l'état nettoyé
      _mapStateService.saveGeneratedRoute(null, null, false);
      
      LogConfig.logInfo('✅ Parcours nettoyé lors activation suivi utilisateur');
    }
  }

  /// 🎯 Restaure vers le mode UserTracking (supprime markers, focus user)
  Future<void> _restoreToUserTrackingMode() async {
    print('🎯 === RESTAURATION MODE USER TRACKING ===');

    // 🆕 AJOUT : Nettoyer le parcours existant avant de changer le mode
    await _clearRouteOnUserTrackingActivation();

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
            coordinates: mp.Position(_userLongitude!, _userLatitude!),
          ),
          zoom: 12,
        ),
        mp.MapAnimationOptions(duration: 1200),
      );
      LogConfig.logInfo('📍 FlyTo position utilisateur: $_userLatitude, $_userLongitude');
    }

    // 4. Sauvegarder l'état
    _mapStateService.saveSelectedPosition(
      _userLatitude ?? 0,
      _userLongitude ?? 0,
    );
    _mapStateService.saveMarkerState(false, null, null);

    LogConfig.logInfo('Mode UserTracking restauré');
  }

  /// 📍 Restaure vers le mode Manual (conserve markers, focus marker)
  Future<void> _restoreToManualMode(
    double? lastSelectedLat,
    double? lastSelectedLng,
  ) async {
    LogConfig.logInfo('📍 === RESTAURATION MODE MANUAL ===');

    if (lastSelectedLat == null || lastSelectedLng == null) {
      LogConfig.logError('❌ Pas de position à restaurer, fallback UserTracking');
      await _restoreToUserTrackingMode();
      return;
    }

    // 1. Changer le mode (garder le mode actuel s'il est déjà manual/searchSelected)
    setState(() {
      if (_trackingMode == TrackingMode.userTracking) {
        _trackingMode =
            TrackingMode
                .manual; // Passer en manual si on était en user tracking
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
            coordinates: mp.Position(lastSelectedLng, lastSelectedLat),
          ),
          zoom: 12,
        ),
        mp.MapAnimationOptions(duration: 1200),
      );
      LogConfig.logInfo('📍 FlyTo marker: $lastSelectedLat, $lastSelectedLng');
    }

    // 4. Sauvegarder l'état avec marker
    _mapStateService.saveSelectedPosition(lastSelectedLat, lastSelectedLng);
    _mapStateService.saveMarkerState(true, lastSelectedLat, lastSelectedLng);

    LogConfig.logInfo('Mode Manual restauré avec marker');
  }

  /// 🆕 S'assure qu'un marker est présent à la position donnée
  Future<void> _ensureMarkerAtPosition(
    double longitude,
    double latitude,
  ) async {
    LogConfig.logInfo('🔍 Vérification marker à: $latitude, $longitude');

    // Si on a déjà un marker Lottie à cette position, c'est bon
    if (_showLottieMarker &&
        _lottieMarkerLat != null &&
        _lottieMarkerLng != null &&
        (_lottieMarkerLat! - latitude).abs() < 0.0001 &&
        (_lottieMarkerLng! - longitude).abs() < 0.0001) {
      LogConfig.logInfo('Marker Lottie déjà présent à la bonne position');
      return;
    }

    // Si on a des markers classiques à peu près à cette position
    bool hasNearbyMarker = false;
    if (locationMarkers.isNotEmpty) {
      // Pour simplifier, on considère qu'on a un marker s'il y en a
      hasNearbyMarker = true;
    }

    if (!hasNearbyMarker && !_showLottieMarker) {
      LogConfig.logInfo('📍 Création marker manquant');
      await _placeMarkerWithLottie(longitude, latitude);
    } else {
      LogConfig.logInfo('Marker présent (classique ou Lottie)');
    }
  }

  // Affichage de la route sur la carte
  Future<void> _displayRouteOnMap(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) return;

    try {
      print('🎬 Début animation d\'affichage de route...');

      // // ÉTAPE 2 : Afficher progressivement le tracé
      await _drawRouteProgressively(coordinates);

      // ÉTAPE 3 : Animation finale pour montrer toute la route
      await _animateToFullRoute(coordinates);

      LogConfig.logInfo('Animation d\'affichage terminée');
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de l\'affichage animé de la route: $e');
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
    LogConfig.logInfo('🎨 _drawRouteSimple: ${coordinates.length} coordonnées');

    if (coordinates.isEmpty) {
      LogConfig.logError('❌ Aucune coordonnée à afficher');
      return;
    }

    try {
      // Convertir les coordonnées
      final lineCoordinates =
          coordinates.map((coord) => mp.Position(coord[0], coord[1])).toList();

      // Créer une ligne simple et visible
      final routeLine = mp.PolylineAnnotationOptions(
        geometry: mp.LineString(coordinates: lineCoordinates),
        lineColor: AppColors.primary.toARGB32(), // Rouge vif pour le debug
        lineWidth: 5.0,
        lineOpacity: 1.0,
        lineJoin: mp.LineJoin.MITER,
      );

      await routeLineManager!.create(routeLine);
      LogConfig.logInfo('Route simple créée (rouge, 8px, opacité 1.0)');
    } catch (e) {
      LogConfig.logError('❌ Erreur _drawRouteSimple: $e');
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
      southwest: mp.Point(
        coordinates: mp.Position(minLon - margin, minLat - margin),
      ),
      northeast: mp.Point(
        coordinates: mp.Position(maxLon + margin, maxLat + margin),
      ),
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
    routeLineManager =
        await mapboxMap!.annotations.createPolylineAnnotationManager();

    // Convertir les coordonnées pour Mapbox
    final lineCoordinates =
        coordinates.map((coord) => mp.Position(coord[0], coord[1])).toList();

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
        southwest: mp.Point(
          coordinates: mp.Position(minLon - margin, minLat - margin),
        ),
        northeast: mp.Point(
          coordinates: mp.Position(maxLon + margin, maxLat + margin),
        ),
        infiniteBounds: false,
      );

      final camera = await mapboxMap!.cameraForCoordinateBounds(
        bounds,
        mp.MbxEdgeInsets(top: 100, left: 50, bottom: 200, right: 50),
        null,
        null,
        null,
        null,
      );

      // Utiliser flyTo au lieu de setCamera
      await mapboxMap!.flyTo(camera, mp.MapAnimationOptions(duration: 1500));
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de l\'ajustement smooth de la vue: $e');
    }
  }

  // Affichage des erreurs
  void _showRouteGenerationError(String error) {
    if (!mounted) return;

    showTopSnackBar(
      Overlay.of(context),
      TopSnackBar(isError: true, title: error),
    );
  }

  // === GESTION DES POSITIONS ===

  Future<void> _ensureCustomMarkerImage() async {
    if (mapboxMap == null) return;
    if (await mapboxMap!.style.hasStyleImage('custom-pin')) return;

    final bytes = await rootBundle.load('assets/img/pin.png');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final img = frame.image;

    await mapboxMap!.style.addStyleImage(
      'custom-pin',
      1.0,
      mp.MbxImage(
        width: img.width,
        height: img.height,
        data: bytes.buffer.asUint8List(),
      ),
      false,
      /* sdf ? */ [],
      [],
      null,
    );
  }

  Future<void> _placeMarkerWithLottie(double lon, double lat) async {
    if (mapboxMap == null) return;

    try {
      LogConfig.logInfo('🎯 Placement du marqueur Lottie à: ($lat, $lon)');

      // Retour haptique immédiat
      HapticFeedback.mediumImpact();

      // 1️⃣ Positionner / lancer l'animation Lottie (overlay)
      setState(() {
        _showLottieMarker = true;
        _lottieMarkerLng = lon;
        _lottieMarkerLat = lat;
      });

      LogConfig.logInfo('Lottie affiché à: ($lat, $lon)');

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
      markerPointManager ??=
          await mapboxMap!.annotations.createPointAnnotationManager();

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

      LogConfig.logInfo('Marqueur personnalisé ajouté et Lottie masqué');
    } catch (e) {
      LogConfig.logError('❌ Erreur ajout marqueur personnalisé: $e');

      // Fallback: utiliser l'icône par défaut de Mapbox
      try {
        markerPointManager ??=
            await mapboxMap!.annotations.createPointAnnotationManager();
        final marker = await markerPointManager!.create(
          mp.PointAnnotationOptions(
            geometry: mp.Point(coordinates: mp.Position(lon, lat)),
            iconSize: 1.0,
          ),
        );
        locationMarkers.add(marker);
        LogConfig.logInfo('Marqueur par défaut ajouté en fallback');
      } catch (fallbackError) {
        LogConfig.logError('❌ Erreur fallback marqueur: $fallbackError');
      }
    }
  }

  Future<void> _clearLocationMarkers() async {
    LogConfig.logInfo('🧹 Nettoyage des marqueurs...');

    // 1️⃣ Masquer le marqueur Lottie
    if (_showLottieMarker) {
      setState(() {
        _showLottieMarker = false;
        _lottieMarkerLat = null;
        _lottieMarkerLng = null;
      });
      LogConfig.logInfo('Lottie marqueur masqué');
    }

    // 2️⃣ Supprimer les PointAnnotations
    try {
      if (markerPointManager != null) {
        await markerPointManager!.deleteAll();
        locationMarkers.clear();
        LogConfig.logInfo('PointAnnotations supprimés');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur suppression PointAnnotations: $e');
    }

    // 3️⃣ Supprimer les cercles (si utilisés)
    try {
      if (circleAnnotationManager != null) {
        await circleAnnotationManager!.deleteAll();
        LogConfig.logInfo('CircleAnnotations supprimés');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur suppression CircleAnnotations: $e');
    }

    // 💾 Sauvegarder l'absence de marqueurs
    _mapStateService.saveMarkerState(false, null, null);

    LogConfig.logInfo('Nettoyage des marqueurs terminé');
  }

  Future<Offset?> _getScreenPosition(double lat, double lng) async {
    if (mapboxMap == null) return null;

    try {
      final point = mp.Point(coordinates: mp.Position(lng, lat));
      final screenCoordinate = await mapboxMap!.pixelForCoordinate(point);
      return Offset(screenCoordinate.x, screenCoordinate.y);
    } catch (e) {
      LogConfig.logError('❌ Erreur conversion coordonnées: $e');
      return null;
    }
  }

  // === ACTIONS UTILISATEUR ===
  // 🆕 Méthode pour tracker les actions utilisateur importantes
  void _trackUserAction(String action, {Map<String, dynamic>? data}) {
    try {
      MonitoringService.instance.recordMetric(
        'user_action',
        1,
        tags: {
          'screen': 'home',
          'action': action,
          'tracking_mode': _trackingMode.toString(),
          ...?data,
        },
      );
    } catch (e) {
      print('Erreur tracking action: $e');
    }
  }

  /// Active le mode suivi utilisateur
  void _activateUserTracking() async {
    // Vérifier qu'on a une position GPS
    if (_userLatitude == null || _userLongitude == null) {
      LogConfig.logInfo('❌ Position utilisateur non disponible pour le tracking');
      return;
    }

    bool? shouldContinue = true;

    if (generatedRouteCoordinates != null) {
      shouldContinue = await _presentModalSheet<bool>((_) {
        return ModalDialog(
          title: context.l10n.reallyContinueTitle,
          subtitle: context.l10n.reallyContinueDesc,
          validLabel: context.l10n.continueForms,
          cancelLabel: context.l10n.cancel,
          onValid: () => context.pop(true),
          onCancel: () => context.pop(false),
        );
      });

      // L’utilisateur annule ou ferme la feuille : on arrête tout
      if (shouldContinue != true) return;

      // 🔐 Ajoute ça AVANT de remettre l’état à zéro
      _dismissRouteInfoModal();
    }

    // Nettoyer le parcours existant
    await _clearRouteOnUserTrackingActivation();

    setState(() {
      _trackingMode = TrackingMode.userTracking;
      // Réinitialiser le flag de parcours historique
      _isHistoricRouteActive = false;
      // Synchroniser immédiatement avec la position GPS
      _selectedLatitude = _userLatitude!;
      _selectedLongitude = _userLongitude!;
    });

    // 💾 Sauvegarder le mode et la position
    _mapStateService.saveTrackingMode(_trackingMode);
    _mapStateService.saveSelectedPosition(_userLatitude!, _userLongitude!);

    // Mettre à jour le bloc avec la position GPS actuelle
    if (mounted) {
      context.routeParametersBloc.add(
        StartLocationUpdated(
          longitude: _userLongitude!,
          latitude: _userLatitude!,
        ),
      );
    }

    // Centrer la caméra
    _centerOnUserLocation(animate: true);

    // Nettoyer les marqueurs car on suit la position en temps réel
    _clearLocationMarkers();
    setState(() {
      _showLottieMarker = false;
      _lottieMarkerLat = null;
      _lottieMarkerLng = null;
    });

    LogConfig.logSuccess(
      '✅ Mode UserTracking activé avec position GPS: $_userLatitude, $_userLongitude',
    );
  }

  // 🔧 MÉTHODE FALLBACK : En cas d'erreur, utiliser la position utilisateur
  Future<void> _setManualPositionFallback(
    double longitude,
    double latitude,
  ) async {
    LogConfig.logInfo('Fallback: Position manuelle à la position utilisateur');

    setState(() {
      _trackingMode = TrackingMode.manual;
      _selectedLatitude = latitude;
      _selectedLongitude = longitude;
    });

    await _clearLocationMarkers();
    await _placeMarkerWithLottie(longitude, latitude);

    if (mounted) {
      context.routeParametersBloc.add(
        StartLocationUpdated(longitude: longitude, latitude: latitude),
      );
    }
  }

  Map<String, double> getGenerationPosition() {
    // En priorité, utiliser la position sélectionnée
    if (_selectedLatitude != null && _selectedLongitude != null) {
      LogConfig.logInfo(
        '🎯 Position génération: sélectionnée ($_selectedLatitude, $_selectedLongitude)',
      );
      return {'latitude': _selectedLatitude!, 'longitude': _selectedLongitude!};
    }

    // Fallback sur la position utilisateur
    if (_userLatitude != null && _userLongitude != null) {
      LogConfig.logInfo(
        '🎯 Position génération: fallback utilisateur ($_userLatitude, $_userLongitude)',
      );
      return {'latitude': _userLatitude!, 'longitude': _userLongitude!};
    }

    // Erreur : aucune position disponible
    throw Exception(context.l10n.generationEmptyLocation);
  }

  /// Sélection via recherche d'adresse
  Future<void> _onLocationSelected(
    double longitude,
    double latitude,
    String placeName,
  ) async {
    LogConfig.logInfo('🔍 === POSITION SÉLECTIONNÉE VIA RECHERCHE ===');
    LogConfig.logInfo('🔍 Lieu: $placeName ($latitude, $longitude)');

    _trackUserAction('location_selected', data: {
      'latitude': latitude,
      'longitude': longitude,
      'is_user_location': latitude == _userLatitude && longitude == _userLongitude,
    });

    // Nettoyer parcours existant
    if (generatedRouteCoordinates != null) {
      LogConfig.logInfo('🧹 Nettoyage du parcours existant avant nouvelle recherche');

      if (routeLineManager != null && mapboxMap != null) {
        try {
          await routeLineManager!.deleteAll();
          await mapboxMap!.annotations.removeAnnotationManager(
            routeLineManager!,
          );
          routeLineManager = null;
        } catch (e) {
          LogConfig.logError('❌ Erreur suppression route: $e');
        }
      }

      if (mounted) {
        context.routeGenerationBloc.add(const RouteStateReset());
      }

      setState(() {
        generatedRouteCoordinates = null;
        routeMetadata = null;
        _hasAutoSaved = false;
      });

      // 💾 Nettoyer dans le service
      _mapStateService.clearMarkersAndRoute();
    }

    // 🔧 CORRECTION : Mettre à jour la position ET le mode SearchSelected
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
          zoom: 12,
        ),
        mp.MapAnimationOptions(duration: 1200),
      );
    }

    // 🔧 CORRECTION : Mettre à jour le BLoC avec la position recherchée
    if (mounted) {
      context.routeParametersBloc.add(
        StartLocationUpdated(longitude: longitude, latitude: latitude),
      );
    }

    LogConfig.logInfo('Position via recherche définie: $placeName');
  }

  // === GESTION DE LA CARTE ===
  Future<void> _onMapCreated(mp.MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    LogConfig.logInfo('🗺️ === CARTE CRÉÉE - POSITION DÉJÀ DÉFINIE ===');
    LogConfig.logInfo('🗺️ Première initialisation: ${!_mapStateService.isMapInitialized}');

    // Configuration de base
    await _setupMapboxSettings();
    await _setupLongTapInteraction();
    await _setupMapMoveListener();

    // 🔄 Gestion intelligente de l'initialisation
    if (!_mapStateService.isMapInitialized) {
      // === PREMIÈRE INITIALISATION ===
      LogConfig.logInfo('🆕 Première initialisation de la carte');
      await _performInitialSetup();
      _mapStateService.markMapAsInitialized();
    } else {
      // === RETOUR SUR LA PAGE ===
      LogConfig.logInfo('🔄 Retour sur la page - restauration de l\'état');
      await _restoreMapState();
    }
  }

  /// 🆕 Configuration initiale (première fois)
  Future<void> _performInitialSetup() async {
    LogConfig.logInfo('🆕 Configuration initiale de la carte');

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

    LogConfig.logInfo('Configuration initiale terminée');
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
        _mapStateService.saveUserPosition(
          position.latitude,
          position.longitude,
        );
        _mapStateService.saveSelectedPosition(
          position.latitude,
          position.longitude,
        );

        LogConfig.logSuccess(
          '✅ Position synchronisée: ${position.latitude}, ${position.longitude}',
        );
      }
    } catch (e) {
      LogConfig.logInfo('Erreur synchronisation position: $e');
    }
  }

  /// 🔄 Restauration de l'état (retour)
  Future<void> _restoreMapState() async {
    LogConfig.logInfo('🔄 Restauration de l\'état de la carte');

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

    LogConfig.logInfo('État de la carte restauré');
  }

  /// 🎯 Centrer sur la position utilisateur
  Future<void> _centerOnUserLocation({required bool animate}) async {
    if (mapboxMap == null || _userLatitude == null || _userLongitude == null) return;

    try {
      final cameraOptions = mp.CameraOptions(
        center: mp.Point(
          coordinates: mp.Position(_userLongitude!, _userLatitude!),
        ),
        zoom: 12,
        pitch: 0,
        bearing: 0,
      );

      if (animate) {
        await mapboxMap!.flyTo(
          cameraOptions,
          mp.MapAnimationOptions(duration: 1500),
        );
        LogConfig.logSuccess('🎬 Centrage animé sur position utilisateur');
      } else {
        await mapboxMap!.setCamera(cameraOptions);
        LogConfig.logSuccess('📷 Centrage instantané sur position utilisateur');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur centrage position utilisateur: $e');
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
      pointAnnotationManager =
          await mapboxMap!.annotations.createPointAnnotationManager();
      circleAnnotationManager =
          await mapboxMap!.annotations.createCircleAnnotationManager();
      markerPointManager =
          await mapboxMap!.annotations.createPointAnnotationManager();

      // Masquer les éléments d'interface
      await mapboxMap!.compass.updateSettings(
        mp.CompassSettings(enabled: false),
      );
      await mapboxMap!.attribution.updateSettings(
        mp.AttributionSettings(enabled: false),
      );
      await mapboxMap!.logo.updateSettings(mp.LogoSettings(enabled: false));
      await mapboxMap!.scaleBar.updateSettings(
        mp.ScaleBarSettings(enabled: false),
      );

      LogConfig.logSuccess('⚙️ Paramètres Mapbox configurés');
    } catch (e) {
      LogConfig.logError('❌ Erreur configuration Mapbox: $e');
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

    LogConfig.logInfo('🤏 Listener de déplacement configuré');
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

          LogConfig.logSuccess('🔗 LongTap détecté à: ($latitude, $longitude)');

          // Activer le mode manuel à cette position
          _activateManualSelectionAtPosition(longitude, latitude);
        },
        stopPropagation: true, // Arrêter la propagation de l'événement
      );

      // Ajouter l'interaction à la carte (sans cibler de layer spécifique)
      mapboxMap!.addInteraction(longTapInteraction!);

      LogConfig.logInfo('LongTapInteraction configurée sur la carte');
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de la configuration LongTapInteraction: $e');
    }
  }

  void _dismissRouteInfoModal() {
    _routeInfoEntry?.remove();
    _routeInfoEntry = null;
  }

  Future<void> _activateManualSelectionAtPosition(
    double longitude,
    double latitude,
  ) async {
    if (mapboxMap == null) {
      LogConfig.logError('❌ Carte non initialisée pour sélection manuelle');
      return;
    }

    try {
      LogConfig.logInfo('📍 === POSITIONNEMENT MANUEL VIA LONGTAP ===');
      LogConfig.logInfo('📍 Position: ($latitude, $longitude)');

      // Nettoyer parcours existant
      if (generatedRouteCoordinates != null) {
        final bool? shouldContinue = await _presentModalSheet<bool>((_) {
          return ModalDialog(
            title: context.l10n.reallyContinueTitle,
            subtitle: context.l10n.reallyContinueDesc,
            validLabel: context.l10n.continueForms,
            cancelLabel: context.l10n.cancel,
            onValid: () => context.pop(true),
            onCancel: () => context.pop(false),
          );
        });

        // L’utilisateur annule ou ferme la feuille : on arrête tout
        if (shouldContinue != true) return;

        // 🔐 Ajoute ça AVANT de remettre l’état à zéro
        _dismissRouteInfoModal();

        // L’utilisateur confirme : on nettoie l’ancien parcours
        LogConfig.logInfo('🧹 Nettoyage du parcours existant');

        if (routeLineManager != null && mapboxMap != null) {
          try {
            await routeLineManager!.deleteAll();
            await mapboxMap!.annotations.removeAnnotationManager(
              routeLineManager!,
            );
            routeLineManager = null;
          } catch (e) {
            LogConfig.logError('❌ Erreur suppression route: $e');
          }
        }

        if (mounted) {
          context.routeGenerationBloc.add(const RouteStateReset());
        }

        setState(() {
          generatedRouteCoordinates = null;
          routeMetadata = null;
          _hasAutoSaved = false;
        });

        // 💾 Nettoyer dans le service
        _mapStateService.clearMarkersAndRoute();
      }

      // 🔧 CORRECTION : Mettre à jour la position ET le mode
      setState(() {
        _trackingMode = TrackingMode.manual;
        _selectedLatitude = latitude;
        _selectedLongitude = longitude;
      });

      // 💾 Sauvegarder le nouveau mode et position
      _mapStateService
      ..saveTrackingMode(_trackingMode)
      ..saveSelectedPosition(latitude, longitude);

      // Placer le marqueur avec transition fluide
      await _clearLocationMarkers();
      await _placeMarkerWithLottie(longitude, latitude);

      // Centrer la caméra
      if (mapboxMap != null) {
        await mapboxMap!.flyTo(
          mp.CameraOptions(
            center: mp.Point(coordinates: mp.Position(longitude, latitude)),
            zoom: 12,
          ),
          mp.MapAnimationOptions(duration: 1000),
        );
      }

      // 🔧 CORRECTION : Mettre à jour le BLoC avec la position manuelle
      if (mounted) {
        context.routeParametersBloc.add(
          StartLocationUpdated(longitude: longitude, latitude: latitude),
        );
      }

      LogConfig.logInfo('Position manuelle définie avec sauvegarde d\'état');
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de l\'activation manuelle: $e');

      if (_userLatitude != null && _userLongitude != null) {
        await _setManualPositionFallback(_userLongitude!, _userLatitude!);
      }
    }
  }

  /// 🎨 Changement de style de carte
  Future<void> _onMapStyleSelected(String styleId) async {
    if (styleId == _currentMapStyleId || mapboxMap == null) return;

    try {
      LogConfig.logInfo('🎨 Changement de style vers: $styleId');

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

      LogConfig.logInfo('Style de carte mis à jour: ${newStyle.name}');
    } catch (e) {
      LogConfig.logError('❌ Erreur changement de style: $e');
    }
  }

  /// 🔄 Restaurer le style depuis le service
  void _restoreMapStyleFromService() {
    _currentMapStyleId = _mapStateService.selectedMapStyleId;
    LogConfig.logInfo('🎨 Style restauré depuis le service: $_currentMapStyleId');
  }

  // === INTERFACE UTILISATEUR ===
  void _openMapStyleSelector() {
    _presentModalSheet<String>(
      (_) => MapStyleSelector(
        currentStyleId: _currentMapStyleId,
        onStyleSelected: _onMapStyleSelected,
      ),
    );
  }

  void openGenerator() {
    _trackUserAction('open_generator', data: {
      'has_location': _selectedLatitude != null && _selectedLongitude != null,
      'tracking_mode': _trackingMode.toString(),
    });

    _presentModalSheet<String>(
      (_) => BlocProvider.value(
        value: context.routeParametersBloc,
        child: BlocProvider.value(
          value: context.routeGenerationBloc,
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
  void _handleGenerateRoute() async {
    final operationId = MonitoringService.instance.trackOperation(
      'route_generation_from_home',
      description: 'Génération de parcours depuis l\'écran principal',
      data: {
        'selected_lat': _selectedLatitude,
        'selected_lng': _selectedLongitude,
        'tracking_mode': _trackingMode.toString(),
      },
    );

    try {
      // Déterminer le type d'utilisateur
      final authState = context.authBloc.state;
      final isGuest =
          authState is! Authenticated ||
          su.Supabase.instance.client.auth.currentUser == null;

      LogConfig.logInfo('👤 Mode: ${isGuest ? "Guest" : "Authentifié"}');

      if (isGuest) {
        // Logique guest existante (inchangée)
        final capability = await context.routeGenerationBloc
            .checkGenerationCapability(context.authBloc);

        if (!capability.canGenerate) {
          showLimitCapability(
            capability,
          ); // Cette modal est adaptée pour les guests
          return;
        }

        if (mounted) {
          final consumed = await context.routeGenerationBloc.consumeGeneration(
            context.authBloc,
          );
          if (!consumed && mounted) {
            _showRouteGenerationError(context.l10n.unableLaunchGeneration);
            return;
          }
        }
      } else {
        // 🆕 Logique pour utilisateurs authentifiés avec UI adaptée
        final creditResult = await context.creditService
            .verifyCreditsForGeneration(requiredCredits: 1);

        if (!creditResult.isValid) {
          LogConfig.logError('❌ Crédits insuffisants pour utilisateur authentifié');

          // Utiliser la nouvelle UI spécialement conçue pour les utilisateurs connectés
          _showInsufficientCreditsBottomSheet(
            availableCredits: creditResult.availableCredits,
            requiredCredits: creditResult.requiredCredits,
          );
          return;
        }
      }

      // Continuer avec la génération...
      setState(() {
        _hasAutoSaved = false;
      });

      if (mounted) {
        final parametersState = context.routeParametersBloc.state;
        final parameters = parametersState.parameters;

        if (!parameters.isValid) {
          _showRouteGenerationError(context.l10n.invalidParameters);
          return;
        }

        context.routeGenerationBloc.add(
          RouteGenerationRequested(
            parameters,
            mapboxMap: mapboxMap,
            bypassCreditCheck: isGuest,
          ),
        );

        ConversionTriggers.onRouteGenerated(context);
        LogConfig.logInfo('🚀 Génération lancée avec succès');

        MonitoringService.instance.finishOperation(operationId, success: true);
        _trackUserAction('route_generated');
      }
    } catch (e, stackTrace) {
      LogConfig.logError('❌ Erreur génération: $e');
      _showRouteGenerationError('Erreur: $e');
      if (mounted) {
        context.captureError(e, stackTrace, extra: {
          'operation': 'route_generation',
          'selected_location': {'lat': _selectedLatitude, 'lng': _selectedLongitude},
        });
      }
      
      MonitoringService.instance.finishOperation(
        operationId, 
        success: false, 
        errorMessage: e.toString(),
      );
    }
  }

  void _showInsufficientCreditsBottomSheet({
    required int availableCredits,
    required int requiredCredits,
  }) {
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: ModalDialog(
        title: context.l10n.insufficientCreditsTitle,
        subtitle: context.l10n.insufficientCreditsDescription(requiredCredits, context.l10n.generateRoute.toLowerCase(), availableCredits),
        validLabel: context.l10n.buyCredits,
        cancelLabel:context.l10n.later,
        onValid: () {
          context.pop();
          context.push('/manage-credits');
        },
      ),
    );
  }

  void _showExportDialog() {
    if (generatedRouteCoordinates == null || routeMetadata == null) {
      showTopSnackBar(
        Overlay.of(context),
        TopSnackBar(isError: true, title: context.l10n.emptyRouteForExport),
      );
      return;
    }

    _presentModalSheet<void>(
      (_) => ExportFormatDialog(
        onGpxSelected: () => _exportRoute(RouteExportFormat.gpx),
        onKmlSelected: () => _exportRoute(RouteExportFormat.kml),
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
    } catch (e) {
      completer.completeError(e);

      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(isError: true, title: context.l10n.routeExportError(e.toString())),
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
      final appDataState = context.appDataBloc.state;
      if (!appDataState.hasHistoricData) {
        return false;
      }

      final savedRoutes = appDataState.savedRoutes;
      final currentDistance = _getGeneratedRouteDistance();
      final routeState = context.routeGenerationBloc.state;

      // Si le parcours vient de l'historique, il est déjà sauvegardé par définition
      if (routeState.isLoadedFromHistory) {
        return true;
      }

      // Vérifier s'il existe un parcours similaire
      return _findSimilarRoute(
            savedRoutes,
            currentDistance,
            routeState.usedParameters,
          ) !=
          null;
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de la vérification du parcours: $e');
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
      final savedDistance =
          savedRoute.actualDistance ?? savedRoute.parameters.distanceKm;

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

  Future<T?> _presentModalSheet<T>(
    Widget Function(BuildContext) builder,
    { bool useSafeArea = false}
  ) async {
    // 1️⃣ Masquer le panneau s’il est visible
    _removeRouteInfoPanel();

    // 2️⃣ Afficher le bottom-sheet
    final res = await showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      builder: builder,
    );

    // 3️⃣ Quand le sheet se ferme, remettre le panneau (si la route existe tjs)
    if (mounted && generatedRouteCoordinates != null) {
      _showRouteInfoModal();
    }

    return res;
  }

  /// Retire proprement le panneau s’il est encore monté
  void _removeRouteInfoPanel() {
    if (_routeInfoEntry?.mounted ?? false) {
      _routeInfoEntry!.remove();
    }
    _routeInfoEntry = null;
  }

  SavedRoute? _getCurrentLoadedRoute() {
    if (!_isHistoricRouteActive) return null;
    
    try {
      final appDataState = context.appDataBloc.state;
      if (!appDataState.hasHistoricData) return null;

      final savedRoutes = appDataState.savedRoutes;
      final currentDistance = _getGeneratedRouteDistance();
      final currentParams = context.routeGenerationBloc.state.usedParameters;
      
      // Utiliser la méthode existante pour trouver la route similaire
      return _findSimilarRoute(savedRoutes, currentDistance, currentParams);
    } catch (e) {
      LogConfig.logError('❌ Erreur lors de la récupération de la route courante: $e');
      return null;
    }
  }

  void _showRouteInfoModal() {
    _removeRouteInfoPanel(); // retire l’éventuel ancien panel

    final overlayState = Overlay.of(context, rootOverlay: true);

    // Récupérer la route sauvegardée si c'est un parcours historique
    final currentSavedRoute = _getCurrentLoadedRoute();

    // 2. construire l’entry
    _routeInfoEntry = OverlayEntry(
      builder:
          (_) => _RouteInfoEntry(
            panel: FloatingRouteInfoPanel(
              routeName: currentSavedRoute?.name ?? generateAutoRouteName(
                context,
                context.routeGenerationBloc.state.usedParameters!,
                _getGeneratedRouteDistance(),
              ),
            routeDesc: currentSavedRoute != null 
              ? generateAutoRouteDesc(
                  context,
                  currentSavedRoute.parameters,
                  currentSavedRoute.actualDistance ?? _getGeneratedRouteDistance(),
                )
              : generateAutoRouteDesc(
                  context,
                  context.routeGenerationBloc.state.usedParameters!,
                  _getGeneratedRouteDistance(),
                ),
              parameters: context.routeGenerationBloc.state.usedParameters!,
              distance: _getGeneratedRouteDistance(),
              isLoop: routeMetadata!['is_loop'] as bool? ?? true,
              waypointCount: routeMetadata!['points_count'] as int? ?? 0,
              routeMetadata: routeMetadata!,
              coordinates: generatedRouteCoordinates!,
              onClear: () {
                _removeRouteInfoPanel();
                _clearGeneratedRoute();
              },
              onShare: _showExportDialog,
              onSave: _handleSaveRoute,
              isSaving: _isSaveDialogOpen,
              isAlreadySaved: _isCurrentRouteAlreadySaved(),
              onDismiss: _removeRouteInfoPanel,
            ),
          ),
    );

    // --- trouver l’anchor (= entry la plus basse) ---------------------------
    OverlayEntry? anchor;
    final dynState = overlayState as dynamic; // accès « réflexif »

    try {
      // ≥ 3.16
      final list = dynState.entries as List<OverlayEntry>;
      if (list.isNotEmpty) anchor = list.first;
    } catch (_) {
      try {
        // 3.13 – 3.15
        final list = dynState.overlayEntries as List<OverlayEntry>;
        if (list.isNotEmpty) anchor = list.first;
      } catch (_) {
        /* aucune propriété accessible */
      }
    }

    // --- insertion ----------------------------------------------------------
    if (anchor != null) {
      overlayState.insert(_routeInfoEntry!, below: anchor);
    } else {
      // très vieux Flutter : on ne connaît pas la pile → on insère « au‐dessus »
      overlayState.insert(_routeInfoEntry!);
    }
  }

  // 🆕 Démarre le timer de temps minimum pour le loading
  void _startMinimumLoadingTimer() {
    _loadingMinimumTimer?.cancel();
    _loadingStartTime = DateTime.now();
    _isMinimumLoadingTimeElapsed = false;
    _isPendingRouteInfoDisplay = false;
    _isLoadingOverlayVisible = true; // 🆕 AJOUT
    
    _loadingMinimumTimer = Timer(_minimumLoadingDuration, () {
      if (mounted) {
        setState(() {
          _isMinimumLoadingTimeElapsed = true;
        });
        
        // Vérifier si on peut fermer l'overlay et afficher le RouteInfoCard
        _checkAndCompleteLoading();
      }
    });
  }

  void _checkAndCompleteLoading() {
    if (_isMinimumLoadingTimeElapsed && _isPendingRouteInfoDisplay && _isLoadingOverlayVisible) {
      // Fermer l'overlay d'abord
      _loading.hide();
      _isLoadingOverlayVisible = false;
      
      // Attendre un frame pour s'assurer que l'overlay est fermé, puis afficher le RouteInfoCard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showRouteInfoModal();
          _isPendingRouteInfoDisplay = false;
        }
      });
    }
  }

  // 🆕 Gère l'affichage du RouteInfoCard avec respect du temps minimum
  void _handleRouteInfoDisplay() {
    if (_isMinimumLoadingTimeElapsed && !_isLoadingOverlayVisible) {
      // Le temps minimum est écoulé et l'overlay n'est pas visible, on peut afficher immédiatement
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRouteInfoModal();
      });
    } else {
      // Le temps minimum n'est pas écoulé ou l'overlay est visible, on marque comme en attente
      _isPendingRouteInfoDisplay = true;
      _checkAndCompleteLoading(); // Vérifier si on peut déjà compléter
    }
  }

  void _toggleLoader(BuildContext context, bool show, String msg) {
    if (show) {
      // 🆕 Démarrer le timer quand on affiche le loader
      _startMinimumLoadingTimer();
      _loading.show(context, msg);
    } else {
      // 🆕 Marquer que le loading doit se terminer mais respecter le temps minimum
      if (_isMinimumLoadingTimeElapsed) {
        _loading.hide();
        _isLoadingOverlayVisible = false;
        _loadingMinimumTimer?.cancel();
        
        // Si on a un RouteInfoCard en attente, l'afficher maintenant
        if (_isPendingRouteInfoDisplay) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showRouteInfoModal();
              _isPendingRouteInfoDisplay = false;
            }
          });
        }
      } else {
        // Le temps minimum n'est pas écoulé, on va attendre
        _checkAndCompleteLoading();
      }
    }
  }

  void _onRouteGenerationStateChanged(
    BuildContext context,
    RouteGenerationState state,
  ) {
    // gestion du loader plein-écran
    final msg = state.isGeneratingRoute
      ? context.l10n.generateInProgress
      : null; // ici pas de sauvegarde (gérée par AppDataBloc)

    _toggleLoader(context, msg != null, msg ?? '');

    // succès de génération : on stocke & on affiche (avec respect du temps minimum)
    if (state.hasGeneratedRoute && state.isNewlyGenerated && !state.isGeneratingRoute) {
      // Marquer qu'aucun parcours historique n'est actif (nouveau parcours généré)
      _isHistoricRouteActive = false;

      setState(() {
        generatedRouteCoordinates = state.generatedRoute;
        routeMetadata = state.routeMetadata;
      });
      if (state.generatedRoute case final coords?) _displayRouteOnMap(coords);
      
      // Utiliser la nouvelle méthode qui respecte le temps minimum
      _handleRouteInfoDisplay();
    }

    // Parcours chargé depuis l'historique (avec respect du temps minimum)
    if (state.hasGeneratedRoute && state.isLoadedFromHistory && !state.isGeneratingRoute) {
      // Marquer qu'un parcours historique est maintenant actif
      _isHistoricRouteActive = true;

      setState(() {
        generatedRouteCoordinates = state.generatedRoute;
        routeMetadata = state.routeMetadata;
        // Passer en mode manual pour éviter le recentrage automatique
        _trackingMode = TrackingMode.manual;
      });

      if (state.generatedRoute case final coords?) {
        _displayRouteOnMap(coords);

        // Centrer la caméra sur le parcours historique sans tracking automatique
        _centerCameraOnRoute(coords);

        // Pour l'historique, pas de temps minimum (affichage immédiat)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showRouteInfoModal();
            LogConfig.logInfo('RouteInfoCard affiché pour parcours historique');
          }
        });
      }

      // Sauvegarder le nouveau mode de tracking
      _mapStateService.saveTrackingMode(_trackingMode);
      LogConfig.logInfo('🔒 Mode tracking passé en manual pour parcours historique');
    }

    // erreur éventuelle
    if (state.errorMessage != null && !state.isGeneratingRoute) {
      _showRouteGenerationError(state.errorMessage!);
    }
  }

  // Centre la caméra sur un parcours
  Future<void> _centerCameraOnRoute(List<List<double>> coordinates) async {
    if (mapboxMap == null || coordinates.isEmpty) return;

    try {
      // Calculer le centre du parcours
      double minLat = coordinates.first[1];
      double maxLat = coordinates.first[1];
      double minLng = coordinates.first[0];
      double maxLng = coordinates.first[0];

      for (final coord in coordinates) {
        final lng = coord[0];
        final lat = coord[1];
        
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;

      // Mettre à jour la position sélectionnée avec le centre du parcours
      setState(() {
        _selectedLatitude = centerLat;
        _selectedLongitude = centerLng;
      });

      // Calculer le zoom approprié pour voir tout le parcours
      final latDiff = maxLat - minLat;
      final lngDiff = maxLng - minLng;
      final maxDiff = math.max(latDiff, lngDiff);
      
      // Zoom adaptatif basé sur la taille du parcours
      double zoom;
      if (maxDiff > 0.1) {zoom = 10;}      // Très grand parcours
      else if (maxDiff > 0.05) {zoom = 11;} // Grand parcours  
      else if (maxDiff > 0.02) {zoom = 12;} // Parcours moyen
      else if (maxDiff > 0.01) {zoom = 13;} // Petit parcours
      else {zoom = 14;}                     // Très petit parcours

      // Voler vers le centre du parcours
      await mapboxMap!.flyTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(centerLng, centerLat),
          ),
          zoom: zoom,
        ),
        mp.MapAnimationOptions(duration: 1500),
      );

      // Sauvegarder la nouvelle position
      _mapStateService.saveSelectedPosition(centerLat, centerLng);
      
      LogConfig.logInfo('📍 Caméra centrée sur parcours historique: $centerLat, $centerLng (zoom: $zoom)');

    } catch (e) {
      LogConfig.logError('❌ Erreur centrage caméra sur parcours: $e');
    }
  }

  void showLimitCapability(GenerationCapability capability) {
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: GenerationLimitWidget(
        capability: capability,
        onDebug:
            () => showModalSheet(
              context: context,
              backgroundColor: Colors.transparent,
              child: GuestGenerationIndicator(),
            ),
        onLogin: () => showSignModal(context, 0),
      ),
    );
  }

  void navigateTo(Widget child) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      if (mounted) {
        _presentModalSheet((_) => ModalDialog(
          isDismissible: true,
          imgPath: "https://cdn.lottielab.com/l/13mdUjaB8g6HWu.json",
          title: context.l10n.notLoggedIn,
          subtitle: context.l10n.loginOrCreateAccountHint,
          validLabel: context.l10n.logIn,
          cancelLabel: context.l10n.createAccount,
          onValid: () {
            showSignModal(context, 1);
            // context.push('/auth/1'); // Login
          },
          onCancel: () {
            showSignModal(context, 0);
            // context.push('/auth/0');
          },
        ));
      }
    } else {
      _presentModalSheet((_) => ModalSheet(child: child), useSafeArea: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MonitoredScreen(
      screenName: 'home_screen',
      child: MultiBlocListener(
        listeners: [
          // 1️⃣  Génération de parcours
          BlocListener<RouteGenerationBloc, RouteGenerationState>(
            listenWhen: (previous, current) => 
              previous.generatedRoute != current.generatedRoute ||
              previous.isGeneratingRoute != current.isGeneratingRoute ||
              previous.savedRoutes.length != current.savedRoutes.length,
            listener: _onRouteGenerationStateChanged,
          ),
      
          // 2️⃣  Sauvegarde de parcours
          BlocListener<AppDataBloc, AppDataState>(
            listenWhen: (previous, current) => previous.isSavingRoute != current.isSavingRoute,
            listener: (context, state) => _toggleLoader(context, state.isSavingRoute, context.l10n.saving),
          ),
        ],
        child: BlocBuilder<RouteGenerationBloc, RouteGenerationState>(
          builder: (context, routeState) {
            return _buildMainContent(context, routeState);
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, RouteGenerationState routeState) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: OfflineGenerationCapability(
        timeout: const Duration(seconds: 2), // Timeout court pour éviter les blocages
        loadingWidget: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Initialisation...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        builder: (capability) {      
          return Stack(
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
                  restoreFromCache: _mapStateService.isMapInitialized,
                ),
              ),
    
              // 🆕 MARQUEUR LOTTIE ANIMÉ
              if (_showLottieMarker &&
                  _lottieMarkerLat != null &&
                  _lottieMarkerLng != null)
                _buildLottieMarker(),
    
              // Interface normale
              if (!isNavigationMode && !_isInNavigationMode)
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.94,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Right menu
                            Row(
                              spacing: 8.0,
                              mainAxisAlignment:
                                  MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.0,
                                    vertical: 5.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.adaptiveBackground,
                                    borderRadius:
                                        BorderRadius.circular(100),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.15),
                                        spreadRadius: 2,
                                        blurRadius: 30,
                                        offset: Offset(
                                          0,
                                          0,
                                        ), // changes position of shadow
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      HugeIcons.solidRoundedFavourite,
                                      size: 25.0,
                                    ),
                                    onPressed:
                                        () => navigateTo(HistoricScreen()),
                                  ),
                                ),
    
                                // Left menu
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 5.0,
                                        vertical: 5.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            context
                                                .adaptiveBackground,
                                        borderRadius:
                                            BorderRadius.circular(
                                              100,
                                            ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(
                                                  alpha: 0.15,
                                                ),
                                            spreadRadius: 2,
                                            blurRadius: 30,
                                            offset: Offset(
                                              0,
                                              0,
                                            ), // changes position of shadow
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        spacing: 5.0,
                                        children: [
                                          // User tracking
                                          IconButton(
                                            icon: Icon(
                                              HugeIcons
                                                  .solidRoundedMapsGlobal01,
                                              color:
                                                  _trackingMode ==
                                                          TrackingMode
                                                              .userTracking
                                                      ? AppColors
                                                          .primary
                                                      : context
                                                          .adaptiveTextSecondary,
                                              size: 28.0,
                                            ),
                                            onPressed: _activateUserTracking,
                                          ),
                                          // Map style
                                          IconButton(
                                            icon: Icon(
                                              HugeIcons
                                                  .solidRoundedLayerMask01,
                                              size: 28.0,
                                            ),
                                            onPressed: _openMapStyleSelector,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
    
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 6.0,
                              ),
                              decoration: BoxDecoration(
                                color: context.adaptiveBackground,
                                borderRadius: BorderRadius.circular(
                                  100,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    spreadRadius: 2,
                                    blurRadius: 30,
                                    offset: Offset(0,0,), // changes position of shadow
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  HugeIcons.solidRoundedAiMagic,
                                  size: 30.0,
                                ),
                                onPressed: openGenerator,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    
              FloatingLocationSearchSheet(
                onLocationSelected: _onLocationSelected,
                userLongitude: _userLongitude,
                userLatitude: _userLatitude,
                onProfile: () => navigateTo(AccountScreen()),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🆕 Getter pour vérifier l'état de sauvegarde
  bool get _isSavingRoute {
    try {
      final routeState = context.routeGenerationBloc.state;
      return routeState.isSavingRoute;
    } catch (e) {
      return false;
    }
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
          top: pos.dy - _markerSize,
          child: IgnorePointer(
            child: SizedBox(
              width: _markerSize,
              height: _markerSize,
              child: Lottie.network(
                'https://cdn.lottielab.com/l/7h3oieuvwUgm9B.json',
                controller: _lottieController,
                fit: BoxFit.contain,
                onLoaded:
                    (c) =>
                        _lottieController
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

class _RouteInfoEntry extends StatelessWidget {
  final Widget panel;
  const _RouteInfoEntry({required this.panel});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(color: Colors.transparent, child: panel),
    );
  }
}
