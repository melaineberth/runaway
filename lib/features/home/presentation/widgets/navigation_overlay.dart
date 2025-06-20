import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/home/data/services/navigation_service.dart';
import 'package:runaway/features/home/domain/models/navigation_tracking_data.dart';

class NavigationOverlay extends StatelessWidget {
  final String instruction;
  final NavigationUpdate? navUpdate;
  final Map<String, dynamic> routeStats;
  final VoidCallback onStop;
  final VoidCallback onPause;
  final String navigationMode; // 'to_route', 'on_route'
  final bool isNavigatingToRoute;
  final NavigationTrackingData? trackingData;

  const NavigationOverlay({
    super.key,
    required this.instruction,
    required this.navUpdate,
    required this.routeStats,
    required this.onStop,
    required this.onPause,
    this.navigationMode = 'on_route',
    this.isNavigatingToRoute = false,
    this.trackingData,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height / 1.2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Instruction principale avec badge de mode et contrôles
          SquircleContainer(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            color: Colors.black.withValues(alpha: 0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge de mode + contrôles
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
                    
                    // Bouton pause (seulement en mode parcours)
                    if (!isNavigatingToRoute && trackingData != null) ...[
                      GestureDetector(
                        onTap: onPause,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: HugeIcon(
                            icon: trackingData!.isPaused 
                                ? HugeIcons.strokeRoundedPlay
                                : HugeIcons.strokeRoundedPause,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                      ),
                      8.w,
                    ],
                    
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
                  trackingData?.isPaused == true 
                      ? context.l10n.navigationPaused 
                      : instruction,
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
                              isNavigatingToRoute 
                                  ? _formatDistance(navUpdate!.distanceToTarget)
                                  : '${trackingData?.remainingDistance.toStringAsFixed(1) ?? '0.0'} km',
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
                                      : '${context.l10n.progress}: ${trackingData?.progressPercentage.toStringAsFixed(0) ?? '0'}%',
                                  style: context.bodySmall?.copyWith(color: Colors.white70),
                                ),
                                if (!isNavigatingToRoute && trackingData != null)
                                  Text(
                                    '${trackingData!.distanceTraveled.toStringAsFixed(1)}/${trackingData!.totalRouteDistance.toStringAsFixed(1)} km',
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
                                  : (trackingData?.progressPercentage ?? 0) / 100,
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
          
          // Métriques de tracking en temps réel (seulement si on suit le parcours)
          if (!isNavigatingToRoute && trackingData != null) ...[
            // Grandes métriques principales
            _buildMainMetrics(context),
            
            12.h,
            
            // Métriques secondaires
            _buildSecondaryMetrics(context),
          ] else if (isNavigatingToRoute) ...[
            // Informations simplifiées pour navigation vers le parcours
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
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
                    label: context.l10n.estimatedTime,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainMetrics(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Ligne 1: Temps et Distance
          Row(
            children: [
              Expanded(
                child: _buildLargeMetric(
                  icon: HugeIcons.strokeRoundedTime01,
                  value: _formatDuration(trackingData!.activeTime),
                  label: context.l10n.time,
                  isPaused: trackingData!.isPaused,
                ),
              ),
              16.w,
              Expanded(
                child: _buildLargeMetric(
                  icon: HugeIcons.strokeRoundedRoute03,
                  value: '${trackingData!.distanceTraveled.toStringAsFixed(2)} km',
                  label: context.l10n.distance,
                ),
              ),
            ],
          ),
          
          20.h,
          
          // Ligne 2: Rythme et Vitesse
          Row(
            children: [
              Expanded(
                child: _buildLargeMetric(
                  icon: HugeIcons.strokeRoundedActivity02,
                  value: trackingData!.averagePaceMinutesPerKm > 0 
                      ? '${trackingData!.averagePaceMinutesPerKm.toStringAsFixed(1)}\'/km'
                      : '--',
                  label: context.l10n.pace,
                ),
              ),
              16.w,
              Expanded(
                child: _buildLargeMetric(
                  icon: HugeIcons.strokeRoundedDashboardSpeed02,
                  value: '${trackingData!.currentSpeed.toStringAsFixed(1)} km/h',
                  label: context.l10n.speed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryMetrics(BuildContext context) {
    return Container(
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
              icon: HugeIcons.strokeRoundedMountain,
              value: '${trackingData!.currentElevation.toStringAsFixed(0)}m',
              label: context.l10n.elevation,
            ),
            
            VerticalDivider(color: Colors.white30, width: 1),
            
            _buildCompactStat(
              icon: HugeIcons.strokeRoundedMountain,
              value: '+${trackingData!.elevationGain.toStringAsFixed(0)}m',
              label: context.l10n.elevationGain,
            ),
            
            VerticalDivider(color: Colors.white30, width: 1),
            
            _buildCompactStat(
              icon: HugeIcons.strokeRoundedTime02,
              value: trackingData!.estimatedTimeRemaining != Duration.zero
                  ? _formatDuration(trackingData!.estimatedTimeRemaining)
                  : '--',
              label: context.l10n.remaining,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeMetric({
    required dynamic icon,
    required String value,
    required String label,
    bool isPaused = false,
  }) {
    return Column(
      children: [
        HugeIcon(
          icon: icon,
          color: isPaused ? Colors.orange : Colors.white70,
          size: 24,
        ),
        8.h,
        Text(
          value,
          style: TextStyle(
            color: isPaused ? Colors.orange : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        4.h,
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
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

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
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