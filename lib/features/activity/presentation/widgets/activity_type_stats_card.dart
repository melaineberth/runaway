import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import '../../../../core/helper/extensions/extensions.dart';
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
              context.l10n.activityFilter,
              style: context.bodyMedium?.copyWith(
                fontSize: 18,
                color: context.adaptiveTextSecondary,
                fontWeight: FontWeight.w600,
              ),
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
          color: context.adaptiveBorder.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(100),
        ),
        padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
        child: Text(
          selectedType?.title ?? context.l10n.allFilter,
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
      color: context.adaptiveBorder.withValues(alpha: 0.05),
      child: Row(
        children: [
          SquircleContainer(
            radius: 30.0,
            isGlow: true,
            padding: const EdgeInsets.all(20),
            color: context.adaptivePrimary,
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
                  context.l10n.totalRoutes(stat.totalRoutes),
                  style: context.bodySmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.adaptiveTextPrimary.withValues(alpha: 0.7),
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
                  text: context.l10n.distanceType,
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
      color: context.adaptiveBorder.withValues(alpha: 0.05),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                HugeIcons.strokeRoundedActivity01,
                size: 48,
                color: context.adaptiveDisabled,
              ),
              8.h,
              Text(
                context.l10n.emptyDataFilter,
                style: context.bodySmall?.copyWith(
                  color: context.adaptiveDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      child: ModalSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.byActivityFilter,
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextPrimary,
              ),
            ),
            Text(
                context.l10n.typeOfActivity,
                style: context.bodySmall?.copyWith(
                  color: context.adaptiveTextSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500
                ),
              ),
              
              20.h,
                      
            _buildFilterOption(context, null, context.l10n.allActivities),
            ...ActivityType.values.map(
              (type) => _buildFilterOption(context, type, type.label(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(BuildContext context, ActivityType? type, String label) {
    final isSelected = selectedType == type;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: SquircleContainer(
        onTap: () {
          onTypeSelected(type);
          context.pop();
        },
        radius: 50,
        color: context.adaptiveBorder.withValues(alpha: 0.08),
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SquircleContainer(
                  radius: 30,
                  isGlow: true,
                  color: context.adaptivePrimary,
                  padding: const EdgeInsets.all(15),
                  child: Icon(
                    type?.icon ?? HugeIcons.solidRoundedMenu01,
                    color: Colors.white,
                    size: 25,
                  ),
                ),

                15.w,
                
                Text(
                  label,
                  style: context.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ],
            ),

            // Indicateur de sélection
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [],
                  color: isSelected 
                      ? context.adaptivePrimary
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected 
                        ? context.adaptivePrimary
                        : context.adaptiveBorder,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        HugeIcons.solidRoundedTick02,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}