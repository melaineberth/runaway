import 'package:flutter/material.dart';
// import 'package:progressive_blur/progressive_blur.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:smooth_gradient/smooth_gradient.dart';

class BlurryPage extends StatefulWidget {
  final List<Widget> children;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? contentPadding;
  final Color? color;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;

  /// Callback appelé quand l'état de scroll change (true = scrollé, false = en haut)
  final ValueChanged<bool>? onScrollStateChanged;

  /// Callback qui expose le controller de scroll pour synchronisation externe
  final ValueChanged<ScrollController>? onScrollControllerReady;

  const BlurryPage({
    super.key,
    required this.children,
    this.child,
    this.padding,
    this.contentPadding,
    this.color,
    this.shrinkWrap = true,
    this.physics,
    this.onScrollStateChanged,
    this.onScrollControllerReady,
    this.scrollDirection = Axis.vertical,
  });

  @override
  State<BlurryPage> createState() => _BlurryPageState();
}

class _BlurryPageState extends State<BlurryPage> with TickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _blurAnimationController;
  late final Animation<double> _blurAnimation;
  bool _isCutByTop = false;
  bool _isCutByLeft  = false;         // 🆕 si scroll horizontal
  bool _isCutByRight = false;         // 🆕 si scroll horizontal

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
    ).animate(
      CurvedAnimation(
        parent: _blurAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _scrollController = ScrollController()
    ..addListener(() => _updateEdgeState(_scrollController.position));

    // Exposer le controller au parent après l'initialisation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateEdgeState(_scrollController.position);
      widget.onScrollControllerReady?.call(_scrollController);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _blurAnimationController.dispose();
    super.dispose();
  }

  // 1️⃣  helper : calcule la visibilité des bords
  void _updateEdgeState(ScrollMetrics m) {
    if (widget.scrollDirection == Axis.vertical) {
      final cut = _scrollController.offset > 0;
      if (cut != _isCutByTop) {
        setState(() => _isCutByTop = cut);

        // Notifier le parent du changement d'état
        widget.onScrollStateChanged?.call(cut);
        
        // Animer le flou au lieu d'un changement brusque
        if (cut) {
          _blurAnimationController.forward();
        } else {
          _blurAnimationController.reverse();
        }
      }
    } else {
      final offset = _scrollController.offset;
      final max    = _scrollController.position.maxScrollExtent;
      final cutLeft  = offset > 0;
      final cutRight = offset < max;
      if (cutLeft != _isCutByLeft || cutRight != _isCutByRight) {
        setState(() {
          _isCutByLeft  = cutLeft;
          _isCutByRight = cutRight;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.loose,
      children: [
        AnimatedBuilder(
          animation: _blurAnimation,
          builder: (context, child) {
            // Protection : s'assurer que sigma est toujours valide
            // final safeSigma = _blurAnimation.value.clamp(0.1, 50.0);

            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Padding(
                  padding: widget.padding ?? EdgeInsets.zero,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      _updateEdgeState(n.metrics);        // <— met à jour même sans déplacement
                      return false;
                    },
                    child: widget.child ??
                        ListView(
                          controller: _scrollController,
                          scrollDirection: widget.scrollDirection,
                          physics: widget.physics,
                          shrinkWrap: widget.shrinkWrap,
                          padding: widget.contentPadding,
                          children: widget.children,
                        ),
                  ),
                ),
                if (widget.scrollDirection == Axis.vertical)
                IgnorePointer(
                  ignoring: true,
                  child: Container(
                    height: MediaQuery.of(context).size.height / 2.5,
                    decoration: BoxDecoration(
                      gradient: SmoothGradient(
                        from:
                            widget.color?.withValues(alpha: 0) ??
                            context.adaptiveBackground.withValues(alpha: 0),
                        to: widget.color ?? context.adaptiveBackground,
                        curve: Curves.linear,
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // 🔸 Fade TOP 
        if (widget.scrollDirection == Axis.vertical)
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
                  to:
                      widget.color?.withValues(alpha: 0) ??
                      context.adaptiveBackground.withValues(alpha: 0),
                  curve: Curves.linear,
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                ),
              ),
            ),
          ),
        ),

        // 🔸 Fade GAUCHE (scroll horizontal)
        if (widget.scrollDirection == Axis.horizontal)
          AnimatedOpacity(
            opacity: _isCutByLeft ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: true,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: MediaQuery.of(context).size.width / 2.5,
                  decoration: BoxDecoration(
                    gradient: SmoothGradient(
                      from: widget.color ?? context.adaptiveBackground,
                      to:   widget.color?.withValues(alpha: 0) ??
                            context.adaptiveBackground.withValues(alpha: 0),
                      begin: Alignment.centerLeft,
                      end:   Alignment.center,
                      curve: Curves.linear,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 🔸 Fade DROITE (scroll horizontal)
        if (widget.scrollDirection == Axis.horizontal)
          AnimatedOpacity(
            opacity: _isCutByRight ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: true,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: MediaQuery.of(context).size.width / 2.5,
                  decoration: BoxDecoration(
                    gradient: SmoothGradient(
                      from: widget.color?.withValues(alpha: 0) ??
                            context.adaptiveBackground.withValues(alpha: 0),
                      to:   widget.color ?? context.adaptiveBackground,
                      begin: Alignment.center,
                      end:   Alignment.centerRight,
                      curve: Curves.linear,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    // return ProgressiveBlurWidget(
    //   sigma: 50.0,
    //   linearGradientBlur: const LinearGradientBlur(
    //     values: [0, 1],
    //     stops: [0.7, 0.9],
    //     start: Alignment.center,
    //     end: Alignment.bottomCenter,
    //   ),
    //   child: Stack(
    //     fit: StackFit.loose,
    //     children: [
    //       AnimatedBuilder(
    //         animation: _blurAnimation,
    //         builder: (context, child) {
    //           // Protection : s'assurer que sigma est toujours valide
    //           final safeSigma = _blurAnimation.value.clamp(0.1, 50.0);

    //           return ProgressiveBlurWidget(
    //             sigma: safeSigma,
    //             linearGradientBlur: const LinearGradientBlur(
    //               values: [1, 0],
    //               stops: [0.1, 0.55],
    //               start: Alignment.topCenter,
    //               end: Alignment.center,
    //             ),
    //             child: Stack(
    //               alignment: Alignment.bottomCenter,
    //               children: [
    //                 Padding(
    //                   padding: widget.padding ?? EdgeInsets.zero,
    //                   child: ListView(
    //                     shrinkWrap: widget.shrinkWrap,
    //                     padding: widget.contentPadding,
    //                     controller: _scrollController,
    //                     children: widget.children,
    //                   ),
    //                 ),
    //                 IgnorePointer(
    //                   ignoring: true,
    //                   child: Container(
    //                     height: MediaQuery.of(context).size.height / 3,
    //                     decoration: BoxDecoration(
    //                       gradient: SmoothGradient(
    //                         from: widget.color?.withValues(alpha: 0) ?? context.adaptiveBackground.withValues(alpha: 0),
    //                         to: widget.color ?? context.adaptiveBackground,
    //                         curve: Curves.linear,
    //                         begin: Alignment.center,
    //                         end: Alignment.bottomCenter,
    //                       ),
    //                     ),
    //                   ),
    //                 ),
    //               ],
    //             ),
    //           );
    //         },
    //       ),
    //       AnimatedOpacity(
    //         opacity: _isCutByTop ? 1.0 : 0.0,
    //         duration: const Duration(milliseconds: 300),
    //         curve: Curves.easeInOut,
    //         child: IgnorePointer(
    //           ignoring: true,
    //           child: Container(
    //             height: MediaQuery.of(context).size.height / 2.5,
    //             decoration: BoxDecoration(
    //               gradient: SmoothGradient(
    //                 from: widget.color ?? context.adaptiveBackground,
    //                 to: widget.color?.withValues(alpha: 0) ?? context.adaptiveBackground.withValues(alpha: 0),
    //                 curve: Curves.linear,
    //                 begin: Alignment.topCenter,
    //                 end: Alignment.center,
    //               ),
    //             ),
    //           ),
    //         ),
    //       ),
    //     ],
    //   ),
    // );
  }
}
