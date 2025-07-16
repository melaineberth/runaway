import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/helper/extensions/extensions.dart';
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
    return ModalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? context.l10n.modifyGoal : context.l10n.newGoal,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextPrimary,
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
          SquircleContainer(
            onTap: _saveGoal,
            height: 65,
            color: context.adaptivePrimary,
            radius: 50.0,
            child: Center(
              child: Text(
                _isEditing ? context.l10n.modify : context.l10n.create,
                style: context.bodySmall?.copyWith(
                  fontSize: 19,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return AuthTextField(
      controller: _titleController,
      hint: context.l10n.goalTitle,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return context.l10n.titleValidator;
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return AuthTextField(
      controller: _descriptionController,
      hint: context.l10n.optionalDescription,
      maxLines: 2,
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.goalType,
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
                  color: isSelected ? context.adaptivePrimary : context.adaptiveBorder.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Text(
                  type.goalLabel(context),
                  style: context.bodySmall?.copyWith(
                    fontSize: 14,
                    color: isSelected ? Colors.white : context.adaptiveTextPrimary,
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
          context.l10n.optionalActivity,
          style: context.bodySmall,
        ),
        8.h,
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            _buildActivityOption(null, context.l10n.allFilter),
            ...ActivityType.values.map(
              (activity) => _buildActivityOption(activity, activity.label(context)),
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
          color: isSelected ? context.adaptivePrimary : context.adaptiveBorder.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(100),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Text(
          label,
          style: context.bodySmall?.copyWith(
            fontSize: 14,
            color: isSelected ? Colors.white : context.adaptiveTextPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTargetValueField() {
    return AuthTextField(
      controller: _targetValueController,
      hint: context.l10n.targetValue,
      suffixText: _getUnit(),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return context.l10n.targetValueValidator;
        }
        final doubleValue = double.tryParse(value);
        if (doubleValue == null || doubleValue <= 0) {
          return context.l10n.positiveValueValidator;
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
          context.l10n.optionalDeadline,
          style: context.bodySmall,
        ),
        8.h,
        SquircleContainer(
          onTap: _selectDeadline,
          padding: const EdgeInsets.all(16),
          height: 60,
          color: context.adaptiveBorder.withValues(alpha: 0.08),
          radius: 30,
          child: Row(
            children: [
              Icon(
                HugeIcons.strokeRoundedCalendar03,
                color: _deadline != null ? context.adaptiveTextPrimary : context.adaptiveDisabled,
                size: 20,
              ),
              12.w,
              Expanded(
                child: Text(
                  _deadline != null
                      ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'
                      : context.l10n.selectDate,
                  style: context.bodySmall?.copyWith(
                    color: _deadline != null ? context.adaptiveTextPrimary : context.adaptiveDisabled,
                  ),
                ),
              ),
              if (_deadline != null)
                GestureDetector(
                  onTap: () => setState(() => _deadline = null),
                  child: Icon(
                    HugeIcons.solidRoundedCancelCircle,
                    color: context.adaptiveTextPrimary,
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
        return context.l10n.distanceType;
      case GoalType.routes:
        return context.l10n.routesType;
      case GoalType.speed:
        return context.l10n.speedType;
      case GoalType.elevation:
        return context.l10n.elevationType;
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