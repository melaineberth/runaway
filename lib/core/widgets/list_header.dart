import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';

class ListHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  const ListHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: titleStyle ?? context.bodySmall?.copyWith(
            fontSize: 18,
            color: context.adaptiveTextPrimary,
          ),
        ),
        if (subtitle != null) ...[
          Text(
            subtitle!,
            style: subtitleStyle ?? context.bodyMedium?.copyWith(
              fontSize: 16,
              color: context.adaptiveTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        15.h,
      ],
    );
  }
}

