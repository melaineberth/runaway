import 'package:bounce/bounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

class SquircleBtn extends StatelessWidget {
  final String? label;
  final Widget? child;
  final Function()? onTap;
  final bool isGradient;
  final bool isPrimary;
  final bool isDestructive;
  final bool isLoading;
  final bool isDisabled;
  final EdgeInsetsGeometry? padding;

  const SquircleBtn({
    super.key, 
    this.label,
    this.onTap,
    this.child,
    this.isGradient = false,
    this.isPrimary = false,
    this.isDestructive = false,
    this.isLoading = false,
    this.isDisabled = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Bounce(
      scale: isDisabled ? false : true,
      tilt: isDisabled ? false : true,
      onTap: isDisabled ? null : onTap,
      child: SquircleContainer(
        height: 60,
        padding: padding,
        gradient: isGradient,
        color: isDisabled ? context.adaptiveDisabled.withValues(alpha: 0.05) : isLoading ? context.adaptivePrimary.withValues(alpha: 0.5) : isPrimary ? isDestructive ? Colors.red : context.adaptivePrimary : context.adaptiveDisabled.withValues(alpha: 0.1),
        radius: 50.0,
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: isLoading 
          ? Center(
            child: child ?? Text(
              label!,
              style: context.bodySmall?.copyWith(
                fontSize: 18,
                color: isPrimary ? Colors.white : context.adaptiveDisabled,
                fontWeight: FontWeight.w600,
              ),
            ),
          ) 
          .animate(onPlay: (controller) => controller.loop())
          .shimmer(color: context.adaptivePrimary, duration: Duration(seconds: 2)) 
          : Center(
            child: child ?? Text(
              label!,
              style: context.bodySmall?.copyWith(
                fontSize: 18,
                color: isDisabled ? context.adaptiveTextPrimary.withValues(alpha: 0.25) : isPrimary ? Colors.white : context.adaptiveTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}