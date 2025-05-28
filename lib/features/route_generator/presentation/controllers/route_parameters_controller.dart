import 'package:flutter/material.dart';
import '../../domain/models/activity_type.dart';
import '../../domain/models/route_parameters.dart';
import '../../domain/models/terrain_type.dart';
import '../../domain/models/urban_density.dart';

class RouteParametersController extends ChangeNotifier {
  RouteParameters _parameters;
  
  // Historique des paramètres pour undo/redo
  final List<RouteParameters> _history = [];
  int _historyIndex = -1;
  
  // Favoris de l'utilisateur
  final List<RouteParameters> _favorites = [];
  
  RouteParametersController({
    required double startLongitude,
    required double startLatitude,
  }) : _parameters = RouteParameters(
          activityType: ActivityType.running,
          terrainType: TerrainType.mixed,
          urbanDensity: UrbanDensity.mixed,
          distanceKm: 5.0,
          searchRadius: 5000.0,
          elevationGain: 0.0,
          startLongitude: startLongitude,
          startLatitude: startLatitude,
        ) {
    _addToHistory(_parameters);
  }

  RouteParameters get parameters => _parameters;
  List<RouteParameters> get favorites => List.unmodifiable(_favorites);
  
  // Getters pour un accès facile
  ActivityType get activityType => _parameters.activityType;
  TerrainType get terrainType => _parameters.terrainType;
  UrbanDensity get urbanDensity => _parameters.urbanDensity;
  double get distanceKm => _parameters.distanceKm;
  double get searchRadius => _parameters.searchRadius;
  double get elevationGain => _parameters.elevationGain;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  // Setters avec validation
  void setActivityType(ActivityType type) {
    if (_parameters.activityType == type) return;
    
    // Ajuster la distance si elle est hors des limites de la nouvelle activité
    double newDistance = _parameters.distanceKm;
    if (newDistance < type.minDistance) {
      newDistance = type.minDistance;
    } else if (newDistance > type.maxDistance) {
      newDistance = type.maxDistance;
    }
    
    _updateParameters(_parameters.copyWith(
      activityType: type,
      distanceKm: newDistance,
    ));
  }

  void setTerrainType(TerrainType type) {
    if (_parameters.terrainType == type) return;
    
    // Ajuster le dénivelé en fonction du terrain
    double suggestedElevation = _parameters.distanceKm * type.maxElevationGain;
    
    _updateParameters(_parameters.copyWith(
      terrainType: type,
      elevationGain: suggestedElevation,
    ));
  }

  void setUrbanDensity(UrbanDensity density) {
    if (_parameters.urbanDensity == density) return;
    
    _updateParameters(_parameters.copyWith(
      urbanDensity: density,
    ));
  }

  void setDistance(double km) {
    // Validation
    if (km < _parameters.activityType.minDistance || 
        km > _parameters.activityType.maxDistance) {
      return;
    }
    
    // Ajuster le rayon de recherche si nécessaire
    double newRadius = _parameters.searchRadius;
    if (newRadius < km * 500) { // Au moins 500m par km
      newRadius = km * 1000; // 1km de rayon par km de distance
    }
    
    // Ajuster le dénivelé proportionnellement
    double ratio = km / _parameters.distanceKm;
    double newElevation = _parameters.elevationGain * ratio;
    
    _updateParameters(_parameters.copyWith(
      distanceKm: km,
      searchRadius: newRadius,
      elevationGain: newElevation,
    ));
  }

  void setSearchRadius(double radius) {
    // Le rayon doit être au moins la moitié de la distance
    if (radius < _parameters.distanceKm * 500) {
      return;
    }
    
    _updateParameters(_parameters.copyWith(
      searchRadius: radius,
    ));
  }

  void setElevationGain(double elevation) {
    if (elevation < 0) return;
    
    // Limiter selon le type de terrain
    double maxElevation = _parameters.distanceKm * _parameters.terrainType.maxElevationGain;
    if (elevation > maxElevation) {
      elevation = maxElevation;
    }
    
    _updateParameters(_parameters.copyWith(
      elevationGain: elevation,
    ));
  }

  void updateStartLocation(double longitude, double latitude) {
    _updateParameters(_parameters.copyWith(
      startLongitude: longitude,
      startLatitude: latitude,
    ));
  }

  // Presets
  void applyBeginnerPreset() {
    _updateParameters(RouteParameters.beginnerPreset(
      startLongitude: _parameters.startLongitude,
      startLatitude: _parameters.startLatitude,
    ));
  }

  void applyIntermediatePreset() {
    _updateParameters(RouteParameters.intermediatePreset(
      startLongitude: _parameters.startLongitude,
      startLatitude: _parameters.startLatitude,
    ));
  }

  void applyAdvancedPreset() {
    _updateParameters(RouteParameters.advancedPreset(
      startLongitude: _parameters.startLongitude,
      startLatitude: _parameters.startLatitude,
    ));
  }

  // Favoris
  void addToFavorites(String name) {
    _favorites.add(_parameters.copyWith());
    notifyListeners();
  }

  void removeFavorite(int index) {
    if (index >= 0 && index < _favorites.length) {
      _favorites.removeAt(index);
      notifyListeners();
    }
  }

  void applyFavorite(int index) {
    if (index >= 0 && index < _favorites.length) {
      _updateParameters(_favorites[index].copyWith(
        startLongitude: _parameters.startLongitude,
        startLatitude: _parameters.startLatitude,
      ));
    }
  }

  // Historique
  void undo() {
    if (canUndo) {
      _historyIndex--;
      _parameters = _history[_historyIndex].copyWith();
      notifyListeners();
    }
  }

  void redo() {
    if (canRedo) {
      _historyIndex++;
      _parameters = _history[_historyIndex].copyWith();
      notifyListeners();
    }
  }

  // Méthode privée pour mettre à jour et gérer l'historique
  void _updateParameters(RouteParameters newParams) {
    _parameters = newParams;
    _addToHistory(newParams);
    notifyListeners();
  }

  void _addToHistory(RouteParameters params) {
    // Supprimer l'historique après la position actuelle
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    
    _history.add(params.copyWith());
    _historyIndex = _history.length - 1;
    
    // Limiter la taille de l'historique
    if (_history.length > 20) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  // Validation
  String? validateParameters() {
    if (!_parameters.isValid) {
      if (_parameters.distanceKm < _parameters.activityType.minDistance) {
        return 'La distance minimale pour ${_parameters.activityType.title} est ${_parameters.activityType.minDistance} km';
      }
      if (_parameters.distanceKm > _parameters.activityType.maxDistance) {
        return 'La distance maximale pour ${_parameters.activityType.title} est ${_parameters.activityType.maxDistance} km';
      }
      if (_parameters.searchRadius < _parameters.distanceKm * 500) {
        return 'Le rayon de recherche est trop petit pour la distance choisie';
      }
    }
    return null;
  }

  @override
  void dispose() {
    _history.clear();
    _favorites.clear();
    super.dispose();
  }
}