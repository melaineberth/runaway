import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';

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

    context.read<RouteParametersBloc>().add(
      StartLocationUpdated(
        longitude: widget.startLongitude,
        latitude: widget.startLatitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      height: MediaQuery.of(context).size.height * 0.6,
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
                      context.read<RouteParametersBloc>().add(ActivityTypeChanged(type));
                    },
                  ),
                  30.h,
                    
                  // Terrain
                  TerrainSelector(
                    selectedTerrain: state.parameters.terrainType,
                    onTerrainSelected: (terrain) {
                      context.read<RouteParametersBloc>().add(TerrainTypeChanged(terrain));
                    },
                  ),
                  30.h,
                    
                  // Densité urbaine
                  UrbanDensitySelector(
                    selectedDensity: state.parameters.urbanDensity,
                    onDensitySelected: (density) {
                      context.read<RouteParametersBloc>().add(UrbanDensityChanged(density));
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
                    icon: HugeIcons.strokeRoundedRoute03,
                    onChanged: (value) {
                      context.read<RouteParametersBloc>().add(DistanceChanged(value));
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
                    icon: HugeIcons.strokeRoundedMountain,
                    onChanged:  (value) {
                      context.read<RouteParametersBloc>().add(ElevationGainChanged(value));
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
      child: SizedBox(
        width: double.infinity,
        child: IconBtn(
          label: context.l10n.generate,
          backgroundColor: context.adaptivePrimary,
          labelColor: Colors.white,
          onPressed: () {
            if (mounted) {
              context.pop();
            }
        
            Future.delayed(const Duration(milliseconds: 100));
            widget.generateRoute();
          },
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
            context.read<RouteParametersBloc>().add(LoopToggled(value));
          },
        ),
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
            context.read<RouteParametersBloc>().add(AvoidTrafficToggled(value));
          },
        ),
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
            context.read<RouteParametersBloc>().add(PreferScenicToggled(value));
          },
        ),
      ],
    );
  }
}
