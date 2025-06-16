import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:progressive_blur/progressive_blur.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:smooth_gradient/smooth_gradient.dart';

import '../../../home/presentation/blocs/route_parameters/route_parameters_bloc.dart';
import '../../../home/presentation/blocs/route_parameters/route_parameters_event.dart';
import '../../../home/presentation/blocs/route_parameters/route_parameters_state.dart';
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

class _RouteParameterScreenState extends State<RouteParameterScreen> with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  bool _isCutByTop = false; // au lancement, le début est sous la modal

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController()
    ..addListener(() {
      final cut = _scrollController.offset > 0;
      if (cut != _isCutByTop) {
        setState(() => _isCutByTop = cut);
      }
    });

    context.read<RouteParametersBloc>().add(
      StartLocationUpdated(
        longitude: widget.startLongitude,
        latitude: widget.startLatitude,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Stack(
        children: [
          ProgressiveBlurWidget(
            sigma: 50.0,
            linearGradientBlur: const LinearGradientBlur(
              values: [0, 1], // 0 - no blur, 1 - full blur
              stops: [0.5, 0.9],
              start: Alignment.center,
              end: Alignment.bottomCenter,
            ),
            child: _buildParametersTab(),
          ),

          // Top fade-in/out
          AnimatedOpacity(
            opacity: _isCutByTop ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  gradient: SmoothGradient(
                    from: Colors.black.withAlpha(0),
                    to:   Colors.black, // ou .withAlpha(180)
                    begin: Alignment.center,
                    end:   Alignment.topCenter,
                    steps: 25,
                  ),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: _buildSaveButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: IconBtn(
                label: "Générer",
                backgroundColor: AppColors.primary,
                labelColor: Colors.black,
                onPressed: () {
                  if (mounted) {
                    context.pop();
                  }

                  Future.delayed(const Duration(milliseconds: 100));
                  widget.generateRoute();
                },
              ),
            ),
            15.w,
            IconBtn(
              backgroundColor: Colors.white12,
              icon: HugeIcons.strokeRoundedFavourite,
              onPressed: () => _showAddToFavoritesDialog(),
            ),
          ],
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

  Widget _buildParametersTab() {
    return BlocBuilder<RouteParametersBloc, RouteParametersState>(
      builder: (context, state) {
        return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(30, 30, 30, kBottomNavigationBarHeight * 3),
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
                title: "Distance",
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
                title: "Dénivelé positif",
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
          );
      },
    );
  }

  Widget _buildAdvancedOptions(RouteParametersState state) {
    return ExpansionTile(
      collapsedIconColor: Colors.white,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text('Options avancées', style: context.bodySmall?.copyWith(color: Colors.white)),
      children: [
        SwitchListTile(
          inactiveTrackColor: Colors.white12,
          contentPadding: EdgeInsets.zero,
          title: Text('Parcours en boucle', style: context.bodySmall?.copyWith(color: Colors.white)),
          subtitle: Text(
            'Revenir au point de départ',
            style: context.bodySmall?.copyWith(
              color: Colors.grey.shade500,
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
          inactiveTrackColor: Colors.white12,
          contentPadding: EdgeInsets.zero,
          title: Text('Éviter le trafic', style: context.bodySmall?.copyWith(color: Colors.white)),
          subtitle: Text(
            'Privilégier les rues calmes',
            style: context.bodySmall?.copyWith(
              color: Colors.grey.shade500,
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
          inactiveTrackColor: Colors.white12,
          contentPadding: EdgeInsets.zero,
          title: Text('Parcours pittoresque', style: context.bodySmall?.copyWith(color: Colors.white)),
          subtitle: Text(
            'Privilégier les beaux paysages',
            style: context.bodySmall?.copyWith(
              color: Colors.grey.shade500,
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

  void _showAddToFavoritesDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Ajouter aux favoris'),
            content: TextField(
              decoration: InputDecoration(
                labelText: 'Nom du favori',
                hintText: 'Ex: Parcours du dimanche',
              ),
              onSubmitted: (name) {
                if (name.isNotEmpty) {
                  context.read<RouteParametersBloc>().add(FavoriteAdded(name));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ajouté aux favoris'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Annuler'),
              ),
            ],
          ),
    );
  }
}
