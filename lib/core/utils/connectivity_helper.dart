import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';
import 'package:runaway/core/widgets/modal_dialog.dart';
import 'package:runaway/core/utils/constant/constants.dart';

/// Helper simple pour vérifier la connectivité et afficher un modal si hors ligne
class ConnectivityHelper {
  ConnectivityHelper._();

  /// Vérifie la connexion et affiche un modal si hors ligne
  static bool checkConnectionAndShowModal(BuildContext context) {
    if (ConnectivityService.instance.isOffline) {
      _showOfflineModal(context);
      return false;
    }
    return true;
  }

  /// Affiche le modal d'alerte connexion internet
  static void _showOfflineModal(BuildContext context) {
    showModalSheet(
      context: context,
      backgroundColor: Colors.transparent,
      child: ModalDialog(
        title: context.l10n.noInternetConnection,
        subtitle: context.l10n.checkNetwork,
        validLabel: context.l10n.retry,
        activeCancel: false,
        onValid: () {
          context.pop();
        },
      ),
    );
  }
}