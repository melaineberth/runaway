import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';

class SelectableBtn extends StatelessWidget {
  final dynamic icon;
  final bool active;
  final String label;
  final Function()? onTap;

  const SelectableBtn({
    super.key,
    this.icon,
    this.onTap,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: active ? Colors.red : Colors.red.shade200,
              borderRadius: BorderRadius.circular(15),
              border:
                  active
                      ? Border.all(
                        color: Colors.blue,
                        width: 4,
                        strokeAlign: BorderSide.strokeAlignInside,
                      )
                      : null,
            ),
            child: HugeIcon(
              icon: icon,
              size: 28,
              color: active ? Colors.black : Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ),
        5.h,
        Text(
          label,
          style: context.bodySmall?.copyWith(
            color: active ? Colors.black : Colors.black.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}
