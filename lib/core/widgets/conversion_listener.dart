import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/helper/services/conversion_service.dart';
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
}

class _ConversionListenerState extends State<ConversionListener> {
  Timer? _delayedPromptTimer;
  bool _isPromptShowing = false;
  
  @override
  void initState() {
    super.initState();
    // Initialiser le service de conversion
    ConversionService.instance.initializeSession();
  }
  
  @override
  void dispose() {
    _delayedPromptTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
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
          print('⏳ Authentification en cours - annulation des prompts');
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
      print('❌ Erreur vérification auth: $e');
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
  
  /// Vérifie les conditions et affiche le prompt si approprié
  Future<void> _checkAndShowPrompt([String? promptContext]) async {
    if (_isPromptShowing) return;
    
    // ✅ VÉRIFICATION CRITIQUE : Ne jamais afficher le prompt si l'utilisateur est connecté
    if (_isUserAuthenticated()) {
      print('🚫 Prompt annulé - utilisateur connecté');
      return;
    }
    
    // 🔧 CORRECTION: Vérifier aussi l'état de chargement
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthLoading) {
      print('🚫 Prompt annulé - authentification en cours');
      return;
    }
    
    try {
      final shouldShow = await ConversionService.instance.shouldShowConversionPrompt();
      
      // ✅ Triple vérification avant affichage
      if (shouldShow && mounted && !_isUserAuthenticated() && authState is! AuthLoading) {
        _isPromptShowing = true;
        
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: true,
          enableDrag: true,
          builder: (context) => ConversionPromptModal(context: promptContext),
        );
        
        _isPromptShowing = false;
      } else {
        print('🚫 Prompt annulé - conditions non remplies');
      }
    } catch (e) {
      print('❌ Erreur vérification prompt: $e');
      _isPromptShowing = false;
    }
  }
}