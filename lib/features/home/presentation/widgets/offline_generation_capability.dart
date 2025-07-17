import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/blocs/connectivity/connectivity_cubit.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/route_generator/presentation/blocs/extensions/route_generation_bloc_extensions.dart';
import 'package:runaway/features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';

/// 🆕 Widget optimisé pour gérer la vérification de capacité de génération
/// avec support offline et timeouts courts
class OfflineGenerationCapability extends StatefulWidget {
  final Widget Function(GenerationCapability capability) builder;
  final Widget? loadingWidget;
  final Duration timeout;

  const OfflineGenerationCapability({
    super.key,
    required this.builder,
    this.loadingWidget,
    this.timeout = const Duration(seconds: 3),
  });

  @override
  State<OfflineGenerationCapability> createState() => 
      _OfflineGenerationCapabilityState();
}

class _OfflineGenerationCapabilityState 
    extends State<OfflineGenerationCapability> {
  
  GenerationCapability? _cachedCapability;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkCapabilityOptimized();
  }

  Future<void> _checkCapabilityOptimized() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authBloc = context.read<AuthBloc>();
      final routeBloc = context.read<RouteGenerationBloc>();
      
      // 🚀 Vérification rapide avec timeout et gestion offline
      final capability = await routeBloc
          .checkGenerationCapability(authBloc)
          .timeout(widget.timeout);

      if (mounted) {
        setState(() {
          _cachedCapability = capability;
          _isLoading = false;
        });
      }

    } catch (e) {
      print('❌ Erreur vérification capacité: $e');
      
      if (mounted) {
        // 🆕 Fallback intelligent basé sur l'état de connectivité
        final connectivityService = ConnectivityService.instance;
        final fallbackCapability = connectivityService.isOffline
            ? GenerationCapability.guest(canGenerate: true, remainingGenerations: 5)
            : GenerationCapability.unavailable('Erreur de connexion');

        setState(() {
          _cachedCapability = fallbackCapability;
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🆕 Écouter les changements de connectivité pour re-vérifier si nécessaire
    return BlocListener<ConnectivityCubit, ConnectionStatus>(
      listener: (context, connectionStatus) {
        // Si on passe d'offline à online, re-vérifier la capacité
        if (connectionStatus != ConnectionStatus.offline && 
            _cachedCapability?.type == GenerationType.guest &&
            _error != null) {
          print('🔄 Reconnexion détectée - re-vérification capacité');
          _checkCapabilityOptimized();
        }
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return widget.loadingWidget ?? const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_cachedCapability == null) {
      // Fallback de secours
      final fallbackCapability = GenerationCapability.guest(
        canGenerate: true, 
        remainingGenerations: 5
      );
      return widget.builder(fallbackCapability);
    }

    return widget.builder(_cachedCapability!);
  }
}

// 🆕 Extension pour simplifier l'utilisation dans HomeScreen
extension HomeScreenOfflineOptimizations on State<StatefulWidget> {
  
  /// Remplace le FutureBuilder par ce widget optimisé
  Widget buildOptimizedGenerationCapability({
    required Widget Function(GenerationCapability) builder,
    Widget? loadingWidget,
    Duration timeout = const Duration(seconds: 3),
  }) {
    return OfflineGenerationCapability(
      builder: builder,
      loadingWidget: loadingWidget,
      timeout: timeout,
    );
  }
}