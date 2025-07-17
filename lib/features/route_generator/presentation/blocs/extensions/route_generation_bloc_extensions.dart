import 'package:runaway/core/errors/api_exceptions.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';
import 'package:runaway/core/helper/services/guest_limitation_service.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as su;
import 'package:runaway/core/helper/config/log_config.dart';

/// Extensions pour RouteGenerationBloc qui gèrent les limitations des guests
/// 🆕 Optimisées pour les cas offline
extension RouteGenerationBlocGuestExtensions on RouteGenerationBloc {

  /// Vérifie rapidement si on peut faire des appels réseau
  Future<bool> canMakeNetworkCall() async {
    try {
      await ConnectivityService.instance.waitForInitialization(
        timeout: const Duration(seconds: 1)
      );
      return !ConnectivityService.instance.isOffline;
    } catch (e) {
      LogConfig.logInfo('Erreur vérification connectivité: $e');
      return false; // En cas de doute, on assume offline
    }
  }

  /// Affiche un message d'erreur adapté au contexte réseau
  String getNetworkAwareErrorMessage(dynamic error) {
    if (ConnectivityService.instance.isOffline) {
      return 'Vous êtes hors ligne. Vérifiez votre connexion internet et réessayez.';
    }
    
    if (error is NetworkException) {
      switch (error.code) {
        case 'TIMEOUT':
          return 'Délai d\'attente dépassé. Votre connexion semble lente, veuillez réessayer.';
        case 'NO_INTERNET':
          return 'Pas de connexion internet. Vérifiez votre réseau.';
        default:
          return 'Problème de connexion: ${error.message}';
      }
    }
    
    return 'Erreur inattendue: $error';
  }

  bool _isReallyAuthenticated(AuthState authState) {
    // Vérifier d'abord l'état du BLoC
    if (authState is! Authenticated) {
      return false;
    }
    
    try {
      // Vérifier la session Supabase réelle
      final currentUser = su.Supabase.instance.client.auth.currentUser;
      return currentUser != null;
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification session Supabase: $e');
      return false;
    }
  }
  
  /// 🆕 Vérifie si l'utilisateur peut générer une route avec gestion offline optimisée
  Future<GenerationCapability> checkGenerationCapability(AuthBloc authBloc) async {
    try {
      final authState = authBloc.state;
      
      LogConfig.logInfo('🔍 === VÉRIFICATION CAPACITÉ GÉNÉRATION ===');
      LogConfig.logInfo('🔍 AuthState: ${authState.runtimeType}');
      
      // 🆕 ÉTAPE 1: Vérification rapide de la connectivité
      final connectivityService = ConnectivityService.instance;
      
      // Attendre l'initialisation avec timeout court
      await connectivityService.waitForInitialization(
        timeout: const Duration(seconds: 1)
      );
      
      final isOffline = connectivityService.isOffline;
      LogConfig.logInfo('🌐 État connectivité: ${isOffline ? 'OFFLINE' : 'ONLINE'}');
      
      // 🆕 ÉTAPE 2: Vérification authentification (rapide, locale)
      final isReallyAuth = _isReallyAuthenticated(authState);
      LogConfig.logInfo('🔍 Vraiment authentifié: $isReallyAuth');
      
      // 🆕 ÉTAPE 3: Mode offline - fallback immédiat vers guest
      if (isOffline) {
        LogConfig.logInfo('📱 Mode OFFLINE détecté - fallback guest immédiat');
        return _handleGuestModeOffline();
      }
      
      // 🆕 ÉTAPE 4: Mode online - vérifications normales avec timeouts courts
      if (isReallyAuth) {
        LogConfig.logInfo('💳 Mode: Utilisateur authentifié avec crédits');
        return await _handleAuthenticatedModeOnline();
      }
      
      // Utilisateur non authentifié - mode guest
      LogConfig.logInfo('👤 Mode: Utilisateur guest ou session expirée');
      return _handleGuestMode();
      
    } catch (e) {
      LogConfig.logError('❌ Erreur globale vérification capacité génération: $e');
      // En cas d'erreur, fallback vers guest mode
      return _handleGuestModeOffline();
    }
  }

  /// 🆕 Gestion rapide du mode guest offline (sans appels réseau)
  Future<GenerationCapability> _handleGuestModeOffline() async {
    try {
      final guestService = GuestLimitationService.instance;
      
      // Ces appels sont locaux (SharedPreferences) donc rapides même offline
      final canGenerate = await guestService.canGuestGenerate();
      final remaining = await guestService.getRemainingGuestGenerations();
      
      LogConfig.logInfo('👤 Guest OFFLINE: canGenerate=$canGenerate, remaining=$remaining');
      
      return GenerationCapability.guest(
        canGenerate: canGenerate,
        remainingGenerations: remaining,
      );
    } catch (e) {
      LogConfig.logError('❌ Erreur mode guest offline: $e');
      // Fallback conservateur
      return GenerationCapability.guest(
        canGenerate: true,
        remainingGenerations: 5, // Valeur par défaut raisonnable
      );
    }
  }

  /// 🆕 Gestion du mode authentifié online avec timeouts courts
  Future<GenerationCapability> _handleAuthenticatedModeOnline() async {
    try {
      // Appels avec timeouts courts pour éviter les blocages
      final Future<bool> canGenerateFuture = canGenerateRoute()
          .timeout(const Duration(seconds: 3));
      
      final Future<int> creditsFuture = getAvailableCredits()
          .timeout(const Duration(seconds: 3));
      
      // Exécuter en parallèle avec timeout global
      final results = await Future.wait([
        canGenerateFuture,
        creditsFuture,
      ]).timeout(const Duration(seconds: 5));
      
      final canGenerate = results[0] as bool;
      final availableCredits = results[1] as int;
      
      LogConfig.logInfo('💳 Résultat: canGenerate=$canGenerate, credits=$availableCredits');
      
      return GenerationCapability.authenticated(
        canGenerate: canGenerate,
        availableCredits: availableCredits,
      );
      
    } catch (e) {
      LogConfig.logError('❌ Erreur récupération crédits (timeout ou erreur réseau): $e');
      // Fallback vers mode guest si l'API des crédits échoue
      LogConfig.logInfo('🔄 Fallback vers mode guest...');
      return _handleGuestMode();
    }
  }

  /// Gestion normale du mode guest (garde le comportement existant)
  Future<GenerationCapability> _handleGuestMode() async {
    try {
      final guestService = GuestLimitationService.instance;
      final canGenerate = await guestService.canGuestGenerate();
      final remaining = await guestService.getRemainingGuestGenerations();
      
      LogConfig.logInfo('👤 Guest: canGenerate=$canGenerate, remaining=$remaining');
      
      return GenerationCapability.guest(
        canGenerate: canGenerate,
        remainingGenerations: remaining,
      );
    } catch (e) {
      LogConfig.logError('❌ Erreur mode guest: $e');
      return GenerationCapability.unavailable('Erreur mode guest');
    }
  }

  /// Consomme une génération (crédit ou génération guest)
  Future<bool> consumeGeneration(AuthBloc authBloc) async {
    try {
      final authState = authBloc.state;
      final isReallyAuth = _isReallyAuthenticated(authState);
      
      LogConfig.logInfo('💳 === CONSOMMATION GÉNÉRATION ===');
      LogConfig.logInfo('💳 AuthState: ${authState.runtimeType}');
      LogConfig.logInfo('💳 Vraiment authentifié: $isReallyAuth');
      
      // Utilisateur authentifié avec session valide - NE PAS consommer ici
      if (isReallyAuth) {
        LogConfig.logInfo('👤 Utilisateur authentifié - consommation sera gérée par RouteGenerationBloc');
        return true; // On laisse le bloc gérer la consommation de crédits
      }
      
      // Utilisateur non authentifié ou session expirée - consommer une génération guest
      LogConfig.logInfo('👤 Mode guest - consommation d\'une génération gratuite');
      final guestService = GuestLimitationService.instance;
      final consumed = await guestService.consumeGuestGeneration();
      LogConfig.logInfo('👤 Guest - consommation: ${consumed ? "✅" : "❌"}');
      return consumed;
      
    } catch (e) {
      LogConfig.logError('❌ Erreur consommation génération: $e');
      return false;
    }
  }

  /// Nettoie les données guest lors de la connexion
  Future<void> clearGuestDataOnLogin() async {
    try {
      final guestService = GuestLimitationService.instance;
      await guestService.clearGuestDataOnLogin();
      LogConfig.logInfo('🧹 Données guest nettoyées après connexion');
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage données guest: $e');
    }
  }
}

/// Modèle représentant la capacité de génération d'un utilisateur
class GenerationCapability {
  final bool canGenerate;
  final GenerationType type;
  final int? availableCredits;
  final int? remainingGenerations;
  final String? reason;

  const GenerationCapability._({
    required this.canGenerate,
    required this.type,
    this.availableCredits,
    this.remainingGenerations,
    this.reason,
  });

  /// Constructeur pour utilisateur authentifié
  factory GenerationCapability.authenticated({
    required bool canGenerate,
    required int availableCredits,
  }) {
    return GenerationCapability._(
      canGenerate: canGenerate,
      type: GenerationType.authenticated,
      availableCredits: availableCredits,
    );
  }

  /// Constructeur pour utilisateur guest
  factory GenerationCapability.guest({
    required bool canGenerate,
    required int remainingGenerations,
  }) {
    return GenerationCapability._(
      canGenerate: canGenerate,
      type: GenerationType.guest,
      remainingGenerations: remainingGenerations,
    );
  }

  /// Constructeur pour limitation ou erreur
  factory GenerationCapability.unavailable(String reason) {
    return GenerationCapability._(
      canGenerate: false,
      type: GenerationType.unavailable,
      reason: reason,
    );
  }

  /// Retourne un message d'affichage pour l'UI
  String get displayMessage {
    switch (type) {
      case GenerationType.authenticated:
        if (canGenerate) {
          return '$availableCredits crédit${availableCredits! > 1 ? 's' : ''} disponible${availableCredits! > 1 ? 's' : ''}';
        } else {
          return 'Aucun crédit disponible';
        }
        
      case GenerationType.guest:
        if (canGenerate) {
          return '$remainingGenerations génération${remainingGenerations! > 1 ? 's' : ''} gratuite${remainingGenerations! > 1 ? 's' : ''} restante${remainingGenerations! > 1 ? 's' : ''}';
        } else {
          return 'Limite de générations gratuites atteinte';
        }
        
      case GenerationType.unavailable:
        return reason ?? 'Génération non disponible';
    }
  }

  /// Retourne un message d'encouragement pour l'achat/connexion
  String? get upgradeMessage {
    switch (type) {
      case GenerationType.authenticated:
        if (!canGenerate) {
          return 'Achetez des crédits pour continuer à générer des parcours';
        }
        break;
        
      case GenerationType.guest:
        if (!canGenerate) {
          return 'Créez un compte gratuit pour plus de générations ou achetez des crédits';
        }
        break;
        
      case GenerationType.unavailable:
        break;
    }
    return null;
  }

  @override
  String toString() {
    return 'GenerationCapability(type: $type, canGenerate: $canGenerate, credits: $availableCredits, remaining: $remainingGenerations)';
  }
}

enum GenerationType {
  authenticated,
  guest, 
  unavailable,
}