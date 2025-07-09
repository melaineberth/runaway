import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_event.dart';
import 'package:runaway/core/blocs/locale/locale_bloc.dart';
import 'package:runaway/core/blocs/notification/notification_bloc.dart';
import 'package:runaway/core/blocs/theme_bloc/theme_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
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
  CreditsBloc get creditsBloc => read<CreditsBloc>();
  
  // Pour les blocs avec instances multiples, utiliser le context comme avant
  NavigationBloc get navigationBloc => read<NavigationBloc>();
  RouteParametersBloc get routeParametersBloc => read<RouteParametersBloc>();
  RouteGenerationBloc get routeGenerationBloc => read<RouteGenerationBloc>();

  // ===== 🆕 MÉTHODES HELPER POUR LES CRÉDITS =====
  
  /// Nombre de crédits disponibles (0 si pas de données)
  int get availableCredits => appDataBloc.state.availableCredits;
  
  /// Vérifie si l'utilisateur a des crédits
  bool get hasCredits => appDataBloc.state.hasCredits;
  
  /// Vérifie si l'utilisateur peut générer un parcours
  bool get canGenerateRoute => appDataBloc.state.canGenerateRoute;
  
  /// Vérifie si les données de crédits sont chargées
  bool get isCreditDataLoaded => appDataBloc.state.isCreditDataLoaded;
  
  /// Plans de crédits actifs
  List<CreditPlan> get activeCreditPlans => appDataBloc.state.activePlans;
  
  /// Plan populaire
  CreditPlan? get popularCreditPlan => appDataBloc.state.popularPlan;
  
  /// Transactions récentes
  List<CreditTransaction> get recentTransactions => appDataBloc.state.recentTransactions;

  // ===== 🆕 MÉTHODES D'ACTION POUR LES CRÉDITS =====
  
  /// Rafraîchit les données de crédits
  void refreshCreditData() {
    appDataBloc.add(const CreditDataRefreshRequested());
  }
  
  /// Pré-charge les données de crédits
  void preloadCreditData() {
    appDataBloc.add(const CreditDataPreloadRequested());
  }
  
  /// Mise à jour optimiste du solde
  void updateCreditBalanceOptimistic(int newBalance) {
    appDataBloc.add(CreditBalanceUpdatedInAppData(
      newBalance: newBalance,
      isOptimistic: true,
    ));
  }
  
  /// Synchronise après utilisation de crédits
  void syncAfterCreditUsage({
    required int amount,
    required String reason,
    String? routeGenerationId,
    required String transactionId,
  }) {
    appDataBloc.add(CreditUsageCompletedInAppData(
      amount: amount,
      reason: reason,
      routeGenerationId: routeGenerationId,
      transactionId: transactionId,
    ));
  }
  
  /// Synchronise après achat de crédits
  void syncAfterCreditPurchase({
    required String planId,
    required String paymentIntentId,
    required int creditsAdded,
  }) {
    appDataBloc.add(CreditPurchaseCompletedInAppData(
      planId: planId,
      paymentIntentId: paymentIntentId,
      creditsAdded: creditsAdded,
    ));
  }

  // ===== 🆕 MÉTHODES HELPER POUR LES AUTRES DONNÉES =====
  
  /// Vérifie si toutes les données sont chargées
  bool get isAllDataLoaded => appDataBloc.state.isDataLoaded;
  
  /// Vérifie si les données d'activité sont chargées
  bool get isActivityDataLoaded => appDataBloc.state.hasActivityData;
  
  /// Vérifie si les données d'historique sont chargées
  bool get isHistoricDataLoaded => appDataBloc.state.hasHistoricData;
  
  /// Nombre de parcours sauvegardés
  int get savedRoutesCount => appDataBloc.state.savedRoutes.length;
  
  /// Rafraîchit toutes les données
  void refreshAllData() {
    appDataBloc.add(const AppDataRefreshRequested());
  }
  
  /// Rafraîchit les données d'activité
  void refreshActivityData() {
    appDataBloc.add(const ActivityDataRefreshRequested());
  }
  
  /// Rafraîchit les données d'historique
  void refreshHistoricData() {
    appDataBloc.add(const HistoricDataRefreshRequested());
  }
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

/// 🆕 Widget wrapper pour les pages nécessitant un accès aux crédits
class CreditAwarePageWrapper extends StatelessWidget {
  final Widget child;
  final bool preloadOnInit;

  const CreditAwarePageWrapper({
    super.key,
    required this.child,
    this.preloadOnInit = true,
  });

  @override
  Widget build(BuildContext context) {
    // Déclencher le pré-chargement si nécessaire
    if (preloadOnInit && !context.isCreditDataLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.preloadCreditData();
      });
    }

    return child;
  }
}

/// 🆕 Widget wrapper pour les pages de génération de parcours
class RouteGenerationPageWrapper extends StatelessWidget {
  final Widget child;

  const RouteGenerationPageWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<RouteParametersBloc>(create: (_) => sl<RouteParametersBloc>()),
        BlocProvider<RouteGenerationBloc>(create: (_) => sl<RouteGenerationBloc>()),
      ],
      child: CreditAwarePageWrapper(child: child),
    );
  }
}