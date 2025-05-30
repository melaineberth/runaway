import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';

class ParameterSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String unit;
  final dynamic icon;
  final Function(double) onChanged;
  final int? divisions;
  final String? subtitle;

  const ParameterSlider({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.icon,
    required this.onChanged,
    this.divisions,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: context.bodySmall,
              ),
              Text(
                '${value.toStringAsFixed(value < 10 ? 1 : 0)} $unit',
                style: context.bodyLarge?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          12.h,
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Theme.of(context).primaryColor,
              inactiveTrackColor: Colors.grey.shade300,
              thumbColor: Theme.of(context).primaryColor,
              overlayColor: Theme.of(context).primaryColor.withAlpha(30),
              trackHeight: 6,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions ?? ((max - min) * 10).round(),
              onChanged: onChanged,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
