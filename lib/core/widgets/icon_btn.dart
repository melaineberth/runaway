import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';

class IconBtn extends StatelessWidget {
  final dynamic icon;
  final dynamic trailling;
  final double? iconSize;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? labelColor;
  final Function()? onPressed;
  final String? label;
  final double? radius;
  final double? padding;
  final BoxBorder? border;
  final TextStyle? textStyle;

  const IconBtn({
    super.key, 
    this.icon, 
    this.trailling, 
    this.iconSize, 
    this.backgroundColor,
    this.labelColor,
    this.iconColor, 
    this.onPressed, 
    this.label,
    this.radius,
    this.padding,
    this.border,
    this.textStyle,
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
          border: border,
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
              if (icon != null) 10.w,
              Padding(
                padding: EdgeInsets.only(right: icon != null ? padding == 0 ? 0.0 : 3.0 : 0.0, left: trailling != null ? padding == 0 ? 0.0 : 5.0 : 0.0),
                child: Text(
                  label!, 
                  style: textStyle ?? context.bodySmall?.copyWith(
                    color: labelColor ?? Colors.white,
                  ),
                ),
              ),
              if (trailling != null) 10.w else if (padding == 0) 0.w,
            ],
            if (trailling != null) ...[
              HugeIcon(
                icon: trailling, 
                size: iconSize ?? 28, 
                color: iconColor ?? Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }
}