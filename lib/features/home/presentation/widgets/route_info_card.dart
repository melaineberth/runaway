import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

/// Widget pour afficher les informations de la route générée
class RouteInfoCard extends StatelessWidget {
  final double distance;
  final bool isLoop;
  final int waypointCount;
  final VoidCallback onClear;
  final VoidCallback onNavigate;
  final VoidCallback onShare;

  const RouteInfoCard({
    super.key,
    required this.distance,
    required this.isLoop,
    required this.waypointCount,
    required this.onClear,
    required this.onNavigate,
    required this.onShare,
  });

  static const _innerRadius = 35.0;
  static const _padding = 15.0;

  @override
  Widget build(BuildContext context) {
    return SquircleContainer(
      padding: EdgeInsets.all(_padding),
      color: Colors.black,
      radius: _innerRadius.outerRadius(_padding),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          spreadRadius: 2,
          blurRadius: 30,
          offset: Offset(0, 0), // changes position of shadow
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête avec infos principales
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SquircleContainer(
                radius: 25,
                color: AppColors.primary.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Icon(
                    HugeIcons.solidRoundedRouteBlock, 
                    color: AppColors.primary,
                  ),
                ),
              ),
              12.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.pathGenerated,
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
                  color: Colors.grey.shade600,
                  size: 24,
                ),
              ),
            ],
          ),
          
          16.h,
          
          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  radius: _innerRadius,
                  icon: HugeIcons.solidRoundedNavigation03,
                  label: context.l10n.start,
                  onTap: onNavigate,
                  isPrimary: true,
                ),
              ),
              12.w,
              _ActionButton(
                radius: _innerRadius,
                icon: HugeIcons.strokeRoundedShare08,
                label: context.l10n.share,
                onTap: onShare,
                isPrimary: false,
              ),
            ],
          ),
        ],
      ),
    );
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
          color: Colors.white38,
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
            color: Colors.white38,
          ),
          6.w,
          Text(
            label,
            style: context.bodySmall?.copyWith(
              fontSize: 14,
              color: Colors.white38,
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
  final VoidCallback onTap;
  final bool isPrimary;
  final double radius;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SquircleContainer(
        padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
        radius: radius,
        color: isPrimary 
            ? AppColors.primary 
            : Colors.white10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: icon,
              size: 20,
              color: isPrimary ? Colors.white : Colors.white,
            ),
            8.w,
            Text(
              label,
              style: context.bodySmall?.copyWith(
                color: isPrimary ? Colors.white : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}