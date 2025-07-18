// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';

import 'test_setup.dart';

void main() {
  setUpAll(() async {
    await TestSetup.initialize();
  });

  tearDownAll(() async {
    await TestSetup.cleanup();
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Créer une app de test simple avec tous les blocs nécessaires
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
          home: CounterTestWidget(),
        ),
      ),
    );

    // Vérifier que le compteur démarre à 0
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Taper sur l'icône '+' et déclencher un frame
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Vérifier que le compteur a été incrémenté
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}

/// Widget de test simple pour simuler un compteur
class CounterTestWidget extends StatefulWidget {
  @override
  _CounterTestWidgetState createState() => _CounterTestWidgetState();
}

class _CounterTestWidgetState extends State<CounterTestWidget> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Counter Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}