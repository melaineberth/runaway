import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class HistoricCard extends StatelessWidget {
  final String imgPath;
  final String title;
  final String location;
  final String timestamp;

  const HistoricCard({
    super.key, required this.imgPath, required this.title, required this.location, required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    const innerRadius = 30.0;
    const double imgSize = 150;
    const double paddingValue = 15.0;
    const padding = EdgeInsets.all(paddingValue);
    final outerRadius = padding.calculateOuterRadius(innerRadius);

    return IntrinsicHeight(
      child: SquircleContainer(
        radius: outerRadius,
        padding: padding,
        color: Colors.white10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Conteneur de l'image : taille fixe en largeur, en hauteur on étreint le parent
            SizedBox(
              height: 250,
              width: imgSize,
              child: SquircleContainer(
                radius: innerRadius,
                color: Colors.blue,
                padding: EdgeInsets.zero,
                child: Image.asset(
                  imgPath,
                  fit: BoxFit.cover,
                  width: imgSize,
                ),
              ),
            ),
            // Espace horizontal
            paddingValue.h,
            // Zone texte et bouton : on la laisse se dimensionner verticalement
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre et sous-titre
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                                style: context.bodyMedium?.copyWith(
                                  height: 1.3,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  text: '$location • ',
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: timestamp,
                                      style: context.bodySmall?.copyWith(
                                        height: 1.3,
                                        fontSize: 15,
                                        fontStyle: FontStyle.normal,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white38,
                                      ),
                                    )
                                  ],
                                  style: context.bodySmall?.copyWith(
                                    height: 1.3,
                                    fontSize: 15,
                                    fontStyle: FontStyle.normal,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white38,
                                  ),
                                )
                              ),
                            ],
                          ),
                        ),
                        15.h,
                        // Détails
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
                                    'Course',
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
                                    HugeIcons.solidRoundedNavigator01, 
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
                                    HugeIcons.solidRoundedCity03, 
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
                                    HugeIcons.solidRoundedRepeat, 
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                  5.w,
                                  Text(
                                    'Loop',
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
    );
  }
}