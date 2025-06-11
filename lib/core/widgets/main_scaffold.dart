import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/config/colors.dart';
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
        child: Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(bottomNavItems.length, (index) {
              final item = bottomNavItems[index];
              final bool isSelected = index == selectedIndex;
              return GestureDetector(
                onTap: () {
                  // on change la route
                  context.go(item.route);
                },
                child: Icon(
                  isSelected ? item.activeIcon : item.inactiveIcon,
                  color: isSelected ? AppColors.primary : Colors.white60,
                  size: 28,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
