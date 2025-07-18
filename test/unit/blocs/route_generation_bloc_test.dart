import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/features/credits/data/services/credit_verification_service.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_event.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_state.dart';
import 'package:runaway/features/route_generator/data/services/screenshot_service.dart';

import '../../test_setup.dart';
import '../mocks/mock_generator.mocks.dart';

@GenerateMocks([RoutesRepository, CreditVerificationService, AppDataBloc, ScreenshotService])
void main() {
  setUpAll(() async {
    await TestSetup.initialize();
  });

  tearDownAll(() async {
    await TestSetup.cleanup();
  });
  
  group('RouteGenerationBloc', () {
    late RouteGenerationBloc bloc;
    late MockRoutesRepository mockRepository;
    late MockCreditVerificationService mockCreditService;
    late MockAppDataBloc mockAppDataBloc;
    late MockScreenshotService mockScreenshotService;
    late MockMapboxMap mockMapboxMap;

    setUp(() {
      mockRepository = MockRoutesRepository();
      mockCreditService = MockCreditVerificationService();
      mockAppDataBloc = MockAppDataBloc();
      mockScreenshotService = MockScreenshotService();
      mockMapboxMap = MockMapboxMap();
      
      // Configuration des mocks par défaut
      when(mockCreditService.canGenerateRoute()).thenAnswer((_) async => true);
      when(mockCreditService.getAvailableCredits()).thenAnswer((_) async => 5);
      when(mockScreenshotService.captureAndUploadMapSnapshot(
        liveMap: mockMapboxMap, 
        routeCoords: [], 
        routeId: '', 
        userId: '',
        )).thenAnswer((_) async => 'test_screenshot_url');
      
      bloc = RouteGenerationBloc(
        routesRepository: mockRepository,
        creditService: mockCreditService,
        appDataBloc: mockAppDataBloc,
      );
    });

    tearDown(() {
      bloc.close();
    });

    group('Route Generation', () {
      final testRouteParams = RouteParameters(
        activityType: ActivityType.cycling,
        terrainType: TerrainType.mixed,
        urbanDensity: UrbanDensity.urban,
        startLatitude: 48.8566,
        startLongitude: 2.3522, 
        distanceKm: 10, 
        elevationRange: ElevationRange(min: 1, max: 800),
      );

      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'génère une route avec succès',
        build: () {
          // Mock de la génération interne (GraphHopper API) 
          // Note: La génération se fait dans le bloc, pas dans le repository
          return bloc;
        },
        act: (bloc) => bloc.add(RouteGenerationRequested(testRouteParams)),
        expect: () => [
          isA<RouteGenerationState>().having(
            (state) => state.isGeneratingRoute, 
            'isGeneratingRoute', 
            true
          ),
          // Le test peut échouer car il faut mocker GraphHopper API
          // On s'attend à une erreur ou succès selon le mock
        ],
        verify: (_) {
          verify(mockCreditService.canGenerateRoute()).called(1);
        },
      );

      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'échoue si crédits insuffisants',
        build: () {
          when(mockCreditService.canGenerateRoute()).thenAnswer((_) async => false);
          when(mockCreditService.getAvailableCredits()).thenAnswer((_) async => 0);
          return bloc;
        },
        act: (bloc) => bloc.add(RouteGenerationRequested(testRouteParams)),
        expect: () => [
          isA<RouteGenerationState>()
              .having((state) => state.errorMessage, 'errorMessage', isNotNull)
              .having((state) => state.isGeneratingRoute, 'isGeneratingRoute', false),
        ],
        verify: (_) {
          verify(mockCreditService.canGenerateRoute()).called(1);
        },
      );

      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'gère les erreurs réseau',
        build: () {
          when(mockCreditService.canGenerateRoute()).thenAnswer((_) async => true);
          // La génération échouera car GraphHopper n'est pas mocké
          return bloc;
        },
        act: (bloc) => bloc.add(RouteGenerationRequested(testRouteParams)),
        expect: () => [
          isA<RouteGenerationState>().having(
            (state) => state.isGeneratingRoute, 
            'isGeneratingRoute', 
            true
          ),
          isA<RouteGenerationState>()
              .having((state) => state.isGeneratingRoute, 'isGeneratingRoute', false)
              .having((state) => state.errorMessage, 'errorMessage', contains('Erreur')),
        ],
      );
    });

    group('Route Saving', () {
      final testRouteParams = RouteParameters(
        activityType: ActivityType.cycling,
        terrainType: TerrainType.mixed,
        urbanDensity: UrbanDensity.urban,
        startLatitude: 48.8566,
        startLongitude: 2.3522, 
        distanceKm: 10, 
        elevationRange: ElevationRange(min: 1, max: 800),
      );

      final testRoute = SavedRoute(
        id: 'test_route_id',
        name: 'Test Route',
        coordinates: [],
        createdAt: DateTime.now(), 
        parameters: testRouteParams,
      );

      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'sauvegarde une route avec succès',
        build: () {
          when(mockRepository.saveRoute(
            name: anyNamed('name'),
            parameters: anyNamed('parameters'),
            coordinates: anyNamed('coordinates'),
            actualDistance: anyNamed('actualDistance'),
            estimatedDuration: anyNamed('estimatedDuration'),
            imageUrl: anyNamed('imageUrl'),
          )).thenAnswer((_) async => testRoute);
          
          return bloc;
        },
        seed: () => RouteGenerationState(
          generatedRoute: [[2.3522, 48.8566]],
          usedParameters: testRouteParams,
        ),
        act: (bloc) => bloc.add(GeneratedRouteSaved('My Saved Route', map: mockMapboxMap)),
        expect: () => [
          isA<RouteGenerationState>().having(
            (state) => state.isSavingRoute, 
            'isSavingRoute', 
            true
          ),
          isA<RouteGenerationState>()
              .having((state) => state.isSavingRoute, 'isSavingRoute', false)
              .having((state) => state.errorMessage, 'errorMessage', isNull),
        ],
        verify: (_) {
          verify(mockRepository.saveRoute(
            name: anyNamed('name'),
            parameters: anyNamed('parameters'),
            coordinates: anyNamed('coordinates'),
            actualDistance: anyNamed('actualDistance'),
            estimatedDuration: anyNamed('estimatedDuration'),
            imageUrl: anyNamed('imageUrl'),
          )).called(1);
        },
      );
    });

    group('Route Loading', () {
      final testRouteParams = RouteParameters(
        activityType: ActivityType.cycling,
        terrainType: TerrainType.mixed,
        urbanDensity: UrbanDensity.urban,
        startLatitude: 48.8566,
        startLongitude: 2.3522, 
        distanceKm: 10, 
        elevationRange: ElevationRange(min: 1, max: 800),
      );

      final testRoute = SavedRoute(
        id: 'test_route_id',
        name: 'Test Route',
        coordinates: [],
        createdAt: DateTime.now(), 
        parameters: testRouteParams,
      );

      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'charge une route sauvegardée',
        build: () {
          when(mockRepository.getUserRoutes()).thenAnswer(
            (_) async => [testRoute],
          );
          return bloc;
        },
        act: (bloc) => bloc.add(SavedRouteLoaded('test_route_id')),
        expect: () => [
          isA<RouteGenerationState>()
              .having((state) => state.generatedRoute, 'generatedRoute', isNotNull)
              .having((state) => state.isLoadedFromHistory, 'isLoadedFromHistory', true),
        ],
        verify: (_) {
          verify(mockRepository.getUserRoutes()).called(1);
        },
      );
    });

    group('Route Deletion', () {
      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'supprime une route avec succès',
        build: () {
          when(mockRepository.deleteRoute(any)).thenAnswer((_) async => {});
          return bloc;
        },
        act: (bloc) => bloc.add(SavedRouteDeleted('test_route_id')),
        expect: () => [
          isA<RouteGenerationState>()
              .having((state) => state.errorMessage, 'errorMessage', isNull),
        ],
        verify: (_) {
          verify(mockRepository.deleteRoute('test_route_id')).called(1);
        },
      );
    });

    group('Saved Routes Management', () {
      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'charge la liste des routes sauvegardées',
        build: () {
          when(mockRepository.getUserRoutes()).thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) => bloc.add(SavedRoutesRequested()),
        expect: () => [
          isA<RouteGenerationState>().having(
            (state) => state.isAnalyzingZone, 
            'isAnalyzingZone', 
            true
          ),
          isA<RouteGenerationState>()
              .having((state) => state.isAnalyzingZone, 'isAnalyzingZone', false)
              .having((state) => state.savedRoutes, 'savedRoutes', isEmpty),
        ],
      );
    });
  });
}