// test/unit/models/route_parameters_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('RouteParameters', () {
    test('crée des paramètres valides', () {
      final params = TestHelpers.createMockParameters(
        activityType: ActivityType.running,
        distanceKm: 5.0,
      );

      expect(params.isValid, true);
      expect(params.activityType, ActivityType.running);
      expect(params.distanceKm, 5.0);
      expect(params.elevationRange.min, 0);
      expect(params.elevationRange.max, 100);
    });

    test('valide les contraintes de distance', () {
      final invalidParams = TestHelpers.createInvalidRoute();

      expect(invalidParams.isValid, false);
    });

    test('sérialise et désérialise correctement', () {
      final original = TestHelpers.createMockParameters(
        activityType: ActivityType.cycling,
        distanceKm: 20.0,
        elevationRange: const ElevationRange(min: 50, max: 300),
      );

      final json = original.toJson();
      final restored = RouteParameters.fromJson(json);

      expect(restored.activityType, original.activityType);
      expect(restored.distanceKm, original.distanceKm);
      expect(restored.startLongitude, original.startLongitude);
      expect(restored.startLatitude, original.startLatitude);
      expect(restored.elevationRange.min, original.elevationRange.min);
      expect(restored.elevationRange.max, original.elevationRange.max);
    });

    test('génère des presets cohérents', () {
      final beginner = RouteParameters.beginnerPreset(
        startLongitude: 2.3522,
        startLatitude: 48.8566,
      );
      
      final intermediate = RouteParameters.intermediatePreset(
        startLongitude: 2.3522,
        startLatitude: 48.8566,
      );
      
      final advanced = RouteParameters.advancedPreset(
        startLongitude: 2.3522,
        startLatitude: 48.8566,
      );

      expect(beginner.isValid, true);
      expect(intermediate.isValid, true);
      expect(advanced.isValid, true);
      
      // Vérifier la progression logique
      expect(beginner.distanceKm < intermediate.distanceKm, true);
      expect(intermediate.distanceKm < advanced.distanceKm, true);
      expect(beginner.maxInclinePercent <= advanced.maxInclinePercent, true);
    });

    test('utilise les helpers pour différents types d\'activité', () {
      final runningRoute = TestHelpers.createValidRunningRoute();
      final cyclingRoute = TestHelpers.createValidCyclingRoute();

      expect(runningRoute.isValid, true);
      expect(cyclingRoute.isValid, true);
      expect(runningRoute.activityType, ActivityType.running);
      expect(cyclingRoute.activityType, ActivityType.cycling);
      expect(cyclingRoute.distanceKm > runningRoute.distanceKm, true);
    });

    test('gère les valeurs limites', () {
      final minParams = TestHelpers.createMockParameters(
        activityType: ActivityType.walking,
        distanceKm: ActivityType.walking.minDistance,
        elevationRange: const ElevationRange(min: 0, max: 0),
        maxInclinePercent: 1.0,
        preferredWaypoints: 0,
        surfacePreference: 1.0,
      );

      expect(minParams.isValid, true);
    });

    test('valide les contraintes d\'élévation', () {
      final invalidElevation = TestHelpers.createMockParameters(
        elevationRange: const ElevationRange(min: 100, max: 50), // min > max
      );

      expect(invalidElevation.isValid, false);
    });

    test('valide les contraintes d\'inclinaison', () {
      final invalidIncline = TestHelpers.createMockParameters(
        maxInclinePercent: 30.0, // > 25%
      );

      expect(invalidIncline.isValid, false);
    });

    test('valide le nombre de waypoints', () {
      final tooManyWaypoints = TestHelpers.createMockParameters(
        preferredWaypoints: 15, // > 10
      );

      expect(tooManyWaypoints.isValid, false);
    });

    test('copie avec modifications', () {
      final original = TestHelpers.createValidRunningRoute();
      
      final modified = original.copyWith(distanceKm: 8.0);
      
      expect(modified.distanceKm, 8.0);
      expect(modified.activityType, original.activityType);
      expect(modified.elevationRange, original.elevationRange);
    });

    test('compare l\'égalité correctement', () {
      final params1 = TestHelpers.createMockParameters(distanceKm: 5.0);
      final params2 = TestHelpers.createMockParameters(distanceKm: 5.0);
      final params3 = TestHelpers.createMockParameters(distanceKm: 10.0);

      expect(params1, equals(params2));
      expect(params1, isNot(equals(params3)));
    });

    test('génère un hashCode cohérent', () {
      final params1 = TestHelpers.createMockParameters(distanceKm: 5.0);
      final params2 = TestHelpers.createMockParameters(distanceKm: 5.0);

      expect(params1.hashCode, equals(params2.hashCode));
    });

    test('gère les types de terrain', () {
      final flatRoute = TestHelpers.createMockParameters(
        terrainType: TerrainType.flat,
      );
      final hillyRoute = TestHelpers.createMockParameters(
        terrainType: TerrainType.hilly,
      );

      expect(flatRoute.terrainType, TerrainType.flat);
      expect(hillyRoute.terrainType, TerrainType.hilly);
      expect(flatRoute.isValid, true);
      expect(hillyRoute.isValid, true);
    });

    test('gère les densités urbaines', () {
      final urbanRoute = TestHelpers.createMockParameters(
        urbanDensity: UrbanDensity.urban,
      );
      final natureRoute = TestHelpers.createMockParameters(
        urbanDensity: UrbanDensity.nature,
      );

      expect(urbanRoute.urbanDensity, UrbanDensity.urban);
      expect(natureRoute.urbanDensity, UrbanDensity.nature);
      expect(urbanRoute.isValid, true);
      expect(natureRoute.isValid, true);
    });
  });
}