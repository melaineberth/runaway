import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:uuid/uuid.dart';
import '../../../../config/extensions.dart';
import '../../domain/models/activity_stats.dart';
import '../../../route_generator/domain/models/activity_type.dart';

class GoalTemplatesDialog extends StatelessWidget {
  const GoalTemplatesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modèles d\'objectifs',
            style: context.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          20.h,
          _buildTemplate(
            context,
            'Course mensuelle',
            '50km par mois de course',
            HugeIcons.strokeRoundedWorkoutRun,
            () => _createTemplate(
              'Course mensuelle',
              'Courir 50km par mois',
              GoalType.distance,
              50,
              ActivityType.running,
            ),
          ),
          _buildTemplate(
            context,
            'Vélo hebdomadaire',
            '100km par semaine à vélo',
            HugeIcons.strokeRoundedBicycle01,
            () => _createTemplate(
              'Vélo hebdomadaire',
              'Faire 100km de vélo par semaine',
              GoalType.distance,
              100,
              ActivityType.cycling,
            ),
          ),
          _buildTemplate(
            context,
            'Parcours réguliers',
            '10 parcours par mois',
            HugeIcons.strokeRoundedActivity01,
            () => _createTemplate(
              'Parcours réguliers',
              'Compléter 10 parcours par mois',
              GoalType.routes,
              10,
              null,
            ),
          ),
          _buildTemplate(
            context,
            'Défi montagne',
            '1000m de dénivelé par mois',
            HugeIcons.strokeRoundedActivity01,
            () => _createTemplate(
              'Défi montagne',
              'Gravir 1000m de dénivelé par mois',
              GoalType.elevation,
              1000,
              null,
            ),
          ),
          _buildTemplate(
            context,
            'Vitesse moyenne',
            'Maintenir 12km/h de moyenne',
            HugeIcons.strokeRoundedActivity01,
            () => _createTemplate(
              'Vitesse moyenne',
              'Maintenir une vitesse moyenne de 12km/h',
              GoalType.speed,
              12,
              ActivityType.running,
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SquircleContainer(
        onTap: () {
          final goal = createGoal();
          context.pop(goal);
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
                  color: Colors.blue.withValues(alpha: 0.1),
                  child: Icon(icon, color: Colors.blue, size: 30),
                  
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
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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