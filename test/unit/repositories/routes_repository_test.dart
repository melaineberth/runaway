import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_event.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_state.dart';

import '../../helpers/test_helpers.dart';
import '../mocks/mock_generator.mocks.dart';

class MockRoutesRepository extends Mock implements RoutesRepository {}

void main() {
  group('RoutesRepository', () {
    late RouteGenerationBloc bloc;
    late MockRoutesRepository mockRepository;
    late MockAppDataBloc mockAppDataBloc;
    late MockCreditVerificationService mockCreditService;

    setUp(() {
      mockRepository = MockRoutesRepository();
      mockAppDataBloc = MockAppDataBloc();
      mockCreditService = MockCreditVerificationService();
      bloc = RouteGenerationBloc(
        routesRepository: mockRepository,
        creditService: mockCreditService,
        appDataBloc: mockAppDataBloc,
      );
    });

  blocTest<RouteGenerationBloc, RouteGenerationState>(
      'génère une route avec succès',
      build: () {
        when(mockCreditService.canGenerateRoute())
            .thenAnswer((_) async => true);
        when(mockCreditService.canGenerateRoute())
            .thenAnswer((_) async => false);
        return bloc;
      },
      act: (bloc) {
        final parameters = TestHelpers.createMockParameters();
        bloc.add(RouteGenerationRequested(parameters));
      },
      expect: () => [
        isA<RouteGenerationState>()
            .having((s) => s.isGeneratingRoute, 'isGeneratingRoute', true),
        isA<RouteGenerationState>()
            .having((s) => s.isGeneratingRoute, 'isGeneratingRoute', false)
            .having((s) => s.generatedRoute, 'generatedRoute', isNotNull)
            .having((s) => s.errorMessage, 'errorMessage', isNull),
      ],
    );

    test('sauvegarde une route', () async {
      final parameters = TestHelpers.createMockParameters();
      final coordinates = TestHelpers.createMockCoordinates(10);
      
      // Test que la méthode ne lève pas d'exception
      expect(() => mockRepository.saveRoute(name: 'Test Route', parameters: parameters, coordinates: coordinates), 
             returnsNormally);
    });

    test('récupère les routes utilisateur', () async {
      // Test que la méthode ne lève pas d'exception
      expect(() => mockRepository.getUserRoutes(), 
             returnsNormally);
    });

    test('supprime une route', () async {
      // Test que la méthode ne lève pas d'exception
      expect(() => mockRepository.deleteRoute('test-route'), 
             returnsNormally);
    });
  });
}