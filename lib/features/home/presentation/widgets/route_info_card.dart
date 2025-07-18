import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/home/domain/models/route_metrics.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/route_generator/domain/models/terrain_type.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';

/// Widget pour afficher les informations de la route générée
class RouteInfoCard extends StatelessWidget {
  final String routeName;
  final RouteParameters parameters;
  final RouteMetrics metrics;
  final bool isLoop;
  final VoidCallback onClear;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final bool isSaving;
  final bool isAlreadySaved;

  const RouteInfoCard({
    super.key,
    required this.routeName,
    required this.parameters,
    required this.metrics,
    required this.isLoop,
    required this.onClear,
    required this.onShare,
    required this.onSave,
    this.isSaving = false,
    this.isAlreadySaved = false,

  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // En-tête avec infos principales
        Padding(
          padding: const EdgeInsets.fromLTRB(30.0, 30.0, 30.0, 0.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  routeName,
                  style: context.bodyMedium,
                ),
              ),
              // Bouton fermer
              IconBtn(
                padding: 0.0,
                backgroundColor: Colors.transparent,
                onPressed: onClear,
                icon: HugeIcons.solidRoundedCancelCircle,
                iconColor: context.adaptiveDisabled.withValues(alpha: 0.2),
              ),
            ],
          ),
        ),

        10.h,
        _buildDetailChips(context),
        
        20.h,
    
        // Boutons d'action
        Padding(
          padding: const EdgeInsets.fromLTRB(30.0, 0.0, 30.0, 30.0),
          child: Column(
            children: [
              SquircleBtn(
                label: context.l10n.download,
                onTap: onShare,
                isPrimary: true,
              ),
              8.h,
              SquircleBtn(
                label: _getSaveLabel(context),
                onTap: _getSaveAction(),
                isPrimary: false,
                isLoading: isSaving,
                isDisabled: isAlreadySaved,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailChips(BuildContext context) {
    // Nouveau format avec plus d'informations
    return SizedBox(
      height: 40,
      child: BlurryPage(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 30),
        children: [
          // Type de terrain
          _InfoChip(
            icon: getTerrainIcon(parameters.terrainType.id),
            label: parameters.terrainType.label(context),
          ),
          10.w,
          
          // Densité urbaine
          _InfoChip(
            icon: getUrbanDensityIcon(parameters.urbanDensity.id),
            label: parameters.urbanDensity.label(context),
          ),
          10.w,
          
          // Type de parcours
          _InfoChip(
            icon: isLoop 
                ? HugeIcons.solidRoundedRepeat
                : HugeIcons.strokeRoundedArrowRight01,
            label: isLoop ? context.l10n.pathLoop : context.l10n.pathSimple,
          ),
          10.w,
          
          // Score paysage
          if (metrics.scenicScore > 6)
            _InfoChip(
              icon: HugeIcons.solidRoundedImage01,
              label: '${context.l10n.scenic} ${metrics.scenicScore.toStringAsFixed(1)}/10',
            ),
          10.w,
          
          // Pente maximale
          if (metrics.maxIncline > 5)
            _InfoChip(
              icon: HugeIcons.strokeRoundedMountain,
              label: '${context.l10n.maxSlope} ${metrics.maxIncline.toStringAsFixed(1)}%',
            ),
        ],
      ),
    );
  }

  String _getSaveLabel(BuildContext context) {
    if (isSaving) {
      return context.l10n.saving;
    } else if (isAlreadySaved) {
      return context.l10n.alreadySaved;
    } else {
      return context.l10n.save;
    }
  }

  VoidCallback? _getSaveAction() {
    if (isSaving || isAlreadySaved) {
      return null; // Désactiver le bouton
    } else {
      return onSave;
    }
  }
}

/// Chip d'information
class _InfoChip extends StatelessWidget {
  final dynamic icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: context.adaptiveBorder.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            size: 17,
            color: context.adaptiveTextPrimary,
          ),
          5.w,
          Text(
            label,
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