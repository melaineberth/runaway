import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/di/bloc_provider_extension.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_container.dart';

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

class _RouteParameterScreenState extends State<RouteParameterScreen> {
  @override
  void initState() {
    super.initState();

    context.routeParametersBloc.add(
      StartLocationUpdated(
        longitude: widget.startLongitude,
        latitude: widget.startLatitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      padding: 0.0,
      height: MediaQuery.of(context).size.height * 0.8,
      child: BlocBuilder<RouteParametersBloc, RouteParametersState>(
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
                    onActivitySelected: (type) {
                      context.routeParametersBloc.add(ActivityTypeChanged(type));
                    },
                  ),
                  30.h,
                    
                  // Terrain
                  TerrainSelector(
                    selectedTerrain: state.parameters.terrainType,
                    onTerrainSelected: (terrain) {
                      context.routeParametersBloc.add(TerrainTypeChanged(terrain));
                    },
                  ),
                  30.h,
                    
                  // Densité urbaine
                  UrbanDensitySelector(
                    selectedDensity: state.parameters.urbanDensity,
                    onDensitySelected: (density) {
                      context.routeParametersBloc.add(UrbanDensityChanged(density));
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
                    onChanged: (value) {
                      context.routeParametersBloc.add(DistanceChanged(value));
                    },
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
                    onChanged:  (value) {
                      context.routeParametersBloc.add(ElevationGainChanged(value));
                    },
                  ),
                  30.h,
                    
                  // Options avancées
                  _buildAdvancedOptions(state),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _buildSaveButton(),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: SquircleContainer(
        onTap: () {
          if (mounted) {
            context.pop();
          }
      
          Future.delayed(const Duration(milliseconds: 100));
          widget.generateRoute();
        },
        height: 55,
        gradient: false,
        color: context.adaptivePrimary,
        radius: 50.0,
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: Center(
            child: Text(
              context.l10n.generate,
              style: context.bodySmall?.copyWith(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showTopSnackBar(
    context,
    String message, {
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        dismissDirection: DismissDirection.up,
        duration: duration ?? const Duration(milliseconds: 1000),
        backgroundColor: Colors.green,
        margin: EdgeInsets.only(
          bottom: 20,
          left: 10,
          right: 10,
        ),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 20,
          ),
        ),
      ),
    );
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
