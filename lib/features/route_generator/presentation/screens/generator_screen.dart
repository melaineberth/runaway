import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/config/colors.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/icon_btn.dart';
import 'package:soft_edge_blur/soft_edge_blur.dart';

import '../../../home/presentation/blocs/route_parameters/route_parameters_bloc.dart';
import '../../../home/presentation/blocs/route_parameters/route_parameters_event.dart';
import '../../../home/presentation/blocs/route_parameters/route_parameters_state.dart';
import '../widgets/activity_selector.dart';
import '../widgets/parameter_slider.dart';
import '../widgets/preset_selector.dart';
import '../widgets/terrain_selector.dart';
import '../widgets/urban_density_selector.dart';

class GeneratorScreen extends StatefulWidget {
  final double startLongitude;
  final double startLatitude;
  final Function(double)? onRadiusChanged;

  const GeneratorScreen({
    super.key,
    required this.startLongitude,
    required this.startLatitude,
    this.onRadiusChanged,
  });

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Mettre à jour la position de départ dans le bloc
    context.read<RouteParametersBloc>().add(
      StartLocationUpdated(
        longitude: widget.startLongitude,
        latitude: widget.startLatitude,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Column(
            children: [
              // Handle
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              20.h,
    
              // Tabs
              TabBar(
                dividerHeight: 0,
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: [Tab(text: 'Paramètres'), Tab(text: 'Presets')],
              ),
    
              // Content
              Expanded(
                child: SoftEdgeBlur(
                  edges: [
                    EdgeBlur(
                      type: EdgeType.bottomEdge,
                      size: 150,
                      sigma: 20,
                      tintColor: Colors.white.withValues(alpha: 0.8),
                      controlPoints: [
                        ControlPoint(
                          position: 0.7,
                          type: ControlPointType.visible,
                        ),
                        ControlPoint(
                          position: 1,
                          type: ControlPointType.transparent,
                        )
                      ],
                    )
                  ],
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Paramètres
                      _buildParametersTab(),
                  
                      // Tab 2: Presets
                      _buildPresetsTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bouton générer
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 40),
            child: SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: IconBtn(
                      label: "Enregistrer",
                      backgroundColor: AppColors.primary,
                      labelColor: Colors.white,
                      onPressed: () {
                        final routeParametersBloc = context.read<RouteParametersBloc>();
                        final currentParameters = routeParametersBloc.state.parameters;

                        // Fermer la modal après un court délai pour éviter les conflits d'animation
                        Future.delayed(const Duration(milliseconds: 100), () {
                          Navigator.of(context).pop(currentParameters); // Retourne les paramètres au parent (HomeScreen)
                        });
                      },
                    ),
                  ),
                  15.w,
                  IconBtn(
                    icon: HugeIcons.strokeRoundedFavourite,
                    onPressed: () => _showAddToFavoritesDialog(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParametersTab() {
    return BlocBuilder<RouteParametersBloc, RouteParametersState>(
      builder: (context, state) => ListView(
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

              // Rayon de recherche
              ParameterSlider(
                title: "Zone de recherche",
                value: state.parameters.searchRadius / 1000, // Convertir en km
                min: state.parameters.distanceKm / 2,
                max: 50.0,
                unit: "km",
                icon: HugeIcons.strokeRoundedLocationShare01,
                onChanged: (value) {
                  context.read<RouteParametersBloc>().add(SearchRadiusChanged(value * 1000));
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
          ),
    );
  }

  Widget _buildPresetsTab() {
    return BlocBuilder<RouteParametersBloc, RouteParametersState>(
      builder: (context, state) => PresetSelector(
          onPresetSelected: (preset) {
            switch (preset) {
              case 'beginner':
                context.read<RouteParametersBloc>().add(PresetApplied('beginner'));
                break;
              case 'intermediate':
                context.read<RouteParametersBloc>().add(PresetApplied('intermediate'));
                break;
              case 'advanced':
                context.read<RouteParametersBloc>().add(PresetApplied('advanced'));
                break;
            }
            _tabController.animateTo(0); // Retourner aux paramètres
          },
          favorites: [],
          onFavoriteSelected: (index) {
            context.read<RouteParametersBloc>().add(FavoriteApplied(index));
            _tabController.animateTo(0);
          },
          onFavoriteDeleted: (index) {
            context.read<RouteParametersBloc>().add(FavoriteRemoved(index));
            _tabController.animateTo(0);
          },
        )
    );
  }

  Widget _buildAdvancedOptions(RouteParametersState state) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text('Options avancées', style: context.bodySmall),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Parcours en boucle', style: context.bodySmall),
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
            // TODO: Implémenter
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Éviter le trafic', style: context.bodySmall),
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
            // TODO: Implémenter
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Parcours pittoresque', style: context.bodySmall),
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
            // TODO: Implémenter
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
