import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/utils/constant/constants.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

/// Widget pour afficher les informations de la route générée
class RouteInfoCard extends StatelessWidget {
  final String routeName;
  final double distance;
  final bool isLoop;
  final int waypointCount;
  final RouteParameters? parameters; // Paramètres du parcours
  final VoidCallback onClear;
  final VoidCallback onShare;
  final VoidCallback onSave; // Callback de sauvegarde
  final bool isSaving; // État de sauvegarde en cours
  final bool isAlreadySaved; // Indique si le parcours est déjà sauvegardé

  const RouteInfoCard({
    super.key,
    required this.routeName,
    required this.distance,
    required this.isLoop,
    required this.waypointCount,
    this.parameters,
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
          // Type d'activité
          _InfoChip(
            icon: parameters!.activityType.icon,
            label: parameters!.activityType.title,
          ),
          10.w,
          // Distance
          _InfoChip(
            icon: HugeIcons.solidRoundedNavigator01,
            label: '${distance.toStringAsFixed(1)} km',
          ),
          10.w,
          // Type de terrain
          _InfoChip(
            icon: getTerrainIcon(parameters!.terrainType.id),
            label: parameters!.terrainType.title,
          ),
          10.w,
          // Densité urbaine
          _InfoChip(
            icon: getUrbanDensityIcon(parameters!.urbanDensity.id),
            label: parameters!.urbanDensity.title,
          ),
          10.w,
          // Dénivelé (si > 0)
          if (parameters!.elevationGain > 0)
            _InfoChip(
              icon: HugeIcons.solidSharpMountain,
              label: '${parameters!.elevationGain.toStringAsFixed(0)}m',
            ),
            10.w,
          // Type de parcours (boucle/simple)
          _InfoChip(
            icon: isLoop 
                ? HugeIcons.solidRoundedRepeat
                : HugeIcons.strokeRoundedArrowRight01,
            label: isLoop ? context.l10n.pathLoop : context.l10n.pathSimple,
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