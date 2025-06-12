import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/account/presentation/screens/account_screen.dart';

import '../../../../core/widgets/ask_registration.dart';

class HistoricScreen extends StatefulWidget {
  const HistoricScreen({super.key});

  @override
  State<HistoricScreen> createState() => _HistoricScreenState();
}

class _HistoricScreenState extends State<HistoricScreen> {
  bool isAuth = true;

  @override
  void initState() {
    checkAuth();
    super.initState();
  }

  void checkAuth() {
    if (!isAuth) {
      _showAuthModal();
    }
  }

  Future<void> _showAuthModal() async { 
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context, 
        useRootNavigator: true,
        enableDrag: false,
        isDismissible: false,
        isScrollControlled: true,
        builder: (modalCtx) {
          return AskRegistration();
        },
      );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    const innerRadius = 30.0;
    const double imgSize = 150;
    const double paddingValue = 8.0;
    const padding = EdgeInsets.all(paddingValue);
    final outerRadius = padding.calculateOuterRadius(innerRadius);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        title: Text(
          "Historique",
          style: context.bodySmall?.copyWith(
            color: Colors.white,
          ),
        ),
      ),
      body: BlurryPage(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                IntrinsicHeight(
                  child: SquircleContainer(
                    radius: outerRadius,
                    padding: padding,
                    color: Colors.white10,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Conteneur de l'image : taille fixe en largeur, en hauteur on étreint le parent
                        SizedBox(
                          width: imgSize,
                          child: SquircleContainer(
                            radius: innerRadius,
                            color: Colors.blue,
                            padding: EdgeInsets.zero,
                            child: Image.asset(
                              "assets/img/road.png",
                              fit: BoxFit.cover,
                              width: imgSize,
                            ),
                          ),
                        ),
                        // Espace horizontal
                        paddingValue.w,
                        // Zone texte et bouton : on la laisse se dimensionner verticalement
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Titre et sous-titre
                              Expanded(
                                child: SquircleContainer(
                                  color: Colors.white10,
                                  padding: EdgeInsets.all(12.0),
                                  radius: innerRadius,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Parcours d'entraînement",
                                              overflow: TextOverflow.ellipsis,
                                              style: context.bodyMedium?.copyWith(
                                                height: 1.3,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              "Brulon, France",
                                              style: context.bodySmall?.copyWith(
                                                height: 1.3,
                                                fontSize: 15,
                                                fontStyle: FontStyle.italic,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      15.h,
                                      // Détails
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 8.0,
                                            runSpacing: 8.0,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white10,
                                                  borderRadius: BorderRadius.circular(100),
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12.0,
                                                  vertical: 8.0
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      HugeIcons.solidRoundedWorkoutRun, 
                                                      color: Colors.white,
                                                      size: 17,
                                                    ),
                                                    5.w,
                                                    Text(
                                                      '10km',
                                                      style: context.bodySmall?.copyWith(
                                                        fontSize: 13,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white10,
                                                  borderRadius: BorderRadius.circular(100),
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12.0,
                                                  vertical: 8.0
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      HugeIcons.solidRoundedRouteBlock, 
                                                      color: Colors.white,
                                                      size: 17,
                                                    ),
                                                    5.w,
                                                    Text(
                                                      'Mixte',
                                                      style: context.bodySmall?.copyWith(
                                                        fontSize: 13,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white10,
                                                  borderRadius: BorderRadius.circular(100),
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12.0,
                                                  vertical: 8.0
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      HugeIcons.solidSharpMountain, 
                                                      color: Colors.white,
                                                      size: 17,
                                                    ),
                                                    5.w,
                                                    Text(
                                                      '5km',
                                                      style: context.bodySmall?.copyWith(
                                                        fontSize: 13,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              paddingValue.h,
                              // Bouton "Suivre"
                              SizedBox(
                                width: double.infinity,
                                // Ne pas imbriquer Expanded dans SizedBox : on veut juste que le bouton prenne toute la largeur disponible de la colonne
                                child: SquircleContainer(
                                  radius: innerRadius,
                                  color: AppColors.primary,
                                  padding: EdgeInsets.symmetric(
                                    vertical: 15.0,
                                  ),
                                  child: Center(
                                    child: Text(
                                      "Suivre", 
                                      style: context.bodySmall?.copyWith(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}