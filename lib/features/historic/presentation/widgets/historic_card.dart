import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/services/reverse_geocoding_service.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';

class HistoricCard extends StatefulWidget {
  final SavedRoute route;
  final bool isEdit;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onSync;

  const HistoricCard({
    super.key,
    required this.route,
    this.onTap,
    this.onDelete,
    this.onRename,
    this.onSync,
    required this.isEdit,
  });

  @override
  State<HistoricCard> createState() => _HistoricCardState();
}

class _HistoricCardState extends State<HistoricCard> {
  late TextEditingController _nameController;
  late FocusNode _focusNode;
  String? _locationName;
  bool _isImageLoading = true;
  bool _hasImageError = false;

  @override
  void initState() {
    super.initState();
    _loadLocationName();
    _nameController = TextEditingController(text: widget.route.name);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
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
          spacing: 20.0,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Visualisation du parcours
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
        
            // Titre et localisation
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getLocationName()} • ${widget.route.timeAgo}',
                  style: context.bodySmall?.copyWith(
                    fontSize: 15,
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.w500,
                    color: Colors.white38,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: EditableText(
                        controller: _nameController,
                        focusNode: _focusNode,
                        style: context.bodyMedium!,
                        cursorColor: AppColors.primary,
                        backgroundCursorColor: AppColors.primary,
                        readOnly: widget.isEdit,
                      ),
                    ),
                    
                    if (widget.isEdit)
                    PullDownButton(
                      itemBuilder: (context) => [
                        PullDownMenuItem(
                          icon: HugeIcons.solidRoundedTypeCursor,
                          title: context.l10n.renameRoute,
                          onTap: widget.onRename,
                        ),
                        PullDownMenuItem(
                          icon: HugeIcons.strokeRoundedLayerSendToBack,
                          title: context.l10n.synchronizeRoute,
                          onTap: widget.onSync,
                        ),
                        PullDownMenuItem(
                          isDestructive: true,
                          icon: HugeIcons.strokeRoundedDelete02,
                          title: context.l10n.deleteRoute,
                          onTap: widget.onDelete,
                        ),
                      ],
                      buttonBuilder: (context, showMenu) => GestureDetector(
                        onTap: () {
                          showMenu();
                          HapticFeedback.mediumImpact();
                        },
                        child: Icon(
                          HugeIcons.strokeRoundedMoreHorizontalCircle02,
                        ),
                      ),
                    )
                    else 
                    GestureDetector(
                      onTap: widget.onRename,
                      child: Icon(
                        HugeIcons.solidRoundedTick02,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // Chips avec détails du parcours
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                _buildDetailChip(
                  icon: widget.route.parameters.activityType.icon,
                  text: widget.route.parameters.activityType.label(context),
                ),
                _buildDetailChip(
                  icon: HugeIcons.solidRoundedNavigator01,
                  text: widget.route.formattedDistance,
                ),
                _buildDetailChip(
                  icon: _getTerrainIcon(),
                  text: widget.route.parameters.terrainType.label(context),
                ),
                _buildDetailChip(
                  icon: _getUrbanDensityIcon(),
                  text: widget.route.parameters.urbanDensity.label(context),
                ),
                if (widget.route.parameters.elevationGain > 0)
                  _buildDetailChip(
                    icon: HugeIcons.solidSharpMountain,
                    text: '${widget.route.parameters.elevationGain.toStringAsFixed(0)}m',
                  ),
                if (widget.route.parameters.isLoop)
                  _buildDetailChip(
                    icon: HugeIcons.solidRoundedRepeat,
                    text: widget.route.parameters.isLoop ? context.l10n.pathLoop : context.l10n.pathSimple,
                  ),
                if (widget.route.timesUsed > 0)
                  _buildDetailChip(
                    icon: HugeIcons.solidRoundedFavourite,
                    text: '${widget.route.timesUsed}x',
                    color: Colors.orange,
                  ),
              ],
            ),
        
            // Boutons d'action
            SquircleContainer(
              onTap: widget.onTap,
              radius: innerRadius,
              color: AppColors.primary,
              padding: EdgeInsets.symmetric(vertical: 15.0),
              child: Center(
                child: Text(
                  context.l10n.followRoute, 
                  style: context.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
              context.l10n.loading,
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
                  context.l10n.imageUnavailable,
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
            style: context.bodySmall?.copyWith(
              fontSize: 14,
              color:Colors.white,
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