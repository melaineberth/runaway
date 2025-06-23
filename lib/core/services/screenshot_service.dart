// lib/core/services/screenshot_service.dart

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ScreenshotService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucketName = 'route-screenshots';
  static const Uuid _uuid = Uuid();

  /// Capture une screenshot de la carte et l'upload vers Supabase
  static Future<String?> captureAndUploadMapScreenshot({
    required GlobalKey mapKey,
    required String routeId,
    required String userId,
  }) async {
    try {
      print('📸 Début capture screenshot pour route: $routeId');

      // 1. Capturer la screenshot
      final imageBytes = await _captureWidgetScreenshot(mapKey);
      if (imageBytes == null) {
        print('❌ Impossible de capturer la screenshot');
        return null;
      }

      // 2. Upload vers Supabase Storage
      final imageUrl = await _uploadScreenshotToStorage(
        imageBytes: imageBytes,
        routeId: routeId,
        userId: userId,
      );

      if (imageUrl != null) {
        print('✅ Screenshot uploadée: $imageUrl');
      }

      return imageUrl;

    } catch (e) {
      print('❌ Erreur capture/upload screenshot: $e');
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

  /// Initialise le bucket de screenshots (à appeler au démarrage de l'app)
  static Future<void> initializeScreenshotBucket() async {
    try {
      // Vérifier si le bucket existe
      final buckets = await _supabase.storage.listBuckets();
      final bucketExists = buckets.any((bucket) => bucket.name == _bucketName);

      if (!bucketExists) {
        // Créer le bucket s'il n'existe pas
        await _supabase.storage.createBucket(
          _bucketName,
          BucketOptions(
            public: true,
            allowedMimeTypes: ['image/png', 'image/jpeg'],
            fileSizeLimit: '5242880', // 5MB max
          ),
        );
        print('✅ Bucket $_bucketName créé');
      } else {
        print('✅ Bucket $_bucketName existe déjà');
      }

    } catch (e) {
      print('❌ Erreur initialisation bucket: $e');
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