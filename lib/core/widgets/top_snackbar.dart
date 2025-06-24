import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class TopSnackBar extends StatelessWidget {
  final Color? color;
  final String title;
  final IconData icon;

  const TopSnackBar({
    super.key,
    this.color,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SquircleContainer(
      radius: 40,
      padding: EdgeInsets.all(20.0),
      color: color ?? Colors.red,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: context.bodySmall?.copyWith(
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Icon(
            icon,
            size: 25,
          ),
        ],
      ),
    );
  }
}