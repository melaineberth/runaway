import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/features/auth/presentation/screens/auth_screen.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

final _channel = const MethodChannel('corner_radius');

Future<double> getDeviceCornerRadius() async {
  if (kDebugMode) debugPrint('[CR] ▶︎ Demande du rayon…');

  // 1️⃣ plateforme non prise en charge
  if (!Platform.isAndroid && !Platform.isIOS) {
    if (kDebugMode) debugPrint('[CR] ⛔️ Desktop / Web – retourne 0');
    return 0;
  }

  try {
    final radius = await _channel.invokeMethod<double>('getCornerRadius');

    if (kDebugMode) {
      debugPrint('[CR] ✔︎ Réponse native = ${radius ?? 'null'}');
    }

    return radius ?? 0;
  } on PlatformException catch (e, s) {
    if (kDebugMode) {
      debugPrint('[CR] 💥 PlatformException : ${e.message}');
      debugPrint('[CR] Stack :\n$s');
    }
    return 0;
  } catch (e, s) {
    if (kDebugMode) {
      debugPrint('[CR] 🔥 Erreur inconnue : $e');
      debugPrint('[CR] Stack :\n$s');
    }
    return 0;
  }
}

void showModalSheet({
  required BuildContext context,
  required Widget child,
  Color backgroundColor = Colors.black,
  bool isDismissible = true,
  bool useSafeArea = false,
}) {
  showModalBottomSheet(
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: false,
    context: context,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    clipBehavior: Clip.antiAliasWithSaveLayer,
    builder: (modalCtx) {
      return child;
    },
  );
}

String generateAutoRouteName(RouteParameters p, double distanceKm) {
  final now = DateTime.now();
  final timeString =
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';
  final dateString = '${now.day}/${now.month}';
  return '${p.activityType.title} '
      '${distanceKm.toStringAsFixed(0)}km - $timeString ($dateString)';
}

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
        // showSignModal(context, 1);
        context.push('/auth/1'); // Login
      },
      onCancel: () {
        // showSignModal(context, 0);
        context.push('/auth/0');
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