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

  // 🆕 Paramètres pour LazyLoading
  final bool enableLazyLoading;
  final int initialItemCount;
  final int itemsPerPage;
  final VoidCallback? onLoadMore;
  final bool isLoading;
  final bool hasMoreData;

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
    // 🆕 Paramètres LazyLoading par défaut
    this.enableLazyLoading = false,
    this.initialItemCount = 10,
    this.itemsPerPage = 10,
    this.onLoadMore,
    this.isLoading = false,
    this.hasMoreData = true,
  });

  @override
  State<BlurryPage> createState() => _BlurryPageState();
}

class _BlurryPageState extends State<BlurryPage> with TickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _blurAnimationController;
  late final Animation<double> _blurAnimation;
  bool _isCutByTop = false;
  bool _isCutByBottom = false;
  bool _isCutByLeft = false; // 🆕 si scroll horizontal
  bool _isCutByRight = false; // 🆕 si scroll horizontal

  // 🆕 Variables pour LazyLoading
  int _currentItemCount = 0;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();

    // 🆕 Initialiser le nombre d'éléments pour LazyLoading
    _currentItemCount = widget.enableLazyLoading 
      ? widget.initialItemCount 
      : widget.children.length;

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

    _scrollController = ScrollController();
    
    // 🆕 Listener pour détection fin de liste
    if (widget.enableLazyLoading) {
      _scrollController.addListener(_checkForLoadMore);
    }

    _scrollController.addListener(_onScroll);

    widget.onScrollControllerReady?.call(_scrollController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateEdgeState(_scrollController.position);
      }
    });
  }

  // 🆕 Méthode pour détecter quand charger plus d'éléments
  void _checkForLoadMore() {
    if (!widget.enableLazyLoading || 
        _isLoadingMore || 
        !widget.hasMoreData || 
        widget.onLoadMore == null) {
      return;
    }

    final scrollController = _scrollController;
    const threshold = 200.0; // Déclencher le chargement 200px avant la fin

    if (scrollController.position.pixels >= 
        scrollController.position.maxScrollExtent - threshold) {
      
      setState(() => _isLoadingMore = true);
      
      // Déclencher le chargement avec un délai pour éviter les doublons
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !widget.isLoading) {
          widget.onLoadMore?.call();
        }
      });
    }
  }

  void _onScroll() {
    _updateEdgeState(_scrollController.position);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _blurAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BlurryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 🆕 Mettre à jour le compteur d'éléments
    if (widget.enableLazyLoading) {
      final newCount = (_currentItemCount + widget.itemsPerPage)
          .clamp(0, widget.children.length);
      
      if (oldWidget.isLoading && !widget.isLoading) {
        setState(() {
          _currentItemCount = newCount;
          _isLoadingMore = false;
        });
      }
    } else {
      _currentItemCount = widget.children.length;
    }
  }

  // Calcule la visibilité des bords
  void _updateEdgeState(ScrollMetrics m) {
    if (widget.scrollDirection == Axis.vertical) {
      final cutTop = _scrollController.offset > 0;
      final cutBottom = _scrollController.offset < _scrollController.position.maxScrollExtent;

      bool changed = false;

      if (cutTop != _isCutByTop) {
        _isCutByTop = cutTop;
        widget.onScrollStateChanged?.call(cutTop);

        if (cutTop) {
          _blurAnimationController.forward();
        } else {
          _blurAnimationController.reverse();
        }

        changed = true;
      }

      if (cutBottom != _isCutByBottom) {
        _isCutByBottom = cutBottom;
        changed = true;
      }

      if (changed) setState(() {});
    } else {
      final offset = _scrollController.offset;
      final max = _scrollController.position.maxScrollExtent;
      final cutLeft = offset > 0;
      final cutRight = offset < max;

      if (cutLeft != _isCutByLeft || cutRight != _isCutByRight) {
        setState(() {
          _isCutByLeft = cutLeft;
          _isCutByRight = cutRight;
        });
      }
    }
  }

  // 🆕 Construire la liste avec LazyLoading
  Widget _buildLazyLoadingList() {
    final displayItemCount = _currentItemCount.clamp(0, widget.children.length);
    final displayItems = widget.children.take(displayItemCount).toList();

    // Ajouter un indicateur de chargement si nécessaire
    if (widget.hasMoreData && displayItemCount < widget.children.length) {
      displayItems.add(_buildLoadingIndicator());
    }

    return ListView(
      controller: _scrollController,
      scrollDirection: widget.scrollDirection,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      padding: widget.contentPadding,
      children: displayItems,
    );
  }

  // 🆕 Indicateur de chargement simple
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              context.adaptivePrimary.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
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
                      _updateEdgeState(n.metrics); // <— met à jour même sans déplacement
                      return false;
                    },
                    child: widget.child ?? 
                    // 🆕 Utiliser la liste LazyLoading si activée
                    (widget.enableLazyLoading 
                      ? _buildLazyLoadingList()
                      : ListView(
                          controller: _scrollController,
                          scrollDirection: widget.scrollDirection,
                          physics: widget.physics,
                          shrinkWrap: widget.shrinkWrap,
                          padding: widget.contentPadding,
                          children: widget.children,
                        )
                    ),
                  ),
                ),
    
                // 🔸 Fade BOTTOM 
                if (widget.scrollDirection == Axis.vertical)
                AnimatedOpacity(
                  opacity: _isCutByBottom ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      height: MediaQuery.of(context).size.height / 2.5,
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
                  to: widget.color?.withValues(alpha: 0) ?? context.adaptiveBackground.withValues(alpha: 0),
                  curve: Curves.linear,
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                ),
              ),
            ),
          ),
        ),
    
        // 🔸 Fade GAUCHE
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
                      to: widget.color?.withValues(alpha: 0) ?? context.adaptiveBackground.withValues(alpha: 0),
                      begin: Alignment.centerLeft,
                      end: Alignment.center,
                      curve: Curves.linear,
                    ),
                  ),
                ),
              ),
            ),
          ),
    
        // 🔸 Fade DROITE
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
                      from: widget.color?.withValues(alpha: 0) ?? context.adaptiveBackground.withValues(alpha: 0),
                      to: widget.color ?? context.adaptiveBackground,
                      begin: Alignment.center,
                      end: Alignment.centerRight,
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
