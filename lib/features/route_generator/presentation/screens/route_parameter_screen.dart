import 'dart:math' as math;

import 'package:bounce/bounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/core/blocs/app_data/app_data_state.dart';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/utils/injections/bloc_provider_extension.dart';
import 'package:runaway/core/helper/extensions/monitoring_extensions.dart';
import 'package:runaway/core/helper/services/monitoring_service.dart';
import 'package:runaway/core/helper/services/permission_service.dart';
import 'package:runaway/core/widgets/blurry_page.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/core/widgets/tick_slider.dart';
import 'package:runaway/features/route_generator/data/validation/route_parameters_validator.dart';
import 'package:runaway/features/route_generator/domain/models/route_parameters.dart';

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

  ValidationResult? _currentValidation;
  List<AppPermissionStatus> _missingPermissions = [];

  // ✅ Variables pour éviter les fuites mémoire
  bool _isDisposed = false;

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

    // Vérifier les permissions
    await _checkPermissions();

    // Tracking de l'écran
    if (mounted) {
      _screenLoadId = context.trackScreenLoad('enhanced_route_parameter_screen');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.finishScreenLoad(_screenLoadId);
        _performInitialValidation();
      });
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final permissions = await PermissionService.instance.checkAllPermissions();
      final missing = permissions.values
          .where((p) => p.needsAction && p.permission == AppPermission.location)
          .toList();
      
      // ✅ Utiliser _safeSetState
      _safeSetState(() {
        _missingPermissions = missing;
      });
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification permissions: $e');
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
    if (_isDisposed) return;
    
    try {
      final state = context.routeParametersBloc.state;
      final validation = RouteParametersValidator.validate(state.parameters);
      
      _safeSetState(() {
        _currentValidation = validation;
      });
      
      if (!validation.isValid && !_isDisposed) {
        _validationAnimationController.forward();
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur validation initiale: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    
    // Arrêter toutes les animations en cours
    _validationAnimationController.stop();
    _validationAnimationController.dispose();
    
    // Nettoyer les variables
    _currentValidation = null;
    _missingPermissions.clear();
    
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  void _handleParametersChanged(BuildContext context, RouteParametersState state) {
    if (_isDisposed) return;
    
    try {
      // Validation en temps réel
      final validation = RouteParametersValidator.validate(state.parameters);
      
      if (validation != _currentValidation) {
        _safeSetState(() {
          _currentValidation = validation;
        });
        
        if (!validation.isValid && !_isDisposed) {
          _validationAnimationController.forward();
          HapticFeedback.lightImpact();
        } else if (!_isDisposed) {
          _validationAnimationController.reverse();
        }
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur gestion changement paramètres: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

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
          // ✅ Optimiser les rebuilds pour la validation
          buildWhen: (previous, current) {
            if (_isDisposed) return false;
            return previous.parameters != current.parameters ||
                previous.validationResult != current.validationResult ||
                previous.errorMessage != current.errorMessage;
          },
            
          // ✅ Écouter seulement les changements de validation
          listenWhen: (previous, current) {
            if (_isDisposed) return false;
            return previous.validationResult != current.validationResult;
          },

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
      
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.elevationRange,
                          style: context.bodySmall?.copyWith(
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                        15.h,
                        Column(
                          children: [
                            // Dénivelé minimum
                            ParameterSlider(
                              title: context.l10n.minElevation, 
                              value: state.parameters.elevationRange.min,
                              min: 0,
                              max: math.max(10, state.parameters.elevationRange.max - 10),
                              unit: "m",
                              startIcon: HugeIcons.strokeRoundedArrowDown01,
                              endIcon: HugeIcons.strokeRoundedArrowUp01,
                              onChanged: (minElevation) {
                                final newRange = state.parameters.elevationRange.copyWith(
                                  min: minElevation,
                                );
                                context.routeParametersBloc.add(ElevationRangeChanged(newRange));
                                _trackParameterChange('elevation_min', minElevation);
                              },
                              enableHapticFeedback: true,
                              hapticIntensity: HapticIntensity.light,
                              style: context.bodySmall?.copyWith(
                                color: context.adaptiveTextSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500
                              ),
                            ),
                            15.h,
                            // Dénivelé maximum
                            ParameterSlider(
                              title: context.l10n.maxElevation,
                              value: state.parameters.elevationRange.max,
                              min: math.min(
                                state.parameters.elevationRange.min + 10,
                                state.parameters.distanceKm * state.parameters.terrainType.maxElevationGain - 10,
                              ),
                              max: math.max(
                                state.parameters.elevationRange.min + 20,
                                state.parameters.distanceKm * state.parameters.terrainType.maxElevationGain,
                              ),
                              unit: "m",
                              startIcon: HugeIcons.strokeRoundedArrowUp01,
                              endIcon: HugeIcons.strokeRoundedMountain,
                              onChanged: (maxElevation) {
                                final newRange = state.parameters.elevationRange.copyWith(
                                  max: maxElevation,
                                );
                                context.routeParametersBloc.add(ElevationRangeChanged(newRange));
                                _trackParameterChange('elevation_max', maxElevation);
                              },
                              enableHapticFeedback: true,
                              hapticIntensity: HapticIntensity.light,
                              style: context.bodySmall?.copyWith(
                                color: context.adaptiveTextSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    30.h,

                    // 🆕 Niveau de difficulté
                    DifficultySelector(
                      selectedDifficulty: state.parameters.difficulty,
                      onDifficultySelected: (difficulty) {
                        context.routeParametersBloc.add(DifficultyChanged(difficulty));
                        _trackParameterChange('difficulty', difficulty.id);
                      },
                    ),

                    30.h,

                    // 🆕 Pente maximale
                    ParameterSlider(
                      title: context.l10n.maxIncline,
                      value: state.parameters.maxInclinePercent,
                      min: 3.0,
                      max: 20.0,
                      unit: "%",
                      startIcon: HugeIcons.strokeRoundedAngle01,
                      endIcon: HugeIcons.strokeRoundedMountain,
                      onChanged: (maxIncline) {
                        context.routeParametersBloc.add(MaxInclineChanged(maxIncline));
                        _trackParameterChange('max_incline', maxIncline);
                      },
                      enableHapticFeedback: true,
                      hapticIntensity: HapticIntensity.light,
                    ),

                    30.h,

                    // 🆕 Section options avancées (collapsible)
                    ExpansionTile(
                      title: Text(
                        context.l10n.advancedOptions,
                        style: context.bodySmall?.copyWith(
                          color: context.adaptiveTextPrimary,
                        ),
                      ),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 15),
                      children: [
                        _buildAdvancedOptions(state),
                      ],
                    ),
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
      child: BlocBuilder<AppDataBloc, AppDataState>(
      builder: (context, appDataState) {
          // Déterminer si on peut générer selon les données disponibles
          bool isLoadingCredits = false;
          bool canGenerate = true;
          String? errorMessage;

          // Si on est en train de charger pour la première fois
          if (!appDataState.isCreditDataLoaded && appDataState.isLoading) {
            isLoadingCredits = true;
          } else if (appDataState.lastError != null && !appDataState.hasCreditData) {
            // Erreur de chargement mais permettre quand même la génération
            canGenerate = true;
            errorMessage = 'Données non disponibles (mode déconnecté)';
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [           
              // Message d'information si nécessaire
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    errorMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),   
              
              // Bouton principal
              SquircleBtn(
                isPrimary: true,
                isLoading: isLoadingCredits,
                onTap: canGenerate ? _handleGenerate : null,
                label: context.l10n.generate,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleGenerate() async {
    try {
      LogConfig.logInfo('🔍 === GÉNÉRATION DEMANDÉE ===');
      
      // Validation des paramètres avant de continuer
      final validation = _currentValidation;
      if (validation != null && !validation.isValid) {
        LogConfig.logWarning('❌ Paramètres invalides, génération annulée');
        return;
      }
        
      // Fermer la modal des paramètres
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Attendre un peu pour que la modal se ferme proprement
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Lancer la génération normale
      widget.generateRoute();
      
      LogConfig.logInfo('✅ Génération déclenchée avec succès');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur lors du lancement de la génération: $e');
      
      // Afficher un message d'erreur à l'utilisateur si nécessaire
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du lancement: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildAdvancedOptions(RouteParametersState state) {
    return Column(
      children: [
        ParameterSlider(
          title: context.l10n.waypointsCount,
          value: state.parameters.preferredWaypoints.toDouble(),
          min: 0,
          max: 8,
          unit: context.l10n.points,
          startIcon: HugeIcons.strokeRoundedLocation01,
          endIcon: HugeIcons.strokeRoundedLocationStar01,
          onChanged: (waypoints) {
            context.routeParametersBloc.add(PreferredWaypointsChanged(waypoints.round()));
            _trackParameterChange('waypoints', waypoints.round());
          },
          enableHapticFeedback: true,
          hapticIntensity: HapticIntensity.light,
        ),
        
        30.h,
        
        SurfacePreferenceSelector(
          currentValue: state.parameters.surfacePreference,
          onValueChanged: (value) {
            context.routeParametersBloc.add(SurfacePreferenceChanged(value));
            _trackParameterChange('surface_preference', value);
          },
        ),

        30.h,
        
        SwitchListTile(
          inactiveTrackColor: context.adaptiveBorder.withValues(alpha: 0.08),
          activeColor: context.adaptivePrimary,
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.l10n.prioritizeParks,
            style: context.bodySmall?.copyWith(color: context.adaptiveTextPrimary),
          ),
          subtitle: Text(
            context.l10n.preferGreenSpaces,
            style: context.bodySmall?.copyWith(
              color: context.adaptiveTextSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          value: state.parameters.prioritizeParks,
          onChanged: (value) {
            context.routeParametersBloc.add(PrioritizeParksToggled(value));
            _trackParameterChange('prioritize_parks', value);
          },
        ),
        
        15.h,

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

        30.h,
      ],
    );
  }
}


class DifficultySelector extends StatelessWidget {
  final DifficultyLevel selectedDifficulty;
  final ValueChanged<DifficultyLevel> onDifficultySelected;

  const DifficultySelector({
    super.key,
    required this.selectedDifficulty,
    required this.onDifficultySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.difficulty,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
        15.h,
        Wrap(
          runSpacing: 8.0,
          children: DifficultyLevel.values.map((difficulty) {
            final isSelected = difficulty == selectedDifficulty;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Bounce(
                onTap: () => onDifficultySelected(difficulty),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? context.adaptivePrimary : context.adaptiveBorder.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? context.adaptivePrimary.withValues(alpha: 0.4) : Colors.transparent,
                        blurRadius: 30.0,
                        spreadRadius: 1.0,
                        offset: const Offset(0.0, 0.0),
                      ),
                    ],
                  ),
                  child: Text(
                    difficulty.label(context),
                    style: context.bodySmall?.copyWith(
                      color: isSelected ? Colors.white : context.adaptiveTextSecondary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class SurfacePreferenceSelector extends StatelessWidget {
  final double currentValue;
  final ValueChanged<double> onValueChanged;

  const SurfacePreferenceSelector({
    super.key,
    required this.currentValue,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentType = SurfaceType.fromValue(currentValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.surfacePreference,
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextPrimary,
          ),
        ),
        3.h,
        Text(
          _getDescription(context, currentType),
          style: context.bodySmall?.copyWith(
            color: context.adaptiveTextSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w500
          ),
        ),
        15.h,
        Row(
          children: SurfaceType.values.map((surface) {
            final isSelected = surface == currentType;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Bounce(
                onTap: () => onValueChanged(surface.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? context.adaptivePrimary : context.adaptiveBorder.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? context.adaptivePrimary.withValues(alpha: 0.4) : Colors.transparent,
                        blurRadius: 30.0,
                        spreadRadius: 1.0,
                        offset: const Offset(0.0, 0.0),
                      ),
                    ],
                  ),
                  child: Text(
                    surface.label(context),
                    style: context.bodySmall?.copyWith(
                      color: isSelected ? Colors.white : context.adaptiveTextSecondary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getDescription(BuildContext context, SurfaceType surface) {
    switch (surface) {
      case SurfaceType.asphalt:
        return context.l10n.asphaltSurfaceDesc;
      case SurfaceType.mixed:
        return context.l10n.mixedSurfaceDesc;
      case SurfaceType.natural:
        return context.l10n.naturalSurfaceDesc;
    }
  }
}