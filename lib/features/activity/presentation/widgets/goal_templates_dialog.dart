import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:uuid/uuid.dart';
import '../../../../config/extensions.dart';
import '../../domain/models/activity_stats.dart';
import '../../../route_generator/domain/models/activity_type.dart';

class GoalTemplatesDialog extends StatelessWidget {
  const GoalTemplatesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.goalsModels,
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextPrimary,
              ),
            ),
            20.h,
            _buildTemplate(
              context,
              context.l10n.monthlyRaceTitle,
              context.l10n.monthlyRaceMessage,
              HugeIcons.solidRoundedWorkoutRun,
              () => _createTemplate(
                context.l10n.monthlyRaceTitle,
                context.l10n.monthlyRaceGoal,
                GoalType.distance,
                50,
                ActivityType.running,
              ),
            ),
            10.h,
            _buildTemplate(
              context,
              context.l10n.weeklyBikeTitle,
              context.l10n.weeklyBikeMessage,
              HugeIcons.solidRoundedBicycle01,
              () => _createTemplate(
                context.l10n.weeklyBikeTitle,
                context.l10n.weeklyBikeGoal,
                GoalType.distance,
                100,
                ActivityType.cycling,
              ),
            ),
            10.h,
            _buildTemplate(
              context,
              context.l10n.regularTripsTitle,
              context.l10n.regularTripsMessage,
              HugeIcons.solidRoundedRoute01,
              () => _createTemplate(
                context.l10n.regularTripsTitle,
                context.l10n.regularTripsGoal,
                GoalType.routes,
                10,
                null,
              ),
            ),
            10.h,
            _buildTemplate(
              context,
              context.l10n.mountainChallengeTitle,
              context.l10n.mountainChallengeMessage,
              HugeIcons.solidRoundedMountain,
              () => _createTemplate(
                context.l10n.mountainChallengeTitle,
                context.l10n.mountainChallengeGoal,
                GoalType.elevation,
                1000,
                null,
              ),
            ),
            10.h,
            _buildTemplate(
              context,
              context.l10n.averageSpeedTitle,
              context.l10n.averageSpeedMessage,
              HugeIcons.solidRoundedRocket01,
              () => _createTemplate(
                context.l10n.averageSpeedTitle,
                context.l10n.averageSpeedGoal,
                GoalType.speed,
                12,
                ActivityType.running,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplate(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    PersonalGoal Function() createGoal,
  ) {
    return SquircleContainer(
      onTap: () {
        final goal = createGoal();
        Navigator.of(context).pop(goal);
      },
      radius: 40,
      color: context.adaptiveBorder.withValues(alpha: 0.08),
      padding: EdgeInsets.all(9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SquircleContainer(
                padding: EdgeInsets.all(12),
                radius: 18,
                color: Colors.blue.withValues(alpha: 0.1),
                child: Icon(icon, color: Colors.blue, size: 25),
                
              ),
              15.w,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.bodyMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: context.bodySmall?.copyWith(
                      fontSize: 14,
                      color: context.adaptiveTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Icon(
            HugeIcons.strokeRoundedArrowRight01,
            color: context.adaptiveTextPrimary,
            size: 20,
          ),
        ],
      ),
    );
  }

  PersonalGoal _createTemplate(
    String title,
    String description,
    GoalType type,
    double targetValue,
    ActivityType? activityType,
  ) {
    return PersonalGoal(
      id: const Uuid().v4(),
      title: title,
      description: description,
      type: type,
      targetValue: targetValue,
      currentValue: 0,
      createdAt: DateTime.now(),
      deadline: DateTime.now().add(Duration(days: 30)),
      isCompleted: false,
      activityType: activityType,
    );
  }
}