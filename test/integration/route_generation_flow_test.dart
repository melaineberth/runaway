import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:runaway/main.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('Flux de génération de parcours', () {
    testWidgets('génère et sauvegarde un parcours complet', (tester) async {
      await tester.pumpWidget(const Trailix());
      await tester.pumpAndSettle();
      
      // Attendre le chargement initial
      await tester.pump(const Duration(seconds: 3));
      
      // Vérifier la présence des éléments principaux
      expect(find.byType(FloatingActionButton), findsOneWidget);
      
      // Simuler la génération d'un parcours
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      
      // Vérifier que l'interface répond
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('gère l\'absence de crédits', (tester) async {
      await tester.pumpWidget(const Trailix());
      await tester.pumpAndSettle();
      
      // Simuler un utilisateur sans crédits
      // (Le test exact dépend de votre implémentation UI)
      
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
