import 'package:flutter/material.dart';

class SquircleContainer extends StatelessWidget {
  final Widget child;
  final double? radius;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final List<BoxShadow>? boxShadow;

  const SquircleContainer({
    super.key,
    required this.child,
    this.radius,
    this.padding,
    this.color, 
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius ?? 60)),
        ),
      ),
      child: Container(
        padding: padding ?? EdgeInsets.zero,
        decoration: BoxDecoration(
          color: color,
          boxShadow: boxShadow,
        ),
        child: child,
      ),
    );
  }
}
