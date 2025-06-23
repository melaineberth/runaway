import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/core/widgets/main_scaffold.dart';
import 'package:runaway/features/account/presentation/screens/account_screen.dart';
import 'package:runaway/features/activity/presentation/screens/activity_screen.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/screens/login_screen.dart';
import 'package:runaway/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:runaway/features/auth/presentation/screens/signup_screen.dart';
import 'package:runaway/features/historic/presentation/screens/historic_screen.dart';
import 'package:runaway/features/navigation/presentation/screens/navigation_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';

// Clé globale pour accéder au contexte du router
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  
  // Redirection globale basée sur l'état d'authentification
  redirect: (BuildContext context, GoRouterState state) {
    final authBloc = context.read<AuthBloc>();
    final authState = authBloc.state;
    
    final String currentLocation = state.matchedLocation;
    
    // Pages d'authentification
    final authPages = ['/login', '/signup', '/onboarding'];
    final isOnAuthPage = authPages.contains(currentLocation);
    
    print('🧭 Router redirect: current=$currentLocation, authState=${authState.runtimeType}');
    
    // Gestion des redirections selon l'état d'authentification
    if (authState is AuthInitial || authState is AuthLoading) {
      // En cours d'initialisation, ne pas rediriger
      return null;
    }
    
    if (authState is ProfileIncomplete) {
      // Profil incomplet, rediriger vers l'onboarding sauf si déjà dessus
      if (currentLocation != '/onboarding') {
        print('🧭 Redirecting to onboarding - profile incomplete');
        return '/onboarding';
      }
    }
    
    if (authState is Authenticated) {
      // Utilisateur connecté
      if (isOnAuthPage) {
        // Si sur une page d'auth alors qu'il est connecté, rediriger vers l'accueil
        print('🧭 Redirecting to home - already authenticated');
        return '/home';
      }
    }
    
    // Pas de redirection nécessaire
    return null;
  },
  
  routes: [
    // Routes d'authentification (sans shell)
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const SignupScreen(),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
      ),
    ),
    
    // Routes principales avec shell (navigation bottom)
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return AuthWrapper(child: MainScaffold(child: child));
      },
      routes: [
        // Route d'accueil - accessible à tous
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const HomeScreen(),
          ),
        ),
        
        // Routes protégées - nécessitent une authentification
        GoRoute(
          path: '/activity',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: ActivityScreen(),
          ),
        ),
        GoRoute(
          path: '/historic',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: HistoricScreen(),
          ),
        ),
        GoRoute(
          path: '/account',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: AccountScreen(),
          ),
        ),
        GoRoute(
          path: '/navigation',
          pageBuilder: (context, state) {
            final args = state.extra as NavigationArgs;
            return NoTransitionPage(
              key: state.pageKey,
              child: NavigationScreen(args: args),
            );
          },
        ),

      ],
    ),
  ],
  
  // Gestion des erreurs de route
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          SizedBox(height: 16),
          Text(
            'Page non trouvée',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 8),
          Text(
            'La page "${state.matchedLocation}" n\'existe pas.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: Text('Retour à l\'accueil'),
          ),
        ],
      ),
    ),
  ),
);

/// Wrapper pour gérer l'authentification au niveau du shell
class AuthWrapper extends StatelessWidget {
  final Widget child;
  
  const AuthWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        // Listener pour les changements d'état d'authentification
        if (authState is Unauthenticated) {
          // L'utilisateur vient de se déconnecter
          final currentLocation = GoRouter.of(context).state.matchedLocation;
          final protectedPages = ['/activity', '/historic', '/account'];
          
          if (protectedPages.contains(currentLocation)) {
            // Rediriger vers l'accueil si on est sur une page protégée
            context.go('/home');
          }
        }
        
        if (authState is Authenticated) {
          // L'utilisateur vient de se connecter
          print('✅ User authenticated: ${authState.profile.email}');
        }
        
        if (authState is AuthError) {
          // Erreur d'authentification, afficher un message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur d\'authentification: ${authState.message}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      },
      child: child,
    );
  }
}