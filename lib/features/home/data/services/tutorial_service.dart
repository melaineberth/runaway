import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';

class TutorialService {
  static const String _firstLaunchKey = 'first_launch_completed';
  
  static TutorialService? _instance;
  static TutorialService get instance => _instance ??= TutorialService._();
  TutorialService._();

  /// Vérifie si c'est le premier lancement de l'application
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    // 🔧 CORRECTION : La logique était inversée !
    final hasCompletedFirstLaunch = prefs.getBool(_firstLaunchKey) ?? false;
    return !hasCompletedFirstLaunch; // Si pas encore complété = premier lancement
  }

  /// Marque le premier lancement comme terminé
  Future<void> markFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, true); // true = terminé
    if (kDebugMode) {
      debugPrint('🔧 [DEBUG] Premier lancement marqué comme terminé');
    }
  }

  /// Reset le flag de premier lancement 
  Future<void> resetFirstLaunch() async {
    if (kDebugMode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstLaunchKey, false); // false = pas encore terminé
      debugPrint('🔧 [DEBUG] Flag premier lancement réinitialisé - prochaine ouverture = premier lancement');
    }
  }

  /// Force l'affichage du tutoriel 
  Future<bool> forceShowTutorial() async {
    if (kDebugMode) {
      debugPrint('🔧 [DEBUG] Forçage affichage tutoriel');
      return true;
    }
    return false;
  }

  /// Démarre le tutoriel principal
  void startMainTutorial(BuildContext context, {
    required GlobalKey aiButtonKey,
    required GlobalKey searchButtonKey,
    required GlobalKey historyButtonKey,
    required GlobalKey userTrackingButtonKey,
    required GlobalKey mapStyleButtonKey,
  }) {
    final targets = _createTutorialTargets(
      context,
      aiButtonKey: aiButtonKey,
      searchButtonKey: searchButtonKey,
      historyButtonKey: historyButtonKey,
      userTrackingButtonKey: userTrackingButtonKey,
      mapStyleButtonKey: mapStyleButtonKey,
    );

    TutorialCoachMark(
      targets: targets,
      pulseEnable: false,
      colorShadow: Colors.black.withValues(alpha: 0.8),
      paddingFocus: 8,
      opacityShadow: 0.8,
      hideSkip: true,
      skipWidget: _buildSkipButton(context, () {
        // Marquer comme terminé même en mode debug
        markFirstLaunchCompleted();
      }),
      onFinish: () {
        // Toujours marquer comme terminé
        markFirstLaunchCompleted();
        return true;
      },
      onSkip: () {
        // Toujours marquer comme terminé
        markFirstLaunchCompleted();
        return true;
      },
    ).show(context: context);
  }

  /// Crée les cibles du tutoriel
  List<TargetFocus> _createTutorialTargets(
    BuildContext context, {
    required GlobalKey aiButtonKey,
    required GlobalKey searchButtonKey,
    required GlobalKey historyButtonKey,
    required GlobalKey userTrackingButtonKey,
    required GlobalKey mapStyleButtonKey,
  }) {
    return [
      // Bouton de recherche de lieu
      TargetFocus(
        identify: "search_button",
        keyTarget: searchButtonKey,
        alignSkip: Alignment.bottomRight,
        radius: 45,
        paddingFocus: 30,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialContent(
                context,
                title: context.l10n.searchKeyTitle,
                description: context.l10n.searchKeyDesc,
                icon: HugeIcons.solidRoundedSearch01,
                iconLabel: context.l10n.nextMessage,
                onPressed: () => controller.next(),
              );
            },
          ),
        ],
      ),

      // Bouton de génération IA
      TargetFocus(
        identify: "ai_button",
        keyTarget: aiButtonKey,
        alignSkip: Alignment.topLeft,
        radius: 35,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialContent(
                context,
                title: context.l10n.generationKeyTitle,
                description: context.l10n.generationKeyDesc,
                icon: HugeIcons.solidRoundedAiMagic,
                iconLabel: context.l10n.nextMessage,
                onPressed: () => controller.next(),
              );
            },
          ),
        ],
      ),

      // Bouton historique
      TargetFocus(
        identify: "history_button",
        keyTarget: historyButtonKey,
        alignSkip: Alignment.topLeft,
        radius: 20,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTutorialContent(
                context,
                title: context.l10n.historyKeyTitle,
                description: context.l10n.historyKeyDesc,
                icon: HugeIcons.solidRoundedFavourite,
                iconLabel: context.l10n.nextMessage,
                onPressed: () => controller.next(),
              );
            },
          ),
        ],
      ),

      // Réglage de la carte
      TargetFocus(
        identify: "user_tracking_button",
        keyTarget: userTrackingButtonKey,
        alignSkip: Alignment.topLeft,
        radius: 20,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTutorialContent(
                context,
                title: context.l10n.userTrackingKeyTitle,
                description: context.l10n.userTrackingKeyDesc,
                icon: HugeIcons.solidRoundedMapsGlobal01,
                iconLabel: context.l10n.nextMessage,
                onPressed: () => controller.next(),
              );
            },
          ),
        ],
      ),

      // Réglage de la carte
      TargetFocus(
        identify: "map_style_button",
        keyTarget: mapStyleButtonKey,
        alignSkip: Alignment.topLeft,
        radius: 20,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTutorialContent(
                context,
                title: context.l10n.mapStyleKeyTitle,
                description: context.l10n.mapStyleKeyDesc,
                icon: HugeIcons.solidRoundedLayerMask01,
                iconLabel: context.l10n.finishMessage,
                onPressed: () => controller.skip(),
              );
            },
          ),
        ],
      ),
    ];
  }

  /// Construit le contenu d'une étape du tutoriel
  Widget _buildTutorialContent(
    BuildContext context, {
    required String title,
    required String description,
    required String iconLabel,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SquircleContainer(
      gradient: false,
      radius: 80.0,
      padding: EdgeInsets.all(20),
      color: context.adaptiveBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SquircleContainer(
                radius: 40.0,
                gradient: false,
                isGlow: true,
                height: 70,
                width: 70,
                padding: EdgeInsets.all(15.0),
                color: context.adaptivePrimary,
                child: Icon(
                  icon,
                  color: Colors.white,
                ),
              ),
              12.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        color: context.adaptiveTextSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          20.h,

          SquircleBtn(
            isPrimary: true,
            label: iconLabel,
            onTap: onPressed, 
          ),
        ],
      ),
    );
  }

  /// Construit le bouton "Passer"
  Widget _buildSkipButton(BuildContext context, VoidCallback onPressed) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 5.0,
      ),
      decoration: BoxDecoration(
        color: context.adaptivePrimary,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        "Suivant",
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }
}