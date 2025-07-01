import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

/// Widget pour afficher les informations de la route générée
class RouteInfoCard extends StatelessWidget {
  final String routeName;           // <-- nouveau
  final double distance;
  final bool isLoop;
  final int waypointCount;
  final VoidCallback onClear;
  final VoidCallback onNavigate;
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
    required this.onClear,
    required this.onNavigate,
    required this.onShare,
    required this.onSave, // 🆕 Requis
    this.isSaving = false, // 🆕 Par défaut false
    this.isAlreadySaved = false,
  });

  static const _innerRadius = 35.0;
  static const _padding = 15.0;

  @override
  Widget build(BuildContext context) {
    return SquircleContainer(
      padding: EdgeInsets.all(_padding),
      color: context.adaptiveBackground,
      radius: _innerRadius.outerRadius(_padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête avec infos principales
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SquircleContainer(
                radius: 25,
                color: context.adaptivePrimary.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Icon(
                    HugeIcons.solidRoundedRouteBlock, 
                    color: context.adaptivePrimary,
                  ),
                ),
              ),
              12.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routeName,
                      style: context.bodySmall,
                    ),
                    4.h,
                    Row(
                      children: [
                        _InfoChip(
                          icon: HugeIcons.solidRoundedWorkoutRun,
                          label: '${distance.toStringAsFixed(1)} km',
                        ),
                        8.w,
                        _InfoChip(
                          icon: isLoop 
                              ? HugeIcons.solidRoundedArrowReloadHorizontal 
                              : HugeIcons.strokeRoundedArrowRight01,
                          label: isLoop ? context.l10n.pathLoop : context.l10n.pathSimple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Bouton fermer
              IconButton(
                onPressed: onClear,
                icon: HugeIcon(
                  icon: HugeIcons.solidRoundedCancelCircle,
                  color: context.adaptiveTextPrimary,
                  size: 24,
                ),
              ),
            ],
          ),
          
          16.h,

          // Boutons d'action
          Row(
            children: [
              // 🆕 Bouton Sauvegarde
              Expanded(
                child: _ActionButton(
                  radius: _innerRadius,
                  icon: _getSaveIcon(),
                  label: _getSaveLabel(context),
                  onTap: _getSaveAction(),
                  isPrimary: false,
                  isLoading: isSaving,
                  isDisabled: isAlreadySaved,
                ),
              ),

              12.w,

              Expanded(
                child: _ActionButton(
                  radius: _innerRadius,
                  icon: HugeIcons.solidRoundedDownloadCircle01,
                  label: context.l10n.download,
                  onTap: onShare,
                  isPrimary: false,
                ),
              ),
            ],
          ),

          12.h,
          _ActionButton(
            radius: _innerRadius,
            icon: HugeIcons.solidRoundedFlag02,
            label: context.l10n.start,
            onTap: onNavigate,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  dynamic _getSaveIcon() {
    if (isSaving) {
      return HugeIcons.strokeRoundedLoading03;
    } else if (isAlreadySaved) {
      return HugeIcons.solidRoundedCheckmarkCircle02;
    } else {
      return HugeIcons.solidRoundedLocationStar01;
    }
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
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(
          color: context.adaptiveDisabled,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            size: 16,
            color: context.adaptiveDisabled,
          ),
          6.w,
          Text(
            label,
            style: context.bodySmall?.copyWith(
              fontSize: 14,
              color: context.adaptiveDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton d'action
class _ActionButton extends StatelessWidget {
  final dynamic icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;
  final double radius;
  final bool isLoading; // 🆕 Indicateur de chargement
  final bool isDisabled;

  const _ActionButton({
    required this.icon,
    required this.label,
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
      onTap: isInactive ? null : onTap, // 🆕 Désactiver si loading
      padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
      radius: radius,
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
              : HugeIcon(
                  icon: icon,
                  size: 20,
                  color: _getIconColor(context),
                ),
          if (label.isNotEmpty) ...[
            10.w,
            Text(
              label,
              style: context.bodySmall?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _getTextColor(context),
              ),
            ),
          ],
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

  Color _getIconColor(BuildContext context) {
    if (isPrimary) {
      return Colors.white;
    } else if (isDisabled || isLoading) {
      return context.adaptiveDisabled;
    } else {
      return context.adaptiveTextPrimary;
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