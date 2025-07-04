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
              child: GestureDetector(
                onTap: () => onDensitySelected(density),
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
                    density.label(context),
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
