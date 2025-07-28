import 'package:bounce/bounce.dart';
import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/list_header.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

class SurfacePreferenceSelector extends StatelessWidget {
  final double currentValue;
  final ValueChanged<double> onValueChanged;

  const SurfacePreferenceSelector({
    super.key,
    required this.currentValue,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentType = SurfaceType.fromValue(currentValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListHeader(
          title: context.l10n.surfacePreference,
          subtitle: _getDescription(context, currentType),
        ),
        Row(
          children: SurfaceType.values.map((surface) {
            final isSelected = surface == currentType;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Bounce(
                onTap: () => onValueChanged(surface.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    surface.label(context),
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

  String _getDescription(BuildContext context, SurfaceType surface) {
    switch (surface) {
      case SurfaceType.asphalt:
        return context.l10n.asphaltSurfaceDesc;
      case SurfaceType.mixed:
        return context.l10n.mixedSurfaceDesc;
      case SurfaceType.natural:
        return context.l10n.naturalSurfaceDesc;
    }
  }
}