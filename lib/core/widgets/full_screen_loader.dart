import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/particles_spark.dart';
import 'package:runaway/core/widgets/particles_spark_loader.dart';

enum LoadingType { generation, saving }

class FullScreenLoader extends StatefulWidget {
  final LoadingType? loadingType;

  const FullScreenLoader({
    super.key,
    this.loadingType,
  });

  @override
  State<FullScreenLoader> createState() => _FullScreenLoaderState();
}

class _FullScreenLoaderState extends State<FullScreenLoader> {
  Timer? _messageTimer;
  int _currentMessageIndex = 0;
  String _currentMessage = '';
  bool _hasInitializedMessages = false; // Flag pour savoir si les messages sont initialisés

  // 1.6s permet d'afficher 2-3 messages pendant les 4 secondes minimum
  static const Duration _messageRotationInterval = Duration(milliseconds: 1600);

  // 🔧 FIX : Messages par défaut pour éviter l'accès à context.l10n dans initState
  static const String _defaultGenerationMessage = 'Génération en cours...';
  static const String _defaultSavingMessage = 'Sauvegarde en cours...';

  // Messages pour la génération de parcours - Maintenant dans une méthode
  List<String> _getGenerationMessages() => [
    context.l10n.generationMessage1,
    context.l10n.generationMessage2,
    context.l10n.generationMessage3,
    context.l10n.generationMessage4,
    context.l10n.generationMessage5,
    context.l10n.generationMessage6,
  ];

  // Messages pour la sauvegarde - Version engageante
  List<String> _getSavingMessages() => [
    context.l10n.savingMessage1,
    context.l10n.savingMessage2,
    context.l10n.savingMessage3,
    context.l10n.savingMessage4,
  ];

  @override
  void initState() {
    super.initState();
    // Utiliser un message par défaut et ne pas démarrer la rotation
    _currentMessage = widget.loadingType == LoadingType.saving 
        ? _defaultSavingMessage 
        : _defaultGenerationMessage;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialiser les messages localisés ICI au lieu de initState()
    if (!_hasInitializedMessages) {
      _initializeMessage();
      _startMessageRotation();
      _hasInitializedMessages = true;
    }
  }

  @override
  void didUpdateWidget(FullScreenLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loadingType != oldWidget.loadingType) {
      _initializeMessage();
      _restartMessageRotation();
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  void _initializeMessage() {
    if (widget.loadingType != null) {
      final messages = _getMessagesForType(widget.loadingType!);
      _currentMessage = messages.isNotEmpty ? messages[0] : _getFallbackMessage();
      _currentMessageIndex = 0;
    } else {
      _currentMessage = context.l10n.currentGeneration;
    }
  }

  List<String> _getMessagesForType(LoadingType type) {
    switch (type) {
      case LoadingType.generation:
        return _getGenerationMessages(); // 🔧 FIX : Utiliser la méthode au lieu du getter
      case LoadingType.saving:
        return _getSavingMessages(); // 🔧 FIX : Utiliser la méthode au lieu du getter
    }
  }

  String _getFallbackMessage() {
    return widget.loadingType == LoadingType.saving 
        ? context.l10n.saving 
        : context.l10n.generateInProgress;
  }

  void _startMessageRotation() {
    if (widget.loadingType == null) return;
    
    // 🆕 AMÉLIORATION : Intervalle optimisé pour meilleure expérience
    _messageTimer = Timer.periodic(_messageRotationInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        final messages = _getMessagesForType(widget.loadingType!);
        if (messages.isNotEmpty) {
          _currentMessageIndex = (_currentMessageIndex + 1) % messages.length;
          _currentMessage = messages[_currentMessageIndex];
          debugPrint('💬 Message ${_currentMessageIndex + 1}/${messages.length}: $_currentMessage');
        }
      });
    });
  }

  void _restartMessageRotation() {
    _messageTimer?.cancel();
    _startMessageRotation();
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: context.adaptiveBackground,
              height: double.infinity,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: StepRotatingShape(
                            size: 25,
                            rotationDuration: const Duration(milliseconds: 600), // Duration of each 45° rotation
                            pauseDuration: const Duration(milliseconds: 300), // Pause duration between rotations
                            color: context.adaptivePrimary,
                          ),
                        ),
                        16.h,
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.3),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _currentMessage,
                            key: ValueKey(_currentMessage),
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              color: context.adaptiveTextPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    Positioned.fill(
                      child: ParticlesSpark(
                        quantity: 20,
                        maxSize: 8,
                        minSize: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
