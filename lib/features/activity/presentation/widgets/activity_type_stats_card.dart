import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import '../../../../config/extensions.dart';
import '../../domain/models/activity_stats.dart';
import '../../../route_generator/domain/models/activity_type.dart';

class ActivityTypeStatsCard extends StatelessWidget {
  final List<ActivityTypeStats> stats;
  final ActivityType? selectedType;
  final Function(ActivityType?) onTypeSelected;

  const ActivityTypeStatsCard({
    super.key,
    required this.stats,
    this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filteredStats = selectedType != null
        ? stats.where((s) => s.activityType == selectedType).toList()
        : stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Par activité',
              style: context.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            _buildFilterButton(context),
          ],
        ),
        15.h,
        Column(
          children: [
            if (filteredStats.isEmpty)
              _buildEmptyState(context)
            else
            ...filteredStats.asMap().entries.map((entry) {
                final i = entry.key;
                final stat = entry.value;

                return Padding(
                  // on enlève le bas uniquement sur le dernier
                  padding: EdgeInsets.only(
                    bottom: i == filteredStats.length - 1 ? 0 : 8,
                  ),
                  child: _buildActivityStatRow(context, stat),
                );
              },
            ),         
          ],
        ),
      ],
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFilterDialog(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(100),
        ),
        padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
        child: Text(
          selectedType?.title ?? 'Tous',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityStatRow(BuildContext context, ActivityTypeStats stat) {
    return SquircleContainer(
      radius: 50.0,
      padding: const EdgeInsets.all(10),
      color: Colors.white10,
      child: Row(
        children: [
          SquircleContainer(
            radius: 30.0,
            padding: const EdgeInsets.all(20),
            color: AppColors.primary,
            child: Icon(
              stat.activityType.icon,
              color: Colors.white,
              size: 30,
            ),
          ),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.activityType.title,
                  style: context.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${stat.totalRoutes} parcours',
                  style: context.bodySmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              text: stat.bestSpeedKmh.toStringAsFixed(1),
              style: context.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: " km/h",
                  style: context.bodySmall?.copyWith(
                    fontSize: 15,
                  ),
                )
              ]
            )
          ),
          10.w,
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SquircleContainer(
      radius: 50.0,
      padding: const EdgeInsets.all(20),
      color: Colors.white10,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                HugeIcons.strokeRoundedActivity01,
                size: 48,
                color: Colors.white30,
              ),
              8.h,
              Text(
                'Aucune donnée pour ce filtre',
                style: context.bodySmall?.copyWith(
                  color: Colors.white30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      context: context,
      backgroundColor: Colors.black,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filtrer par activité',
                style: context.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Choisissez le type d\'activité :',
                      style: context.bodySmall?.copyWith(
                        color: Colors.white38,
                      ),
                    ),
                    
                    20.h,
            
                  _buildFilterOption(context, null, 'Toutes les activités'),
                  ...ActivityType.values.map(
                    (type) => _buildFilterOption(context, type, type.title),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(BuildContext context, ActivityType? type, String label) {
    final isSelected = selectedType == type;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SquircleContainer(
        onTap: () {
          onTypeSelected(type);
          Navigator.of(context).pop();
        },
        radius: 40,
        color: Colors.white10,
        padding: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SquircleContainer(
                  padding: EdgeInsets.all(8),
                  radius: 18,
                  color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.white10,
                  child: Icon(
                    type?.icon ?? HugeIcons.solidRoundedMenu01,
                    color: isSelected ? Colors.blue : Colors.white,
                  ),
                ),
                15.w,
                Text(
                  label,
                  style: context.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.blue : Colors.white,
                  ),
                ),
              ],
            ),
            Icon(
              HugeIcons.strokeRoundedArrowRight01,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}