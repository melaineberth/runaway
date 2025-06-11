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
          'Niveau d\'urbanisation',
          style: context.bodySmall?.copyWith(
            color: Colors.white,
          ),
        ),
        3.h,
        Text(
          selectedDensity.description,
          style: context.bodySmall?.copyWith(
            color: Colors.grey.shade500,
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
                label: Text(density.title),
                selected: isSelected,
                onSelected: (_) => onDensitySelected(density),
                selectedColor: Theme.of(context).primaryColor,
                backgroundColor: const Color.fromARGB(255, 38, 38, 38),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : Colors.white24,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
