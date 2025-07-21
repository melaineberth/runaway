import 'package:flutter/material.dart';

class SquircleContainer extends StatelessWidget {
  final Widget? child;
  final double? radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final Function()? onTap;
  final bool isGlow;
  final bool isBorder;
  final bool gradient;
  final Color? borderColor;
  final double? borderWidth;

  const SquircleContainer({
    super.key,
    this.child,
    this.radius,
    this.padding,
    this.margin,
    this.color, 
    this.boxShadow, 
    this.width, 
    this.height,
    this.onTap,
    this.isBorder = false,
    this.isGlow = false,
    this.gradient = true,
    this.borderColor,
    this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isGlow ? BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color!.withValues(alpha: 0.4),
            blurRadius: 30.0,
            spreadRadius: 1.0,
            offset: const Offset(0.0, 0.0),
          ),
        ],
      ) : null,
      child: isBorder ? _buildWithBorder() : _buildWithoutBorder(),
    );
  }

  Widget _buildWithBorder() {
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(radius ?? 60),
          ),
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          margin: margin,
          decoration: BoxDecoration(
            color: borderColor ?? Colors.grey,
          ),
          child: Container(
            margin: EdgeInsets.all(borderWidth ?? 2.0),
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular((radius ?? 60) - (borderWidth ?? 2.0)),
                  ),
                ),
              ),
              child: Container(
                padding: padding ?? EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: boxShadow,
                  gradient: gradient ? LinearGradient(
                    colors: [
                      color!,
                      color!.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ) : null,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWithoutBorder() {
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
            gradient: gradient ? LinearGradient(
              colors: [
                color!,
                color!.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}