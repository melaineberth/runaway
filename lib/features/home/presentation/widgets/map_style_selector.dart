import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/list_header.dart';
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListHeader(
            title: context.l10n.mapStyleTitle,
            subtitle: context.l10n.mapStyleSubtitle,
          ),
          ...MapboxStyleConstants.availableStyles.asMap().entries.map((entry) {
              final i = entry.key;
              final style = entry.value;
              final isSelected = style.id == widget.currentStyleId;
      
              return Padding(
                // on enlève le bas uniquement sur le dernier
                padding: EdgeInsets.only(
                  bottom: i == MapboxStyleConstants.availableStyles.length - 1 ? 0 : 10,
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
    );
  }

  Widget _buildStyleTile({
    required MapboxStyleData style,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return SquircleContainer(
      onTap: onTap,
      radius: 50,
      gradient: false,
      color: context.adaptiveBorder.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icône du style
          Row(
            children: [
              SquircleContainer(
                radius: 30,
                isGlow: true,
                color: context.adaptivePrimary,
                padding: const EdgeInsets.all(15),
                child: Icon(
                  style.icon,
                  color: Colors.white,
                  size: 25,
                ),
              ),
                
              10.w,
                
              // Informations du style
              Text(
                style.mapStyle(context),
                style: context.bodyMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
            
          // Indicateur de sélection
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected 
                    ? context.adaptivePrimary
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected 
                      ? context.adaptivePrimary
                      : context.adaptiveBorder,
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
          ),
        ],
      ),
    );
  }
}

