import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:uuid/uuid.dart';
import '../../../../config/extensions.dart';
import '../../domain/models/activity_stats.dart';
import '../../../route_generator/domain/models/activity_type.dart';

class GoalTemplatesDialog extends StatelessWidget {
  const GoalTemplatesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Modèles d\'objectifs',
        style: context.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Fermer',
            style: TextStyle(color: Colors.white60),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplate(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    PersonalGoal Function() createGoal,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
        onTap: () {
          final goal = createGoal();
          Navigator.of(context).pop(goal);
        },
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