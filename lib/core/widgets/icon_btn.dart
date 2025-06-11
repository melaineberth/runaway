import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';

class IconBtn extends StatelessWidget {
  final dynamic icon;
  final double? iconSize;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? labelColor;
  final Function()? onPressed;
  final String? label;
  final double? radius;
  final double? padding;

  const IconBtn({
    super.key, 
    this.icon, 
    this.iconSize, 
    this.backgroundColor,
    this.labelColor,
    this.iconColor, 
    this.onPressed, 
    this.label,
    this.radius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(padding ?? 15.0),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.black,
          borderRadius: BorderRadius.circular(radius ?? 100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              spreadRadius: 2,
              blurRadius: 30,
              offset: Offset(0, 0), // changes position of shadow
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              HugeIcon(
                icon: icon, 
                size: iconSize ?? 28, 
                color: iconColor ?? Colors.white,
              ),
            ],
            if (label != null && label!.isNotEmpty) ...[
              10.w,
              Padding(
                padding: const EdgeInsets.only(right: 3.0),
                child: Text(
                  label!, 
                  style: context.bodySmall?.copyWith(
                    color: labelColor ?? Colors.white,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}