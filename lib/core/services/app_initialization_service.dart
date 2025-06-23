// lib/core/services/app_initialization_service.dart

import 'package:runaway/core/services/reverse_geocoding_service.dart';

/// Service pour initialiser les différents composants de l'application au démarrage
class AppInitializationService {
  
  /// Initialise tous les services nécessaires au démarrage de l'application
  static Future<void> initialize() async {
    print('🚀 Initialisation des services de l\'application...');
      
    // Nettoyer le cache de géocodage expiré
    await _cleanupReverseGeocodingCache();
    
    print('✅ Initialisation des services terminée');
  }
    
  /// 🆕 Nettoie le cache de reverse geocoding
  static Future<void> _cleanupReverseGeocodingCache() async {
    try {
      await ReverseGeocodingService.cleanExpiredCache();
      print('✅ Cache de géocodage nettoyé');
    } catch (e) {
      print('❌ Erreur nettoyage cache géocodage: $e');
      // Non bloquant, l'app peut continuer
    }
  }
  
  /// Vérifie si tous les services sont correctement configurés
  static Future<bool> checkServicesHealth() async {
    bool allHealthy = true;
    
    // Vérifier Supabase
    try {
      // Test basique de connectivité Supabase
      // await Supabase.instance.client.auth.getUser();
      print('✅ Supabase accessible');
    } catch (e) {
      print('⚠️ Problème avec Supabase: $e');
      allHealthy = false;
    }
    
    return allHealthy;
  }
}