import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/features/home/presentation/widgets/maps_styles_selector.dart';

import '../blocs/map_style/map_style_bloc.dart';
import '../blocs/map_style/map_style_event.dart';
import '../blocs/map_style/map_style_state.dart';

class MapsStylesScreen extends StatefulWidget {
  const MapsStylesScreen({super.key});

  @override
  State<MapsStylesScreen> createState() => _MapsStylesScreenState();
}

class _MapsStylesScreenState extends State<MapsStylesScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapStyleBloc, MapStyleState>(
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MapsStylesSelector(
              selectedStyle: state.style,
              onStyleSelected: (style) {
                context.read<MapStyleBloc>().add(MapStyleChanged(style));
              },
            ),
          ],
        );
      },
    );
  }
}