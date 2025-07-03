import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/services/conversion_service.dart';
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
        // Ne montrer les prompts que pour les utilisateurs non connectés
        if (authState is Unauthenticated && !_isPromptShowing) {
          _scheduleDelayedPromptCheck();
        }
      },
      child: widget.child,
    );
  }
  
  /// Programme une vérification retardée pour éviter d'interrompre l'utilisateur
  void _scheduleDelayedPromptCheck([String? promptContext]) {
    _delayedPromptTimer?.cancel();
    
    // Attendre 2-5 secondes pour laisser l'utilisateur finir son action
    final delay = Duration(seconds: 2 + (promptContext?.length ?? 0) % 3);
    
    _delayedPromptTimer = Timer(delay, () {
      if (mounted && !_isPromptShowing) {
        _checkAndShowPrompt(promptContext);
      }
    });
  }
  
  /// Vérifie les conditions et affiche le prompt si approprié
  Future<void> _checkAndShowPrompt([String? promptContext]) async {
    if (_isPromptShowing) return;
    
    try {
      final shouldShow = await ConversionService.instance.shouldShowConversionPrompt();
      
      if (shouldShow && mounted) {
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
      }
    } catch (e) {
      print('❌ Erreur vérification prompt: $e');
      _isPromptShowing = false;
    }
  }
}
