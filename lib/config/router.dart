import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/conversion_listener.dart';
import 'package:runaway/core/widgets/main_scaffold.dart';
import 'package:runaway/features/account/presentation/screens/account_screen.dart';
import 'package:runaway/features/account/presentation/screens/edit_profile_screen.dart';
import 'package:runaway/features/activity/presentation/screens/activity_screen.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:runaway/features/credits/presentation/screens/credit_plans_screen.dart';
import 'package:runaway/features/historic/presentation/screens/historic_screen.dart';
import 'package:runaway/features/navigation/blocs/navigation_bloc.dart';
import 'package:runaway/features/navigation/presentation/screens/live_navigation_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';

// Clé globale pour accéder au contexte du router
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  
  // Redirection globale basée sur l'état d'authentification
  redirect: (BuildContext context, GoRouterState state) {
    final authBloc = context.authBloc;
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
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
      ),
    ),
    GoRoute(
      path: '/live-navigation',
      name: 'live-navigation',
      pageBuilder: (context, state) {
        final args = state.extra as LiveNavigationArgs?;
        
        if (args == null) {
          return NoTransitionPage(
            key: state.pageKey,
            child: const HomeScreen(),
          );
        }
        
        // 🔧 SOLUTION : AuthWrapper + BlocProvider
        return NoTransitionPage(
          key: state.pageKey,
          child: AuthWrapper(  // ← Garde l'accès aux BLoCs d'auth
            child: BlocProvider(
              create: (context) => NavigationBloc(),
              child: LiveNavigationScreen(args: args),
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) {
        // Récupérer le profil depuis l'état d'authentification
        final authBloc = context.authBloc;
        final authState = authBloc.state;
        
        if (authState is Authenticated) {
          return EditProfileScreen(profile: authState.profile);
        }
        
        // Rediriger si pas authentifié
        return const Scaffold(
          body: Center(child: Text('Non autorisé')),
        );
      },
    ),
    GoRoute(
      path: '/manage-credits',
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const CreditPlansScreen(),
        );
      },
    ),

    // Routes principales avec shell (navigation bottom)
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return ConversionListener(child: child);
      },
      routes: [
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
          ],
        ),
      ]
    )
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
        // 🔧 CORRECTION: Ajouter des logs pour debug et éviter les actions redondantes
        print('🔄 AuthWrapper: Changement d\'état - ${authState.runtimeType}');
        
        // Listener pour les changements d'état d'authentification
        if (authState is Unauthenticated) {
          // L'utilisateur vient de se déconnecter - NETTOYER LE CACHE
          print('🚪 Utilisateur déconnecté, nettoyage du cache...');
          try {
            // Déclencher le nettoyage du cache via AppDataBloc
            context.appDataBloc.add(const AppDataClearRequested());
          } catch (e) {
            print('❌ Erreur lors du nettoyage du cache: $e');
          }
          
          // Redirection vers l'accueil si on est sur une page protégée
          final currentLocation = GoRouter.of(context).state.matchedLocation;
          final protectedPages = ['/activity', '/historic', '/account'];
          
          if (protectedPages.contains(currentLocation)) {
            print('🔀 Redirection vers /home depuis $currentLocation');
            context.go('/home');
          }
        }
        
        if (authState is Authenticated) {
          // L'utilisateur vient de se connecter
          print('✅ User authenticated: ${authState.profile.email}');
          
          // 🔧 CORRECTION: Délai pour s'assurer que la navigation est stable
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              try {
                context.appDataBloc.add(const AppDataPreloadRequested());
              } catch (e) {
                print('❌ Erreur lors du pré-chargement: $e');
              }
            }
          });
        }
        
        if (authState is AuthError) {
          // Erreur d'authentification, afficher un message
          print('❌ Erreur d\'authentification: ${authState.message}');
          
          // 🔧 CORRECTION: Délai pour éviter les conflits avec la navigation
          Future.delayed(const Duration(milliseconds: 200), () {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur d\'authentification: ${authState.message}'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          });
        }
        
        // 🔧 CORRECTION: Gérer l'état de chargement
        if (authState is AuthLoading) {
          print('⏳ Authentification en cours...');
        }
      },
      child: child,
    );
  }
}