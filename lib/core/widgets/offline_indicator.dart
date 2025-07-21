// lib/core/widgets/offline_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/blocs/connectivity/connectivity_cubit.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';

/// Widget pour indiquer l'état offline avec gestion écran blanc
class OfflineIndicator extends StatefulWidget {
  final Widget child;
  final bool showPersistentIndicator;
  final Duration animationDuration;

  const OfflineIndicator({
    super.key,
    required this.child,
    this.showPersistentIndicator = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  ConnectionStatus? _currentStatus;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    // 🆕 Forcer une vérification au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceConnectivityCheck();
    });
  }

  /// 🆕 Force une vérification de connectivité
  void _forceConnectivityCheck() {
    try {
      ConnectivityService.instance.forceCheck();
    } catch (e) {
      LogConfig.logError('❌ Erreur force check: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectionStatus>(
      listener: (context, connectionStatus) {
        final oldStatus = _currentStatus;
        _currentStatus = connectionStatus;
        
        print('🔔 OfflineIndicator: $oldStatus → $connectionStatus');
        
        // Actions spéciales selon les transitions
        if (oldStatus == ConnectionStatus.offline && 
            connectionStatus != ConnectionStatus.offline) {
          print('🟢 Reconnexion détectée - forcing rebuild');
          // Force un rebuild complet
          if (mounted) {
            setState(() {});
          }
        }
        
        if (oldStatus != ConnectionStatus.offline && 
            connectionStatus == ConnectionStatus.offline) {
          print('🔴 Déconnexion détectée');
        }
        
        _isInitialLoad = false;
      },
      builder: (context, connectionStatus) {
        final isOffline = connectionStatus == ConnectionStatus.offline;
        
        LogConfig.logInfo('🎨 OfflineIndicator rebuild: offline=$isOffline, status=$connectionStatus, initial=$_isInitialLoad');

        // 🆕 Gestion de l'écran blanc initial
        Widget content = widget.child;
        
        // Si c'est le chargement initial et qu'on est offline, 
        // afficher un écran de fallback au lieu du blanc
        if (_isInitialLoad && isOffline) {
          content = _buildOfflineFallbackScreen();
        }
        
        return Stack(
          children: [
            content,
            
            // Indicateur offline en haut
            AnimatedPositioned(
              duration: widget.animationDuration,
              top: isOffline ? 0 : -100, // Cache plus loin pour être sûr
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: widget.animationDuration,
                height: isOffline ? kToolbarHeight * 2.5 : 0,
                decoration: BoxDecoration(
                  color: isOffline ? Colors.orange[800] : Colors.transparent,
                ),
                child: SafeArea(
                  bottom: false,
                  child: AnimatedOpacity(
                    duration: widget.animationDuration,
                    opacity: isOffline ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            HugeIcons.solidRoundedWifiDisconnected01,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mode hors ligne',
                            style: context.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 🆕 Écran de fallback pour éviter l'écran blanc
  Widget _buildOfflineFallbackScreen() {
    return Material(
      child: Container(
        color: Colors.grey[50],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                HugeIcons.solidRoundedWifiDisconnected01,
                size: 64,
                color: Colors.orange[600],
              ),
              16.h,
              Text(
                'Mode hors ligne',
                style: context.bodyMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              3.h,
              Text(
                'Fonctionnalités limitées disponibles',
                style: context.bodySmall?.copyWith(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              24.h,
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                ),
                child: SquircleBtn(
                  label: 'Vérifier la connexion',
                  onTap: _forceConnectivityCheck,
                  labelColor: Colors.white,
                  backgroundColor: Colors.orange[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension pour envelopper facilement n'importe quel widget
extension OfflineIndicatorExtension on Widget {
  Widget withOfflineIndicator({
    bool showPersistentIndicator = true,
    Duration animationDuration = const Duration(milliseconds: 300),
  }) {
    return OfflineIndicator(
      showPersistentIndicator: showPersistentIndicator,
      animationDuration: animationDuration,
      child: this,
    );
  }
}