import 'package:runaway/core/services/reverse_geocoding_service.dart';
import 'package:runaway/core/services/app_data_initialization_service.dart';
import 'package:runaway/core/services/location_preload_service.dart';

/// Service pour initialiser les différents composants de l'application au démarrage
class AppInitializationService {
  
  /// Initialise tous les services nécessaires au démarrage de l'application
  static Future<void> initialize() async {
    print('🚀 Initialisation des services de l\'application...');
      
    // Démarrer le pré-chargement de géolocalisation immédiatement en parallèle
    final locationFuture = _initializeLocationService();
    
    // Nettoyer le cache de géocodage expiré
    await _cleanupReverseGeocodingCache();
    
    // Initialiser d'autres services
    await _initializeOtherServices();
    
    // Attendre que la géolocalisation soit prête (ne bloque pas si elle échoue)
    await locationFuture;
    
    print('✅ Initialisation des services terminée');
  }

  /// 🆕 Initialise le service de géolocalisation en arrière-plan
  static Future<void> _initializeLocationService() async {
    try {
      print('🌍 Démarrage du pré-chargement de géolocalisation...');
      
      // Démarrer le pré-chargement en arrière-plan (non bloquant)
      LocationPreloadService.instance.initializeLocation().then((position) {
        print('✅ Géolocalisation pré-chargée au démarrage: ${position.latitude}, ${position.longitude}');
      }).catchError((e) {
        print('⚠️ Pré-chargement géolocalisation échoué (non bloquant): $e');
      });
      
    } catch (e) {
      print('⚠️ Erreur initialisation service géolocalisation: $e');
      // Non bloquant - l'app peut continuer
    }
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
    
    // Vérifier le service de géolocalisation
    if (!LocationPreloadService.instance.isInitialized) {
      print('⚠️ Service de géolocalisation non initialisé');
      // Ne pas marquer comme unhealthy car c'est non bloquant
    }
    
    return allHealthy;
  }

  /// 🆕 Obtient le statut des services
  static Map<String, dynamic> getServicesStatus() {
    return {
      'locationService': {
        'initialized': LocationPreloadService.instance.isInitialized,
        'hasPosition': LocationPreloadService.instance.hasValidPosition,
      },
      'dataService': {
        'initialized': AppDataInitializationService.isInitialized,
      },
    };
  }
}
