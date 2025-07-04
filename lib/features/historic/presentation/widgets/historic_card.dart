import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/constants.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/core/services/reverse_geocoding_service.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/home/presentation/widgets/export_format_dialog.dart';
import 'package:runaway/features/route_generator/data/services/route_export_service.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class HistoricCard extends StatefulWidget {
  final SavedRoute route;
  final bool isEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onSync;

  const HistoricCard({
    super.key,
    required this.route,
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

  /// 🆕 Affiche le dialogue de sélection du format d'export
  void _showExportDialog() {
    showModalSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      child: ExportFormatDialog(
        onGpxSelected: () => _exportRoute(RouteExportFormat.gpx),
        onKmlSelected: () => _exportRoute(RouteExportFormat.kml),
        onJsonSelected: () => _exportRoute(RouteExportFormat.json),
      ),
    );
  }

  /// 🆕 Exporte la route dans le format sélectionné
  Future<void> _exportRoute(RouteExportFormat format) async {
    try {
      // Créer les métadonnées à partir de la route sauvegardée
      final metadata = _buildMetadataFromRoute();
      
      // Exporter la route
      await RouteExportService.exportRoute(
        context: context,
        coordinates: widget.route.coordinates,
        metadata: metadata,
        format: format,
        customName: widget.route.name,
      );

      // Afficher un message de succès
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: 'Parcours exporté en ${format.displayName}',
            icon: HugeIcons.solidRoundedTick04,
            color: Colors.lightGreen,
          ),
        );
      }

    } catch (e) {
      // Afficher un message d'erreur
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: 'Erreur lors de l\'export: $e',
            icon: HugeIcons.solidRoundedAlert02,
            color: Colors.red,
          ),
        );
      }
    }
  }

  /// 🆕 Construit les métadonnées à partir de la route sauvegardée
  Map<String, dynamic> _buildMetadataFromRoute() {
    return {
      'distanceKm': widget.route.actualDistance ?? widget.route.parameters.distanceKm,
      'durationMinutes': widget.route.formattedDuration,
      'elevationGain': widget.route.parameters.elevationGain,
      'is_loop': widget.route.parameters.isLoop,
      'generatedAt': widget.route.createdAt.toIso8601String(),
      'parameters': {
        'activity_type': widget.route.parameters.activityType.id,
        'terrain_type': widget.route.parameters.terrainType.id,
        'urban_density': widget.route.parameters.urbanDensity.id,
      },
    };
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
        gradient: false,
        color: context.adaptiveBorder.withValues(alpha: 0.08),
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
                    color: context.adaptiveTextSecondary,
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
                        cursorColor: context.adaptivePrimary,
                        backgroundCursorColor: context.adaptivePrimary,
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
                  icon: getTerrainIcon(widget.route.parameters.terrainType.title.toLowerCase()),
                  text: widget.route.parameters.terrainType.label(context),
                ),
                _buildDetailChip(
                  icon: getUrbanDensityIcon(widget.route.parameters.urbanDensity.title.toLowerCase()),
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
              onTap: _showExportDialog,
              radius: innerRadius,
              height: 55,
              color: context.adaptivePrimary,
              padding: EdgeInsets.symmetric(vertical: 15.0),
              child: Center(
                child: Text(
                  context.l10n.download, 
                  style: context.bodySmall?.copyWith(
                    fontSize: 18,
                    color: Colors.white,
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
                  color: context.adaptiveBackground,
                  size: 40,
                ),
                12.h,
                
                // Informations sur le parcours
                Text(
                  widget.route.formattedDistance,
                  style: context.titleMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                4.h,
                Text(
                  widget.route.parameters.activityType.title,
                  style: context.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
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
                  color: context.adaptiveBackground.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.l10n.imageUnavailable,
                  style: context.bodySmall?.copyWith(
                    color: context.adaptiveTextPrimary,
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
        color: context.adaptiveBorder.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color ?? context.adaptiveTextPrimary,
            size: 17,
          ),
          5.w,
          Text(
            text,
            style: context.bodySmall?.copyWith(
              fontSize: 14,
              color:context.adaptiveTextPrimary,
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
}