// test/unit/services/credit_verification_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/credits/data/services/credit_verification_service.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';

import '../../helpers/test_helpers.dart';
import '../mocks/mock_generator.mocks.dart';

@GenerateMocks([AppDataBloc])
void main() {
  group('CreditVerificationService', () {
    late CreditVerificationService service;
    late MockAppDataBloc mockAppDataBloc;
    late CreditsRepository creditsRepository;
    late CreditsBloc creditsBloc;

    setUp(() {
      mockAppDataBloc = MockAppDataBloc();
      creditsRepository = CreditsRepository();
      creditsBloc = CreditsBloc();
      service = CreditVerificationService(
        appDataBloc: mockAppDataBloc, 
        creditsRepository: creditsRepository, 
        creditsBloc: creditsBloc,
      );
    });

    test('vérifie correctement les crédits suffisants', () async {
      // Utiliser TestHelpers pour créer des crédits valides
      final userCredits = TestHelpers.createCreditsWithSufficientBalance();
      
      final state = AppDataState(
        userCredits: userCredits,
        isCreditDataLoaded: true,
      );
      
      when(mockAppDataBloc.state).thenReturn(state);

      final result = await service.canGenerateRoute();
      expect(result, true);
    });

    test('détecte les crédits insuffisants', () async {
      // Utiliser TestHelpers pour créer des crédits insuffisants
      final userCredits = TestHelpers.createCreditsWithInsufficientBalance();
      
      final state = AppDataState(
        userCredits: userCredits,
        isCreditDataLoaded: true,
      );
      
      when(mockAppDataBloc.state).thenReturn(state);

      final result = await service.canGenerateRoute();
      expect(result, false);
    });

    test('gère l\'absence de données de crédits', () async {
      // Simuler état sans données
      final state = AppDataState(
        userCredits: null,
        isCreditDataLoaded: false,
      );
      
      when(mockAppDataBloc.state).thenReturn(state);

      final result = await service.canGenerateRoute();
      expect(result, false);
    });

    test('retourne le nombre correct de crédits disponibles', () async {
      // Utiliser TestHelpers avec des crédits personnalisés
      final userCredits = TestHelpers.createMockCredits(
        availableCredits: 5,
        totalCredits: 10,
      );
      
      final state = AppDataState(
        userCredits: userCredits,
        isCreditDataLoaded: true,
      );
      
      when(mockAppDataBloc.state).thenReturn(state);

      final credits = await service.getAvailableCredits();
      expect(credits, 5);
    });

    test('gère un nouvel utilisateur sans crédits', () async {
      // Utiliser TestHelpers pour un nouvel utilisateur
      final userCredits = TestHelpers.createNewUserCredits();
      
      final state = AppDataState(
        userCredits: userCredits,
        isCreditDataLoaded: true,
      );
      
      when(mockAppDataBloc.state).thenReturn(state);

      final result = await service.canGenerateRoute();
      expect(result, false);
      
      final credits = await service.getAvailableCredits();
      expect(credits, 0);
    });

    test('gère les données de crédits non chargées', () async {
      // Crédits existants mais données pas encore chargées
      final userCredits = TestHelpers.createCreditsWithSufficientBalance();
      
      final state = AppDataState(
        userCredits: userCredits,
        isCreditDataLoaded: false, // Pas chargé
      );
      
      when(mockAppDataBloc.state).thenReturn(state);

      final result = await service.canGenerateRoute();
      expect(result, false); // Devrait retourner false si données non chargées
    });

    test('retourne 0 crédits si userCredits est null', () async {
      final state = AppDataState(
        userCredits: null,
        isCreditDataLoaded: true,
      );
      
      when(mockAppDataBloc.state).thenReturn(state);

      final credits = await service.getAvailableCredits();
      expect(credits, 0);
    });

    test('vérifie que ensureCreditDataLoaded ne lève pas d\'exception', () {
      // Test que la méthode peut être appelée sans erreur
      expect(() => service.ensureCreditDataLoaded(), returnsNormally);
    });
  });
}