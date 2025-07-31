import 'dart:async';

import 'package:flutter/material.dart';
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

  // Messages pour la génération de parcours - Version engageante
  List<String> get _generationMessages => [
    'Exploration de votre zone...',
    'Recherche des meilleurs chemins...',
    'Création de votre parcours...',
    'Vérification de la qualité...',
    'Optimisation finale...',
    'Votre parcours est presque prêt !',
  ];

  // Messages pour la sauvegarde - Version engageante
  List<String> get _savingMessages => [
    'Sauvegarde de votre parcours...',
    'Capture de l\'aperçu...',
    'Synchronisation cloud...',
    'Finalisation...',
  ];

  @override
  void initState() {
    super.initState();
    _initializeMessage();
    _startMessageRotation();
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

  // Pour utiliser une version alternative, modifiez la méthode _getMessagesForType :
  List<String> _getMessagesForType(LoadingType type) {
    switch (type) {
      case LoadingType.generation:
        return _generationMessages; // ou _generationMessagesSport ou _generationMessagesTech
      case LoadingType.saving:
        return _savingMessages;
    }
  }

  String _getFallbackMessage() {
    return widget.loadingType == LoadingType.saving 
        ? 'Sauvegarde...' 
        : 'Génération...';
  }

  void _startMessageRotation() {
    if (widget.loadingType == null) return;
    
    _messageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        final messages = _getMessagesForType(widget.loadingType!);
        _currentMessageIndex = (_currentMessageIndex + 1) % messages.length;
        _currentMessage = messages[_currentMessageIndex];
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
              color: Colors.black,
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
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.3),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                )),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _currentMessage,
                            key: ValueKey(_currentMessage),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
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
