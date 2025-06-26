import 'dart:async';

import 'package:runaway/core/services/reverse_geocoding_service.dart';
import 'package:runaway/core/services/location_preload_service.dart';

/// Service pour initialiser les différents composants de l'application au démarrage
class AppInitializationService {
  
  /// Initialise tous les services nécessaires au démarrage de l'application
  static Future<void> initialize() async {
    print('🚀 === INITIALISATION RAPIDE DE L\'APPLICATION ===');
      
    // 🌍 PRIORITÉ ABSOLUE: Démarrer la géolocalisation en premier
    final locationFuture = _initializeLocationServiceImmediate();
    
    // Autres services en parallèle (non bloquants)
    final otherServicesFutures = [
      _cleanupReverseGeocodingCache(),
      _initializeOtherServices(),
    ];
    
    // Attendre les services non critiques
    await Future.wait(otherServicesFutures);
    
    // Vérifier l'état de la géolocalisation (sans bloquer)
    _checkLocationInitializationStatus(locationFuture);
    
    print('✅ Initialisation de l\'application terminée');
  }

  /// 🚀 Initialise la géolocalisation immédiatement et en arrière-plan
  static Future<void> _initializeLocationServiceImmediate() async {
    print('🌍 Démarrage IMMÉDIAT du pré-chargement géolocalisation...');
    
    // Fire-and-forget: démarrer le processus immédiatement
    LocationPreloadService.instance.initializeLocation().then((position) {
      print('✅ 🎯 Géolocalisation pré-chargée avec succès: ${position.latitude}, ${position.longitude}');
    }).catchError((e) {
      print('⚠️ Pré-chargement géolocalisation échoué (non bloquant): $e');
      // Ne pas bloquer l'app, l'utilisateur aura juste un loader un peu plus long
    });
  }

  /// 🔍 Vérifie l'état de l'initialisation géolocalisation sans bloquer
  static void _checkLocationInitializationStatus(Future<void> locationFuture) {
    // Vérification après 2 secondes pour voir si c'est prêt
    Timer(Duration(seconds: 2), () {
      if (LocationPreloadService.instance.hasValidPosition) {
        print('🎉 Géolocalisation prête en 2s - UX optimale !');
      } else {
        print('⏳ Géolocalisation encore en cours après 2s');
      }
    });
  }

  /// Initialise le pré-chargement des données une fois l'authentification prête
  static Future<void> initializeDataPreloading() async {
    print('📊 Initialisation du système de pré-chargement...');
    
    // Le pré-chargement sera déclenché automatiquement 
    // quand l'utilisateur s'authentifie via l'AuthListener
    
    print('✅ Système de pré-chargement prêt');
  }
    
  /// Nettoie le cache de reverse geocoding (non bloquant)
  static Future<void> _cleanupReverseGeocodingCache() async {
    try {
      await ReverseGeocodingService.cleanExpiredCache();
      print('✅ Cache de géocodage nettoyé');
    } catch (e) {
      print('❌ Erreur nettoyage cache géocodage: $e');
      // Non bloquant, l'app peut continuer
    }
  }

  /// Initialise d'autres services nécessaires (non bloquants)
  static Future<void> _initializeOtherServices() async {
    // Placeholder pour d'autres initialisations futures
    // Ex: services de notification, analytics, etc.
    
    // Exemple d'initialisation non bloquante:
    // await AnalyticsService.initialize().catchError((e) {
    //   print('⚠️ Analytics init failed: $e');
    // });
    
    print('✅ Autres services initialisés');
  }
}
