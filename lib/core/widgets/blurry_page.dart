import 'package:flutter/material.dart';
import 'package:progressive_blur/progressive_blur.dart';
import 'package:runaway/config/extensions.dart';
import 'package:smooth_gradient/smooth_gradient.dart';

class BlurryPage extends StatefulWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? contentPadding;
  final Color? color;
  final bool shrinkWrap;
  
  const BlurryPage({super.key, required this.children, this.padding, this.contentPadding, this.color, this.shrinkWrap = true});

  @override
  State<BlurryPage> createState() => _BlurryPageState();
}

class _BlurryPageState extends State<BlurryPage> with TickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _blurAnimationController;
  late final Animation<double> _blurAnimation;
  bool _isCutByTop = false;

  @override
  void initState() {
    super.initState();

    // Animation controller pour la transition graduelle du flou
    _blurAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _blurAnimation = Tween<double>(
      begin: 0.1, // Valeur minimale pour éviter les crashes iOS
      end: 50.0,
    ).animate(CurvedAnimation(
      parent: _blurAnimationController,
      curve: Curves.easeInOut,
    ));

    _scrollController = ScrollController()
    ..addListener(() {
      final cut = _scrollController.offset > 0;
      if (cut != _isCutByTop) {
        setState(() => _isCutByTop = cut);
        // Animer le flou au lieu d'un changement brusque
        if (cut) {
          _blurAnimationController.forward();
        } else {
          _blurAnimationController.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _blurAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProgressiveBlurWidget(
      sigma: 50.0,
      linearGradientBlur: const LinearGradientBlur(
        values: [0, 1],
        stops: [0.7, 0.9],
        start: Alignment.center,
        end: Alignment.bottomCenter,
      ),
      child: Stack(
        fit: StackFit.loose,
        children: [
          AnimatedBuilder(
            animation: _blurAnimation,
            builder: (context, child) {
              // Protection : s'assurer que sigma est toujours valide
              final safeSigma = _blurAnimation.value.clamp(0.1, 50.0);
              
              return ProgressiveBlurWidget(
                sigma: safeSigma,
                linearGradientBlur: const LinearGradientBlur(
                  values: [1, 0],
                  stops: [0.1, 0.55],
                  start: Alignment.topCenter,
                  end: Alignment.center,
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Padding(
                      padding: widget.padding ?? EdgeInsets.zero,
                      child: ListView(
                        shrinkWrap: widget.shrinkWrap,
                        padding: widget.contentPadding,
                        controller: _scrollController,
                        children: widget.children,
                      ),
                    ),
                    IgnorePointer(
                      ignoring: true,
                      child: Container(
                        height: MediaQuery.of(context).size.height / 3,
                        decoration: BoxDecoration(
                          gradient: SmoothGradient(
                            from: widget.color?.withValues(alpha: 0) ?? context.adaptiveBackground.withValues(alpha: 0),
                            to: widget.color ?? context.adaptiveBackground,
                            curve: Curves.linear,
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          AnimatedOpacity(
            opacity: _isCutByTop ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                height: MediaQuery.of(context).size.height / 2.5,
                decoration: BoxDecoration(
                  gradient: SmoothGradient(
                    from: widget.color ?? context.adaptiveBackground,
                    to: widget.color?.withValues(alpha: 0) ?? context.adaptiveBackground.withValues(alpha: 0),
                    curve: Curves.linear,
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}