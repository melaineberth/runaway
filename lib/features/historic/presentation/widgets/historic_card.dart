import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';

class HistoricCard extends StatelessWidget {
  final SavedRoute route;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const HistoricCard({
    super.key,
    required this.route,
    this.onTap,
    this.onDelete,
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
            // Image générée ou icône représentative
            SizedBox(
              height: 250,
              width: imgSize,
              child: SquircleContainer(
                radius: innerRadius,
                color: _getActivityColor(),
                padding: EdgeInsets.zero,
                child: _buildRouteVisualization(),
              ),
            ),
            paddingValue.h,
            
            // Zone texte et bouton
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre et informations
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: context.bodyMedium?.copyWith(
                                  height: 1.3,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              4.h,
                              Text.rich(
                                TextSpan(
                                  text: '${_getLocationName()} • ',
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: route.timeAgo,
                                      style: context.bodySmall?.copyWith(
                                        height: 1.3,
                                        fontSize: 13,
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
                        
                        // Chips avec détails du parcours
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            _buildDetailChip(
                              icon: route.parameters.activityType.icon,
                              text: route.parameters.activityType.title,
                            ),
                            _buildDetailChip(
                              icon: HugeIcons.solidRoundedNavigator01,
                              text: route.formattedDistance,
                            ),
                            _buildDetailChip(
                              icon: _getTerrainIcon(),
                              text: route.parameters.terrainType.title,
                            ),
                            _buildDetailChip(
                              icon: _getUrbanDensityIcon(),
                              text: route.parameters.urbanDensity.title,
                            ),
                            if (route.parameters.elevationGain > 0)
                              _buildDetailChip(
                                icon: HugeIcons.solidSharpMountain,
                                text: '${route.parameters.elevationGain.toStringAsFixed(0)}m',
                              ),
                            if (route.parameters.isLoop)
                              _buildDetailChip(
                                icon: HugeIcons.solidRoundedRepeat,
                                text: 'Boucle',
                              ),
                            if (route.timesUsed > 0)
                              _buildDetailChip(
                                icon: HugeIcons.solidRoundedFavourite,
                                text: '${route.timesUsed}x',
                                color: Colors.orange,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  paddingValue.h,
                  
                  // Boutons d'action
                  Row(
                    children: [
                      // Bouton principal "Suivre"
                      Expanded(
                        child: SquircleContainer(
                          onTap: onTap,
                          radius: innerRadius,
                          color: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 15.0),
                          child: Center(
                            child: Text(
                              "Suivre", 
                              style: context.bodySmall?.copyWith(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      12.w,
                      
                      // Bouton supprimer
                      SquircleContainer(
                        onTap: onDelete,
                        radius: innerRadius,
                        color: Colors.red.withAlpha(30),
                        padding: EdgeInsets.all(15.0),
                        child: Icon(
                          HugeIcons.strokeRoundedDelete02,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget de visualisation de la route (simple pattern géométrique)
  Widget _buildRouteVisualization() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getActivityColor(),
            _getActivityColor().withAlpha(180),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Pattern de route stylisé
          Center(
            child: Icon(
              route.parameters.activityType.icon,
              size: 80,
              color: Colors.white.withAlpha(150),
            ),
          ),
          
          // Badge de synchronisation si pertinent
          if (!route.isSynced)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  HugeIcons.strokeRoundedWifiOff01,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
            
          // Badge de favori si utilisé plusieurs fois
          if (route.timesUsed > 3)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  HugeIcons.solidRoundedStar,
                  size: 16,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Chip de détail personnalisé
  Widget _buildDetailChip({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(100),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color ?? Colors.white,
            size: 17,
          ),
          5.w,
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color ?? Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Couleur basée sur le type d'activité
  Color _getActivityColor() {
    switch (route.parameters.activityType.title.toLowerCase()) {
      case 'course':
        return Colors.red;
      case 'vélo':
        return Colors.blue;
      case 'marche':
        return Colors.green;
      default:
        return AppColors.primary;
    }
  }

  /// Icône pour le terrain
  IconData _getTerrainIcon() {
    switch (route.parameters.terrainType.title.toLowerCase()) {
      case 'plat':
        return HugeIcons.strokeRoundedRoad;
      case 'vallonné':
        return HugeIcons.strokeRoundedMountain;
      default:
        return HugeIcons.solidRoundedRouteBlock;
    }
  }

  /// Icône pour la densité urbaine
  IconData _getUrbanDensityIcon() {
    switch (route.parameters.urbanDensity.title.toLowerCase()) {
      case 'urbain':
        return HugeIcons.solidRoundedCity03;
      case 'nature':
        return HugeIcons.strokeRoundedTree05;
      default:
        return HugeIcons.strokeRoundedLocation04;
    }
  }

  /// Nom de localisation simplifié
  String _getLocationName() {
    // Pour l'instant, retourner une localisation générique
    // Plus tard, on pourrait faire du reverse geocoding avec les coordonnées
    return 'Localisation';
  }
}