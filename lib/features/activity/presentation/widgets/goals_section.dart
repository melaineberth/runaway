import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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
              'Objectifs personnels',
              style: context.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            IconBtn(
              padding: 8.0,
              icon: HugeIcons.solidRoundedAdd01,
              iconSize: 16,
              label: "Ajouter",
              textStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              backgroundColor: Colors.white10,
              onPressed: onAddGoal,
            ),
          ],
        ),
        15.h,
        SquircleContainer(
          radius: 50.0,
          padding: const EdgeInsets.all(20),
          color: Colors.white10,
          child: Column(
            children: [
              if (goals.isEmpty)
                _buildEmptyState(context)
              else
                ...goals.map((goal) => _buildGoalCard(goal)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildGoalCard(PersonalGoal goal) {
    final progress = goal.progressPercentage;
    final isCompleted = goal.isCompleted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  4.h,
                  Text(
                    goal.description,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
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
              GestureDetector(
                onTap: () => onEditGoal(goal),
                child: Icon(
                  HugeIcons.strokeRoundedEdit01,
                  color: Colors.white60,
                  size: 16,
                ),
              ),
          ],
        ),
        12.h,
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${goal.currentValue.toStringAsFixed(1)} / ${goal.targetValue.toStringAsFixed(1)} ${goal.type.label}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  4.h,
                  LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? Colors.green : Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            8.w,
            Text(
              '${progress.toStringAsFixed(0)}%',
              style: TextStyle(
                color: isCompleted ? Colors.green : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (goal.deadline != null) ...[
          8.h,
          Text(
            'Échéance: ${goal.deadline!.day}/${goal.deadline!.month}/${goal.deadline!.year}',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              HugeIcons.strokeRoundedTarget01,
              size: 48,
              color: Colors.white30,
            ),
            8.h,
            Text(
              'Vous n\'avez aucun objectif de défini',
              style: context.bodySmall?.copyWith(
                color: Colors.white30,
              ),
            ),
            4.h,
            Text(
              'Appuyez sur + pour en créer un',
              style: context.bodySmall?.copyWith(
                color: Colors.white30,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}