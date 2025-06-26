import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/loading_overlay.dart';
import 'package:runaway/features/home/domain/models/nav_item_model.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_state.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    // On calcule dynamiquement l'index sélectionné à partir de la route actuelle
    final String loc = GoRouter.of(context).state.matchedLocation;
    final int selectedIndex = bottomNavItems.indexWhere((item) => item.route == loc).clamp(0, bottomNavItems.length - 1);

    return BlocBuilder<RouteGenerationBloc, RouteGenerationState>(
      builder: (context, routeState) {
        // 🔑 LoadingOverlay affiché pendant génération OU analyse
        final bool shouldShowLoading = routeState.isGeneratingRoute || routeState.isAnalyzingZone;
        
        return Stack(
          children: [
            // Interface principale
            Scaffold(
              extendBody: true,
              body: child,
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 80),
                  child: ClipRRect(
                    borderRadius: BorderRadiusGeometry.circular(100),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: selectedIndex == 0 ? 0 : 30, sigmaY: selectedIndex == 0 ? 0 : 30),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: selectedIndex == 0 ? 1 : 0.4),
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
            ),
            
            // LoadingOverlay global au premier plan
            if (shouldShowLoading)
              Positioned.fill(
                child: LoadingOverlay(),
              ),
          ],
        );
      },
    );
  }
}