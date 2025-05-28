import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:runaway/config/router.dart';
import 'package:runaway/config/theme.dart';

import 'core/blocs/app_bloc_observer.dart';
import 'features/home/presentation/blocs/map_style/map_style_bloc.dart';
import 'features/home/presentation/blocs/route_parameters/route_parameters_bloc.dart';
import 'features/route_generator/presentation/blocs/route_generation/route_generation_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser HydratedBloc pour la persistance
  final directory = await getApplicationDocumentsDirectory();

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(directory.path),
  );

  // Observer pour debug
  Bloc.observer = AppBlocObserver();

  await dotenv.load(fileName: ".env");

  // Pass your access token to MapboxOptions so you can load a map
  String mapBoxToken = dotenv.get('MAPBOX_TOKEN');
  MapboxOptions.setAccessToken(mapBoxToken);

  runApp(const RunAway());
}

class RunAway extends StatelessWidget {
  const RunAway({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => MapStyleBloc(),
        ),
        BlocProvider(
          create: (_) => RouteParametersBloc(
            startLongitude: 0.0, // Sera mis à jour avec la position réelle
            startLatitude: 0.0,
          ),
        ),
        BlocProvider(
          create: (_) => RouteGenerationBloc(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Générateur de Parcours',
        debugShowCheckedModeBanner: false,
        routerConfig: router, // <- Intégration ici
        theme: getAppTheme(Brightness.light),
        darkTheme: getAppTheme(Brightness.dark),
        themeMode: ThemeMode.system, // ou ThemeMode.dark pour forcer
      ),
    );
  }
}
