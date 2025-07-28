import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/route_generator/data/services/reverse_geocoding_service.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/home/presentation/widgets/export_format_dialog.dart';
import 'package:runaway/features/route_generator/data/services/route_export_service.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';
import 'package:runaway/features/route_generator/presentation/widgets/overlay_view.dart';
import 'package:smooth_gradient/smooth_gradient.dart';
import 'package:soft_edge_blur/soft_edge_blur.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class HistoricCard extends StatefulWidget {
  final SavedRoute route;
  final bool isEdit;
  final VoidCallback? onDelete;
  final Function(String)? onRename;
  final VoidCallback? onSync;
  final VoidCallback? onShowOnMap;

  const HistoricCard({
    super.key,
    required this.route,
    this.onDelete,
    this.onRename,
    this.onSync,
    required this.isEdit,
    this.onShowOnMap,
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
  String _originalName = ''; // Nom original pour annulation

  @override
  void initState() {
    super.initState();
    _loadLocationName();
    _nameController = TextEditingController(text: widget.route.name);
     _originalName = widget.route.name;
    _focusNode = FocusNode();

    // 🆕 Écouter les changements pour validation
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    // Validation en temps réel si nécessaire
    setState(() {});
  }

  // Ouvre la modal sheet et traite le résultat
  Future<void> _showRenameSheet() async {
    final newName = await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, Animation<double> animation, __) {
          return OverleyView(
            unit: context.l10n.updateRouteNameHint, // Utiliser le hint comme unit
            initialValue: widget.route.name,
            animation: animation,
            onTap: () => Navigator.of(context).pop(),
            isNumber: false, // 🆕 Mode texte
            maxLength: 50, // 🆕 Limite de caractères
            textCapitalization: TextCapitalization.sentences, // 🆕 Capitalisation
            validator: (value) {
              // 🆕 Validateur personnalisé identique à _confirmRename
              if (value == null || value.isEmpty) {
                return context.l10n.routeNameUpdateException;
              }
              
              if (value.length > 50) {
                return context.l10n.routeNameUpdateExceptionCountCharacters;
              }

              if (value.contains(RegExp(r'[<>:"/\\|?*]'))) {
                return context.l10n.routeNameUpdateExceptionForbiddenCharacters;
              }

              if (value.length < 2) {
                return context.l10n.routeNameUpdateExceptionMinCharacters;
              }

              return null; // Validation OK
            },
          );
        },
      ),
    );

    if (!mounted) return;
    
    if (newName != null && newName != widget.route.name) {
      widget.onRename?.call(newName);
    }
  }

  /// Charge le nom de la localisation via reverse geocoding
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
      LogConfig.logError('❌ Erreur reverse geocoding pour ${widget.route.id}: $e');
      if (mounted) {
        setState(() {
          _locationName = 'Localisation';
        });
      }
    }
  }

  /// Affiche le dialogue de sélection du format d'export
  void _showExportDialog() {
    showModalSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      child: ExportFormatDialog(
        onGpxSelected: () => _exportRoute(RouteExportFormat.gpx),
        onKmlSelected: () => _exportRoute(RouteExportFormat.kml),
      ),
    );
  }

  /// Exporte la route dans le format sélectionné
  Future<void> _exportRoute(RouteExportFormat format) async {
    try {
      // Créer les métadonnées à partir de la route sauvegardée
      final metadata = _buildMetadataFromRoute();
    
      // Nettoyer le nom du fichier
      final cleanName = _sanitizeFileName(widget.route.name);
      
      await RouteExportService.exportRoute(
        context: context,
        coordinates: widget.route.coordinates,
        metadata: metadata,
        format: format,
        customName: cleanName,
      );
    } catch (e) {
      // Afficher un message d'erreur
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            isError: true,
            title: context.l10n.routeExportError(e.toString()),
          ),
        );
      }
    }
  }

  /// Nettoie le nom de fichier en supprimant les caractères invalides
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') // Caractères Windows invalides
        .replaceAll(RegExp(r'[()-]'), '')
        .replaceAll(RegExp(r'[()]'), '') // Parenthèses
        .replaceAll(RegExp(r'\s+'), '_') // Espaces multiples
        .replaceAll(RegExp(r'_+'), '_') // Underscores multiples
        .replaceAll(RegExp(r'^_|_$'), ''); // Underscores en début/fin
  }

  /// Construit les métadonnées à partir de la route sauvegardée
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
    const double imgHeight = 500;
    const double paddingValue = 15.0;

        // Calculer le temps estimé selon l'activité
    final int estimatedMinutes = calculateEstimatedDuration(
      widget.route.parameters.distanceKm, 
      widget.route.parameters.activityType, 
      widget.route.parameters.elevationGain,
    );

    // Formater le temps
    final String timeString = formatDuration(estimatedMinutes);

    return SquircleContainer(
      height: imgHeight,
      onTap: widget.onShowOnMap,
      radius: 80,
      gradient: false,
      color: context.adaptiveBorder.withValues(alpha: 0.05),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(child: _buildBlurredImage(imgHeight)),

          Container(
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: SmoothGradient(
                from: context.adaptiveBackground.withValues(alpha: 0),
                to: context.adaptiveBackground.withValues(alpha: 0.65),
                curve: Curves.linear,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
      
          // Titre et localisation
          Padding(
            padding: const EdgeInsets.only(
              bottom: paddingValue,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: widget.route.name,
                                  style: context.bodyMedium?.copyWith(
                                  fontSize: 20,
                                  color: context.adaptiveTextPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                children: <InlineSpan>[
                                  TextSpan(
                                    text: " • ${widget.route.timeAgo}",
                                    style: context.bodySmall?.copyWith(
                                      fontSize: 16,
                                      height: 1,
                                      fontWeight: FontWeight.w400,
                                      color: context.adaptiveTextPrimary.withValues(alpha: 0.7),
                                    ),
                                  )
                                ]
                              )
                            ),
                          ),
                          
                          _buildActionMenu(),
                        ],
                      ),
                      2.h,
                      Text(
                        _getLocationName(),
                        style: context.bodySmall?.copyWith(
                          fontSize: 18,
                          height: 1,
                          fontWeight: FontWeight.w400,
                          color: context.adaptiveTextPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                12.h,
                
                // Chips avec détails du parcours
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: paddingValue),
                    child: Row(
                      children: [
                        // Distance
                        _buildDetailChip(
                          icon: HugeIcons.solidRoundedRouteBlock,
                          text: "${widget.route.parameters.distanceKm.toStringAsFixed(0)}km",
                        ),
                        5.w,
                        // Type d'activité
                        _buildDetailChip(
                          icon: getActivityIcon(widget.route.parameters.activityType.id),
                          text: widget.route.parameters.activityType.label(context),
                        ),
                        5.w,
                        // Temps estimé
                        _buildDetailChip(
                          icon: HugeIcons.solidRoundedTimeQuarter02,
                          text: timeString,
                        ),
                        5.w,
                        // Type de terrain
                        _buildDetailChip(
                          icon: HugeIcons.solidRoundedMountain,
                          text: widget.route.parameters.terrainType.label(context),
                        ),
                        5.w,
                        // Densité urbaine
                        _buildDetailChip(
                          icon: HugeIcons.solidRoundedPlant01,
                          text: widget.route.parameters.urbanDensity.label(context),
                        ),
                        if (widget.route.parameters.elevationGain > 0) ...[
                          _buildDetailChip(
                            icon: HugeIcons.solidRoundedSine02,
                            text: '${widget.route.parameters.elevationGain.toStringAsFixed(0)}m',
                          ),
                          5.w,
                        ],
                        if (widget.route.parameters.isLoop) ...[
                          _buildDetailChip(
                            icon: HugeIcons.solidRoundedRepeat,
                            text: context.l10n.pathLoop,
                          ),
                          5.w,
                        ]
                        else ...[
                          _buildDetailChip(
                            icon: HugeIcons.solidRoundedNavigator01,
                            text: context.l10n.pathSimple,
                          ),
                          5.w,
                        ],
                        if (widget.route.timesUsed > 0) ...[
                          _buildDetailChip(
                            icon: HugeIcons.solidRoundedFavourite,
                            text: '${widget.route.timesUsed}x',
                            color: Colors.orange,
                          ),
                          5.w,
                        ],
                        // 🆕 AJOUT : Score paysage si supérieur à 6
                        if (widget.route.metrics.scenicScore > 6) ...[
                          _buildDetailChip(
                            icon: HugeIcons.solidRoundedImage01,
                            text: '${context.l10n.scenic} ${widget.route.metrics.scenicScore.toStringAsFixed(1)}/10',
                          ),
                          5.w,
                        ],
                        // 🆕 AJOUT : Pente maximale si supérieure à 5%
                        if (widget.route.metrics.maxIncline > 5) ...[
                          _buildDetailChip(
                            icon: HugeIcons.solidRoundedChart03,
                            text: '${context.l10n.maxSlope} ${widget.route.metrics.maxIncline.toStringAsFixed(1)}%',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                25.h,
                    
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: paddingValue),
                  child: SquircleBtn(
                    isPrimary: true,
                    onTap: _showExportDialog,
                    label: context.l10n.download,
                  ),
                ),
              ],
            ),
          ),        
        ],
      ),
    );
  }

  /// 📱 Affiche l'état de chargement de l'image avec shimmer
  Widget _buildLoadingState(ImageChunkEvent? loadingProgress) {
    const double innerRadius = 30.0;
    
    return SquircleContainer(
      radius: innerRadius,
      color: context.adaptiveDisabled,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(innerRadius),
        ),
      ),
    )
    .animate(onPlay: (controller) => controller.loop())
    .shimmer(
      color: context.adaptiveBackground.withValues(alpha: 0.5), 
      duration: Duration(seconds: 2)
    );
  }

  // 🆕 Menu d'actions (existant)
  Widget _buildActionMenu() {
    return PullDownButton(
      itemBuilder: (context) => [
        PullDownMenuItem(
          icon: HugeIcons.solidRoundedTypeCursor,
          title: context.l10n.renameRoute,
          onTap: _showRenameSheet,
        ),
        if (widget.onSync != null)
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
          HugeIcons.solidRoundedMoreHorizontal,
          color: context.adaptiveTextPrimary,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildRouteImage() {
    return Image.network(
      widget.route.imageUrl!,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.fitHeight,
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
        // 🆕 En cours de chargement - Afficher shimmer au lieu du CircularProgressIndicator
        return _buildLoadingState(loadingProgress);
      },
      errorBuilder: (context, error, stackTrace) {
        LogConfig.logError('❌ Erreur chargement image: $error');
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
    );
  }

  /// 🎨 Fallback avec design basé sur l'activité
  Widget _buildActivityFallback() {
    const double innerRadius = 30.0;
    
    // Si on est encore en train de charger, afficher le shimmer
    if (_isImageLoading && !_hasImageError) {
      return SquircleContainer(
        radius: innerRadius,
        color: context.adaptiveDisabled,
        padding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(innerRadius),
          ),
        ),
      )
      .animate(onPlay: (controller) => controller.loop())
      .shimmer(
        color: context.adaptiveBackground.withValues(alpha: 0.5), 
        duration: Duration(seconds: 2)
      );
    }

    // Sinon, afficher le fallback normal avec l'icône et les informations
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.adaptiveDisabled,
            context.adaptiveDisabled.withValues(alpha: 0.7),
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
    return _locationName ?? 'Mars';
  }

  /// Crée un chip de détail
  Widget _buildDetailChip({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: context.adaptiveTextPrimary,
        borderRadius: BorderRadius.circular(100),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color ?? context.adaptiveBackground,
            size: 17,
          ),
          5.w,
          Text(
            text,
            style: context.bodySmall?.copyWith(
              fontSize: 14,
              color: context.adaptiveBackground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  SoftEdgeBlur _buildBlurredImage(double imgSize) {
    return SoftEdgeBlur(
      edges: [
        EdgeBlur(
          type: EdgeType.bottomEdge,
          size: 300,
          sigma: 80,
          controlPoints: [
            ControlPoint(
              position: 0.5,
              type: ControlPointType.visible,
            ),
            ControlPoint(
              position: 1,
              type: ControlPointType.transparent,
            )
          ],
        )
      ],
      child: _buildRouteImage(),
    );
  }
}