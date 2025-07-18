import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
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

import '../mocks/mock_generator.mocks.dart';

@GenerateMocks([RoutesRepository, CreditVerificationService, AppDataBloc])
void main() async {
  // 👉 Initialise un storage temporaire
  TestWidgetsFlutterBinding.ensureInitialized();

  final tempDir = await Directory.systemTemp.createTemp();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(tempDir.path),
  );
  
  group('RouteGenerationBloc', () {
    late RouteGenerationBloc bloc;
    late MockRoutesRepository mockRepository;
    late MockCreditVerificationService mockCreditService;
    late MockAppDataBloc mockAppDataBloc;
    late MockMapboxMap mockMapboxMap;
    late RouteParameters mockParameters;
    late MockConnectivityService mockConnectivityService;
    late MockScreenshotService mockScreenshotService;

    setUp(() {
      mockRepository = MockRoutesRepository();
      mockCreditService = MockCreditVerificationService();
      mockAppDataBloc = MockAppDataBloc();
      mockMapboxMap = MockMapboxMap();
      mockConnectivityService = MockConnectivityService();
      mockScreenshotService = MockScreenshotService();
      
      mockParameters = RouteParameters(
        activityType: ActivityType.running,
        terrainType: TerrainType.flat,
        urbanDensity: UrbanDensity.urban,
        distanceKm: 5.0,
        elevationRange: const ElevationRange(min: 0, max: 100),
        difficulty: DifficultyLevel.easy,
        maxInclinePercent: 5.0,
        preferredWaypoints: 2,
        avoidHighways: true,
        prioritizeParks: false,
        surfacePreference: 0.8,
        isLoop: false,
        startLongitude: 2.3522,
        startLatitude: 48.8566,
      );

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
      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'génère une route avec succès',
        build: () {
          // when(mockConnectivityService.isOnline).thenAnswer((_) async => true);
          when(mockCreditService.canGenerateRoute()).thenAnswer((_) async => true);
          when(mockCreditService.canGenerateRoute()).thenAnswer((_) async => false);
          return bloc;
        },
        act: (bloc) => bloc.add(RouteGenerationRequested(mockParameters)),
        expect: () => [
          isA<RouteGenerationState>()
              .having((s) => s.isGeneratingRoute, 'isGeneratingRoute', true),
          isA<RouteGenerationState>()
              .having((s) => s.isGeneratingRoute, 'isGeneratingRoute', false)
              .having((s) => s.generatedRoute, 'generatedRoute', isNotNull)
              .having((s) => s.errorMessage, 'errorMessage', isNull),
        ],
      );

      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'échoue si crédits insuffisants',
        build: () {
          when(mockCreditService.canGenerateRoute()).thenAnswer((_) async => false);
          return bloc;
        },
        act: (bloc) => bloc.add(RouteGenerationRequested(mockParameters)),
        expect: () => [
          isA<RouteGenerationState>()
              .having((s) => s.errorMessage, 'errorMessage', isNotNull)
              .having((s) => s.isGeneratingRoute, 'isGeneratingRoute', false),
        ],
      );

      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'gère les erreurs réseau',
        build: () {
          when(mockCreditService.canGenerateRoute()).thenAnswer((_) async => true);
          when(mockCreditService.canGenerateRoute()).thenAnswer((_) async => false);
          return bloc;
        },
        act: (bloc) => bloc.add(RouteGenerationRequested(mockParameters)),
        expect: () => [
          isA<RouteGenerationState>()
              .having((s) => s.isGeneratingRoute, 'isGeneratingRoute', true),
          isA<RouteGenerationState>()
              .having((s) => s.isGeneratingRoute, 'isGeneratingRoute', false)
              .having((s) => s.errorMessage, 'errorMessage', contains('Erreur')),
        ],
      );
    });

    group('Route Saving', () {
      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'sauvegarde une route avec succès',
        build: () {
          when(mockScreenshotService.captureAndUploadMapSnapshot(liveMap: mockMapboxMap, routeCoords: [], routeId: '', userId: ''))
              .thenAnswer((_) async => 'mocked_url');
          when(mockRepository.saveRoute(name: anyNamed('name'), parameters: anyNamed('parameters'), coordinates: anyNamed('coordinates')))
              .thenAnswer((_) async => SavedRoute(
                id: 'test-route',
                name: 'Test Route',
                parameters: mockParameters,
                coordinates: [[2.3522, 48.8566]],
                createdAt: DateTime.now(),
              ));
          return bloc;
        },
        seed: () => RouteGenerationState(
          generatedRoute: [[2.3522, 48.8566]],
          usedParameters: mockParameters,
        ),
        act: (bloc) => bloc.add(GeneratedRouteSaved('Test Route', map: mockMapboxMap)),
        expect: () => [
          isA<RouteGenerationState>()
              .having((s) => s.isSavingRoute, 'isSavingRoute', true),
          isA<RouteGenerationState>()
              .having((s) => s.isSavingRoute, 'isSavingRoute', false)
              .having((s) => s.savedRoutes, 'savedRoutes', hasLength(1)),
        ],
      );
    });

    group('Route Loading', () {
      blocTest<RouteGenerationBloc, RouteGenerationState>(
        'charge une route sauvegardée',
        build: () {
          final savedRoute = SavedRoute(
            id: 'test-route',
            name: 'Test Route',
            parameters: mockParameters,
            coordinates: [[2.3522, 48.8566]],
            createdAt: DateTime.now(),
          );
          
          when(mockRepository.getUserRoutes())
              .thenAnswer((_) async => [savedRoute]);
          return bloc;
        },
        act: (bloc) => bloc.add(SavedRouteLoaded('test-route')),
        expect: () => [
          isA<RouteGenerationState>()
              .having((s) => s.generatedRoute, 'generatedRoute', isNotNull)
              .having((s) => s.isLoadedFromHistory, 'isLoadedFromHistory', true),
        ],
      );
    });
  });
}
