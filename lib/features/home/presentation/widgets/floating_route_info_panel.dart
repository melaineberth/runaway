import 'package:flutter/material.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/home/presentation/widgets/route_info_card.dart';

class FloatingRouteInfoPanel extends StatefulWidget {
  final String routeName;
  final RouteParameters parameters;
  final double distance;
  final bool isLoop;
  final int waypointCount;
  final Map<String, dynamic> routeMetadata;
  final List<List<double>> coordinates;
  final VoidCallback onClear;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final bool isSaving;
  final bool isAlreadySaved;
  final VoidCallback? onDismiss;

  const FloatingRouteInfoPanel({
    super.key,
    required this.routeName,
    required this.parameters,
    required this.distance,
    required this.isLoop,
    required this.waypointCount,
    required this.routeMetadata,
    required this.coordinates,
    required this.onClear,
    required this.onShare,
    required this.onSave,
    this.isSaving = false,
    this.isAlreadySaved = false,
    this.onDismiss,
  });

  @override
  State<FloatingRouteInfoPanel> createState() => _FloatingRouteInfoPanelState();
}

class _FloatingRouteInfoPanelState extends State<FloatingRouteInfoPanel>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Démarrer les animations
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }


  void _handleDismiss() {
    _slideController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _fadeAnimation]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ModalSheet(
              padding: 0.0,
              child: _buildPanel(),
            ),
          ),
        );
      }
    );
  }

  Widget _buildPanel() {
    return RouteInfoCard(
      routeName: widget.routeName,
      parameters: widget.parameters,
      distance: widget.distance,
      isLoop: widget.isLoop,
      waypointCount: widget.waypointCount,
      onClear: () {
        _handleDismiss();
        widget.onClear();
      },
      onShare: widget.onShare,
      onSave: widget.onSave,
      isSaving: widget.isSaving,
      isAlreadySaved: widget.isAlreadySaved,
    );
  }
}