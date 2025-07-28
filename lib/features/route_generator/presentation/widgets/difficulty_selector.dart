import 'package:bounce/bounce.dart';
import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/list_header.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

class DifficultySelector extends StatelessWidget {
  final DifficultyLevel selectedDifficulty;
  final ValueChanged<DifficultyLevel> onDifficultySelected;

  const DifficultySelector({
    super.key,
    required this.selectedDifficulty,
    required this.onDifficultySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListHeader(
          title: context.l10n.difficulty,
        ),
        Wrap(
          runSpacing: 8.0,
          children: DifficultyLevel.values.map((difficulty) {
            final isSelected = difficulty == selectedDifficulty;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Bounce(
                onTap: () => onDifficultySelected(difficulty),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? context.adaptivePrimary : context.adaptiveBorder.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? context.adaptivePrimary.withValues(alpha: 0.4) : Colors.transparent,
                        blurRadius: 30.0,
                        spreadRadius: 1.0,
                        offset: const Offset(0.0, 0.0),
                      ),
                    ],
                  ),
                  child: Text(
                    difficulty.label(context),
                    style: context.bodySmall?.copyWith(
                      color: isSelected ? Colors.white : context.adaptiveTextSecondary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}