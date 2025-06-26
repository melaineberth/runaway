import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/features/home/domain/models/nav_item_model.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    // On calcule dynamiquement l’index sélectionné à partir de la route actuelle
    final String loc = GoRouter.of(context).state.matchedLocation;
    final int selectedIndex = bottomNavItems.indexWhere((item) => item.route == loc).clamp(0, bottomNavItems.length - 1);

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 80),
          child: ClipRRect(
            borderRadius: BorderRadiusGeometry.circular(100),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    bottomNavItems.length, 
                    (index) {
                      final item = bottomNavItems[index];
                      final bool isSelected = index == selectedIndex;
                      return IconBtn(
                        onPressed: () => context.go(item.route),
                        icon: isSelected ? item.activeIcon : item.inactiveIcon,
                        iconColor: isSelected ? AppColors.primary : Colors.white60,
                        padding: 20,
                        backgroundColor: Colors.transparent,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
