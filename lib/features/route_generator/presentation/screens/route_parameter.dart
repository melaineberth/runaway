import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/helper/extensions/monitoring_extensions.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/core/helper/services/permission_service.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/tick_slider.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_bloc.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_event.dart';
import 'package:runaway/features/credits/presentation/blocs/credits_state.dart';
import 'package:runaway/features/route_generator/data/validation/route_parameters_validator.dart';

import '../../../home/presentation/blocs/route_parameters_bloc.dart';
import '../../../home/presentation/blocs/route_parameters_event.dart';
import '../../../home/presentation/blocs/route_parameters_state.dart';
import '../widgets/activity_selector.dart';
import '../widgets/parameter_slider.dart';
import '../widgets/terrain_selector.dart';
import '../widgets/urban_density_selector.dart';

class RouteParameterScreen extends StatefulWidget {
  final double startLongitude;
  final VoidCallback generateRoute;
  final double startLatitude;
  final Function(double)? onRadiusChanged;

  const RouteParameterScreen({
    super.key,
    required this.startLongitude,
    required this.startLatitude,
    required this.generateRoute,
    this.onRadiusChanged,
  });

  @override
  State<RouteParameterScreen> createState() => _RouteParameterScreenState();
}

class _RouteParameterScreenState extends State<RouteParameterScreen> with TickerProviderStateMixin {
  late String _screenLoadId;
  late AnimationController _validationAnimationController;
  late Animation<double> _validationScaleAnimation;

  bool _isValidating = false;
  ValidationResult? _currentValidation;
  List<AppPermissionStatus> _missingPermissions = [];

  @override
  void initState() {
    super.initState();

    _validationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _validationScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _validationAnimationController,
      curve: Curves.easeOutBack,
    ));

    context.routeParametersBloc.add(
      StartLocationUpdated(
        longitude: widget.startLongitude,
        latitude: widget.startLatitude,
      ),
    );

    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Mettre à jour la position de départ
    context.routeParametersBloc.add(
      StartLocationUpdated(
        longitude: widget.startLongitude,
        latitude: widget.startLatitude,
      ),
    );

    // Charger les crédits
    context.creditsBloc.add(const CreditsRequested());

    // Vérifier les permissions
    await _checkPermissions();

    // Tracking de l'écran
    _screenLoadId = context.trackScreenLoad('enhanced_route_parameter_screen');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.finishScreenLoad(_screenLoadId);
      _performInitialValidation();
    });
  }

  Future<void> _checkPermissions() async {
    final permissions = await PermissionService.instance.checkAllPermissions();
    final missing = permissions.values
        .where((p) => p.needsAction && p.permission == AppPermission.location)
        .toList();
    
    if (missing.isNotEmpty) {
      setState(() {
        _missingPermissions = missing;
      });
    }
  }

  // 🆕 Tracking des changements de paramètres
  void _trackParameterChange(String parameter, dynamic value) {
    MonitoringService.instance.recordMetric(
      'parameter_change',
      1,
      tags: {
        'parameter': parameter,
        'value': value.toString(),
        'screen': 'route_parameter',
      },
    );
  }

  void _performInitialValidation() {
    final state = context.routeParametersBloc.state;
    final validation = RouteParametersValidator.validate(state.parameters);
    
    setState(() {
      _currentValidation = validation;
    });
    
    if (!validation.isValid) {
      _validationAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _validationAnimationController.dispose();
    super.dispose();
  }

  void _handleParametersChanged(BuildContext context, RouteParametersState state) {
    // Validation en temps réel
    final validation = RouteParametersValidator.validate(state.parameters);
    
    if (validation != _currentValidation) {
      setState(() {
        _currentValidation = validation;
      });
      
      if (!validation.isValid) {
        _validationAnimationController.forward();
        HapticFeedback.lightImpact();
      } else {
        _validationAnimationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MonitoredScreen(
      screenName: 'route_parameter',
      screenData: {
        'start_lat': widget.startLatitude,
        'start_lng': widget.startLongitude,
      },
      child: ModalSheet(
        padding: 0.0,
        height: MediaQuery.of(context).size.height * 0.8,
        child: BlocConsumer<RouteParametersBloc, RouteParametersState>(
          listener: _handleParametersChanged,
          builder: (context, state) {
            return Stack(
              children: [
                BlurryPage(
                  color: context.adaptiveBackground,
                  contentPadding: const EdgeInsets.fromLTRB(30, 30, 30, kBottomNavigationBarHeight * 2.5),
                  children: [
                    // Activité
                    ActivitySelector(
                      selectedActivity: state.parameters.activityType,
                      onActivitySelected: (activity) {
                        context.routeParametersBloc.add(ActivityTypeChanged(activity));
                        _trackParameterChange('activity_type', activity.name);
                      },
                    ),
                    30.h,
                      
                    // Terrain
                    TerrainSelector(
                      selectedTerrain: state.parameters.terrainType,
                      onTerrainSelected: (terrain) {
                        context.routeParametersBloc.add(TerrainTypeChanged(terrain));
                        _trackParameterChange('terrain_type', terrain.name);
                      },
                    ),
                    30.h,
                      
                    // Densité urbaine
                    UrbanDensitySelector(
                      selectedDensity: state.parameters.urbanDensity,
                      onDensitySelected: (density) {
                        context.routeParametersBloc.add(UrbanDensityChanged(density));
                        _trackParameterChange('urban_density', density.name);
                      },
                    ),
                    30.h,
      
                    // Distance
                    ParameterSlider(
                      title: context.l10n.distance,
                      value: state.parameters.distanceKm,
                      min: state.parameters.activityType.minDistance,
                      max: state.parameters.activityType.maxDistance,
                      unit: "km",
                      startIcon: HugeIcons.solidRoundedPinLocation03,
                      endIcon: HugeIcons.solidRoundedFlag02,
                      onChanged: (distance) {
                        context.routeParametersBloc.add(DistanceChanged(distance));
                        _trackParameterChange('distance', distance);
                      },
                      enableHapticFeedback: true,
                      hapticIntensity: HapticIntensity.light, // ✅ Plus subtil pour précision
                    ),
                    30.h,
                  
                    // Dénivelé
                    ParameterSlider(
                      title: context.l10n.elevation,
                      value: state.parameters.elevationGain,
                      min: 0,
                      max: state.parameters.distanceKm * state.parameters.terrainType.maxElevationGain,
                      unit: "m",
                      startIcon: HugeIcons.strokeRoundedRoute03,
                      endIcon: HugeIcons.strokeRoundedRoute03,
                      onChanged: (elevation) {
                        context.routeParametersBloc.add(ElevationGainChanged(elevation));
                        _trackParameterChange('elevation_gain', elevation);
                      },
                      enableHapticFeedback: true,
                      hapticIntensity: HapticIntensity.light, // ✅ Plus subtil pour précision
                    ),
                    30.h,
                      
                    // Options avancées
                    _buildAdvancedOptions(state),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildGenerateButton(),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: BlocBuilder<CreditsBloc, CreditsState>(
        builder: (context, creditsState) {
          // Déterminer si on peut générer
          final isLoadingCredits = creditsState is CreditsLoading;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [              
              
              // Bouton principal
              SquircleBtn(
                isPrimary: true,
                isLoading: isLoadingCredits,
                onTap: _handleGenerate,
                label: context.l10n.generate,
              ),
            ],
          );
        },
      ),
    );
  }

  // 🆕 Gérer la génération avec vérification préalable des crédits
  Future<void> _handleGenerate() async {
    print('🔍 === VÉRIFICATION CRÉDITS AVANT GÉNÉRATION ===');
      
    // Fermer la modal des paramètres
    if (mounted) {
      context.pop();
    }
    
    // Attendre un peu pour que la modal se ferme proprement
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Lancer la génération normale
    widget.generateRoute();
  }

  Widget _buildAdvancedOptions(RouteParametersState state) {
    return Column(
      children: [
        SwitchListTile(
          inactiveTrackColor: context.adaptiveBorder.withValues(alpha: 0.08),
          activeColor: context.adaptivePrimary,
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.loopCourse, style: context.bodySmall?.copyWith(color: context.adaptiveTextPrimary)),
          subtitle: Text(
            context.l10n.returnStartingPoint,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          value: state.parameters.isLoop,
          onChanged: (value) {
            context.routeParametersBloc.add(LoopToggled(value));
          },
        ),
        15.h,
        SwitchListTile(
          inactiveTrackColor: context.adaptiveBorder.withValues(alpha: 0.08),
          activeColor: context.adaptivePrimary,
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.avoidTraffic, style: context.bodySmall?.copyWith(color: context.adaptiveTextPrimary)),
          subtitle: Text(
            context.l10n.quietStreets,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          value: state.parameters.avoidTraffic,
          onChanged: (value) {
            context.routeParametersBloc.add(AvoidTrafficToggled(value));
          },
        ),
        15.h,
        SwitchListTile(
          inactiveTrackColor: context.adaptiveBorder.withValues(alpha: 0.08),
          activeColor: context.adaptivePrimary,
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.scenicRoute, style: context.bodySmall?.copyWith(color: context.adaptiveTextPrimary)),
          subtitle: Text(
            context.l10n.prioritizeLandscapes,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          value: state.parameters.preferScenic,
          onChanged: (value) {
            context.routeParametersBloc.add(PreferScenicToggled(value));
          },
        ),
      ],
    );
  }
}
