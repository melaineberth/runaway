import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

class NavItemModel {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String route;

  NavItemModel({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.route,
  });
}

List<NavItemModel> bottomNavItems = [
  NavItemModel(
    label: "Home",
    activeIcon: HugeIcons.solidRoundedHome01,
    inactiveIcon: HugeIcons.strokeRoundedHome01,
    route: '/home',
  ),
  NavItemModel(
    label: "Activity",
    activeIcon: HugeIcons.solidRoundedActivity01,
    inactiveIcon: HugeIcons.strokeRoundedActivity01,
    route: '/activity',
  ),
  NavItemModel(
    label: "Historic",
    activeIcon: HugeIcons.solidRoundedCalendar03,
    inactiveIcon: HugeIcons.strokeRoundedCalendar03,
    route: '/historic',
  ),
  NavItemModel(
    label: "Account",
    activeIcon: HugeIcons.solidRoundedUserCircle02,
    inactiveIcon: HugeIcons.strokeRoundedUserCircle02,
    route: '/account',
  ),
];
