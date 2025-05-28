import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/features/home/domain/models/maps_styles.dart';

class MapsStylesSelector extends StatelessWidget {
  final MapsStyles selectedStyle;
  final Function(MapsStyles) onStyleSelected;

  const MapsStylesSelector({
    super.key,
    required this.selectedStyle,
    required this.onStyleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type de carte',
            style: context.bodySmall,
          ),
          3.h,
          Text(
            selectedStyle.description,
            style: context.bodySmall?.copyWith(
              color: Colors.grey.shade500,
              fontSize: 15,
              fontWeight: FontWeight.w500
            ),
          ),
          15.h,
          Row(
            children: MapsStyles.values.map((style) {
              final isSelected = style == selectedStyle;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: _MapStyleCard(
                    styles: style,
                    isSelected: isSelected,
                    onTap: () => onStyleSelected(style),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MapStyleCard extends StatelessWidget {
  final MapsStyles styles;
  final bool isSelected;
  final VoidCallback onTap;

  const _MapStyleCard({
    required this.styles,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        height: 120,
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).primaryColor 
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Theme.of(context).primaryColor.withAlpha(40),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: styles.icon,
              size: 30,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            5.h,
            Text(
              styles.title,
              style: context.bodySmall?.copyWith(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
