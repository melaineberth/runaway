import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/route_generator/data/services/reverse_geocoding_service.dart';
import 'package:runaway/core/widgets/top_snackbar.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
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
  final Function(String)? onRename;
  final VoidCallback? onSync;
  final VoidCallback? onShowOnMap; // Callback pour afficher sur la carte

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
  bool _isRenaming = false; // État de renommage
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
    final newName = await showModalBottomSheet<String>(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      context: context,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: Colors.transparent,
      builder: (context) => RenameRouteSheet(initialValue: widget.route.name),
    );

    if (!mounted) return;
    final trimmed = newName?.trim();

    if (trimmed != null &&
        trimmed.isNotEmpty &&
        trimmed != widget.route.name) {
      widget.onRename?.call(trimmed);
    }
  }

  /// Confirme le renommage
  void _confirmRename() {
    final newName = _nameController.text.trim();
    
    // Validation basique
    if (newName.isEmpty) {
      _showError('Le nom ne peut pas être vide');
      return;
    }
    
    if (newName == _originalName) {
      _cancelRename();
      return;
    }
    
    if (newName.length > 50) {
      _showError('Le nom ne peut pas dépasser 50 caractères');
      return;
    }

    // 🆕 Validation des caractères interdits
    if (newName.contains(RegExp(r'[<>:"/\\|?*]'))) {
      _showError('Le nom contient des caractères interdits');
      return;
    }

    // 🆕 Validation de la longueur minimale
    if (newName.length < 2) {
      _showError('Le nom doit contenir au moins 2 caractères');
      return;
    }

    setState(() {
      _isRenaming = false;
    });
    
    _focusNode.unfocus();
    
    // Feedback haptique
    HapticFeedback.lightImpact();
    
    widget.onRename?.call(newName);
    
    LogConfig.logInfo('✏️ Renommage confirmé: ${widget.route.id} -> $newName');
  }

  /// Annule le renommage
  void _cancelRename() {
    setState(() {
      _isRenaming = false;
      _nameController.text = _originalName;
    });
    _focusNode.unfocus();
  }

  /// Affiche une erreur
  void _showError(String message) {
    if (mounted) {
      showTopSnackBar(
        Overlay.of(context),
        TopSnackBar(
          isError: true,
          title: message,
        ),
      );
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

      // Afficher un message de succès
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            title: 'Parcours exporté en ${format.displayName}',
          ),
        );
      }

    } catch (e) {
      // Afficher un message d'erreur
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          TopSnackBar(
            isError: true,
            title: 'Erreur lors de l\'export: $e',
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
    const innerRadius = 50.0;
    const double imgSize = 150;
    const double paddingValue = 15.0;
    const padding = EdgeInsets.all(paddingValue);
    final outerRadius = padding.calculateOuterRadius(innerRadius);

    return IntrinsicHeight(
      child: SquircleContainer(
        onTap: widget.onShowOnMap,
        radius: outerRadius,
        padding: padding,
        gradient: false,
        color: context.adaptiveBorder.withValues(alpha: 0.05),
        child: Column(
          spacing: 20.0,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Visualisation du parcours
            SizedBox(
              height: 250,
              width: imgSize,
              child: SquircleContainer(
                radius: 50,
                color: context.adaptiveDisabled,
                padding: EdgeInsets.zero,
                child: _buildRouteImage(),
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
                      child: _isRenaming ? _buildEditableField() : _buildDisplayName(),
                    ),
                    
                    if (widget.isEdit && !_isRenaming)
                      _buildActionMenu()
                    else if (_isRenaming)
                      _buildRenameActions(),
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

            SquircleBtn(
              isPrimary: true,
              onTap: _showExportDialog,
              label: context.l10n.download,
            ),        
          ],
        ),
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

  // 🆕 Champ éditable pour le renommage
  Widget _buildEditableField() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: context.adaptivePrimary, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _nameController,
        focusNode: _focusNode,
        style: context.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        maxLength: 50,
        buildCounter: (context, {required currentLength, maxLength, required isFocused}) => null,
        onSubmitted: (_) => _confirmRename(),
        textInputAction: TextInputAction.done,
      ),
    );
  }

  // 🆕 Nom affiché en mode lecture
  Widget _buildDisplayName() {
    return Text(
      widget.route.name,
      style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // 🆕 Menu d'actions (existant)
  Widget _buildActionMenu() {
    return PullDownButton(
      itemBuilder: (context) => [
        PullDownMenuItem(
          icon: HugeIcons.solidRoundedTypeCursor,
          title: context.l10n.renameRoute,
          onTap: _showRenameSheet, // 🆕 Démarre le renommage
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
          HugeIcons.strokeRoundedMoreVertical,
        ),
      ),
    );
  }

  // 🆕 Actions de confirmation/annulation du renommage
  Widget _buildRenameActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _cancelRename,
          child: Container(
            padding: EdgeInsets.all(6),
            child: Icon(
              HugeIcons.strokeRoundedCancel01,
              color: context.adaptiveTextSecondary,
              size: 20,
            ),
          ),
        ),
        8.w,
        GestureDetector(
          onTap: _confirmRename,
          child: Container(
            padding: EdgeInsets.all(6),
            child: Icon(
              HugeIcons.strokeRoundedTick02,
              color: context.adaptivePrimary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

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
        ),

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
}

class RenameRouteSheet extends StatefulWidget {
  final String initialValue;                // <-- seulement la valeur
  const RenameRouteSheet({required this.initialValue, super.key});

  @override
  State<RenameRouteSheet> createState() => _RenameRouteSheetState();
}

class _RenameRouteSheetState extends State<RenameRouteSheet> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return ModalSheet(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Mise à jour",
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextPrimary,
              ),
            ),
            2.h,
            Text(
              "Choisissez un nouveau nom",
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500
              ),
            ),
            20.h,
            AuthTextField(
              controller: _ctl,
              hint: 'Nom du parcours',
              textCapitalization: TextCapitalization.sentences,
              maxLines: 1,
            ),
              
            12.h,

            SquircleBtn(
              isPrimary: true,
              onTap: () {
                final name = _ctl.text.trim();
                if (name.isEmpty) return;
                context.pop(name);
              }, // 🆕 Désactiver si loading
              label: context.l10n.save,
            ),                 
          ],
        ),
      ),
    );
  }
}