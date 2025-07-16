import 'package:flutter/material.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/features/home/domain/models/route_metrics.dart';
import 'package:runaway/features/route_generator/domain/models/activity_type.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';
import 'package:runaway/features/home/presentation/widgets/route_info_card.dart';
import 'package:runaway/features/route_generator/domain/models/urban_density.dart';

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
    final metrics = _createMetrics();

    return RouteInfoCard(
      routeName: widget.routeName,
      parameters: widget.parameters,
      metrics: metrics,
      isLoop: widget.isLoop,
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
  
  /// 🆕 Crée les métriques enrichies à partir des données disponibles
  RouteMetrics _createMetrics() {
    // Extraire les métriques depuis routeMetadata ou calculer des estimations
    final elevationGain = widget.routeMetadata['elevation_gain'] as double? ?? widget.parameters.elevationGain;
    final elevationLoss = widget.routeMetadata['elevation_loss'] as double? ?? elevationGain * 0.8; // Estimation
    final maxElevation = widget.routeMetadata['max_elevation'] as double? ?? elevationGain;
    final minElevation = widget.routeMetadata['min_elevation'] as double? ?? 0.0;
    final avgIncline = widget.routeMetadata['average_incline'] as double? ?? _calculateAverageIncline();
    final maxIncline = widget.routeMetadata['max_incline'] as double? ?? widget.parameters.maxInclinePercent;
    final scenicScore = widget.routeMetadata['scenic_score'] as double? ?? _calculateScenicScore();
    
    // Calculer la durée estimée
    final duration = widget.parameters.estimatedDuration;
    
    // Calculer les calories
    final calories = _calculateCalories(widget.distance, elevationGain, duration);
    
    // Extraire ou estimer les types de surface
    final surfaceTypes = _extractSurfaceTypes();
    
    // Extraire ou créer les points d'intérêt
    final highlights = _extractHighlights();
    
    // Calculer la difficulté
    final difficulty = _calculateDifficulty();

    return RouteMetrics(
      distanceKm: widget.distance,
      estimatedDuration: duration,
      elevationGain: elevationGain,
      elevationLoss: elevationLoss,
      maxElevation: maxElevation,
      minElevation: minElevation,
      averageIncline: avgIncline,
      maxIncline: maxIncline,
      waypointCount: widget.waypointCount,
      calories: calories,
      surfaceTypes: surfaceTypes,
      highlights: highlights,
      difficulty: difficulty,
      scenicScore: scenicScore,
    );
  }

  double _calculateAverageIncline() {
    if (widget.distance == 0) return 0.0;
    return (widget.parameters.elevationGain / (widget.distance * 1000)) * 100;
  }

  double _calculateScenicScore() {
    var score = 5.0; // Score de base
    
    // Bonus selon la densité urbaine
    switch (widget.parameters.urbanDensity) {
      case UrbanDensity.nature:
        score += 2.0;
        break;
      // case UrbanDensity.suburban:
      //   score += 1.0;
      //   break;
      case UrbanDensity.mixed:
        score += 0.5;
        break;
      case UrbanDensity.urban:
        break; // Pas de bonus
    }
    
    // Bonus pour les préférences scéniques
    if (widget.parameters.preferScenic) {
      score += 1.0;
    }
    
    // Bonus pour priorité parcs
    if (widget.parameters.prioritizeParks) {
      score += 1.0;
    }
    
    return score.clamp(1.0, 10.0);
  }

  double _calculateCalories(double distance, double elevation, Duration duration) {
    // Formules approximatives selon l'activité
    switch (widget.parameters.activityType) {
      case ActivityType.running:
        return (distance * 65) + (elevation * 0.5);
      case ActivityType.cycling:
        return (distance * 35) + (elevation * 0.3);
      case ActivityType.walking:
        return (distance * 45) + (elevation * 0.4);
    }
  }

  List<String> _extractSurfaceTypes() {
    // Extraire depuis les métadonnées ou estimer selon les paramètres
    final metadataSurfaces = widget.routeMetadata['surface_types'] as List<dynamic>?;
    if (metadataSurfaces != null) {
      return metadataSurfaces.map((e) => e.toString()).toList();
    }
    
    // Estimation basée sur les paramètres
    List<String> surfaces = [];
    
    if (widget.parameters.surfacePreference > 0.7) {
      surfaces.add('Route goudronnée');
    } else if (widget.parameters.surfacePreference < 0.3) {
      surfaces.add('Sentier naturel');
    } else {
      surfaces.addAll(['Route goudronnée', 'Sentier']);
    }
    
    if (widget.parameters.prioritizeParks) {
      surfaces.add('Parc');
    }
    
    return surfaces.isEmpty ? ['Mixte'] : surfaces;
  }

  List<String> _extractHighlights() {
    // Extraire depuis les métadonnées ou créer selon les paramètres
    final metadataHighlights = widget.routeMetadata['highlights'] as List<dynamic>?;
    if (metadataHighlights != null) {
      return metadataHighlights.map((e) => e.toString()).toList();
    }
    
    // Création basée sur les paramètres
    List<String> highlights = [];
    
    if (widget.parameters.prioritizeParks) {
      highlights.add('Espaces verts');
    }
    
    if (widget.parameters.preferScenic) {
      highlights.add('Points de vue');
    }
    
    if (widget.parameters.urbanDensity == UrbanDensity.nature) {
      highlights.add('Nature');
    }
    
    if (widget.parameters.elevationGain > 200) {
      highlights.add('Défi sportif');
    }
    
    return highlights;
  }

  String _calculateDifficulty() {
    // Utiliser la difficulté du paramètre ou calculer
    return widget.parameters.difficulty.title;
  }
}