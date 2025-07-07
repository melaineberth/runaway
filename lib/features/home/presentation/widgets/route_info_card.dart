import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/constants.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
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

  static const _innerRadius = 35.0;

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
              _ActionButton(
                radius: _innerRadius,
                label: context.l10n.download,
                onTap: onShare,
                isPrimary: true,
              ),
              8.h,
              // 🆕 Bouton Sauvegarde
              _ActionButton(
                radius: _innerRadius,
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

/// Bouton d'action
class _ActionButton extends StatelessWidget {
  final String? label;
  final VoidCallback? onTap;
  final bool isPrimary;
  final double radius;
  final bool isLoading; // 🆕 Indicateur de chargement
  final bool isDisabled;

  const _ActionButton({
    this.label,
    required this.onTap,
    required this.isPrimary,
    required this.radius,
    this.isLoading = false,
    this.isDisabled = false, // 🆕 Par défaut false
  });

  @override
  Widget build(BuildContext context) {
    final bool isInactive = isLoading || isDisabled || onTap == null;

    return SquircleContainer(
      gradient: isPrimary ? true : false,
      onTap: isInactive ? null : onTap, // 🆕 Désactiver si loading
      padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
      radius: radius,
      height: 55,
      color: _getBackgroundColor(context), // 🆕 Style différent si loading
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 🆕 Animation de rotation pour l'icône loading
          isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPrimary ? Colors.white : context.adaptiveDisabled,
                    ),
                  ),
                )
              : Text(
              label!,
              style: context.bodySmall?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _getTextColor(context),
              ),
            ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    if (isPrimary) {
      return context.adaptivePrimary;
    } else {
      return context.adaptiveBorder.withValues(alpha: 0.08);
    }
  }

  Color _getTextColor(BuildContext context) {
    if (isPrimary) {
      return Colors.white;
    } else if (isDisabled || isLoading) {
      return context.adaptiveDisabled;
    } else {
      return context.adaptiveTextPrimary;
    }
  }
}