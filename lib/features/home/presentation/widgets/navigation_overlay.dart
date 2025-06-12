// lib/core/widgets/navigation_overlay.dart

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/features/home/data/services/navigation_service.dart';

class NavigationOverlay extends StatelessWidget {
  final String instruction;
  final NavigationUpdate? navUpdate;
  final Map<String, dynamic> routeStats;
  final VoidCallback onStop;

  const NavigationOverlay({
    super.key,
    required this.instruction,
    required this.navUpdate,
    required this.routeStats,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Instruction principale
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bouton stop et instruction
              Row(
                children: [
                  Expanded(
                    child: Text(
                      instruction,
                      style: context.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onStop,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
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
              
              if (navUpdate != null && !navUpdate!.isFinished) ...[
                16.h,
                
                // Distance et progression
                Row(
                  children: [
                    // Distance restante
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.twotoneRoundedKeffiyehAfter,
                            color: Colors.blue,
                            size: 16,
                          ),
                          6.w,
                          Text(
                            _formatDistance(navUpdate!.distanceToTarget),
                            style: context.bodySmall?.copyWith(
                              color: Colors.blue,
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
                                'Point ${navUpdate!.waypointIndex + 1}/${navUpdate!.totalWaypoints}',
                                style: context.bodySmall?.copyWith(color: Colors.white70),
                              ),
                              Text(
                                '${(((navUpdate!.waypointIndex + 1) / navUpdate!.totalWaypoints) * 100).round()}%',
                                style: context.bodySmall?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          6.h,
                          LinearProgressIndicator(
                            value: (navUpdate!.waypointIndex + 1) / navUpdate!.totalWaypoints,
                            backgroundColor: Colors.white30,
                            valueColor: AlwaysStoppedAnimation(Colors.blue),
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
        
        // Statistiques du parcours (compactes)
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCompactStat(
                  icon: HugeIcons.strokeRoundedRoute03,
                  value: '${_parseDistance(routeStats['distance_km']).toStringAsFixed(1)} km',
                  label: 'Total',
                ),
                
                VerticalDivider(color: Colors.white30, width: 1),
                
                _buildCompactStat(
                  icon: HugeIcons.strokeRoundedTime01,
                  value: '${routeStats['duration_minutes']} min',
                  label: 'Durée',
                ),
                
                VerticalDivider(color: Colors.white30, width: 1),
                
                _buildCompactStat(
                  icon: HugeIcons.strokeRoundedAbacusBefore,
                  value: '${routeStats['points_count']}',
                  label: 'Points',
                ),
              ],
            ),
          ),
        ),
      ],
    );
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