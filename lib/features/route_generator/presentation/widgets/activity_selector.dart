import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import '../../domain/models/activity_type.dart';

class ActivitySelector extends StatelessWidget {
  final ActivityType selectedActivity;
  final Function(ActivityType) onActivitySelected;

  const ActivitySelector({
    super.key,
    required this.selectedActivity,
    required this.onActivitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.activity,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
        15.h,
        Row(
          children: ActivityType.values.map((activity) {
            final isSelected = activity == selectedActivity;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: _ActivityCard(
                  activity: activity,
                  isSelected: isSelected,
                  onTap: () => onActivitySelected(activity),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityType activity;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.activity,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SquircleContainer(
      onTap: onTap,
      radius: 50,
      height: 120,
      gradient: isSelected ? true : false,
      isGlow: isSelected ? true : false,
      color: isSelected ? context.adaptivePrimary : context.adaptiveBorder.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: activity.icon,
            size: 50,
            color: isSelected ? Colors.white : context.adaptiveTextSecondary.withValues(alpha: 0.5),
          ),
          5.h,
          Text(
            activity.label(context),
            style: context.bodySmall?.copyWith(
              color: isSelected ? Colors.white : context.adaptiveTextSecondary.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
