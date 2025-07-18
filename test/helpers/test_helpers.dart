// test/unit/helpers/test_helpers.dart
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';

class TestHelpers {
  static RouteParameters createMockParameters({
    ActivityType activityType = ActivityType.running,
    TerrainType terrainType = TerrainType.flat,
    UrbanDensity urbanDensity = UrbanDensity.mixed,
    DifficultyLevel? difficulty,
    double distanceKm = 5.0,
    double startLongitude = 2.3522,
    double startLatitude = 48.8566,
    ElevationRange? elevationRange,
    double? maxInclinePercent,
    int? preferredWaypoints,
    bool? avoidHighways,
    bool? prioritizeParks,
    double? surfacePreference,
    bool? isLoop,
  }) {
    return RouteParameters(
      activityType: activityType,
      terrainType: terrainType,
      urbanDensity: urbanDensity,
      distanceKm: distanceKm,
      elevationRange: elevationRange ?? const ElevationRange(min: 0, max: 100),
      difficulty: difficulty ?? DifficultyLevel.easy,
      maxInclinePercent: maxInclinePercent ?? 5.0,
      preferredWaypoints: preferredWaypoints ?? 2,
      avoidHighways: avoidHighways ?? true,
      prioritizeParks: prioritizeParks ?? false,
      surfacePreference: surfacePreference ?? 0.8,
      isLoop: isLoop ?? false,
      startLongitude: startLongitude,
      startLatitude: startLatitude,
    );
  }

  static SavedRoute createMockRoute({
    String id = 'test-route',
    String name = 'Test Route',
    bool isSynced = true,
    RouteParameters? parameters,
    List<List<double>>? coordinates,
    DateTime? createdAt,
    double? actualDistance,
    int? actualDuration,
    int timesUsed = 0,
    DateTime? lastUsedAt,
    String? imageUrl,
  }) {
    return SavedRoute(
      id: id,
      name: name,
      parameters: parameters ?? createMockParameters(),
      coordinates: coordinates ?? [[2.3522, 48.8566], [2.3532, 48.8576]],
      createdAt: createdAt ?? DateTime.now(),
      actualDistance: actualDistance,
      actualDuration: actualDuration,
      isSynced: isSynced,
      timesUsed: timesUsed,
      lastUsedAt: lastUsedAt,
      imageUrl: imageUrl,
    );
  }

  static UserCredits createMockCredits({
    String? id,
    String userId = 'test-user',
    int availableCredits = 10,
    int totalCredits = 20,
    int? totalCreditsPurchased,
    int? totalCreditsUsed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    
    return UserCredits(
      id: id ?? 'test-credits-id',
      userId: userId,
      availableCredits: availableCredits,
      totalCreditsPurchased: totalCreditsPurchased ?? totalCredits,
      totalCreditsUsed: totalCreditsUsed ?? (totalCredits - availableCredits),
      createdAt: createdAt ?? now.subtract(const Duration(days: 30)),
      updatedAt: updatedAt ?? now,
    );
  }

  static List<List<double>> createMockCoordinates(int count) {
    return List.generate(count, (i) => [
      2.3522 + i * 0.001,
      48.8566 + i * 0.001,
    ]);
  }

  /// Crée des paramètres de route pour des tests spécifiques
  static RouteParameters createValidRunningRoute() {
    return createMockParameters(
      activityType: ActivityType.running,
      distanceKm: 5.0,
      elevationRange: const ElevationRange(min: 0, max: 50),
      difficulty: DifficultyLevel.easy,
    );
  }

  static RouteParameters createValidCyclingRoute() {
    return createMockParameters(
      activityType: ActivityType.cycling,
      distanceKm: 20.0,
      elevationRange: const ElevationRange(min: 50, max: 200),
      difficulty: DifficultyLevel.moderate,
    );
  }

  static RouteParameters createInvalidRoute() {
    return createMockParameters(
      activityType: ActivityType.running,
      distanceKm: 100.0, // Trop élevé pour la course
      elevationRange: const ElevationRange(min: 0, max: 100),
    );
  }

  /// Crée des crédits pour différents scénarios de test
  static UserCredits createCreditsWithSufficientBalance() {
    return createMockCredits(
      availableCredits: 10,
      totalCredits: 20,
    );
  }

  static UserCredits createCreditsWithInsufficientBalance() {
    return createMockCredits(
      availableCredits: 0,
      totalCredits: 10,
    );
  }

  static UserCredits createNewUserCredits() {
    return createMockCredits(
      availableCredits: 0,
      totalCredits: 0,
      totalCreditsPurchased: 0,
      totalCreditsUsed: 0,
    );
  }

  /// Crée des routes pour différents scénarios
  static SavedRoute createSyncedRoute() {
    return createMockRoute(
      id: 'synced-route',
      name: 'Synced Route',
      isSynced: true,
    );
  }

  static SavedRoute createUnsyncedRoute() {
    return createMockRoute(
      id: 'unsynced-route',
      name: 'Unsynced Route',
      isSynced: false,
    );
  }

  static SavedRoute createRouteWithUsage() {
    return createMockRoute(
      id: 'used-route',
      name: 'Used Route',
      timesUsed: 5,
      lastUsedAt: DateTime.now().subtract(const Duration(days: 1)),
    );
  }

  /// Utilitaires pour les tests
  static List<SavedRoute> createMockRouteList(int count) {
    return List.generate(count, (i) => createMockRoute(
      id: 'route-$i',
      name: 'Route $i',
    ));
  }

  static Map<String, dynamic> createMockRouteMetadata({
    double? distanceKm,
    int? durationMinutes,
    int? pointsCount,
    bool? isLoop,
  }) {
    return {
      'distanceKm': distanceKm ?? 5.0,
      'distance': ((distanceKm ?? 5.0) * 1000).round(),
      'durationMinutes': durationMinutes ?? 30,
      'points_count': pointsCount ?? 10,
      'is_loop': isLoop ?? false,
    };
  }
}