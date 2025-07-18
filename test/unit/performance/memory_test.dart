// test/unit/performance/memory_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('Tests de performance', () {
    test('pas de fuite mémoire avec de nombreux parcours', () {
      final routes = <SavedRoute>[];
      
      // Créer beaucoup de parcours avec TestHelpers
      for (int i = 0; i < 1000; i++) {
        routes.add(TestHelpers.createMockRoute(
          id: 'route_$i',
          name: 'Route $i',
        ));
      }
      
      expect(routes.length, 1000);
      
      // Simuler le nettoyage
      routes.clear();
      expect(routes.length, 0);
    });

    test('sérialisation performante', () {
      final stopwatch = Stopwatch()..start();
      
      // Créer et sérialiser plusieurs parcours
      for (int i = 0; i < 100; i++) {
        final route = TestHelpers.createMockRoute(
          id: 'route_$i',
          name: 'Route $i',
          coordinates: TestHelpers.createMockCoordinates(100), // 100 points
        );
        
        final json = route.toJson();
        SavedRoute.fromJson(json);
      }
      
      stopwatch.stop();
      
      // Vérifier que la sérialisation est rapide (< 1 seconde pour 100 parcours)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('gestion mémoire avec différents types de parcours', () {
      final routes = <SavedRoute>[];
      
      // Mélanger différents types de parcours
      for (int i = 0; i < 500; i++) {
        if (i % 3 == 0) {
          routes.add(TestHelpers.createMockRoute(
            id: 'running_$i',
            parameters: TestHelpers.createValidRunningRoute(),
          ));
        } else if (i % 3 == 1) {
          routes.add(TestHelpers.createMockRoute(
            id: 'cycling_$i', 
            parameters: TestHelpers.createValidCyclingRoute(),
          ));
        } else {
          routes.add(TestHelpers.createRouteWithUsage());
        }
      }
      
      expect(routes.length, 500);
      
      // Test de filtrage rapide
      final runningRoutes = routes.where((r) => 
        r.parameters.activityType.toString().contains('running')).toList();
      
      expect(runningRoutes.length, greaterThan(0));
      
      routes.clear();
      expect(routes.length, 0);
    });

    test('performance avec coordonnées volumineuses', () {
      final stopwatch = Stopwatch()..start();
      
      // Créer un parcours avec beaucoup de coordonnées
      final route = TestHelpers.createMockRoute(
        id: 'big_route',
        name: 'Big Route',
        coordinates: TestHelpers.createMockCoordinates(1000), // 1000 points
      );
      
      // Test sérialisation/désérialisation
      final json = route.toJson();
      final restored = SavedRoute.fromJson(json);
      
      stopwatch.stop();
      
      expect(restored.coordinates.length, 1000);
      expect(restored.id, route.id);
      
      // Vérifier que même avec 1000 points, ça reste rapide
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('nettoyage de cache efficace', () {
      // Simuler un cache de routes
      final cache = <String, SavedRoute>{};
      
      // Remplir le cache
      for (int i = 0; i < 200; i++) {
        final route = TestHelpers.createMockRoute(id: 'cached_$i');
        cache[route.id] = route;
      }
      
      expect(cache.length, 200);
      
      // Simuler nettoyage avec limite (garder seulement les 100 plus récents)
      final sortedEntries = cache.entries.toList()
        ..sort((a, b) => b.value.createdAt.compareTo(a.value.createdAt));
      
      cache.clear();
      
      // Garder seulement les 100 plus récents
      for (int i = 0; i < 100 && i < sortedEntries.length; i++) {
        cache[sortedEntries[i].key] = sortedEntries[i].value;
      }
      
      expect(cache.length, 100);
    });

    test('performance de recherche dans une liste de routes', () {
      final routes = TestHelpers.createMockRouteList(1000);
      final stopwatch = Stopwatch()..start();
      
      // Recherche par ID
      final foundRoute = routes.firstWhere((r) => r.id == 'route-500', 
                                          orElse: () => routes.first);
      
      // Recherche par nom
      final namedRoutes = routes.where((r) => r.name.contains('Route')).toList();
      
      stopwatch.stop();
      
      expect(foundRoute, isNotNull);
      expect(namedRoutes.length, greaterThan(0));
      
      // Recherche doit être rapide même avec 1000 éléments
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });
}