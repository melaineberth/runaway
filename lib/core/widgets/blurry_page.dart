import 'package:flutter/material.dart';
import 'package:runaway/config/colors.dart';
import 'package:smooth_gradient/smooth_gradient.dart';

class BlurryPage extends StatefulWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? contentPadding;
  final Color? color;
  
  const BlurryPage({super.key, required this.children, this.padding, this.contentPadding, this.color});

  @override
  State<BlurryPage> createState() => _BlurryPageState();
}

class _BlurryPageState extends State<BlurryPage> {
  late final ScrollController _scrollController;
  bool _isCutByTop = false; // au lancement, le début est sous la modal

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController()
    ..addListener(() {
      final cut = _scrollController.offset > 0;
      if (cut != _isCutByTop) {
        setState(() => _isCutByTop = cut);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: ListView(
                shrinkWrap: true,
                padding: widget.contentPadding,
                controller: _scrollController,
                children: widget.children
              ),
            ),
          
            IgnorePointer(
              ignoring: true,
              child: Container(
                height: MediaQuery.of(context).size.height / 4,
                decoration: BoxDecoration(
                  gradient: SmoothGradient(
                    from: widget.color?.withValues(alpha: 0) ?? AppColorsDark.background.withValues(alpha: 0),
                    to: widget.color ?? AppColorsDark.background,
                    curve: Curves.linear,
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
        AnimatedOpacity(
          opacity: _isCutByTop ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: IgnorePointer(
              ignoring: true,
              child: Container(
                height: MediaQuery.of(context).size.height / 3,
                decoration: BoxDecoration(
                  gradient: SmoothGradient(
                    from: widget.color ?? AppColorsDark.background,
                    to: widget.color?.withValues(alpha: 0) ?? AppColorsDark.background.withValues(alpha: 0),
                    curve: Curves.linear,
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
            ),
        ),
      ],
    );
  }
}