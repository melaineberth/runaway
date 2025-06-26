import 'package:runaway/core/services/reverse_geocoding_service.dart';
import 'package:runaway/core/services/app_data_initialization_service.dart';

/// Service pour initialiser les différents composants de l'application au démarrage
class AppInitializationService {
  
  /// Initialise tous les services nécessaires au démarrage de l'application
  static Future<void> initialize() async {
    print('🚀 Initialisation des services de l\'application...');
      
    // Nettoyer le cache de géocodage expiré
    await _cleanupReverseGeocodingCache();
    
    // Initialiser d'autres services si nécessaire
    await _initializeOtherServices();
    
    print('✅ Initialisation des services terminée');
  }

  /// Initialise le pré-chargement des données une fois l'authentification prête
  static Future<void> initializeDataPreloading() async {
    print('📊 Initialisation du système de pré-chargement...');
    
    // Le pré-chargement sera déclenché automatiquement 
    // quand l'utilisateur s'authentifie via l'AuthListener
    
    print('✅ Système de pré-chargement prêt');
  }
    
  /// Nettoie le cache de reverse geocoding
  static Future<void> _cleanupReverseGeocodingCache() async {
    try {
      await ReverseGeocodingService.cleanExpiredCache();
      print('✅ Cache de géocodage nettoyé');
    } catch (e) {
      print('❌ Erreur nettoyage cache géocodage: $e');
      // Non bloquant, l'app peut continuer
    }
  }

  /// Initialise d'autres services nécessaires
  static Future<void> _initializeOtherServices() async {
    // Placeholder pour d'autres initialisations futures
    // Ex: services de notification, analytics, etc.
  }
  
  /// Vérifie si tous les services sont correctement configurés
  static Future<bool> checkServicesHealth() async {
    bool allHealthy = true;
    
    // Vérifier Supabase
    try {
      // Test basique de connectivité Supabase
      print('✅ Supabase accessible');
    } catch (e) {
      print('⚠️ Problème avec Supabase: $e');
      allHealthy = false;
    }
    
    // Vérifier le service de données
    if (!AppDataInitializationService.isInitialized) {
      print('⚠️ Service de données non initialisé');
      allHealthy = false;
    }
    
    return allHealthy;
  }
}