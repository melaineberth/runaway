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
          'Type d\'activité',
          style: context.bodySmall?.copyWith(
            color: Colors.white,
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
                ? Theme.of(context).primaryColor 
                : Colors.white12,
            boxShadow: isSelected ? [
              BoxShadow(
                color: Theme.of(context).primaryColor.withAlpha(40),
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
                color: isSelected ? Colors.black : Colors.white24,
              ),
              5.h,
              Text(
                activity.title,
                style: context.bodySmall?.copyWith(
                  color: isSelected ? Colors.black : Colors.white24,
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
