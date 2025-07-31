import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';

class ListHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final CrossAxisAlignment? crossAxisAlignment;
  final TextAlign? textAlign;

  const ListHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.crossAxisAlignment,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment ?? CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: titleStyle ?? context.bodySmall?.copyWith(
            fontSize: 18,
            color: context.adaptiveTextPrimary,
          ),
          textAlign: textAlign ?? TextAlign.start,
        ),
        if (subtitle != null) ...[
          Text(
            subtitle!,
            style: subtitleStyle ?? GoogleFonts.inter(
              fontSize: 16,
              color: context.adaptiveTextSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: textAlign ?? TextAlign.start,
          ),
        ],
        15.h,
      ],
    );
  }
}

