import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/data/services/credit_verification_service.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';

import '../../helpers/test_helpers.dart';
import '../../test_setup.dart';

// Mock classes
class MockCreditsRepository extends Mock implements CreditsRepository {}
class MockCreditsBloc extends Mock implements CreditsBloc {}
class MockAppDataBloc extends Mock implements AppDataBloc {}

@GenerateMocks([CreditsRepository, CreditsBloc, AppDataBloc])
void main() {
  setUpAll(() async {
    await TestSetup.initialize();
  });

  tearDownAll(() async {
    await TestSetup.cleanup();
  });

  group('CreditVerificationService', () {
    late CreditVerificationService service;
    late MockCreditsRepository mockCreditsRepository;
    late MockCreditsBloc mockCreditsBloc;
    late MockAppDataBloc mockAppDataBloc;

    setUp(() {
      mockCreditsRepository = MockCreditsRepository();
      mockCreditsBloc = MockCreditsBloc();
      mockAppDataBloc = MockAppDataBloc();
      
      service = CreditVerificationService(
        creditsRepository: mockCreditsRepository,
        creditsBloc: mockCreditsBloc,
        appDataBloc: mockAppDataBloc,
      );
    });

    group('Credit Verification', () {
      test('vérifie correctement les crédits suffisants', () async {
        // Arrange
        final userCredits = TestHelpers.createCreditsWithInsufficientBalance();

        when(mockCreditsRepository.getUserCredits()).thenAnswer((_) async => userCredits);

        // Act  
        final result = await service.verifyCreditsForGeneration(requiredCredits: 5);

        // Assert
        expect(result.hasEnoughCredits, true);
        expect(result.availableCredits, 7);
        expect(result.requiredCredits, 5);
        verify(mockCreditsRepository.getUserCredits()).called(1);
      });

      test('détecte les crédits insuffisants', () async {
        // Arrange
        final userCredits = TestHelpers.createCreditsWithInsufficientBalance();

        when(mockCreditsRepository.getUserCredits()).thenAnswer((_) async => userCredits);

        // Act
        final result = await service.verifyCreditsForGeneration(requiredCredits: 5);

        // Assert
        expect(result.hasEnoughCredits, false);
        expect(result.availableCredits, 2);
        expect(result.requiredCredits, 5);
        verify(mockCreditsRepository.getUserCredits()).called(1);
      });

      test('gère l\'absence de données de crédits', () async {
        // Arrange
        when(mockCreditsRepository.getUserCredits());

        // Act
        final result = await service.verifyCreditsForGeneration(requiredCredits: 1);

        // Assert
        expect(result.hasEnoughCredits, false);
        expect(result.availableCredits, 0);
        verify(mockCreditsRepository.getUserCredits()).called(1);
      });

      test('retourne le nombre correct de crédits disponibles', () async {
        // Arrange
        final userCredits = TestHelpers.createCreditsWithInsufficientBalance();

        when(mockCreditsRepository.getUserCredits()).thenAnswer((_) async => userCredits);

        // Act
        final availableCredits = await service.getAvailableCredits();

        // Assert
        expect(availableCredits, 10);
      });

      test('gère un nouvel utilisateur sans crédits', () async {
        // Arrange
        when(mockCreditsRepository.getUserCredits());

        // Act
        final result = await service.verifyCreditsForGeneration(requiredCredits: 1);
        final availableCredits = await service.getAvailableCredits();

        // Assert
        expect(result.hasEnoughCredits, false);
        expect(availableCredits, 0);
      });

      test('gère les données de crédits non chargées', () async {
        // Arrange
        when(mockCreditsRepository.getUserCredits()).thenThrow(Exception('Network error'));

        // Act & Assert
        final result = await service.verifyCreditsForGeneration(requiredCredits: 1);
        expect(result.hasEnoughCredits, false);
        expect(result.errorMessage, isNotNull);
      });

      test('retourne 0 crédits si userCredits est null', () async {
        // Arrange
        when(mockCreditsRepository.getUserCredits());
        // Act
        final availableCredits = await service.getAvailableCredits();

        // Assert
        expect(availableCredits, 0);
      });

      test('vérifie que ensureCreditDataLoaded ne lève pas d\'exception', () async {
        // Act & Assert
        expect(() => service.ensureCreditDataLoaded(), returnsNormally);
      });
    });

    group('Credit Consumption', () {
      test('consomme les crédits avec succès', () async {
        // Act
        final result = await service.consumeCreditsForGeneration(
          amount: 1,
          generationId: 'test_generation',
          metadata: {'test': 'data'},
        );

        // Assert
        expect(result.success, true);
        // En mode test, on peut avoir différents résultats selon les mocks
      });

      test('échoue si pas assez de crédits pour la consommation', () async {
        final userCredits = TestHelpers.createCreditsWithInsufficientBalance();

        when(mockCreditsRepository.getUserCredits()).thenAnswer((_) async => userCredits);

        // Act
        final verificationResult = await service.verifyCreditsForGeneration(requiredCredits: 5);

        // Assert
        expect(verificationResult.hasEnoughCredits, false);
      });
    });
  });
}