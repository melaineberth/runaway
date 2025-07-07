import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/tick_slider.dart';

class ParameterSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Function(double) onChanged;
  final int? divisions;
  final String? subtitle;
  final IconData startIcon;
  final IconData endIcon;

  // ✅ NOUVEAU : Paramètres haptiques optionnels
  final bool enableHapticFeedback;
  final HapticIntensity hapticIntensity;

  const ParameterSlider({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    required this.startIcon,
    required this.endIcon,
    this.divisions,
    this.subtitle,
    this.enableHapticFeedback = true, // ✅ Activé par défaut
    this.hapticIntensity = HapticIntensity.custom, // ✅ Mode intelligent par défaut
  });

  @override
  Widget build(BuildContext context) {    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
        10.h,
        TickSlider(
          min: min,
          max: max,
          unit: unit,
          initialValue: value,
          onChanged: onChanged,
          majorTickColor: context.adaptiveDisabled.withValues(alpha: .35),
          minorTickColor: context.adaptiveDisabled.withValues(alpha: .25),
          enableHapticFeedback: enableHapticFeedback, // ✅ NOUVEAU
          hapticIntensity: hapticIntensity, // ✅ NOUVEAU
        ),
      ],
    );
  }
}
