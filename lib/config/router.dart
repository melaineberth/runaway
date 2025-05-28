import 'package:go_router/go_router.dart';
import '../features/home/presentation/screens/home_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    // GoRoute(
    //   path: '/parameters',
    //   builder: (context, state) => const ParameterSelectionScreen(),
    // ),
    // GoRoute(
    //   path: '/route-preview',
    //   builder: (context, state) => const RoutePreviewScreen(),
    // ),
    // GoRoute(
    //   path: '/map',
    //   builder: (context, state) => const MapScreen(),
    // ),
  ],
);
