import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:interactive_slider/interactive_slider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/config/extensions.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final String distance = round(value.clamp(min, max)).toStringAsFixed(0).toString();
    
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
        InteractiveSlider(
          unfocusedMargin: EdgeInsets.zero,
          focusedMargin: const EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.zero,
          iconPosition: IconPosition.inside,
          startIcon: Icon(startIcon),
          centerIcon: Text(
            "$distance $unit", 
            style: context.bodySmall?.copyWith(
              color: context.adaptiveBorder.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          endIcon: Icon(endIcon),
          unfocusedHeight: 40,
          focusedHeight: 50,
          iconGap: 16,
          min: min,
          max: max,
          onChanged: onChanged,
          iconColor: context.adaptiveBorder.withValues(alpha: 0.4),
          backgroundColor: context.adaptiveBorder.withValues(alpha: 0.08),
          foregroundColor: context.adaptivePrimary,
        ),
      ],
    );
  }
}
