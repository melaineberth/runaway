import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/blocs/connectivity/connectivity_cubit.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';

/// 🧪 Widget de debug pour afficher l'état de connectivité
/// À utiliser temporairement pour voir ce qui se passe
class ConnectivityDebugWidget extends StatelessWidget {
  final Widget child;

  const ConnectivityDebugWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityCubit, ConnectionStatus>(
      listener: (context, state) {
        // 🧪 Afficher un SnackBar à chaque changement d'état
        final message = switch (state) {
          ConnectionStatus.offline => '🔴 OFFLINE',
          ConnectionStatus.onlineWifi => '🟢 WIFI',
          ConnectionStatus.onlineMobile => '🟡 MOBILE',
        };
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug Connectivité: $message'),
            duration: const Duration(seconds: 2),
            backgroundColor: state == ConnectionStatus.offline 
              ? Colors.red[600] 
              : Colors.green[600],
          ),
        );
        
        // 🧪 Log console détaillé
        print('🧪 [DEBUG] ConnectivityCubit State Change: $state');
        print('🧪 [DEBUG] Service isOffline: ${ConnectivityService.instance.isOffline}');
        print('🧪 [DEBUG] Service current: ${ConnectivityService.instance.current}');
      },
      child: BlocBuilder<ConnectivityCubit, ConnectionStatus>(
        builder: (context, state) {
          return Stack(
            children: [
              child,
              
              // 🧪 Indicateur de debug en bas à droite
              Positioned(
                bottom: 100,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DEBUG',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: state == ConnectionStatus.offline 
                            ? Colors.red 
                            : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.name.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 🧪 Extension pour ajouter facilement le debug
extension ConnectivityDebugExtension on Widget {
  Widget withConnectivityDebug() {
    return ConnectivityDebugWidget(child: this);
  }
}
