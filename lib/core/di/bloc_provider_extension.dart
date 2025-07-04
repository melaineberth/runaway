import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/home/presentation/blocs/route_parameters_bloc.dart';
import 'package:runaway/features/navigation/blocs/navigation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'service_locator.dart';

/// Extension pour accéder facilement aux blocs via GetIt
extension BlocAccess on BuildContext {
  // Accès direct aux blocs singleton
  NotificationBloc get notificationBloc => sl<NotificationBloc>();
  AppDataBloc get appDataBloc => sl<AppDataBloc>();
  AuthBloc get authBloc => sl<AuthBloc>();
  LocaleBloc get localeBloc => sl<LocaleBloc>();
  ThemeBloc get themeBloc => sl<ThemeBloc>();
  
  // Pour les blocs avec instances multiples, utiliser le context comme avant
  NavigationBloc get navigationBloc => read<NavigationBloc>();
  RouteParametersBloc get routeParametersBloc => read<RouteParametersBloc>();
  RouteGenerationBloc get routeGenerationBloc => read<RouteGenerationBloc>();
}

/// Widget helper pour créer des BlocProvider avec GetIt
class GetItBlocProvider<T extends BlocBase<Object?>> extends StatelessWidget {
  final Widget child;
  final T Function() create;

  const GetItBlocProvider({
    super.key,
    required this.child,
    required this.create,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<T>.value(
      value: create(),
      child: child,
    );
  }
}

/// Widget pour les pages nécessitant des blocs spécifiques
class RoutePageWrapper extends StatelessWidget {
  final Widget child;

  const RoutePageWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<RouteParametersBloc>(create: (_) => sl<RouteParametersBloc>()),
        BlocProvider<RouteGenerationBloc>(create: (_) => sl<RouteGenerationBloc>()),
      ],
      child: child,
    );
  }
}