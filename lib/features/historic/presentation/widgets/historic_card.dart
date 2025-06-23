import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/services/reverse_geocoding_service.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';

class HistoricCard extends StatefulWidget {
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
  State<HistoricCard> createState() => _HistoricCardState();
}

class _HistoricCardState extends State<HistoricCard> {
  String? _locationName;

  @override
  void initState() {
    super.initState();
    _loadLocationName();
  }

  /// 🆕 Charge le nom de la localisation via reverse geocoding
  Future<void> _loadLocationName() async {
    try {
      final locationInfo = await ReverseGeocodingService.getLocationNameForRoute(
        widget.route.coordinates,
      );
      
      if (mounted) {
        setState(() {
          _locationName = locationInfo.displayName;
        });
      }
    } catch (e) {
      print('❌ Erreur reverse geocoding pour ${widget.route.id}: $e');
      if (mounted) {
        setState(() {
          _locationName = 'Localisation';
        });
      }
    }
  }

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
                                widget.route.name,
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
                                      text: widget.route.timeAgo,
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
                        
                        // Chips avec détails du parcours
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            _buildDetailChip(
                              icon: widget.route.parameters.activityType.icon,
                              text: widget.route.parameters.activityType.title,
                            ),
                            _buildDetailChip(
                              icon: HugeIcons.solidRoundedNavigator01,
                              text: widget.route.formattedDistance,
                            ),
                            _buildDetailChip(
                              icon: _getTerrainIcon(),
                              text: widget.route.parameters.terrainType.title,
                            ),
                            _buildDetailChip(
                              icon: _getUrbanDensityIcon(),
                              text: widget.route.parameters.urbanDensity.title,
                            ),
                            if (widget.route.parameters.elevationGain > 0)
                              _buildDetailChip(
                                icon: HugeIcons.solidSharpMountain,
                                text: '${widget.route.parameters.elevationGain.toStringAsFixed(0)}m',
                              ),
                            if (widget.route.parameters.isLoop)
                              _buildDetailChip(
                                icon: HugeIcons.solidRoundedRepeat,
                                text: 'Boucle',
                              ),
                            if (widget.route.timesUsed > 0)
                              _buildDetailChip(
                                icon: HugeIcons.solidRoundedFavourite,
                                text: '${widget.route.timesUsed}x',
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
                          onTap: widget.onTap,
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
                        onTap: widget.onDelete,
                        radius: innerRadius,
                        color: Colors.red.withValues(alpha: 0.3),
                        padding: EdgeInsets.all(15.0),
                        child: Icon(
                          HugeIcons.solidRoundedDelete02,
                          color: Colors.red,
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

  /// 🆕 Construit la visualisation de la route avec image ou fallback
  Widget _buildRouteVisualization() {
    if (widget.route.hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(30.0),
        child: Stack(
          children: [
            // Image de la route
            Image.network(
              widget.route.imageUrl!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: _getActivityColor(),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              (loadingProgress.expectedTotalBytes ?? 1)
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('❌ Erreur chargement image: $error');
                return _buildFallbackVisualization();
              },
            ),
            // Overlay avec icône d'activité
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  widget.route.parameters.activityType.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return _buildFallbackVisualization();
    }
  }

  /// Visualisation de fallback quand pas d'image
  Widget _buildFallbackVisualization() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.0),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getActivityColor(),
            _getActivityColor().withOpacity(0.7),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Pattern de fond
          CustomPaint(
            size: Size.infinite,
            painter: _RoutePatternPainter(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          // Icône centrale
          Center(
            child: Icon(
              widget.route.parameters.activityType.icon,
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }

  /// 🆕 Retourne le nom de la localisation (implémentation complète)
  String _getLocationName() {
    return _locationName ?? 'Localisation';
  }

  /// Crée un chip de détail
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
    switch (widget.route.parameters.activityType.title.toLowerCase()) {
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
    switch (widget.route.parameters.terrainType.title.toLowerCase()) {
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
    switch (widget.route.parameters.urbanDensity.title.toLowerCase()) {
      case 'urbain':
        return HugeIcons.solidRoundedCity03;
      case 'nature':
        return HugeIcons.strokeRoundedTree05;
      default:
        return HugeIcons.strokeRoundedLocation04;
    }
  }
}

/// 🆕 Painter pour créer un pattern de route stylisé
class _RoutePatternPainter extends CustomPainter {
  final Color color;

  _RoutePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Créer un pattern de route sinueuse
    final width = size.width;
    final height = size.height;
    
    // Ligne principale ondulée
    path.moveTo(width * 0.2, height * 0.3);
    path.quadraticBezierTo(width * 0.5, height * 0.1, width * 0.8, height * 0.4);
    path.quadraticBezierTo(width * 0.6, height * 0.7, width * 0.9, height * 0.8);
    
    // Ligne secondaire
    path.moveTo(width * 0.1, height * 0.6);
    path.quadraticBezierTo(width * 0.4, height * 0.5, width * 0.7, height * 0.7);
    
    canvas.drawPath(path, paint);
    
    // Quelques points de jalons
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(width * 0.2, height * 0.3), 3, pointPaint);
    canvas.drawCircle(Offset(width * 0.8, height * 0.4), 3, pointPaint);
    canvas.drawCircle(Offset(width * 0.9, height * 0.8), 3, pointPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}