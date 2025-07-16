import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class TopSnackBar extends StatelessWidget {
  final String title;
  final bool isError;

  const TopSnackBar({
    super.key,
    required this.title,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadiusGeometry.circular(20.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: SquircleContainer(
          radius: 40,
          gradient: false,
          padding: EdgeInsets.all(20.0),
          color: context.adaptiveTextPrimary.withValues(alpha: 0.1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: context.bodySmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: context.adaptiveTextPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Icon(
                isError ? HugeIcons.strokeRoundedCancelCircle : HugeIcons.strokeRoundedCheckmarkCircle03,
                size: 25,
                color: context.adaptiveTextPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}