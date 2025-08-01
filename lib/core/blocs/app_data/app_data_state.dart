import 'package:equatable/equatable.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';
import 'package:runaway/features/credits/domain/models/credit_transaction.dart';
import 'package:runaway/features/credits/domain/models/user_credits.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';

class AppDataState extends Equatable {
  // ===== HISTORIQUE =====
  final List<SavedRoute> savedRoutes;
  final bool isHistoricDataLoaded;
  
  // ===== 🆕 CRÉDITS =====
  final UserCredits? userCredits;
  final List<CreditPlan> creditPlans;
  final List<CreditTransaction> creditTransactions;
  final bool isCreditDataLoaded;
  
  // ===== ÉTAT GÉNÉRAL =====
  final bool isLoading;
  final bool isSavingRoute;
  final String? lastError;
  final DateTime? lastUpdate;
  final bool isDataLoaded;
  final DateTime? lastCacheUpdate;

  const AppDataState({    
    // Historique
    this.savedRoutes = const [],
    this.isHistoricDataLoaded = false,
    
    // 🆕 Crédits
    this.userCredits,
    this.creditPlans = const [],
    this.creditTransactions = const [],
    this.isCreditDataLoaded = false,
    
    // État général
    this.isLoading = false,
    this.isSavingRoute = false,
    this.lastError,
    this.lastUpdate,
    this.isDataLoaded = false,
    this.lastCacheUpdate,
  });

  AppDataState copyWith({    
    // Historique
    List<SavedRoute>? savedRoutes,
    bool? isHistoricDataLoaded,
    
    // 🆕 Crédits
    UserCredits? userCredits,
    List<CreditPlan>? creditPlans,
    List<CreditTransaction>? creditTransactions,
    bool? isCreditDataLoaded,
    
    // État général
    bool? isLoading,
    bool? isSavingRoute,
    String? lastError,
    DateTime? lastUpdate,
    bool? isDataLoaded,
    DateTime? lastCacheUpdate,
  }) {
    return AppDataState(      
      // Historique
      savedRoutes: savedRoutes ?? this.savedRoutes,
      isHistoricDataLoaded: isHistoricDataLoaded ?? this.isHistoricDataLoaded,
      
      // 🆕 Crédits
      userCredits: userCredits ?? this.userCredits,
      creditPlans: creditPlans ?? this.creditPlans,
      creditTransactions: creditTransactions ?? this.creditTransactions,
      isCreditDataLoaded: isCreditDataLoaded ?? this.isCreditDataLoaded,
      
      // État général
      isLoading: isLoading ?? this.isLoading,
      isSavingRoute: isSavingRoute ?? this.isSavingRoute,
      lastError: lastError ?? this.lastError,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      isDataLoaded: isDataLoaded ?? this.isDataLoaded,
      lastCacheUpdate: lastCacheUpdate ?? this.lastCacheUpdate,
    );
  }

  @override
  List<Object?> get props => [
    // Historique
    savedRoutes,
    isHistoricDataLoaded,
    
    // 🆕 Crédits
    userCredits,
    creditPlans,
    creditTransactions,
    isCreditDataLoaded,
    
    // État général
    isLoading,
    isSavingRoute,
    lastError,
    lastUpdate,
    isDataLoaded,
    lastCacheUpdate,
  ];

  /// Vérifie si toutes les données sont chargées
  bool get isDataLoadedFinish=> hasHistoricData && isCreditDataLoaded;

  /// Vérifie si les données d'historique sont présentes
  bool get hasHistoricData => isHistoricDataLoaded;

  // ===== 🆕 GETTERS CRÉDITS =====
  
  /// Vérifie si les données de crédits sont présentes
  bool get hasCreditData => userCredits != null && creditPlans.isNotEmpty;
  
  /// Nombre de crédits disponibles (0 si pas de données)
  int get availableCredits => userCredits?.availableCredits ?? 0;
  
  /// Vérifie si l'utilisateur a des crédits
  bool get hasCredits => availableCredits > 0;
  
  /// Peut générer un parcours (a des crédits)
  bool get canGenerateRoute => hasCredits;
  
  /// Plan le plus populaire
  CreditPlan? get popularPlan => creditPlans.where((p) => p.isPopular).firstOrNull;
  
  /// Plans actifs seulement
  List<CreditPlan> get activePlans => creditPlans.where((p) => p.isActive).toList();
  
  /// Transactions récentes (les 10 dernières)
  List<CreditTransaction> get recentTransactions => 
      creditTransactions.take(10).toList();
  
  /// Historique des achats seulement
  List<CreditTransaction> get purchaseHistory => 
      creditTransactions.where((t) => t.type == CreditTransactionType.purchase).toList();
  
  /// Historique des utilisations seulement
  List<CreditTransaction> get usageHistory => 
      creditTransactions.where((t) => t.type == CreditTransactionType.usage).toList();


  /// Helpers pour vérifier l'état des données
  bool get hasCompleteData =>  hasHistoricData;
  
  /// Vérifie si le cache est encore valide (30 minutes)
  bool get isCacheValid {
    if (lastCacheUpdate == null) return false;
    return DateTime.now().difference(lastCacheUpdate!) < const Duration(minutes: 30);
  }
  
  /// Vérifie si les données sont prêtes à être utilisées
  bool get isDataReady => isDataLoaded && isCacheValid;
}