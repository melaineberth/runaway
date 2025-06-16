import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';

class LabelDivider extends StatelessWidget {
  final String? label;
  final Color? color;

  const LabelDivider({
    super.key,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Divider(
            color: color ?? Colors.white24,
          )
        ),       
    
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15.0,
          ),
          child: Text(
            label ?? "OR",
            style: context.bodySmall?.copyWith(
              color: color ?? Colors.white24,
            ),
          ),
        ),        
    
        Expanded(
          child: Divider(
            color: color ?? Colors.white24,
          )
        ),
      ]
    );
  }
}