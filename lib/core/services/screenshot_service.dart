import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:runaway/config/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScreenshotService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucketName = 'route-screenshots';

/// Capture la carte (Mapbox) hors-écran et upload l’image PNG.
  static Future<String?> captureAndUploadMapSnapshot({
    required MapboxMap liveMap,               // carte affichée
    required List<List<double>> routeCoords,  // polyligne à dessiner
    required String routeId,
    required String userId,
  }) async {
    try {
      // ------------------------------------------------------------------
      // 1.  Récupérer le style + la caméra du rendu courant
      // ------------------------------------------------------------------
      final camState  = await liveMap.getCameraState();
      final camOpts   = CameraOptions(
        center  : camState.center,
        zoom    : camState.zoom,
        pitch   : camState.pitch,
        bearing : camState.bearing,
      );

      // ------------------------------------------------------------------
      // 2.  Préparer Snapshotter
      // ------------------------------------------------------------------
      final pixelRatio  = ui.window.devicePixelRatio;
      final logicalSize = ui.window.physicalSize / pixelRatio;

      final snap = await Snapshotter.create(
        options: MapSnapshotOptions(
          size: Size(width: logicalSize.width, height: logicalSize.height),
          pixelRatio: pixelRatio,
        ),
      );

      // Style + caméra identiques à la carte live
      await snap.style.setStyleURI(MapboxStyles.DARK);
      await snap.setCamera(camOpts);

      // ------------------------------------------------------------------
      // 3.  Ajouter la polyligne du parcours
      // ------------------------------------------------------------------
      final geoJson = {
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": routeCoords,
        }
      };
      await snap.style.addSource(
        GeoJsonSource(id: 'route-source', data: geoJson.toString()),
      );

      await snap.style.addLayer(
        LineLayer(
          id            : "route-layer",
          sourceId      : "route-source",
          lineColor     : AppColors.primary.toARGB32(),  // violet (réglage libre)
          lineWidth     : 4,
          lineOpacity   : 1,
        ),
      );

      // ------------------------------------------------------------------
      // 4.  Prendre la capture PNG
      // ------------------------------------------------------------------
      final Uint8List? pngBytes = await snap.start();
      await snap.dispose();

      // ------------------------------------------------------------------
      // 5.  Upload Supabase
      // ------------------------------------------------------------------
      final fileName = 'route_${routeId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '$userId/$fileName';

      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(filePath, pngBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/png',
                upsert: false,
              ));

      return _supabase.storage.from(_bucketName).getPublicUrl(filePath);
    } catch (e) {
      debugPrint('❌ Snapshot / upload error: $e');
      return null;
    }
  }

  
  /// Capture la screenshot d'un widget via sa GlobalKey
  static Future<Uint8List?> _captureWidgetScreenshot(GlobalKey key) async {
    try {
      // Attendre que le widget soit complètement rendu
      await Future.delayed(Duration(milliseconds: 500));

      final RenderRepaintBoundary? boundary = 
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        print('❌ RenderRepaintBoundary introuvable');
        return null;
      }

      // Capturer l'image avec une bonne qualité
      final ui.Image image = await boundary.toImage(
        pixelRatio: 2.0, // Haute qualité
      );

      // Convertir en bytes PNG
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        print('❌ Impossible de convertir l\'image en bytes');
        return null;
      }

      return byteData.buffer.asUint8List();

    } catch (e) {
      print('❌ Erreur capture screenshot: $e');
      return null;
    }
  }

  /// Upload la screenshot vers Supabase Storage
  static Future<String?> _uploadScreenshotToStorage({
    required Uint8List imageBytes,
    required String routeId,
    required String userId,
  }) async {
    try {
      // Générer un nom de fichier unique
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'route_${routeId}_${timestamp}.png';
      final filePath = '$userId/$fileName';

      print('📤 Upload vers Storage: $filePath');

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

      print('✅ Screenshot uploadée avec succès: $publicUrl');
      return publicUrl;

    } catch (e) {
      print('❌ Erreur upload screenshot: $e');
      
      // Essayer de supprimer le fichier en cas d'erreur partielle
      try {
        final filePath = '$userId/route_${routeId}_${DateTime.now().millisecondsSinceEpoch}.png';
        await _supabase.storage.from(_bucketName).remove([filePath]);
      } catch (cleanupError) {
        print('❌ Erreur nettoyage après échec: $cleanupError');
      }
      
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
}