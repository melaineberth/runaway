import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';

enum NavItemModel {
  home(
    label: "Home",
    activeIcon: HugeIcons.solidRoundedHome01,
    inactiveIcon: HugeIcons.strokeRoundedHome01,
    route: '/home',
  ),
  activity(
    label: "Activity",
    activeIcon: HugeIcons.solidRoundedActivity01,
    inactiveIcon: HugeIcons.strokeRoundedActivity01,
    route: '/activity',
  ),
  historic(
    label: "Historic",
    activeIcon: HugeIcons.solidRoundedCalendar03,
    inactiveIcon: HugeIcons.strokeRoundedCalendar03,
    route: '/historic',
  ),
  account(
    label: "Account",
    activeIcon: HugeIcons.solidRoundedUserCircle02,
    inactiveIcon: HugeIcons.strokeRoundedUserCircle02,
    route: '/account',
  );

  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String route;

  const NavItemModel({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.route,
  });
}

extension NavItemL10n on NavItemModel {
  /// Renvoie la chaîne localisée pour *cette* valeur de enum.
  String title(BuildContext context) {
    final l10n = context.l10n;     // ou `content.l10n` dans ton widget
    switch (this) {
      case NavItemModel.home:
        return l10n.home;   // clé ARB : "statusPending"
      case NavItemModel.activity:
        return l10n.activityTitle;
      case NavItemModel.historic:
        return l10n.historic;
      case NavItemModel.account:
        return l10n.account;
    }
  }
}
