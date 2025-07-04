import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/features/home/domain/models/nav_item_model.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Interface principale
        Scaffold(
          extendBody: true,
          body: child,
          bottomNavigationBar: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    color: context.adaptiveBackground,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        spreadRadius: 2,
                        blurRadius: 30,
                        offset: Offset(0, 0), // changes position of shadow
                      ),
                    ]
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (context) {
                          // Recalculer l'index à chaque rebuild
                          final String loc = GoRouter.of(context).state.matchedLocation;
                          final int selectedIndex = NavItemModel.values.indexWhere((item) => item.route == loc).clamp(0, NavItemModel.values.length - 1);

                          return GNav(
                            selectedIndex: selectedIndex, // Forcer la mise à jour
                            activeColor: Colors.white,
                            iconSize: 25,
                            color: context.adaptiveTextPrimary.withValues(alpha: 0.5),
                            tabBackgroundColor: context.adaptivePrimary,
                            tabShadow: [BoxShadow(color: context.adaptiveTextPrimary.withValues(alpha: 0.1), blurRadius: 0)], // tab button shadow
                            padding: EdgeInsetsGeometry.symmetric(
                              horizontal: 15.0,
                              vertical: 15.0,
                            ),
                            tabs: [
                              ...NavItemModel.values.asMap().entries.map((entry) {
                                final i = entry.key;
                                final item = entry.value;
                          
                                final bool isSelected = i == selectedIndex;
                          
                                return GButton(
                                  gap: 8,
                                  margin: EdgeInsets.all(4.0),
                                  icon: isSelected ? item.activeIcon : item.inactiveIcon,
                                  text: item.title(context),
                                  textStyle: context.bodySmall?.copyWith(
                                    fontSize: 17,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => context.go(item.route),
                                );
                              }), 
                            ],
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}