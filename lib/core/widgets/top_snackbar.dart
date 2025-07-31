import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class TopSnackBar extends StatelessWidget {
  final String title;
  final bool isError;
  final bool isWarning;
  final Function()? onPressed;
  final bool action;

  const TopSnackBar({
    super.key,
    required this.title,
    this.isError = false,
    this.isWarning = false,
    this.action = false,
    this.onPressed,
  });

  Color get _getBorderColor {
    if (isWarning) return const Color.fromARGB(255, 253, 168, 21);
    if (isError) return const Color.fromARGB(255, 238, 56, 56);
    return const Color.fromARGB(255, 67, 197, 76);
  }

  Color get _getBackgroundColor {
    if (isWarning) return const Color.fromARGB(255, 253, 250, 238);
    if (isError) return const Color.fromARGB(255, 253, 238, 238);
    return const Color.fromARGB(255, 243, 254, 242);
  }

  Color get _getTextColor {
    if (isWarning) return const Color.fromARGB(255, 253, 168, 21);
    if (isError) return const Color.fromARGB(255, 238, 56, 56);
    return const Color.fromARGB(255, 67, 197, 76);
  }

  IconData get _getIcon {
    if (isWarning) return HugeIcons.solidRoundedAlert02;
    if (isError) return HugeIcons.solidRoundedCancelCircle;
    return HugeIcons.solidRoundedCheckmarkCircle01;
  }

  @override
  Widget build(BuildContext context) {
    return SquircleContainer(
      radius: 50.0,
      gradient: false,
      isGlow: true,
      isBorder: true,
      borderColor: _getTextColor,
      borderWidth: 2.0,
      padding: EdgeInsets.all(20.0),
      color: _getBackgroundColor,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          spreadRadius: 2,
          blurRadius: 30,
          offset: Offset(0, 0), // changes position of shadow
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!action)
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
          if (action) ...[
            8.w,
            IconBtn(
              padding: 12.0,
              label: context.l10n.modify,
              backgroundColor: _getBorderColor,
              labelColor: _getBackgroundColor,
              onPressed: onPressed,
            ),
          ],
        ],
      ),
    );
  }
}