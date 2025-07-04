import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/blurry_page.dart';

class BlurryAppBar extends StatefulWidget {
  final String title;
  final List<Widget>? children;
  final Widget? child;
  
  const BlurryAppBar({super.key, required this.title, this.children, this.child});

  @override
  State<BlurryAppBar> createState() => _BlurryAppBarState();
}

class _BlurryAppBarState extends State<BlurryAppBar> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Nouveaux controllers pour la synchronisation avec BlurryPage
  late AnimationController _appBarController;
  late Animation<double> _appBarAnimation;

  // État de scroll partagé
  bool _isScrolled = false;

    @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Controller pour l'animation de l'AppBar synchronisé avec le scroll
    _appBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _appBarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _appBarController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _appBarController.dispose();
    super.dispose();
  }

  // Callback appelé par BlurryPage quand l'état de scroll change
  void _onScrollStateChanged(bool isScrolled) {
    if (_isScrolled != isScrolled) {
      setState(() => _isScrolled = isScrolled);
      
      // Animer l'AppBar en synchronisation avec BlurryPage
      if (isScrolled) {
        _appBarController.forward();
      } else {
        _appBarController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            widget.title,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextPrimary,
            ),
          ),
        ),
        flexibleSpace: AnimatedBuilder(
        animation: _appBarAnimation,
        builder: (context, child) {
            return FlexibleSpaceBar(
              background: AnimatedOpacity(
              opacity: _appBarAnimation.value,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 50 * _appBarAnimation.value,
                    sigmaY: 50 * _appBarAnimation.value,
                  ),
                  child: Container(
                    color: context.adaptiveBackground.withValues(
                      alpha: 0.3 * _appBarAnimation.value,
                    ),
                  ),
                ),
              ),
            );
          }
        ),
      ),
      body: widget.child ?? BlurryPage(
        onScrollStateChanged: _onScrollStateChanged,
        children: widget.children!,
      ),
    );
  }
}