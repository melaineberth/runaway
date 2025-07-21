import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class TopSnackBar extends StatelessWidget {
  final String title;
  final bool isError;
  final bool isWarning;

  const TopSnackBar({
    super.key,
    required this.title,
    this.isError = false,
    this.isWarning = false,
  });

  Color get _getBorderColor {
    if (isWarning) return const Color.fromARGB(255, 253, 168, 21);
    if (isError) return const Color.fromARGB(255, 238, 56, 56);
    return const Color.fromARGB(255, 77, 225, 87);
  }

  Color get _getBackgroundColor {
    if (isWarning) return const Color.fromARGB(255, 253, 250, 238);
    if (isError) return const Color.fromARGB(255, 253, 238, 238);
    return const Color.fromARGB(255, 239, 253, 238);
  }

  Color get _getTextColor {
    if (isWarning) return const Color.fromARGB(255, 253, 168, 21);
    if (isError) return const Color.fromARGB(255, 238, 56, 56);
    return const Color.fromARGB(255, 77, 225, 87);
  }

  IconData get _getIcon {
    if (isWarning) return HugeIcons.solidRoundedAlert02;
    if (isError) return HugeIcons.solidRoundedCancelCircle;
    return HugeIcons.solidRoundedCheckmarkCircle01;
  }

  @override
  Widget build(BuildContext context) {
    return SquircleContainer(
      isBorder: true,
      radius: 50.0,
      gradient: false,
      padding: EdgeInsets.all(20.0),
      borderWidth: 2.0,
      borderColor: _getBorderColor,
      color: _getBackgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _getIcon,
            size: 25,
            color: _getTextColor,
          ),
          12.w,
          Expanded(
            child: Text(
              title,
              style: context.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: _getTextColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}