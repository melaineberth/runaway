import 'package:mockito/annotations.dart';
import 'package:runaway/core/helper/services/connectivity_service.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/features/credits/data/services/credit_verification_service.dart';
import 'package:runaway/core/blocs/app_data/app_data_bloc.dart';
import 'package:runaway/features/route_generator/data/services/graphhopper_api_service.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:runaway/features/route_generator/data/services/screenshot_service.dart';

// Annotation pour générer les mocks
@GenerateMocks([
  RoutesRepository,
  CreditVerificationService,
  AppDataBloc,
  GraphHopperApiService,
  FlutterSecureStorage,
  mp.MapboxMap,
  ConnectivityService,
  ScreenshotService,
])
void main() {
  // Ce fichier est utilisé uniquement pour la génération de mocks
  // Exécuter: dart run build_runner build --delete-conflicting-outputs
}