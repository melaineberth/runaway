import 'dart:async';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:runaway/features/home/domain/enums/tracking_mode.dart';
import 'package:runaway/features/home/domain/models/mapbox_style_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🗺️ Service singleton pour la persistance de l'état de la carte
class MapStateService {
  static final MapStateService _instance = MapStateService._internal();
  factory MapStateService() => _instance;
  MapStateService._internal();

  // Clés pour SharedPreferences
  static const String _mapStyleKey = 'map_style_id';

  // === ÉTAT DE LA CARTE ===
  bool _isMapInitialized = false;
  bool _hasInitialCameraBeenSet = false;
  mp.CameraState? _savedCameraState;
  
  // === POSITION UTILISATEUR ===
  double? _lastUserLatitude;
  double? _lastUserLongitude;
  double? _selectedLatitude;
  double? _selectedLongitude;
  
  // === MODE DE TRACKING ===
  TrackingMode _trackingMode = TrackingMode.userTracking;
  
  // === PARCOURS GÉNÉRÉ ===
  List<List<double>>? _generatedRouteCoordinates;
  Map<String, dynamic>? _routeMetadata;
  bool _hasAutoSaved = false;
  
  // === MARQUEURS ===
  bool _hasActiveMarker = false;
  double? _markerLatitude;
  double? _markerLongitude;

  // === STYLE DE CARTE === (NOUVEAU)
  String _selectedMapStyleId = MapboxStyleConstants.getDefaultStyleId();

  // Getters existants
  bool get isMapInitialized => _isMapInitialized;
  bool get hasInitialCameraBeenSet => _hasInitialCameraBeenSet;
  mp.CameraState? get savedCameraState => _savedCameraState;
  double? get lastUserLatitude => _lastUserLatitude;
  double? get lastUserLongitude => _lastUserLongitude;
  double? get selectedLatitude => _selectedLatitude;
  double? get selectedLongitude => _selectedLongitude;
  TrackingMode get trackingMode => _trackingMode;
  List<List<double>>? get generatedRouteCoordinates => _generatedRouteCoordinates;
  Map<String, dynamic>? get routeMetadata => _routeMetadata;
  bool get hasAutoSaved => _hasAutoSaved;
  bool get hasActiveMarker => _hasActiveMarker;
  double? get markerLatitude => _markerLatitude;
  double? get markerLongitude => _markerLongitude;

  // === NOUVEAUX GETTERS POUR LE STYLE ===
  String get selectedMapStyleId => _selectedMapStyleId;

  /// 🎨 Obtenir l'URI du style actuel
  String getCurrentStyleUri() {
    final style = MapboxStyleConstants.getStyleById(_selectedMapStyleId);
    return style.uri;
  }

  /// 🎨 Sauvegarder le style de carte sélectionné avec persistance
  Future<void> saveMapStyleId(String styleId) async {
    _selectedMapStyleId = styleId;
    print('🎨 Style de carte sauvegardé: $styleId');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_mapStyleKey, styleId);
      print('🎨 Style persisté dans SharedPreferences');
    } catch (e) {
      print('❌ Erreur sauvegarde style dans SharedPreferences: $e');
    }
  }

  /// 🎨 Charger le style depuis la persistance
  Future<void> loadMapStyleFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStyleId = prefs.getString(_mapStyleKey);
      
      if (savedStyleId != null) {
        // Vérifier que le style existe toujours
        try {
          MapboxStyleConstants.getStyleById(savedStyleId);
          _selectedMapStyleId = savedStyleId;
          print('🎨 Style chargé depuis SharedPreferences: $savedStyleId');
        } catch (e) {
          print('⚠️ Style inexistant dans SharedPreferences, utilisation du défaut');
          _selectedMapStyleId = MapboxStyleConstants.getDefaultStyleId();
        }
      } else {
        print('🎨 Aucun style sauvegardé, utilisation du défaut');
        _selectedMapStyleId = MapboxStyleConstants.getDefaultStyleId();
      }
    } catch (e) {
      print('❌ Erreur chargement style depuis SharedPreferences: $e');
      _selectedMapStyleId = MapboxStyleConstants.getDefaultStyleId();
    }
  }

  /// 📸 Sauvegarder l'état de la caméra
  Future<void> saveCameraState(mp.MapboxMap mapboxMap) async {
    try {
      _savedCameraState = await mapboxMap.getCameraState();
      print('📸 État caméra sauvegardé: ${_savedCameraState?.center.coordinates}');
    } catch (e) {
      print('❌ Erreur sauvegarde état caméra: $e');
    }
  }

  /// 🎬 Restaurer l'état de la caméra (sans animation pour les retours)
  Future<void> restoreCameraState(mp.MapboxMap mapboxMap, {bool animate = false}) async {
    if (_savedCameraState == null) return;

    try {
      final cameraOptions = mp.CameraOptions(
        center: _savedCameraState!.center,
        zoom: _savedCameraState!.zoom,
        bearing: _savedCameraState!.bearing,
        pitch: _savedCameraState!.pitch,
      );

      if (animate) {
        await mapboxMap.flyTo(cameraOptions, mp.MapAnimationOptions(duration: 1000));
      } else {
        await mapboxMap.setCamera(cameraOptions);
      }
      
      print('🎬 État caméra restauré ${animate ? "avec" : "sans"} animation');
    } catch (e) {
      print('❌ Erreur restauration état caméra: $e');
    }
  }

  /// 🏗️ Marquer la carte comme initialisée
  void markMapAsInitialized() {
    _isMapInitialized = true;
    print('🏗️ Carte marquée comme initialisée');
  }

  /// 📷 Marquer la caméra initiale comme définie
  void markInitialCameraAsSet() {
    _hasInitialCameraBeenSet = true;
    print('📷 Caméra initiale marquée comme définie');
  }

  /// 📍 Sauvegarder la position utilisateur
  void saveUserPosition(double latitude, double longitude) {
    _lastUserLatitude = latitude;
    _lastUserLongitude = longitude;
    print('📍 Position utilisateur sauvegardée: ($latitude, $longitude)');
  }

  /// 🎯 Sauvegarder la position sélectionnée
  void saveSelectedPosition(double latitude, double longitude) {
    _selectedLatitude = latitude;
    _selectedLongitude = longitude;
    print('🎯 Position sélectionnée sauvegardée: ($latitude, $longitude)');
  }

  /// 🔄 Sauvegarder le mode de tracking
  void saveTrackingMode(TrackingMode mode) {
    _trackingMode = mode;
    print('🔄 Mode tracking sauvegardé: $mode');
  }

  /// 🛣️ Sauvegarder le parcours généré
  void saveGeneratedRoute(List<List<double>>? coordinates, Map<String, dynamic>? metadata, bool hasAutoSaved) {
    _generatedRouteCoordinates = coordinates;
    _routeMetadata = metadata;
    _hasAutoSaved = hasAutoSaved;
    print('🛣️ Parcours sauvegardé: ${coordinates?.length ?? 0} points');
  }

  /// 📌 Sauvegarder l'état du marqueur
  void saveMarkerState(bool hasMarker, double? latitude, double? longitude) {
    _hasActiveMarker = hasMarker;
    _markerLatitude = latitude;
    _markerLongitude = longitude;
    print('📌 État marqueur sauvegardé: $hasMarker à ($latitude, $longitude)');
  }

  /// 🧹 Nettoyer l'état (pour réinitialisation complète)
  void clearState() {
    _isMapInitialized = false;
    _hasInitialCameraBeenSet = false;
    _savedCameraState = null;
    _lastUserLatitude = null;
    _lastUserLongitude = null;
    _selectedLatitude = null;
    _selectedLongitude = null;
    _trackingMode = TrackingMode.userTracking;
    _generatedRouteCoordinates = null;
    _routeMetadata = null;
    _hasAutoSaved = false;
    _hasActiveMarker = false;
    _markerLatitude = null;
    _markerLongitude = null;
    // Le style de carte n'est PAS réinitialisé lors du clearState pour conserver les préférences utilisateur
    print('🧹 État de la carte nettoyé (style conservé)');
  }

  /// 🔄 Réinitialiser seulement les marqueurs et parcours
  void clearMarkersAndRoute() {
    _generatedRouteCoordinates = null;
    _routeMetadata = null;
    _hasAutoSaved = false;
    _hasActiveMarker = false;
    _markerLatitude = null;
    _markerLongitude = null;
    print('🔄 Marqueurs et parcours nettoyés');
  }
}