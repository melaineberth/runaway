import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/features/auth/presentation/screens/auth_screen.dart';

void showSignModal(BuildContext context, int index) {
  showModalSheet(
    context: context,
    isDismissible: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    child: AuthScreen(initialIndex: index),
  );
}

void showAuthModal(BuildContext context) {
  showModalSheet(
    context: context,
    isDismissible: false,
    backgroundColor: Colors.transparent,
    child: ModalDialog(
      isDismissible: true,
      imgPath: 'https://cdn.lottielab.com/l/13mdUjaB8g6HWu.json',
      title: context.l10n.notLoggedIn,
      subtitle: context.l10n.loginOrCreateAccountHint,
      validLabel: context.l10n.logIn,
      cancelLabel: context.l10n.createAccount,
      onValid: () {
        showSignModal(context, 1);
        // context.go('/auth/1'); // Login
      },
      onCancel: () {
        showSignModal(context, 0);
        // context.go('/auth/0');
      },
    ),
  );
}

IconData getTerrainIcon(String terrainId) {
  switch (terrainId) {
    case 'flat':
      return HugeIcons.solidRoundedRoad;
    case 'hilly':
      return HugeIcons.solidRoundedMountain;
    case 'mixed':
    default:
      return HugeIcons.solidRoundedRouteBlock;
  }
}

IconData getUrbanDensityIcon(String urbanDensityId) {
  switch (urbanDensityId) {
    case 'urban':
      return HugeIcons.solidRoundedCity03;
    case 'nature':
      return HugeIcons.solidRoundedTree05;
    case 'mixed':
    default:
      return HugeIcons.solidRoundedLocation04;
  }
}

Color darken(Color color, [double amount = .5]) {
  final hsl = HSLColor.fromColor(color);
  final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return darkened.toColor();
}