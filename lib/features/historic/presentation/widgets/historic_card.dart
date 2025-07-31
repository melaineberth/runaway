import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/route_generator/data/services/reverse_geocoding_service.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/home/presentation/widgets/export_format_dialog.dart';
import 'package:runaway/features/route_generator/data/services/route_export_service.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/presentation/widgets/overlay_view.dart';
import 'package:smooth_gradient/smooth_gradient.dart';
import 'package:soft_edge_blur/soft_edge_blur.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class HistoricCard extends StatefulWidget {
  final SavedRoute route;
  final bool isEdit;
  final bool isSelected; // 🆕 État de sélection
  final VoidCallback? onDelete;
  final VoidCallback? onSync;
  final Function(String)? onRename;
  final VoidCallback? onShowOnMap;
  final VoidCallback? onToggleSelection; // 🆕 Callback de sélection

  const HistoricCard({
    super.key,
    required this.route,
    this.isEdit = false,
    this.isSelected = false, // 🆕 Par défaut non sélectionné
    this.onDelete,
    this.onSync,
    this.onRename,
    this.onShowOnMap,
    this.onToggleSelection, // 🆕 Callback optionnel
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
            maxLength: 30, // 🆕 Limite de caractères
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
    const double imgHeight = 300;
    const double paddingValue = 25.0;

    return SquircleContainer(
      height: imgHeight,
      onTap: () {
        if (widget.isEdit) {
          widget.onToggleSelection?.call();
        } else {
          widget.onShowOnMap?.call();
        }
      },
      radius: 60,
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

          // Checkbox de sélection en mode édition
          if (widget.isEdit)
            Positioned(
              top: 15,
              right: 15,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.isSelected 
                    ? context.adaptivePrimary 
                    : Colors.black.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isSelected 
                    ? HugeIcons.strokeRoundedTick02 
                    : null,
                  color: widget.isSelected ? Colors.white : context.adaptiveTextSecondary,
                  size: 25,
                ),
              ),
            ),
      
          // Titre et localisation
          _buildRouteInfo(paddingValue),        
        ],
      ),
    );
  }

  Widget _buildRouteInfo(double paddingValue) {
    return Padding(
      padding: EdgeInsets.all(paddingValue),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nom de la route avec ellipsis
                  Flexible(
                    child: Text(
                      widget.route.name,
                      style: context.bodyMedium?.copyWith(
                        fontSize: 20,
                        color: context.adaptiveTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  
                  // TimeAgo toujours visible
                  Text(
                    " • ${widget.route.timeAgo}",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      color: context.adaptiveTextPrimary.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
              2.h,
              Text(
                _getLocationName(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: context.adaptiveTextPrimary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),

          if (!widget.isEdit)
          _buildActionMenu(),
        ],
      ),
    );
  }

  /// Affiche l'état de chargement de l'image avec shimmer
  Widget _buildLoadingState() {
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

  // Menu d'actions (existant)
  Widget _buildActionMenu() {
    return PullDownButton(
      itemBuilder: (context) => [
        PullDownMenuItem(
          icon: HugeIcons.strokeStandardCursorText,
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
          icon: HugeIcons.strokeRoundedDownloadSquare02,
          title: context.l10n.download,
          onTap: _showExportDialog,
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
          HugeIcons.solidRoundedMoreVertical,
          color: context.adaptiveTextPrimary,
          size: 25,
        ),
      ),
    );
  }

  Widget _buildRouteImage() {
    return CachedNetworkImage(
      imageUrl: widget.route.imageUrl!,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) {
        return _buildLoadingState();
      },
      errorListener: (value) {
        LogConfig.logError('❌ Erreur chargement image: $value');
        // Marquer l'erreur et afficher le fallback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _hasImageError = true;
              _isImageLoading = false;
            });
          }
        });
      },
    );    
  }

  /// Retourne le nom de la localisation (implémentation complète)
  String _getLocationName() {
    return _locationName ?? 'Mars';
  }

  Widget _buildBlurredImage(double imgSize) {
    return SoftEdgeBlur(
      edges: [
        EdgeBlur(
          type: EdgeType.bottomEdge,
          size: imgSize / 2,
          sigma: 80,
          tintColor: context.adaptiveTextPrimary.withValues(alpha: 0.08),
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