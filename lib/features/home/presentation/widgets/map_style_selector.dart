import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/home/domain/models/mapbox_style_constants.dart';

class MapStyleSelector extends StatefulWidget {
  final String currentStyleId;
  final Function(String styleId) onStyleSelected;

  const MapStyleSelector({
    super.key,
    required this.currentStyleId,
    required this.onStyleSelected,
  });

  @override
  State<MapStyleSelector> createState() => _MapStyleSelectorState();
}

class _MapStyleSelectorState extends State<MapStyleSelector> {

  Future<void> _dismiss() async {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _selectStyle(String styleId) {
    if (styleId != widget.currentStyleId) {
      HapticFeedback.mediumImpact();
      widget.onStyleSelected(styleId);
    }
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Type de carte",
              style: context.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            Text(
              'Choisissez votre style',
              style: context.bodySmall?.copyWith(
                color: Colors.white38,
              ),
            ),
            20.h,
            ...MapboxStyleConstants.availableStyles.asMap().entries.map((entry) {
                final i = entry.key;
                final style = entry.value;
                final isSelected = style.id == widget.currentStyleId;

                return Padding(
                  // on enlève le bas uniquement sur le dernier
                  padding: EdgeInsets.only(
                    bottom: i == MapboxStyleConstants.availableStyles.length - 1 ? 0 : 12,
                  ),
                  child: _buildStyleTile(
                    style: style,
                    isSelected: isSelected,
                    onTap: () => _selectStyle(style.id),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleTile({
    required MapboxStyleData style,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return SquircleContainer(
      onTap: onTap,
      radius: 40,
      color: Colors.white10,
      padding: EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icône du style
          Row(
            children: [
              SquircleContainer(
                padding: EdgeInsets.all(8),
                radius: 18,
                color: style.color.withValues(alpha: 0.1),
                child: Icon(
                  style.icon,
                  color: style.color,
                  size: 24,
                ),
              ),
                
              15.w,
                
              // Informations du style
              Text(
                style.name,
                style: context.bodyMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
            
          // Indicateur de sélection
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected 
                  ? AppColors.primary
                  : Colors.transparent,
              border: Border.all(
                color: isSelected 
                    ? AppColors.primary
                    : Colors.white24,
                width: 2,
              ),
            ),
            child: isSelected
                ? Icon(
                    HugeIcons.solidRoundedTick02,
                    color: Colors.white,
                    size: 20,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

