import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';

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
            color: color ?? context.adaptiveTextPrimary.withValues(alpha: 0.3),
          )
        ),       
    
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15.0,
          ),
          child: Text(
            label ?? context.l10n.orDivider,
            style: context.bodySmall?.copyWith(
              color: color ?? context.adaptiveTextPrimary.withValues(alpha: 0.3),
            ),
          ),
        ),        
    
        Expanded(
          child: Divider(
            color: color ?? context.adaptiveTextPrimary.withValues(alpha: 0.3),
          )
        ),
      ]
    );
  }
}