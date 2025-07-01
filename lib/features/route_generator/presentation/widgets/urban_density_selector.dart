import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import '../../domain/models/urban_density.dart';

class UrbanDensitySelector extends StatelessWidget {
  final UrbanDensity selectedDensity;
  final Function(UrbanDensity) onDensitySelected;

  const UrbanDensitySelector({
    super.key,
    required this.selectedDensity,
    required this.onDensitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.urbanization,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
        3.h,
        Text(
          selectedDensity.desc(context),
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w500
          ),
        ),
        15.h,
        Row(
          children: UrbanDensity.values.map((density) {
            final isSelected = density == selectedDensity;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                showCheckmark: false,
                label: Text(density.label(context)),
                selected: isSelected,
                onSelected: (_) => onDensitySelected(density),
                selectedColor: context.adaptivePrimary,
                backgroundColor: context.adaptiveBorder.withValues(alpha: 0.08),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : context.adaptiveTextSecondary.withValues(alpha: 0.5),
                ),
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: BorderSide(style: BorderStyle.none),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
