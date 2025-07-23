import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/features/auth/presentation/screens/auth_screen.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

final _channel = const MethodChannel('corner_radius');

Future<double> getDeviceCornerRadius() async {
  // 1️⃣ plateforme non prise en charge
  if (!Platform.isAndroid && !Platform.isIOS) {
    return 0;
  }

  try {
    final radius = await _channel.invokeMethod<double>('getCornerRadius');

    return radius ?? 0;
  } on PlatformException catch (e) {
    LogConfig.logError(e.toString());
    return 0;
  } catch (e) {
    LogConfig.logError(e.toString());
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

String generateAutoRouteName(BuildContext context, RouteParameters parameters, double distanceKm) {
  // Obtenir le nombre de parcours existants pour générer le numéro
  final int routeNumber = _getNextRouteNumber(context);
  
  // Générer le nom simple
  return context.l10n.routeGenerateName(routeNumber);
}

String generateAutoRouteDesc(BuildContext context, RouteParameters parameters, double distanceKm) {    
  // Formater la date selon la locale courante de l'application
  final String dateString = _formatDateForLocale(context);

  // Construire le nom final
  return context.l10n.routeGenerateDesc(dateString);
  // return 'Parcours de $activityName d\'environ $timeString - $dateString';
}

/// 🆕 Formate la date selon la langue/locale courante
String _formatDateForLocale(BuildContext context) {
  final DateTime now = DateTime.now();
  final Locale currentLocale = Localizations.localeOf(context);
  
  // Utiliser DateFormat avec la locale courante
  final DateFormat dateFormat = DateFormat.yMd(currentLocale.toString());
    
  return dateFormat.format(now);
}

/// Calcule la durée estimée en minutes selon le type d'activité
int calculateEstimatedDuration(double distanceKm, ActivityType activityType, double elevationGain) {
  // Vitesses moyennes en km/h selon l'activité
  double baseSpeedKmh;
  switch (activityType) {
    case ActivityType.walking:
      baseSpeedKmh = 4.5; // Marche normale
      break;
    case ActivityType.running:
      baseSpeedKmh = 10.0; // Course modérée
      break;
    case ActivityType.cycling:
      baseSpeedKmh = 20.0; // Vélo loisir
      break;
  }
  
  // Calcul du temps de base
  double baseTimeHours = distanceKm / baseSpeedKmh;
  
  // Ajustement pour le dénivelé (formule Naismith simplifiée)
  double elevationPenaltyHours = 0.0;
  if (elevationGain > 0) {
    switch (activityType) {
      case ActivityType.walking:
        // +1 minute par 10m de dénivelé en marche
        elevationPenaltyHours = elevationGain / 600; // 600m/h = 10m/min
        break;
      case ActivityType.running:
        // +30 secondes par 10m de dénivelé en course
        elevationPenaltyHours = elevationGain / 1200; // Impact réduit en course
        break;
      case ActivityType.cycling:
        // +2 minutes par 10m de dénivelé en vélo
        elevationPenaltyHours = elevationGain / 300; // Impact plus important en vélo
        break;
    }
  }
  
  // Temps total en minutes
  final double totalTimeHours = baseTimeHours + elevationPenaltyHours;
  final int totalMinutes = (totalTimeHours * 60).round();
  
  // Minimum 5 minutes pour éviter les valeurs trop faibles
  return math.max(5, totalMinutes);
}

/// Formate la durée en texte lisible
String formatDuration(int minutes) {
  if (minutes < 60) {
    return '${minutes}min';
  } else {
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;
    
    if (remainingMinutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h${remainingMinutes.toString().padLeft(2, '0')}';
    }
  }
}

/// Obtient le prochain numéro de parcours basé sur les parcours existants
int _getNextRouteNumber(BuildContext context) {
  try {
    // Accéder au BLoC AppData pour obtenir les parcours sauvegardés
    final appDataBloc = context.read<AppDataBloc>();
    final appDataState = appDataBloc.state;
    
    if (appDataState.hasHistoricData) {
      // Retourner le nombre de parcours + 1
      return appDataState.savedRoutes.length + 1;
    } else {
      // Si pas de données historiques, commencer à 1
      return 1;
    }
  } catch (e) {
    // En cas d'erreur, commencer à 1
    debugPrint('Erreur lors du calcul du numéro de parcours: $e');
    return 1;
  }
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

IconData getActivityIcon(String activityId) {
  switch (activityId) {
    case 'walking':
      return HugeIcons.solidRoundedRunningShoes;
    case 'running':
      return HugeIcons.solidRoundedWorkoutRun;
    case 'cycling':
    default:
      return HugeIcons.solidRoundedBicycle;
  }
}

IconData getTerrainIcon(String terrainId) {
  switch (terrainId) {
    case 'flat':
      return HugeIcons.solidRoundedRoad;
    case 'hilly':
      return HugeIcons.solidRoundedMountain;
    case 'mixed':
    default:
      return HugeIcons.strokeRoundedRoad02;
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