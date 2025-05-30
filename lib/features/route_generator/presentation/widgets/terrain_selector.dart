import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import '../../domain/models/terrain_type.dart';

class TerrainSelector extends StatelessWidget {
  final TerrainType selectedTerrain;
  final Function(TerrainType) onTerrainSelected;

  const TerrainSelector({
    super.key,
    required this.selectedTerrain,
    required this.onTerrainSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de terrain',
          style: context.bodySmall,
        ),
        3.h,
        Text(
          selectedTerrain.description,
          style: context.bodySmall?.copyWith(
            color: Colors.grey.shade500,
            fontSize: 15,
            fontWeight: FontWeight.w500
          ),
        ),
        15.h,
        Row(
          children: TerrainType.values.map((terrain) {
            final isSelected = terrain == selectedTerrain;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                showCheckmark: false,
                label: Text(terrain.title),
                selected: isSelected,
                onSelected: (_) => onTerrainSelected(terrain),
                selectedColor: Theme.of(context).primaryColor,
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
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
