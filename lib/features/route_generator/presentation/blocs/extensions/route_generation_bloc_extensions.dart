import 'package:runaway/core/services/guest_limitation_service.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as su;

/// Extensions pour RouteGenerationBloc qui gèrent les limitations des guests
extension RouteGenerationBlocGuestExtensions on RouteGenerationBloc {

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
      print('❌ Erreur vérification session Supabase: $e');
      return false;
    }
  }
  
  /// Vérifie si l'utilisateur peut générer une route (authenticated + guest)
  Future<GenerationCapability> checkGenerationCapability(AuthBloc authBloc) async {
    try {
      final authState = authBloc.state;
      
      print('🔍 === VÉRIFICATION CAPACITÉ GÉNÉRATION ===');
      print('🔍 AuthState: ${authState.runtimeType}');
      
      // 🆕 VÉRIFICATION DOUBLE : État BLoC + Session Supabase
      final isReallyAuth = _isReallyAuthenticated(authState);
      print('🔍 Vraiment authentifié: $isReallyAuth');
      
      // Utilisateur authentifié ET session valide - utiliser le système de crédits existant
      if (isReallyAuth) {
        print('💳 Mode: Utilisateur authentifié avec crédits');
        
        try {
          final canGenerate = await canGenerateRoute();
          final availableCredits = await getAvailableCredits();
          
          print('💳 Résultat: canGenerate=$canGenerate, credits=$availableCredits');
          
          return GenerationCapability.authenticated(
            canGenerate: canGenerate,
            availableCredits: availableCredits,
          );
        } catch (e) {
          print('❌ Erreur récupération crédits pour utilisateur auth: $e');
          // Fallback: traiter comme guest si l'API des crédits échoue
          print('🔄 Fallback vers mode guest...');
          return _handleGuestMode();
        }
      }
      
      // Utilisateur non authentifié OU session expirée - utiliser le système guest
      print('👤 Mode: Utilisateur guest ou session expirée');
      return _handleGuestMode();
      
    } catch (e) {
      print('❌ Erreur globale vérification capacité génération: $e');
      return GenerationCapability.unavailable('Erreur de vérification');
    }
  }

Future<GenerationCapability> _handleGuestMode() async {
    try {
      final guestService = GuestLimitationService.instance;
      final canGenerate = await guestService.canGuestGenerate();
      final remaining = await guestService.getRemainingGuestGenerations();
      
      print('👤 Guest: canGenerate=$canGenerate, remaining=$remaining');
      
      return GenerationCapability.guest(
        canGenerate: canGenerate,
        remainingGenerations: remaining,
      );
    } catch (e) {
      print('❌ Erreur mode guest: $e');
      return GenerationCapability.unavailable('Erreur mode guest');
    }
  }

  /// Consomme une génération (crédit ou génération guest)
  Future<bool> consumeGeneration(AuthBloc authBloc) async {
    try {
      final authState = authBloc.state;
      final isReallyAuth = _isReallyAuthenticated(authState);
      
      print('💳 === CONSOMMATION GÉNÉRATION ===');
      print('💳 AuthState: ${authState.runtimeType}');
      print('💳 Vraiment authentifié: $isReallyAuth');
      
      // Utilisateur authentifié avec session valide - NE PAS consommer ici
      if (isReallyAuth) {
        print('👤 Utilisateur authentifié - consommation sera gérée par RouteGenerationBloc');
        return true; // On laisse le bloc gérer la consommation de crédits
      }
      
      // Utilisateur non authentifié ou session expirée - consommer une génération guest
      print('👤 Mode guest - consommation d\'une génération gratuite');
      final guestService = GuestLimitationService.instance;
      final consumed = await guestService.consumeGuestGeneration();
      print('👤 Guest - consommation: ${consumed ? "✅" : "❌"}');
      return consumed;
      
    } catch (e) {
      print('❌ Erreur consommation génération: $e');
      return false;
    }
  }

  /// Nettoie les données guest lors de la connexion
  Future<void> clearGuestDataOnLogin() async {
    try {
      final guestService = GuestLimitationService.instance;
      await guestService.clearGuestData();
      print('🧹 Données guest nettoyées après connexion');
    } catch (e) {
      print('❌ Erreur nettoyage données guest: $e');
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