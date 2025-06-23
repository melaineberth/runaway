// lib/features/route_generator/domain/models/saved_route.dart

import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'route_parameters.dart';
import 'activity_type.dart';
import 'terrain_type.dart';
import 'urban_density.dart';

/// Modèle pour un parcours sauvegardé
class SavedRoute extends Equatable {
  final String id;
  final String name;
  final RouteParameters parameters;
  final List<List<double>> coordinates;
  final DateTime createdAt;
  final double? actualDistance;
  final int? actualDuration;
  final bool isSynced; // Indique si synchronisé avec le serveur
  final int timesUsed; // Nombre d'utilisations
  final DateTime? lastUsedAt; // Dernière utilisation

  const SavedRoute({
    required this.id,
    required this.name,
    required this.parameters,
    required this.coordinates,
    required this.createdAt,
    this.actualDistance,
    this.actualDuration,
    this.isSynced = false,
    this.timesUsed = 0,
    this.lastUsedAt,
  });

  /// Crée une copie avec des champs modifiés
  SavedRoute copyWith({
    String? id,
    String? name,
    RouteParameters? parameters,
    List<List<double>>? coordinates,
    DateTime? createdAt,
    double? actualDistance,
    int? actualDuration,
    bool? isSynced,
    int? timesUsed,
    DateTime? lastUsedAt,
  }) {
    return SavedRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      parameters: parameters ?? this.parameters,
      coordinates: coordinates ?? this.coordinates,
      createdAt: createdAt ?? this.createdAt,
      actualDistance: actualDistance ?? this.actualDistance,
      actualDuration: actualDuration ?? this.actualDuration,
      isSynced: isSynced ?? this.isSynced,
      timesUsed: timesUsed ?? this.timesUsed,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  /// Conversion vers JSON pour la sérialisation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parameters': parameters.toJson(),
      'coordinates': coordinates,
      'created_at': createdAt.toIso8601String(),
      'actual_distance': actualDistance,
      'actual_duration': actualDuration,
      'is_synced': isSynced,
      'times_used': timesUsed,
      'last_used_at': lastUsedAt?.toIso8601String(),
    };
  }

  /// Création depuis JSON avec gestion d'erreurs robuste
  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    try {
      return SavedRoute(
        id: json['id'] as String,
        name: json['name'] as String,
        parameters: RouteParameters.fromJson(json['parameters'] as Map<String, dynamic>),
        coordinates: _parseCoordinates(json['coordinates']),
        createdAt: DateTime.parse(json['created_at'] as String),
        actualDistance: _parseDouble(json['actual_distance']),
        actualDuration: _parseInt(json['actual_duration']),
        isSynced: json['is_synced'] as bool? ?? false,
        timesUsed: json['times_used'] as int? ?? 0,
        lastUsedAt: json['last_used_at'] != null 
            ? DateTime.parse(json['last_used_at'] as String) 
            : null,
      );
    } catch (e) {
      print('❌ Erreur parsing SavedRoute: $e');
      print('📄 JSON problématique: $json');
      rethrow;
    }
  }

  /// 🔧 Helper pour parser les coordonnées de manière robuste
  static List<List<double>> _parseCoordinates(dynamic coords) {
    if (coords is! List) {
      throw FormatException('Coordinates must be a List, got ${coords.runtimeType}');
    }
    
    return coords.map<List<double>>((coord) {
      if (coord is! List) {
        throw FormatException('Each coordinate must be a List, got ${coord.runtimeType}');
      }
      return coord.map<double>((c) => (c as num).toDouble()).toList();
    }).toList();
  }

  /// 🔧 Helper pour parser double de manière robuste
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// 🔧 Helper pour parser int de manière robuste
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Propriétés calculées utiles
  
  /// Distance formatée
  String get formattedDistance {
    final distance = actualDistance ?? parameters.distanceKm;
    return '${distance.toStringAsFixed(1)} km';
  }

  /// Durée formatée
  String get formattedDuration {
    if (actualDuration == null) {
      return '${parameters.estimatedDuration.inMinutes} min (est.)';
    }
    final hours = actualDuration! ~/ 60;
    final minutes = actualDuration! % 60;
    return hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';
  }

  /// Type d'activité formaté
  String get activityTypeDisplayName {
    return parameters.activityType.title;
  }

  /// Indicateur de synchronisation
  String get syncStatus {
    return isSynced ? '☁️ Synchronisé' : '📱 Local seulement';
  }

  /// Age du parcours
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} jours';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inMinutes}min';
    }
  }

  /// Vérifie si le parcours a été utilisé récemment
  bool get isRecentlyUsed {
    if (lastUsedAt == null) return false;
    final daysSinceLastUse = DateTime.now().difference(lastUsedAt!).inDays;
    return daysSinceLastUse <= 7; // Utilisé dans les 7 derniers jours
  }

  /// Score de popularité (pour le tri)
  double get popularityScore {
    final recencyBonus = isRecentlyUsed ? 10.0 : 0.0;
    final usageScore = timesUsed * 5.0;
    final ageScore = math.max(0.0, 30.0 - DateTime.now().difference(createdAt).inDays);
    
    return recencyBonus + usageScore + ageScore;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    parameters,
    coordinates,
    createdAt,
    actualDistance,
    actualDuration,
    isSynced,
    timesUsed,
    lastUsedAt,
  ];

  @override
  String toString() {
    return 'SavedRoute(id: $id, name: $name, distance: $formattedDistance, synced: $isSynced)';
  }
}

/// Extension pour les listes de parcours sauvegardés
extension SavedRouteListExtensions on List<SavedRoute> {
  /// Filtre par type d'activité
  List<SavedRoute> filterByActivity(ActivityType activityType) {
    return where((route) => route.parameters.activityType == activityType).toList();
  }

  /// Filtre par distance
  List<SavedRoute> filterByDistanceRange(double minKm, double maxKm) {
    return where((route) => 
      route.parameters.distanceKm >= minKm && 
      route.parameters.distanceKm <= maxKm
    ).toList();
  }

  /// Tri par popularité
  List<SavedRoute> sortByPopularity() {
    final sorted = List<SavedRoute>.from(this);
    sorted.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
    return sorted;
  }

  /// Tri par date de création
  List<SavedRoute> sortByCreationDate({bool ascending = false}) {
    final sorted = List<SavedRoute>.from(this);
    sorted.sort((a, b) => ascending 
        ? a.createdAt.compareTo(b.createdAt)
        : b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Filtre les parcours non synchronisés
  List<SavedRoute> get unsyncedRoutes {
    return where((route) => !route.isSynced).toList();
  }

  /// Filtre les favoris (utilisés récemment)
  List<SavedRoute> get favoriteRoutes {
    return where((route) => route.isRecentlyUsed || route.timesUsed > 3).toList();
  }
}