import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/home/data/services/navigation_service.dart';

class NavigationOverlay extends StatelessWidget {
  final String instruction;
  final NavigationUpdate? navUpdate;
  final Map<String, dynamic> routeStats;
  final VoidCallback onStop;
  final String navigationMode; // 'to_route', 'on_route'
  final bool isNavigatingToRoute;

  const NavigationOverlay({
    super.key,
    required this.instruction,
    required this.navUpdate,
    required this.routeStats,
    required this.onStop,
    this.navigationMode = 'on_route',
    this.isNavigatingToRoute = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Instruction principale avec badge de mode
        SquircleContainer(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          color: Colors.black.withValues(alpha: 0.9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge de mode + bouton stop
              Row(
                children: [
                  // Badge de mode
                  SquircleContainer(
                    radius: 20,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: _getModeColor().withValues(alpha: 0.2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: _getModeIcon(),
                          color: _getModeColor(),
                          size: 14,
                        ),
                        6.w,
                        Text(
                          _getModeText(context),
                          style: context.bodySmall?.copyWith(
                            color: _getModeColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Spacer(),
                  
                  // Bouton stop
                  GestureDetector(
                    onTap: onStop,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedStop,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              
              12.h,
              
              // Instruction
              Text(
                instruction,
                style: context.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              if (navUpdate != null && !navUpdate!.isFinished) ...[
                16.h,
                
                // Distance et progression
                Row(
                  children: [
                    // Distance restante
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getModeColor().withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: isNavigatingToRoute 
                                ? HugeIcons.strokeRoundedNavigation04
                                : HugeIcons.strokeRoundedRoute03,
                            color: _getModeColor(),
                            size: 16,
                          ),
                          6.w,
                          Text(
                            _formatDistance(navUpdate!.distanceToTarget),
                            style: context.bodySmall?.copyWith(
                              color: _getModeColor(),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    16.w,
                    
                    // Progression
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isNavigatingToRoute 
                                    ? context.l10n.toTheRun
                                    : '${context.l10n.pathPoint} ${navUpdate!.waypointIndex + 1}/${navUpdate!.totalWaypoints}',
                                style: context.bodySmall?.copyWith(color: Colors.white70),
                              ),
                              Text(
                                isNavigatingToRoute 
                                    ? '...'
                                    : '${(((navUpdate!.waypointIndex + 1) / navUpdate!.totalWaypoints) * 100).round()}%',
                                style: context.bodySmall?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          6.h,
                          LinearProgressIndicator(
                            value: isNavigatingToRoute 
                                ? null // Indéterminé pour navigation vers le parcours
                                : (navUpdate!.waypointIndex + 1) / navUpdate!.totalWaypoints,
                            backgroundColor: Colors.white30,
                            valueColor: AlwaysStoppedAnimation(_getModeColor()),
                            minHeight: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        16.h,
        
        // Statistiques du parcours (seulement si on navigue sur le parcours)
        if (!isNavigatingToRoute) ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactStat(
                    icon: HugeIcons.strokeRoundedRoute03,
                    value: '${_parseDistance(routeStats['distance_km']).toStringAsFixed(1)} km',
                    label: context.l10n.pathTotal,
                  ),
                  
                  VerticalDivider(color: Colors.white30, width: 1),
                  
                  _buildCompactStat(
                    icon: HugeIcons.strokeRoundedTime01,
                    value: '${routeStats['duration_minutes']} min',
                    label: context.l10n.pathTime,
                  ),
                  
                  VerticalDivider(color: Colors.white30, width: 1),
                  
                  _buildCompactStat(
                    icon: HugeIcons.strokeRoundedAbacusBefore,
                    value: '${routeStats['points_count']}',
                    label: context.l10n.pointsCount,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getModeColor() {
    return isNavigatingToRoute ? Colors.blue : Colors.green;
  }

  dynamic _getModeIcon() {
    return isNavigatingToRoute 
        ? HugeIcons.strokeRoundedNavigation04
        : HugeIcons.strokeRoundedRoute03;
  }

  String _getModeText(BuildContext context) {
    return isNavigatingToRoute 
        ? context.l10n.guide
        : context.l10n.course;
  }

  Widget _buildCompactStat({
    required dynamic icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        HugeIcon(
          icon: icon,
          color: Colors.white70,
          size: 16,
        ),
        4.h,
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  double _parseDistance(dynamic distanceValue) {
    if (distanceValue == null) return 0.0;
    if (distanceValue is double) return distanceValue;
    if (distanceValue is int) return distanceValue.toDouble();
    if (distanceValue is String) return double.tryParse(distanceValue) ?? 0.0;
    return 0.0;
  }
}