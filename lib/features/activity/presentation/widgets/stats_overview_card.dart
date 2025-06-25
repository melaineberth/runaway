import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import '../../../../config/extensions.dart';
import '../../domain/models/activity_stats.dart';

class StatsOverviewCard extends StatelessWidget {
  final ActivityStats stats;

  const StatsOverviewCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vue d\'ensemble',
          style: context.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        15.h,
        SquircleContainer(
          radius: 40.0,
          padding: const EdgeInsets.all(20),
          color: Colors.white10,
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context: context,
                  icon: HugeIcons.solidRoundedRoute01,
                  value: stats.totalDistanceKm.toStringAsFixed(1),
                  label: 'Distance totale',
                  indicator: " km"
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context: context,
                  icon: HugeIcons.solidRoundedTimer02,
                  value: (stats.totalDurationMinutes / 60).toStringAsFixed(1),
                  label: 'Temps total',
                  indicator: " h"
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context: context,
                  icon: HugeIcons.solidRoundedDashboardSpeed02,
                  value: stats.averageSpeedKmh.toStringAsFixed(1),
                  label: 'Vitesse moy.',
                  indicator: " km/h"
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
    required String indicator,
  }) {
    return Column(
      children: [
        SquircleContainer(
          radius: 40.0,
          padding: const EdgeInsets.all(20),
          color: AppColors.primary,
          child: Icon(
            icon, 
            color: Colors.white,
            size: 30,
          ),
        ),

        10.h,

        Text.rich(
          TextSpan(
            text: value,
            style: context.bodyMedium?.copyWith(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              height: 1
            ),
            children: <InlineSpan>[
              TextSpan(
                text: indicator,
                style: context.bodySmall?.copyWith(
                  fontSize: 15,
                ),
              )
            ]
          )
        ),
        Text(
          label,
          style: context.bodySmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}