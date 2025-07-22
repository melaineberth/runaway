import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/router/router.dart';
import 'package:runaway/features/home/domain/models/route_metrics.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';
import 'route_parameters.dart';
import 'activity_type.dart';
import 'package:runaway/core/helper/config/log_config.dart';

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
  final String? imageUrl; // 🆕 URL de la screenshot du parcours

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
    this.imageUrl, // 🆕 Champ pour l'image
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
    String? imageUrl, // 🆕
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
      imageUrl: imageUrl ?? this.imageUrl, // 🆕
    );
  }

  /// Conversion vers JSON pour la sérialisation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parameters': parameters.toJson(),
      'coordinates': coordinates,
      'created_at': createdAt.toLocal().toIso8601String(), // 🔧 S'assurer du format local
      'actual_distance': actualDistance,
      'actual_duration': actualDuration,
      'is_synced': isSynced,
      'times_used': timesUsed,
      'last_used_at': lastUsedAt?.toLocal().toIso8601String(), // 🔧 Pareil pour lastUsedAt
      'image_url': imageUrl,
    };
  }

  /// Création depuis JSON avec gestion d'erreurs robuste
  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    try {
      // 🔧 Parser les dates avec gestion explicite du timezone
      DateTime createdAt;
      DateTime? lastUsedAt;
      
      try {
        final createdAtString = json['created_at'] as String;
        createdAt = DateTime.parse(createdAtString).toLocal(); // 🔧 Forcer temps local
        print('🕒 Date parsée depuis JSON: $createdAtString -> $createdAt');
      } catch (e) {
        LogConfig.logError('❌ Erreur parsing created_at: $e');
        createdAt = DateTime.now().toLocal(); // Fallback sécurisé
      }
      
      if (json['last_used_at'] != null) {
        try {
          final lastUsedAtString = json['last_used_at'] as String;
          lastUsedAt = DateTime.parse(lastUsedAtString).toLocal(); // 🔧 Forcer temps local
        } catch (e) {
          LogConfig.logError('❌ Erreur parsing last_used_at: $e');
          lastUsedAt = null;
        }
      }
      
      return SavedRoute(
        id: json['id'] as String,
        name: json['name'] as String,
        parameters: RouteParameters.fromJson(json['parameters'] as Map<String, dynamic>),
        coordinates: _parseCoordinates(json['coordinates']),
        createdAt: createdAt, // 🔧 Date corrigée
        actualDistance: _parseDouble(json['actual_distance']),
        actualDuration: _parseInt(json['actual_duration']),
        isSynced: json['is_synced'] as bool? ?? false,
        timesUsed: json['times_used'] as int? ?? 0,
        lastUsedAt: lastUsedAt, // 🔧 Date corrigée
        imageUrl: json['image_url'] as String?,
      );
    } catch (e) {
      LogConfig.logError('❌ Erreur parsing SavedRoute complète: $e');
      print('📄 JSON problématique: $json');
      throw FormatException('Erreur parsing SavedRoute: $e');
    }
  }

  /// Parse les coordonnées de manière robuste
  static List<List<double>> _parseCoordinates(dynamic coordinatesData) {
    if (coordinatesData is List) {
      return coordinatesData.map((coord) {
        if (coord is List) {
          return coord.map((e) => (e as num).toDouble()).toList();
        }
        throw FormatException('Format de coordonnées invalide');
      }).toList();
    }
    throw FormatException('Format de coordonnées invalide');
  }

  /// Parse un double de manière robuste
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Parse un int de manière robuste
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Distance formatée pour l'affichage
  String get formattedDistance {
    final distance = actualDistance ?? parameters.distanceKm;
    return '${distance.toStringAsFixed(1)}km';
  }

  /// Durée formatée pour l'affichage
  String get formattedDuration {
    if (actualDuration == null) return '';
    final hours = actualDuration! ~/ 60;
    final minutes = actualDuration! % 60;
    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}';
    }
    return '${minutes}min';
  }

  /// Temps écoulé depuis la création
  String get timeAgo {
    final context = rootNavigatorKey.currentContext!;
    try {
      final now = DateTime.now();
      
      // S'assurer que les deux dates sont dans le même timezone
      final createdLocal = createdAt.toLocal();
      final nowLocal = now.toLocal();
      
      final difference = nowLocal.difference(createdLocal);
            
      // 🔧 Gestion robuste des différences négatives
      if (difference.isNegative) {
        LogConfig.logInfo('Différence négative: ${difference.inMinutes}min - Probablement un problème de timezone');
        // Si c'est une petite différence négative, considérer comme "à l'instant"  
        if (difference.inMinutes.abs() < 60) {
          return context.l10n.timeAgoAtMoment;
        } else {
          return context.l10n.timeAgoFallback; // Fallback pour des erreurs plus importantes
        }
      }
      
      if (difference.inDays > 0) {
        return context.l10n.daysAgoLabel(difference.inDays);
      } else if (difference.inHours > 0) {
        return context.l10n.timaAgoHours(difference.inHours);
      } else if (difference.inMinutes > 0) {
        return context.l10n.timaAgoMinutes(difference.inMinutes);
      } else if (difference.inSeconds > 10) {
        return context.l10n.timaAgoSecondes(difference.inSeconds);
      } else {
        return context.l10n.timeAgoAtMoment;
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur calcul timeAgo: $e');
      return context.l10n.timeAgoFallback;
    }
  }

  /// Détermine si le parcours a été utilisé récemment
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

  /// 🆕 Vérifie si le parcours a une image
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  RouteMetrics get metrics {
    // Construire les métadonnées de base
    final Map<String, dynamic> routeMetadata = {
      'distance_km': actualDistance ?? parameters.distanceKm,
      'elevation_gain': parameters.elevationGain,
      'elevation_loss': parameters.elevationGain * 0.8, // Estimation
      'max_elevation': parameters.elevationGain,
      'min_elevation': 0.0,
      'average_incline': _calculateAverageIncline(),
      'max_incline': _calculateMaxIncline(),
      'waypoint_count': coordinates.length,
      'scenic_score': _calculateScenicScore(),
      'surface_types': ['Mixte'],
      'highlights': [],
    };

    return RouteMetrics.fromRouteData(
      routeMetadata: routeMetadata,
      coordinates: coordinates,
      parameters: parameters,
    );
  }

  /// Calcule la pente moyenne estimée
  double _calculateAverageIncline() {
    if (parameters.elevationGain <= 0 || (actualDistance ?? parameters.distanceKm) <= 0) {
      return 0.0;
    }
    
    final distance = actualDistance ?? parameters.distanceKm;
    return (parameters.elevationGain / (distance * 1000)) * 100; // Pourcentage
  }

  /// Calcule la pente maximale estimée selon le type de terrain
  double _calculateMaxIncline() {
    switch (parameters.terrainType) {
      case TerrainType.flat:
        return 3.0; // Terrain plat
      case TerrainType.mixed:
        return 8.0; // Terrain mixte
      case TerrainType.hilly:
        return 15.0; // Terrain vallonné
    }
  }

  /// Calcule un score paysage basé sur la densité urbaine et le terrain
  double _calculateScenicScore() {
    double score = 5.0; // Score de base
    
    // Bonus selon la densité urbaine
    switch (parameters.urbanDensity) {
      case UrbanDensity.nature:
        score += 3.0; // Nature = plus beau
        break;
      case UrbanDensity.mixed:
        score += 1.0; // Mixte = moyennement beau
        break;
      case UrbanDensity.urban:
        score += 0.0; // Urbain = score de base
        break;
    }
    
    // Bonus selon le terrain
    switch (parameters.terrainType) {
      case TerrainType.hilly:
        score += 1.5; // Vallonné = plus de points de vue
        break;
      case TerrainType.mixed:
        score += 0.5; // Mixte = un peu plus varié
        break;
      case TerrainType.flat:
        score += 0.0; // Plat = pas de bonus
        break;
    }
    
    // Bonus si on privilégie le paysage
    if (parameters.preferScenic) {
      score += 0.5;
    }
    
    return score.clamp(1.0, 10.0); // Garder entre 1 et 10
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
    imageUrl, // 🆕
  ];

  @override
  String toString() {
    return 'SavedRoute(id: $id, name: $name, distance: $formattedDistance, synced: $isSynced, hasImage: $hasImage)';
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

  /// 🆕 Filtre les parcours avec images
  List<SavedRoute> get routesWithImages {
    return where((route) => route.hasImage).toList();
  }
}
