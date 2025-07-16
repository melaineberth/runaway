import 'dart:convert'; // 🆕 Import manquant pour jsonEncode
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/core/styles/colors.dart';
import 'package:runaway/features/home/data/services/map_state_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScreenshotService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucketName = 'route-screenshots';

  /// 🆕 Capture la carte Mapbox avec le parcours et l'upload vers Supabase
  static Future<String?> captureAndUploadMapSnapshot({
    required MapboxMap liveMap,
    required List<List<double>> routeCoords,
    required String routeId,
    required String userId,
    MapStateService? mapStateService, // 🆕 Paramètre optionnel pour récupérer le style
  }) async {
    try {
      print('🚀 Début capture screenshot pour route: $routeId');

      // 1. Vérifier que les coordonnées sont valides
      if (routeCoords.isEmpty) {
        print('❌ Aucune coordonnée de parcours fournie');
        return null;
      }

      // 2. Obtenir l'utilisateur connecté pour l'ID
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ Utilisateur non connecté');
        return null;
      }
      final realUserId = user.id;

      // 3. Récupérer l'état actuel de la caméra
      final cameraState = await liveMap.getCameraState();
      print('📍 Position caméra: ${cameraState.center.coordinates.lat}, ${cameraState.center.coordinates.lng}');
      
      // Dimensions optimisées pour les cartes (ratio 16:9)
      const double targetWidth = 800;
      const double targetHeight = 600;
      
      final snapshotter = await Snapshotter.create(
        options: MapSnapshotOptions(
          size: Size(width: targetWidth, height: targetHeight),
          pixelRatio: 2.0, // Haute qualité
        ),
      );

      try {
        // 🆕 5. Configurer le style dynamiquement selon le style actuel
        String styleUri;
        if (mapStateService != null) {
          styleUri = mapStateService.getCurrentStyleUri();
          print('🎨 Utilisation du style actuel: $styleUri');
        } else {
          // 🆕 Fallback : récupérer le style directement depuis la map live
          try {
            final currentStyleUri = await liveMap.style.getStyleURI();
            styleUri = currentStyleUri;
            print('🎨 Style récupéré depuis la map live: $styleUri');
          } catch (e) {
            // 🆕 Dernier fallback : style par défaut
            styleUri = 'mapbox://styles/mapbox/outdoors-v12';
            print('⚠️ Utilisation du style par défaut: $styleUri');
          }
        }

        // 5. Configurer le style (theme sombre pour correspondre à l'app)
        await snapshotter.style.setStyleURI(styleUri);
                
        // 6. Calculer les bounds du parcours pour centrer la vue
        final bounds = _calculateRouteBounds(routeCoords);
        
        // 7. Configurer la caméra pour englober tout le parcours
        final cameraOptions = CameraOptions(
          center: Point(coordinates: Position(bounds.centerLng, bounds.centerLat)),
          zoom: _calculateOptimalZoom(bounds, targetWidth, targetHeight),
          bearing: 0.0,
          pitch: 0.0,
        );
        
        await snapshotter.setCamera(cameraOptions);
        print('📷 Caméra configurée - Centre: ${bounds.centerLat}, ${bounds.centerLng}');

        // 8. Ajouter la polyligne du parcours
        await _addRouteToSnapshot(snapshotter, routeCoords);

        // 9. Attendre que le rendu soit prêt
        await Future.delayed(Duration(milliseconds: 800));

        // 10. Capturer l'image
        print('📸 Capture en cours...');
        final rawImageBytes = await snapshotter.start();
        
        if (rawImageBytes == null || rawImageBytes.isEmpty) {
          print('❌ Image capturée vide');
          return null;
        }

        // 🆕 Post-traitement pour enlever le logo Mapbox (optionnel)
        final processedImageBytes = await _removeMapboxLogo(rawImageBytes);
        final imageBytes = processedImageBytes ?? rawImageBytes;

        print('✅ Image capturée: ${imageBytes.length} bytes');

        // 11. Upload vers Supabase Storage
        final imageUrl = await _uploadScreenshotToStorage(
          imageBytes: imageBytes,
          routeId: routeId,
          userId: realUserId,
        );

        print('✅ Screenshot uploadé avec succès: $imageUrl');
        return imageUrl;

      } finally {
        // Nettoyer le snapshotter
        await snapshotter.dispose();
      }

    } catch (e, stackTrace) {
      print('❌ Erreur capture screenshot: $e');
      print('📜 Stack trace: $stackTrace');
      return null;
    }
  }

  /// 🔧 Ajoute la polyligne du parcours au snapshotter - CORRIGÉ
  static Future<void> _addRouteToSnapshot(
    Snapshotter snapshotter,
    List<List<double>> routeCoords,
  ) async {
    try {
      // Créer le GeoJSON pour la polyligne
      final geoJsonMap = {
        "type": "Feature",
        "properties": {},
        "geometry": {
          "type": "LineString",
          "coordinates": routeCoords,
        }
      };

      // 🔧 FIX: Utiliser jsonEncode au lieu de .toString()
      final geoJsonString = jsonEncode(geoJsonMap);
      print('📍 GeoJSON créé: ${geoJsonString.substring(0, 100)}...');

      // Ajouter la source GeoJSON
      await snapshotter.style.addSource(
        GeoJsonSource(
          id: 'route-source',
          data: geoJsonString, // 🔧 Maintenant c'est du JSON valide
        ),
      );

      // Ajouter la couche de ligne avec le style de l'app
      await snapshotter.style.addLayer(
        LineLayer(
          id: "route-layer",
          sourceId: "route-source",
          lineColor: AppColors.primary.toARGB32(), // Couleur primaire de l'app
          lineWidth: 5.0, // Ligne épaisse pour la visibilité
          lineOpacity: 0.9,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );

      // Ajouter des points de début et fin
      if (routeCoords.length >= 2) {
        await _addStartEndMarkers(snapshotter, routeCoords);
      }

      print('✅ Parcours ajouté au snapshot');

    } catch (e) {
      print('❌ Erreur ajout parcours: $e');
      rethrow;
    }
  }

  /// 🔧 Ajoute les marqueurs de début et fin - CORRIGÉ
  static Future<void> _addStartEndMarkers(
    Snapshotter snapshotter,
    List<List<double>> routeCoords,
  ) async {
    try {
      final startPoint = routeCoords.first;
      final endPoint = routeCoords.last;

      // Source pour les marqueurs
      final markersGeoJsonMap = {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"type": "start"},
            "geometry": {
              "type": "Point",
              "coordinates": startPoint,
            }
          },
          {
            "type": "Feature",
            "properties": {"type": "end"},
            "geometry": {
              "type": "Point",
              "coordinates": endPoint,
            }
          }
        ]
      };

      // 🔧 FIX: Utiliser jsonEncode au lieu de .toString()
      final markersGeoJsonString = jsonEncode(markersGeoJsonMap);
      print('🎯 Marqueurs GeoJSON créé');

      await snapshotter.style.addSource(
        GeoJsonSource(
          id: 'markers-source',
          data: markersGeoJsonString, // 🔧 Maintenant c'est du JSON valide
        ),
      );

      // Marqueur de début (vert)
      await snapshotter.style.addLayer(
        CircleLayer(
          id: "start-marker",
          sourceId: "markers-source",
          circleColor: Colors.green.toARGB32(),
          circleRadius: 8.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.toARGB32(),
          filter: ["==", ["get", "type"], "start"],
        ),
      );

      // Marqueur de fin (rouge)
      await snapshotter.style.addLayer(
        CircleLayer(
          id: "end-marker",
          sourceId: "markers-source",
          circleColor: Colors.red.toARGB32(),
          circleRadius: 8.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.toARGB32(),
          filter: ["==", ["get", "type"], "end"],
        ),
      );

      print('✅ Marqueurs début/fin ajoutés');

    } catch (e) {
      print('❌ Erreur ajout marqueurs: $e');
      // Ne pas faire échouer toute la capture pour les marqueurs
    }
  }

  /// Calcule les bounds d'un parcours
  static _RouteBounds _calculateRouteBounds(List<List<double>> routeCoords) {
    if (routeCoords.isEmpty) {
      return _RouteBounds(0, 0, 0, 0);
    }

    double minLat = routeCoords.first[1];
    double maxLat = routeCoords.first[1];
    double minLng = routeCoords.first[0];
    double maxLng = routeCoords.first[0];

    for (final coord in routeCoords) {
      final lng = coord[0];
      final lat = coord[1];
      
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    return _RouteBounds(minLat, maxLat, minLng, maxLng);
  }

  /// Calcule le zoom optimal pour englober le parcours
  static double _calculateOptimalZoom(_RouteBounds bounds, double width, double height) {
    const double padding = 0.1; // 10% de padding
    
    final latDiff = (bounds.maxLat - bounds.minLat) * (1 + padding);
    final lngDiff = (bounds.maxLng - bounds.minLng) * (1 + padding);
    
    // Formule approximative pour le calcul du zoom Mapbox
    final latZoom = math.log(360 / latDiff) / math.ln2;
    final lngZoom = math.log(360 / lngDiff) / math.ln2;
    
    // Prendre le zoom minimum pour que tout soit visible
    final optimalZoom = math.min(latZoom, lngZoom).clamp(8.0, 16.0);
    
    print('📏 Zoom optimal calculé: $optimalZoom');
    return optimalZoom;
  }

  /// Upload l'image vers Supabase Storage
  static Future<String?> _uploadScreenshotToStorage({
    required Uint8List imageBytes,
    required String routeId,
    required String userId,
  }) async {
    try {
      // Générer un nom de fichier unique
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'route_${routeId}_$timestamp.png';
      final filePath = '$userId/$fileName';

      print('📤 Upload vers Storage: $filePath (${imageBytes.length} bytes)');

      // Upload vers le bucket
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Obtenir l'URL publique
      final publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(filePath);

      print('✅ Screenshot uploadé avec succès: $publicUrl');
      return publicUrl;

    } catch (e) {
      print('❌ Erreur upload screenshot: $e');
      return null;
    }
  }

  /// Supprime une screenshot du storage
  static Future<bool> deleteScreenshot(String imageUrl) async {
    try {
      // Extraire le chemin du fichier depuis l'URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // Le chemin dans le storage est après 'object/public/route-screenshots/'
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        print('❌ Impossible d\'extraire le chemin du fichier depuis l\'URL');
        return false;
      }

      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      
      await _supabase.storage
          .from(_bucketName)
          .remove([filePath]);
      
      print('✅ Screenshot supprimée: $filePath');
      return true;

    } catch (e) {
      print('❌ Erreur suppression screenshot: $e');
      return false;
    }
  }

  /// Génère une URL de placeholder pour les routes sans screenshot
  static String getPlaceholderImageUrl(String activityType) {
    // Retourner une URL d'image de placeholder basée sur l'activité
    switch (activityType.toLowerCase()) {
      case 'running':
        return 'https://images.unsplash.com/photo-1544717297-fa95b6ee9643?w=400&h=300&fit=crop';
      case 'cycling':
        return 'https://images.unsplash.com/photo-1558618047-b93c99c64c3a?w=400&h=300&fit=crop';
      case 'walking':
        return 'https://images.unsplash.com/photo-1511593358241-7eea1f3c84e5?w=400&h=300&fit=crop';
      default:
        return 'https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=400&h=300&fit=crop';
    }
  }

  /// 🆕 Enlève le logo Mapbox par recadrage de l'image
  static Future<Uint8List?> _removeMapboxLogo(Uint8List imageBytes) async {
    try {
      // Décoder l'image
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;
      
      // Dimensions originales
      final originalWidth = originalImage.width;
      final originalHeight = originalImage.height;
      
      // Zone à recadrer (enlever ~80px en bas pour le logo/attributions)
      const cropBottomPixels = 50;
      final newHeight = originalHeight - cropBottomPixels;
      
      if (newHeight <= 0) {
        print('⚠️ Image trop petite pour recadrage');
        return null;
      }
      
      // Créer une nouvelle image recadrée
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Dessiner la partie de l'image sans le logo
      canvas.drawImageRect(
        originalImage,
        Rect.fromLTWH(0, 0, originalWidth.toDouble(), newHeight.toDouble()),
        Rect.fromLTWH(0, 0, originalWidth.toDouble(), newHeight.toDouble()),
        Paint(),
      );
      
      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(originalWidth, newHeight);
      
      // Convertir en bytes PNG
      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      
      final croppedBytes = byteData.buffer.asUint8List();
      
      // Nettoyer les ressources
      originalImage.dispose();
      croppedImage.dispose();
      
      print('✅ Logo Mapbox retiré par recadrage ($originalHeight -> ${newHeight}px)');
      return croppedBytes;
      
    } catch (e) {
      print('❌ Erreur recadrage image: $e');
      return null;
    }
  }
}

/// Classe helper pour les bounds d'un parcours
class _RouteBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  _RouteBounds(this.minLat, this.maxLat, this.minLng, this.maxLng);

  double get centerLat => (minLat + maxLat) / 2;
  double get centerLng => (minLng + maxLng) / 2;
}