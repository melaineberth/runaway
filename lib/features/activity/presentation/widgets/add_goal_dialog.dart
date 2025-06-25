import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:uuid/uuid.dart';
import '../../../../config/extensions.dart';
import '../../domain/models/activity_stats.dart';
import '../../../route_generator/domain/models/activity_type.dart';

class AddGoalDialog extends StatefulWidget {
  final PersonalGoal? existingGoal;

  const AddGoalDialog({
    super.key,
    this.existingGoal,
  });

  @override
  State<AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<AddGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetValueController = TextEditingController();
  
  GoalType _selectedType = GoalType.distance;
  ActivityType? _selectedActivity;
  DateTime? _deadline;
  
  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    
    if (_isEditing) {
      final goal = widget.existingGoal!;
      _titleController.text = goal.title;
      _descriptionController.text = goal.description;
      _targetValueController.text = goal.targetValue.toString();
      _selectedType = goal.type;
      _selectedActivity = goal.activityType;
      _deadline = goal.deadline;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Modifier l\'objectif' : 'Nouvel objectif',
            style: context.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          20.h,
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleField(),
                  10.h,
                  _buildDescriptionField(),
                  30.h,
                  _buildTypeSelector(),
                  30.h,
                  _buildActivitySelector(),
                  30.h,
                  _buildTargetValueField(),
                  30.h,
                  _buildDeadlineSelector(),
                ],
              ),
            ),
          ),
          50.h,
          Row(
            children: [
              Expanded(
                child: SquircleContainer(
                  onTap: () => context.pop(),
                  radius: 30.0,
                  color: Colors.white10,
                  padding: EdgeInsets.symmetric(vertical: 15.0),
                  child: Center(
                    child: Text(
                      'Annuler',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              10.w,
              Expanded(
                child: SquircleContainer(
                  onTap: _saveGoal,
                  radius: 30.0,
                  color: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 15.0),
                  child: Center(
                    child: Text(
                      _isEditing ? 'Modifier' : 'Créer',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return AuthTextField(
      controller: _titleController,
      hint: "Titre de l'objectif",
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez saisir un titre';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return AuthTextField(
      controller: _descriptionController,
      hint: "Description (optionnel)",
      maxLines: 2,
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type d\'objectif',
          style: context.bodySmall,
        ),
        8.h,
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: GoalType.values.map((type) {
            final isSelected = _selectedType == type;
            
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.white10,
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Text(
                  type.label,
                  style: context.bodySmall?.copyWith(
                    fontSize: 14,
                    color:Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActivitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activité (optionnel)',
          style: context.bodySmall,
        ),
        8.h,
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            _buildActivityOption(null, 'Toutes'),
            ...ActivityType.values.map(
              (activity) => _buildActivityOption(activity, activity.title),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityOption(ActivityType? activity, String label) {
    final isSelected = _selectedActivity == activity;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedActivity = activity),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white10,
          borderRadius: BorderRadius.circular(100),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Text(
          label,
          style: context.bodySmall?.copyWith(
            fontSize: 14,
            color:Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTargetValueField() {
    return AuthTextField(
      controller: _targetValueController,
      hint: "Valeur cible",
      suffixText: _getUnit(),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez saisir une valeur cible';
        }
        final doubleValue = double.tryParse(value);
        if (doubleValue == null || doubleValue <= 0) {
          return 'Veuillez saisir une valeur positive';
        }
        return null;
      },
    );
  }

  Widget _buildDeadlineSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Échéance (optionnel)',
          style: context.bodySmall,
        ),
        8.h,
        SquircleContainer(
          onTap: _selectDeadline,
          padding: const EdgeInsets.all(16),
          height: 60,
          color: Colors.white10,
          radius: 30,
          child: Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedCalendar03,
                color: _deadline != null ? Colors.white : Colors.white30,
                size: 20,
              ),
              12.w,
              Expanded(
                child: Text(
                  _deadline != null
                      ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'
                      : 'Sélectionner une date',
                  style: context.bodySmall?.copyWith(
                    color: _deadline != null ? Colors.white : Colors.white30,
                  ),
                ),
              ),
              if (_deadline != null)
                GestureDetector(
                  onTap: () => setState(() => _deadline = null),
                  child: Icon(
                    HugeIcons.solidRoundedCancelCircle,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.black87,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _deadline = date);
    }
  }

  String _getUnit() {
    switch (_selectedType) {
      case GoalType.distance:
        return 'km';
      case GoalType.routes:
        return 'parcours';
      case GoalType.speed:
        return 'km/h';
      case GoalType.elevation:
        return 'm';
    }
  }

  void _saveGoal() {
    if (!_formKey.currentState!.validate()) return;

    final goal = PersonalGoal(
      id: _isEditing ? widget.existingGoal!.id : const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      targetValue: double.parse(_targetValueController.text),
      currentValue: _isEditing ? widget.existingGoal!.currentValue : 0,
      createdAt: _isEditing ? widget.existingGoal!.createdAt : DateTime.now(),
      deadline: _deadline,
      isCompleted: _isEditing ? widget.existingGoal!.isCompleted : false,
      activityType: _selectedActivity,
    );

    Navigator.of(context).pop(goal);
  }
}