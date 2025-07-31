import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/features/home/data/services/tutorial_service.dart';
import 'package:runaway/features/home/presentation/widgets/welcome_modal.dart';

/// Mixin pour simplifier l'ajout du tutoriel à n'importe quel écran
mixin TutorialIntegrationMixin<T extends StatefulWidget> on State<T> {
  
  /// GlobalKeys pour les éléments du tutoriel
  late final GlobalKey aiButtonKey = GlobalKey();
  late final GlobalKey searchButtonKey = GlobalKey();
  late final GlobalKey historyButtonKey = GlobalKey();
  late final GlobalKey userTrackingButtonKey = GlobalKey();
  late final GlobalKey mapStyleButtonKey = GlobalKey();      
  
  bool _isWelcomeModalShown = false;
  
  /// Méthode à appeler dans initState() pour démarrer le processus
  void initializeTutorial() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowWelcomeModal();
    });
  }
  
  /// Force l'affichage du tutoriel
  void showTutorialForDebug() {
    if (kDebugMode && mounted) {
      debugPrint('🔧 [DEBUG] Déclenchement manuel du tutoriel');
      _isWelcomeModalShown = false; // Reset le flag
      _showWelcomeModal();
    }
  }

  /// Lance directement le coach sans modal
  void showCoachTutorialForDebug() {
    if (kDebugMode && mounted) {
      debugPrint('🔧 [DEBUG] Déclenchement direct du coach tutorial');
      _startTutorial();
    }
  }

  /// Réinitialise le flag de première visite
  Future<void> resetTutorialForDebug() async {
    if (kDebugMode) {
      await TutorialService.instance.resetFirstLaunch();
      _isWelcomeModalShown = false;
      debugPrint('🔧 [DEBUG] Tutoriel réinitialisé');
    }
  }

  /// Force la complétion (utile pour les tests)
  Future<void> completeTutorialForDebug() async {
    if (kDebugMode) {
      await TutorialService.instance.markFirstLaunchCompleted();
      _isWelcomeModalShown = true;
      debugPrint('🔧 [DEBUG] Tutoriel marqué comme terminé');
    }
  }
  
  /// Vérifie et affiche la modal si nécessaire
  void _checkAndShowWelcomeModal() async {
    if (!mounted) return;
    
    await Future.delayed(Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    // Utilise directement isFirstLaunch
    final isFirstLaunch = await TutorialService.instance.isFirstLaunch();
    
    debugPrint('🔧 [DEBUG] isFirstLaunch = $isFirstLaunch, _isWelcomeModalShown = $_isWelcomeModalShown');
    
    if (isFirstLaunch && !_isWelcomeModalShown && mounted) {
      _isWelcomeModalShown = true;
      debugPrint('🔧 [DEBUG] Affichage de la modal de bienvenue');
      _showWelcomeModal();
    } else {
      debugPrint('🔧 [DEBUG] Modal pas affichée - isFirstLaunch: $isFirstLaunch, modalShown: $_isWelcomeModalShown');
    }
  }
  
  /// Affiche la modal de bienvenue
  void _showWelcomeModal() async {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WelcomeModal(
        onStartTutorial: () {
          context.pop();
          _startTutorial();
        },
        onSkip: () {
          context.pop();
          
          TutorialService.instance.markFirstLaunchCompleted();
        },
      ),
    );
  }
  
  /// Démarre le tutoriel
  void _startTutorial() async {    
    if (!mounted) return;
    
    TutorialService.instance.startMainTutorial(
      context,
      aiButtonKey: aiButtonKey,
      searchButtonKey: searchButtonKey,
      historyButtonKey: historyButtonKey,
      userTrackingButtonKey: userTrackingButtonKey,
      mapStyleButtonKey: mapStyleButtonKey
    );
  }
}

/// Extension pour ajouter facilement une key à un widget existant
extension TutorialKeyExtension on Widget {
  Widget withTutorialKey(GlobalKey key) {
    return KeyedSubtree(
      key: key,
      child: this,
    );
  }
}