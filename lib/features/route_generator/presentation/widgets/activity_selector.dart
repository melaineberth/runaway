import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
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
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(60)),
          ),
        ),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          height: 120,
          decoration: BoxDecoration(
            color: isSelected 
                ? context.adaptivePrimary 
                : context.adaptiveBorder.withValues(alpha: 0.08),
            boxShadow: isSelected ? [
              BoxShadow(
                color: context.adaptivePrimary.withAlpha(40),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ] : [],
          ),
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
        ),
      ),
    );
  }
}
