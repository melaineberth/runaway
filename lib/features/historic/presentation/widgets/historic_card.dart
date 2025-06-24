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
  bool _isImageLoading = true;
  bool _hasImageError = false;

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
            // 🖼️ Image générée ou visualisation de fallback
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

/// 🆕 Construit la visualisation de la route avec image ou fallback amélioré
  Widget _buildRouteVisualization() {
    if (widget.route.hasImage) {
      return _buildRouteImage();
    } else {
      return _buildActivityFallback();
    }
  }

  /// 🖼️ Affiche l'image de la route avec gestion d'erreurs
  Widget _buildRouteImage() {
    return Stack(
      children: [
        // Image principale
        Image.network(
          widget.route.imageUrl!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              // Image chargée avec succès
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _isImageLoading = false;
                    _hasImageError = false;
                  });
                }
              });
              return child;
            }
            // En cours de chargement
            return _buildLoadingState(loadingProgress);
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ Erreur chargement image: $error');
            // Marquer l'erreur et afficher le fallback
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hasImageError = true;
                  _isImageLoading = false;
                });
              }
            });
            return _buildActivityFallback();
          },
        ),

        if (_isImageLoading)
        CircularProgressIndicator(),

        IgnorePointer(
          ignoring: true,
          child: Container(
            height: MediaQuery.of(context).size.height,
            color: Colors.white.withAlpha(18),
          ),
        ),
    
        // Indicator de statut sync
        if (!widget.route.isSynced)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                HugeIcons.strokeRoundedWifiOff01,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  /// 📱 Affiche l'état de chargement de l'image
  Widget _buildLoadingState(ImageChunkEvent loadingProgress) {
    return Container(
      color: _getActivityColor(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      (loadingProgress.expectedTotalBytes ?? 1)
                  : null,
            ),
            8.h,
            Text(
              'Chargement...',
              style: context.bodySmall?.copyWith(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎨 Fallback avec design basé sur l'activité
  Widget _buildActivityFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getActivityColor(),
            _getActivityColor().withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Stack(
        children: [
          // Pattern de fond subtil
          Positioned.fill(
            child: CustomPaint(
              painter: RoutePatternPainter(_getActivityColor()),
            ),
          ),
          
          // Contenu principal
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icône de l'activité
                Icon(
                  _getActivityIcon(),
                  color: Colors.white,
                  size: 40,
                ),
                12.h,
                
                // Informations sur le parcours
                Text(
                  widget.route.formattedDistance,
                  style: context.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                4.h,
                Text(
                  widget.route.parameters.activityType.title,
                  style: context.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Badge "Pas d'image" si erreur
          if (_hasImageError)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Image indisponible',
                  style: context.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

   /// Icône basée sur le type d'activité
  IconData _getActivityIcon() {
    switch (widget.route.parameters.activityType.id) {
      case 'running':
        return HugeIcons.strokeRoundedBicycle01;
      case 'cycling':
        return HugeIcons.strokeRoundedBicycle01;
      case 'walking':
        return HugeIcons.strokeRoundedBicycle01;
      default:
        return HugeIcons.strokeRoundedRoute01;
    }
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
class RoutePatternPainter extends CustomPainter {
  final Color color;

  RoutePatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Dessiner des lignes diagonales subtiles
    for (double i = -size.height; i < size.width + size.height; i += 20) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}