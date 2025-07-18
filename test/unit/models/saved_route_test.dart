// test/unit/models/saved_route_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('SavedRoute', () {
    late SavedRoute mockRoute;

    setUp(() {
      // Utiliser TestHelpers pour créer des objets valides

      mockRoute = TestHelpers.createMockRoute(
        id: 'test-route',
        name: 'Test Route',
        actualDistance: 5.2,
        isSynced: true,
      );
    });

    test('crée un parcours sauvegardé valide', () {
      expect(mockRoute.id, 'test-route');
      expect(mockRoute.name, 'Test Route');
      expect(mockRoute.coordinates, hasLength(2));
      expect(mockRoute.isSynced, true);
      expect(mockRoute.actualDistance, 5.2);
    });

    test('copie avec modifications', () {
      final modified = mockRoute.copyWith(
        name: 'Modified Route',
        timesUsed: 5,
      );

      expect(modified.name, 'Modified Route');
      expect(modified.timesUsed, 5);
      expect(modified.id, mockRoute.id); // Inchangé
      expect(modified.isSynced, mockRoute.isSynced); // Inchangé
    });

    test('sérialise et désérialise correctement', () {
      final json = mockRoute.toJson();
      final restored = SavedRoute.fromJson(json);

      expect(restored.id, mockRoute.id);
      expect(restored.name, mockRoute.name);
      expect(restored.coordinates, mockRoute.coordinates);
      expect(restored.actualDistance, mockRoute.actualDistance);
      expect(restored.isSynced, mockRoute.isSynced);
      expect(restored.parameters.activityType, mockRoute.parameters.activityType);
      expect(restored.parameters.distanceKm, mockRoute.parameters.distanceKm);
    });

    test('gère les dates correctement', () {
      final now = DateTime.now();
      final route = TestHelpers.createMockRoute(
        id: 'test-date',
        name: 'Test Date',
        createdAt: now,
        lastUsedAt: now,
      );

      final json = route.toJson();
      final restored = SavedRoute.fromJson(json);

      // Vérifier que les dates sont préservées (à la seconde près)
      expect(restored.createdAt.millisecondsSinceEpoch ~/ 1000, 
             now.millisecondsSinceEpoch ~/ 1000);
      expect(restored.lastUsedAt!.millisecondsSinceEpoch ~/ 1000, 
             now.millisecondsSinceEpoch ~/ 1000);
    });

    test('gère les différents types d\'activité', () {
      final runningRoute = TestHelpers.createMockRoute(
        parameters: TestHelpers.createValidRunningRoute(),
      );
      
      final cyclingRoute = TestHelpers.createMockRoute(
        parameters: TestHelpers.createValidCyclingRoute(),
      );

      expect(runningRoute.parameters.activityType, ActivityType.running);
      expect(cyclingRoute.parameters.activityType, ActivityType.cycling);
      expect(runningRoute.parameters.distanceKm, lessThan(cyclingRoute.parameters.distanceKm));
    });

    test('gère les statistiques d\'utilisation', () {
      final route = TestHelpers.createRouteWithUsage();
      
      expect(route.timesUsed, greaterThan(0));
      expect(route.lastUsedAt, isNotNull);
      
      final updatedRoute = route.copyWith(
        timesUsed: route.timesUsed + 1,
        lastUsedAt: DateTime.now(),
      );
      
      expect(updatedRoute.timesUsed, route.timesUsed + 1);
      expect(updatedRoute.lastUsedAt, isA<DateTime>());
    });

    test('gère les routes synchronisées et non synchronisées', () {
      final syncedRoute = TestHelpers.createSyncedRoute();
      final unsyncedRoute = TestHelpers.createUnsyncedRoute();
      
      expect(syncedRoute.isSynced, true);
      expect(unsyncedRoute.isSynced, false);
      
      // Test de sérialisation pour les deux types
      final syncedJson = syncedRoute.toJson();
      final unsyncedJson = unsyncedRoute.toJson();
      
      expect(SavedRoute.fromJson(syncedJson).isSynced, true);
      expect(SavedRoute.fromJson(unsyncedJson).isSynced, false);
    });

    test('gère les coordonnées de différentes longueurs', () {
      final shortRoute = TestHelpers.createMockRoute(
        coordinates: TestHelpers.createMockCoordinates(5),
      );
      
      final longRoute = TestHelpers.createMockRoute(
        coordinates: TestHelpers.createMockCoordinates(100),
      );
      
      expect(shortRoute.coordinates, hasLength(5));
      expect(longRoute.coordinates, hasLength(100));
      
      // Vérifier que chaque coordonnée a le bon format
      for (final coord in shortRoute.coordinates) {
        expect(coord, hasLength(2)); // [longitude, latitude]
        expect(coord[0], isA<double>()); // longitude
        expect(coord[1], isA<double>()); // latitude
      }
    });

    test('gère les métadonnées optionnelles', () {
      final routeWithMetadata = TestHelpers.createMockRoute(
        actualDistance: 10.5,
        actualDuration: 45,
        imageUrl: 'https://example.com/route.jpg',
      );
      
      expect(routeWithMetadata.actualDistance, 10.5);
      expect(routeWithMetadata.actualDuration, 45);
      expect(routeWithMetadata.imageUrl, 'https://example.com/route.jpg');
      
      final routeWithoutMetadata = TestHelpers.createMockRoute();
      
      expect(routeWithoutMetadata.actualDistance, isNull);
      expect(routeWithoutMetadata.actualDuration, isNull);
      expect(routeWithoutMetadata.imageUrl, isNull);
    });

    test('préserve l\'intégrité lors de copyWith', () {
      final originalRoute = TestHelpers.createMockRoute(
        timesUsed: 3,
        lastUsedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      
      final modifiedRoute = originalRoute.copyWith(
        name: 'New Name',
      );
      
      // Vérifier que seul le nom a changé
      expect(modifiedRoute.name, 'New Name');
      expect(modifiedRoute.id, originalRoute.id);
      expect(modifiedRoute.timesUsed, originalRoute.timesUsed);
      expect(modifiedRoute.lastUsedAt, originalRoute.lastUsedAt);
      expect(modifiedRoute.coordinates, originalRoute.coordinates);
      expect(modifiedRoute.parameters.activityType, originalRoute.parameters.activityType);
    });

    group('Edge Cases', () {
      test('gère les routes avec coordonnées minimales', () {
        final minimalRoute = TestHelpers.createMockRoute(
          coordinates: [[0.0, 0.0]],
        );
        
        expect(minimalRoute.coordinates, hasLength(1));
        expect(minimalRoute.coordinates.first, [0.0, 0.0]);
      });

      test('gère les routes nouvellement créées', () {
        final newRoute = TestHelpers.createMockRoute(
          timesUsed: 0,
          lastUsedAt: null,
        );
        
        expect(newRoute.timesUsed, 0);
        expect(newRoute.lastUsedAt, isNull);
      });

      test('sérialise correctement les valeurs nulles', () {
        final routeWithNulls = TestHelpers.createMockRoute(
          actualDistance: null,
          actualDuration: null,
          lastUsedAt: null,
          imageUrl: null,
        );
        
        final json = routeWithNulls.toJson();
        final restored = SavedRoute.fromJson(json);
        
        expect(restored.actualDistance, isNull);
        expect(restored.actualDuration, isNull);
        expect(restored.lastUsedAt, isNull);
        expect(restored.imageUrl, isNull);
      });
    });
  });
}