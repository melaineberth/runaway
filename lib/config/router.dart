import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/core/widgets/main_scaffold.dart';
import 'package:runaway/features/account/presentation/screens/account_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return MainScaffold(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/activity',
          pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: Scaffold(backgroundColor: Colors.black, body: Center(child: Text("Activity")))),
        ),
        GoRoute(
          path: '/historic',
          pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: Scaffold(backgroundColor: Colors.black, body: Center(child: Text("Historic")))),
        ),
        GoRoute(
          path: '/account',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const AccountScreen(),
          ),
        ),
      ],
    ),
  ],
);
