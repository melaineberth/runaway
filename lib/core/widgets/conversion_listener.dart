import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/services/conversion_service.dart';
import 'package:runaway/core/widgets/route_info_tracker.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import 'package:runaway/features/auth/presentation/widgets/conversion_prompt_modal.dart';

/// Widget qui écoute les actions utilisateur et déclenche les prompts de conversion
class ConversionListener extends StatefulWidget {
  final Widget child;
  
  const ConversionListener({
    super.key,
    required this.child,
  });

  @override
  State<ConversionListener> createState() => _ConversionListenerState();
  
  /// 🆕 Méthode statique pour déclencher manuellement la modal de conversion
  static void showConversionPrompt([String? context]) {
    if (_ConversionListenerState._instance != null && 
        _ConversionListenerState._instance!.mounted) {
      _ConversionListenerState._instance!._showPromptManually(context);
    }
  }
}

class _ConversionListenerState extends State<ConversionListener> {
  Timer? _delayedPromptTimer;
  bool _isPromptShowing = false;
  
  // 🆕 Clé globale pour accéder à cette instance depuis l'extérieur
  static _ConversionListenerState? _instance;
  
  @override
  void initState() {
    super.initState();
    _instance = this;
    // Initialiser le service de conversion
    ConversionService.instance.initializeSession();
  }
  
  @override
  void dispose() {
    _delayedPromptTimer?.cancel();
    _instance = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        // 🆕 PRIORITÉ: Ignorer les actions pendant le processus de reset de mot de passe
        if (authState is PasswordResetCodeSent || 
            authState is PasswordResetCodeVerified || 
            authState is PasswordResetSuccess) {
          print('🔐 ConversionListener: Processus de reset en cours - ignorer les actions');
          return;
        }
        
        if (authState is Authenticated) {
          // ✅ Utilisateur connecté → annuler tout prompt en cours
          _delayedPromptTimer?.cancel();
          _isPromptShowing = false;
          print('🔐 Utilisateur authentifié - annulation des prompts');
        } else if (authState is Unauthenticated && !_isPromptShowing) {
          // 🔧 CORRECTION: Ne programmer une vérification que si on vient d'une déconnexion
          // et non pas lors du chargement initial de l'app
          print('🚪 Utilisateur non authentifié');
          _scheduleDelayedPromptCheck();
        } else if (authState is AuthLoading) {
          // 🔧 CORRECTION: Annuler les prompts pendant le chargement d'auth
          _delayedPromptTimer?.cancel();
          LogConfig.logInfo('⏳ Authentification en cours - annulation des prompts');
        }
      },
      child: widget.child,
    );
  }
  
  /// Vérifie si l'utilisateur est connecté avec gestion des erreurs
  bool _isUserAuthenticated() {
    try {
      final authState = context.read<AuthBloc>().state;
      return authState is Authenticated;
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification auth: $e');
      return false;
    }
  }
  
  /// Programme une vérification retardée pour éviter d'interrompre l'utilisateur
  void _scheduleDelayedPromptCheck([String? promptContext]) {
    _delayedPromptTimer?.cancel();
    
    // 🔧 CORRECTION: Délai plus court et vérifications plus fréquentes
    const delay = Duration(seconds: 2);
    
    _delayedPromptTimer = Timer(delay, () {
      if (mounted && !_isPromptShowing) {
        _checkAndShowPrompt(promptContext);
      }
    });
  }
  
  /// 🆕 Affiche la modal manuellement sans vérifications
  void _showPromptManually([String? promptContext]) {
    if (_isPromptShowing) {
      LogConfig.logInfo('🚫 Modal déjà affichée - ignoré');
      return;
    }
    
    // 🔧 Vérifier si RouteInfoCard est actif
    if (RouteInfoTracker.instance.isRouteInfoActive) {
      LogConfig.logInfo('🚫 RouteInfoCard actif - reporter l\'affichage');
      _schedulePromptAfterRouteInfoCard(promptContext ?? 'manual');
      return;
    }
    
    _showConversionModal(promptContext ?? 'manual');
  }
  
  /// Vérifie les conditions et affiche le prompt si approprié
  Future<void> _checkAndShowPrompt([String? promptContext]) async {
    if (_isPromptShowing) return;
    
    // ✅ VÉRIFICATION CRITIQUE : Ne jamais afficher le prompt si l'utilisateur est connecté
    if (_isUserAuthenticated()) {
      LogConfig.logInfo('🚫 Prompt annulé - utilisateur connecté');
      return;
    }
    
    // 🔧 CORRECTION: Vérifier aussi l'état de chargement
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthLoading) {
      LogConfig.logInfo('🚫 Prompt annulé - authentification en cours');
      return;
    }
    
    try {
      final shouldShow = await ConversionService.instance.shouldShowConversionPrompt();
      
      // ✅ Triple vérification avant affichage
      if (shouldShow && mounted && !_isUserAuthenticated() && authState is! AuthLoading) {
        // 🔧 Vérifier si RouteInfoCard est actif avant d'afficher
        if (RouteInfoTracker.instance.isRouteInfoActive) {
          LogConfig.logInfo('🚫 RouteInfoCard actif - reporter l\'affichage');
          _schedulePromptAfterRouteInfoCard(promptContext);
          return;
        }
        
        _showConversionModal(promptContext);
      } else {
        LogConfig.logInfo('🚫 Prompt annulé - conditions non remplies');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification prompt: $e');
      _isPromptShowing = false;
    }
  }
  
  /// 🆕 Programme l'affichage de la modal après la fermeture de RouteInfoCard
  void _schedulePromptAfterRouteInfoCard([String? promptContext]) {
    // Attendre un peu puis réessayer
    Timer(const Duration(seconds: 2), () {
      if (mounted && !_isPromptShowing && !RouteInfoTracker.instance.isRouteInfoActive) {
        _showConversionModal(promptContext);
      } else if (mounted && RouteInfoTracker.instance.isRouteInfoActive) {
        // RouteInfoCard toujours actif, réessayer dans 2 secondes
        _schedulePromptAfterRouteInfoCard(promptContext);
      }
    });
  }
  
  /// 🆕 Méthode centralisée pour afficher la modal avec meilleur contrôle z-index
  Future<void> _showConversionModal([String? promptContext]) async {
    if (!mounted) return;
    
    _isPromptShowing = true;
    
    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true, // 🔧 IMPORTANT: Utilise le navigateur racine pour être au-dessus de tout
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        builder: (context) => ConversionPromptModal(context: promptContext),
      );
    } catch (e) {
      LogConfig.logError('❌ Erreur affichage modal conversion: $e');
    } finally {
      _isPromptShowing = false;
    }
  }
}