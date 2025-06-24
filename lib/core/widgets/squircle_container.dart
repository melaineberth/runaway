import 'package:flutter/material.dart';

class SquircleContainer extends StatelessWidget {
  final Widget child;
  final double? radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final Function()? onTap;
  final bool isBorder;

  const SquircleContainer({
    super.key,
    required this.child,
    this.radius,
    this.padding,
    this.margin,
    this.color, 
    this.boxShadow, 
    this.width, 
    this.height,
    this.onTap,
    this.isBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(radius ?? 60)),
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          margin: margin,
          padding: padding ?? EdgeInsets.zero,
          decoration: BoxDecoration(
            color: color,
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
