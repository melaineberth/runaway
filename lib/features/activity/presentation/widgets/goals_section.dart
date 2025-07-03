import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import '../../../../config/extensions.dart';
import '../../../../core/widgets/squircle_container.dart';
import '../../domain/models/activity_stats.dart';

class GoalsSection extends StatelessWidget {
  final List<PersonalGoal> goals;
  final VoidCallback onAddGoal;
  final Function(PersonalGoal) onEditGoal;
  final Function(String) onDeleteGoal;

  const GoalsSection({
    super.key,
    required this.goals,
    required this.onAddGoal,
    required this.onEditGoal,
    required this.onDeleteGoal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.personalGoals,
              style: context.bodyMedium?.copyWith(
                fontSize: 18,
                color: context.adaptiveTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconBtn(
              padding: 8.0,
              icon: HugeIcons.solidRoundedAdd01,
              iconSize: 16,
              label: context.l10n.add,
              textStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              backgroundColor: context.adaptiveBorder.withValues(alpha: 0.05),
              onPressed: onAddGoal,
            ),
          ],
        ),
        15.h,
        Column(
          children: [
            if (goals.isEmpty)
              _buildEmptyState(context)
            else
              ...goals.asMap().entries.map((entry) {
                final i = entry.key;
                final goal = entry.value;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: i == goals.length - 1 ? 0 : 8,
                  ),
                  child: _buildGoalCard(context, goal),
                );
              }),
          ],
        )
      ],
    );
  }

  Widget _buildGoalCard(BuildContext context, PersonalGoal goal) {
    final progress = goal.progressPercentage;
    final isCompleted = goal.isCompleted;

    return SquircleContainer(
      radius: 50.0,
      padding: const EdgeInsets.all(20),
      color: context.adaptiveBorder.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: context.bodySmall?.copyWith(
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                    Text(
                      goal.description,
                      style: context.bodySmall?.copyWith(
                        color: context.adaptiveTextSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                Icon(
                  HugeIcons.solidRoundedCheckmarkCircle02,
                  color: Colors.green,
                  size: 24,
                )
              else
                PullDownButton(
                itemBuilder: (context) => [
                  PullDownMenuItem(
                    icon: HugeIcons.strokeRoundedEdit01,
                    title: context.l10n.editGoal,
                    onTap: () => onEditGoal(goal),
                  ),
                  PullDownMenuItem(
                    isDestructive: true,
                    icon: HugeIcons.strokeRoundedDelete02,
                    title: context.l10n.deleteRoute,
                    onTap: () => onDeleteGoal(goal.id),
                  ),
                ],
                buttonBuilder: (context, showMenu) => GestureDetector(
                  onTap: () {
                    showMenu();
                    HapticFeedback.mediumImpact();
                  },
                  child: Icon(
                    HugeIcons.strokeRoundedMoreVerticalCircle02,
                  ),
                ),
              ),
            ],
          ),
          12.h,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${goal.currentValue.toStringAsFixed(1)} / ${goal.targetValue.toStringAsFixed(1)} ${goal.type.label}',
                        style: context.bodySmall?.copyWith(
                          color: context.adaptiveTextPrimary,
                          fontSize: 14,
                        ),
                      ),
                      8.h,
                      LinearProgressIndicator(
                        value: progress / 100,
                        borderRadius: BorderRadius.circular(100),
                        backgroundColor: context.adaptiveBorder.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isCompleted ? Colors.green : context.adaptivePrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),              
              Text(
                '${progress.toStringAsFixed(0)}%',
                style: context.bodyMedium?.copyWith(
                  color: isCompleted ? Colors.green : context.adaptiveTextPrimary,
                ),
              ),
            ],
          ),
          if (goal.deadline != null) ...[
            15.h,
            Text(
              context.l10n.deadlineValid('${goal.deadline!.day}/${goal.deadline!.month}/${goal.deadline!.year}'),
              style: context.bodySmall?.copyWith(
                color: Colors.orange,
                fontSize: 14,
              ),
            ),
          ],
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
                HugeIcons.strokeRoundedTarget01,
                size: 48,
                color: context.adaptiveDisabled,
              ),
              8.h,
              Text(
                context.l10n.emptyDefinedGoals,
                style: context.bodySmall?.copyWith(
                  color: context.adaptiveDisabled,
                ),
              ),
              4.h,
              Text(
                context.l10n.pressToAdd,
                style: context.bodySmall?.copyWith(
                  color: context.adaptiveDisabled,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}