import 'dart:async';

import 'package:runaway/core/helper/services/lottie_preload_service.dart';
import 'package:runaway/features/route_generator/data/services/reverse_geocoding_service.dart';
import 'package:runaway/core/helper/services/location_preload_service.dart';
import 'package:runaway/core/helper/config/log_config.dart';

/// Service pour initialiser les différents composants de l'application au démarrage
class AppInitializationService {
  
  /// Initialise tous les services nécessaires au démarrage de l'application
  static Future<void> initialize() async {
    LogConfig.logInfo('🚀 === INITIALISATION RAPIDE DE L\'APPLICATION ===');
      
    // Démarrer la géolocalisation en premier
    final locationFuture = _initializeLocationServiceImmediate();

    // Précharger les animations Lottie en parallèle
    final lottieFuture = _initializeLottiePreloading();
    
    // Autres services en parallèle (non bloquants)
    final otherServicesFutures = [
      _cleanupReverseGeocodingCache(),
    ];
    
    // Attendre les services non critiques
    await Future.wait(otherServicesFutures);
    
    // Vérifier l'état de la géolocalisation (sans bloquer)
    _checkLocationInitializationStatus(locationFuture);

    // Vérifier l'état du préchargement Lottie (sans bloquer)
    _checkLottiePreloadingStatus(lottieFuture);
    
    LogConfig.logInfo('Initialisation de l\'application terminée');
  }

  /// 🚀 Initialise la géolocalisation immédiatement et en arrière-plan
  static Future<void> _initializeLocationServiceImmediate() async {
    print('🌍 Démarrage IMMÉDIAT du pré-chargement géolocalisation...');
    
    // Fire-and-forget: démarrer le processus immédiatement
    LocationPreloadService.instance.initializeLocation().then((position) {
      LogConfig.logInfo('🎯 Géolocalisation pré-chargée avec succès: ${position.latitude}, ${position.longitude}');
    }).catchError((e) {
      LogConfig.logInfo('Pré-chargement géolocalisation échoué (non bloquant): $e');
      // Ne pas bloquer l'app, l'utilisateur aura juste un loader un peu plus long
    });
  }

  /// Précharge les animations Lottie immédiatement
  static Future<void> _initializeLottiePreloading() async {
    print('🎬 Démarrage IMMÉDIAT du pré-chargement animations Lottie...');
    
    // Fire-and-forget: démarrer le processus immédiatement
    LottiePreloadService.instance.preloadAuthModalLottie().then((_) {
      LogConfig.logInfo('🎯 Animation Lottie auth modal pré-chargée avec succès');
    }).catchError((e) {
      LogConfig.logInfo('Pré-chargement animation Lottie échoué (non bloquant): $e');
      // Ne pas bloquer l'app, fallback vers le réseau
    });
  }

  /// 🔍 Vérifie l'état de l'initialisation géolocalisation sans bloquer
  static void _checkLocationInitializationStatus(Future<void> locationFuture) {
    // Vérification après 2 secondes pour voir si c'est prêt
    Timer(Duration(seconds: 2), () {
      if (LocationPreloadService.instance.hasValidPosition) {
        print('🎉 Géolocalisation prête en 2s - UX optimale !');
      } else {
        LogConfig.logInfo('⏳ Géolocalisation encore en cours après 2s');
      }
    });
  }

  /// Initialise le pré-chargement des données une fois l'authentification prête
  static Future<void> initializeDataPreloading() async {
    LogConfig.logInfo('📊 Initialisation du système de pré-chargement...');
    
    // Le pré-chargement sera déclenché automatiquement 
    // quand l'utilisateur s'authentifie via l'AuthListener
    
    LogConfig.logInfo('Système de pré-chargement prêt');
  }
    
  /// Nettoie le cache de reverse geocoding (non bloquant)
  static Future<void> _cleanupReverseGeocodingCache() async {
    try {
      await ReverseGeocodingService.cleanExpiredCache();
      LogConfig.logInfo('Cache de géocodage nettoyé');
    } catch (e) {
      LogConfig.logError('❌ Erreur nettoyage cache géocodage: $e');
      // Non bloquant, l'app peut continuer
    }
  }

  /// Vérifie l'état du préchargement Lottie sans bloquer
  static void _checkLottiePreloadingStatus(Future<void> lottieFuture) {
    // Vérification après 2 secondes pour voir si c'est prêt
    Timer(Duration(seconds: 2), () {
      if (LottiePreloadService.instance.isAuthModalLottieLoaded) {
        print('🎉 Animation Lottie prête en 2s - UX optimale !');
      } else {
        LogConfig.logInfo('⏳ Préchargement Lottie encore en cours après 2s');
      }
    });
  }
}
