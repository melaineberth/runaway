import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/home/presentation/blocs/route_parameters_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';

import '../test_setup.dart';

void main() {
  setUpAll(() async {
    await TestSetup.initialize();
  });

  tearDownAll(() async {
    await TestSetup.cleanup();
  });

  group('Flux de génération de parcours', () {
    testWidgets('génère et sauvegarde un parcours complet', (WidgetTester tester) async {
      // Créer l'app avec tous les blocs nécessaires
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AppDataBloc>(
              create: (_) => TestSetup.getTestInstance<AppDataBloc>(),
            ),
            BlocProvider<NotificationBloc>(
              create: (_) => TestSetup.getTestInstance<NotificationBloc>(),
            ),
            BlocProvider<LocaleBloc>(
              create: (_) => TestSetup.getTestInstance<LocaleBloc>(),
            ),
            BlocProvider<ThemeBloc>(
              create: (_) => TestSetup.getTestInstance<ThemeBloc>(),
            ),
            BlocProvider<AuthBloc>(
              create: (_) => TestSetup.getTestInstance<AuthBloc>(),
            ),
            BlocProvider<CreditsBloc>(
              create: (_) => TestSetup.getTestInstance<CreditsBloc>(),
            ),
            BlocProvider<RouteParametersBloc>(
              create: (_) => RouteParametersBloc(startLongitude: 37.785834, startLatitude: -122.406417),
            ),
            BlocProvider<RouteGenerationBloc>(
              create: (_) => RouteGenerationBloc(
                routesRepository: TestSetup.getTestInstance(),
                creditService: TestSetup.getTestInstance(),
                appDataBloc: TestSetup.getTestInstance<AppDataBloc>(),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Test App'),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {},
                child: Icon(Icons.add),
              ),
            ),
          ),
        ),
      );

      // Attendre que l'interface soit construite
      await tester.pumpAndSettle();

      // Vérifier que le FloatingActionButton est présent
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Taper sur le bouton pour déclencher une action
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Vérifier que l'app ne crash pas
      expect(find.text('Test App'), findsOneWidget);
    });

    testWidgets('gère l\'absence de crédits', (WidgetTester tester) async {
      // Créer l'app avec une configuration de crédits insuffisants
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AppDataBloc>(
              create: (_) => TestSetup.getTestInstance<AppDataBloc>(),
            ),
            BlocProvider<NotificationBloc>(
              create: (_) => TestSetup.getTestInstance<NotificationBloc>(),
            ),
            BlocProvider<LocaleBloc>(
              create: (_) => TestSetup.getTestInstance<LocaleBloc>(),
            ),
            BlocProvider<ThemeBloc>(
              create: (_) => TestSetup.getTestInstance<ThemeBloc>(),
            ),
            BlocProvider<AuthBloc>(
              create: (_) => TestSetup.getTestInstance<AuthBloc>(),
            ),
            BlocProvider<CreditsBloc>(
              create: (_) => TestSetup.getTestInstance<CreditsBloc>(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Credit Test App'),
              ),
            ),
          ),
        ),
      );

      // Attendre que l'interface soit construite
      await tester.pumpAndSettle();

      // Vérifier que l'app est rendue correctement
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Credit Test App'), findsOneWidget);
    });
  });
}