import 'dart:async';
import 'package:runaway/core/services/cache_service.dart';
import 'package:runaway/features/credits/data/repositories/credits_repository.dart';
import 'package:runaway/features/route_generator/data/repositories/routes_repository.dart';
import 'package:runaway/features/activity/data/repositories/activity_repository.dart';

/// Service de synchronisation optimisé avec protection anti-race conditions
class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  SyncService._();

  final CacheService _cache = CacheService.instance;
  
  // Mutex pour éviter les race conditions
  final Map<String, Completer<void>> _syncMutex = {};
  
  // Timers pour éviter les synchronisations trop fréquentes
  final Map<String, Timer> _debounceTimers = {};
  
  // Compteurs pour les statistiques
  final Map<String, int> _syncCounts = {};
  final Map<String, DateTime> _lastSyncTimes = {};
  
  static const Duration _minSyncInterval = Duration(seconds: 3);
  static const Duration _debounceDelay = Duration(milliseconds: 500);
  
  /// Synchronise les crédits utilisateur avec protection anti-race condition
  Future<void> syncCredits({
    required CreditsRepository creditsRepository,
    bool force = false,
  }) async {
    const syncKey = 'credits_sync';
    
    // Vérifier l'intervalle minimal
    if (!force && !_canSync(syncKey)) {
      print('⏳ Synchronisation crédits ignorée (trop fréquente)');
      return;
    }
    
    // Mutex pour éviter les synchronisations simultanées
    if (_syncMutex.containsKey(syncKey)) {
      print('⏳ Synchronisation crédits déjà en cours, attente...');
      await _syncMutex[syncKey]!.future;
      return;
    }
    
    final completer = Completer<void>();
    _syncMutex[syncKey] = completer;
    
    try {
      print('🔄 Début synchronisation crédits...');
      
      // Synchronisation avec timeout
      await _syncCreditsInternal(creditsRepository).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏰ Timeout synchronisation crédits');
          throw TimeoutException('Synchronisation crédits timeout');
        },
      );
      
      _updateSyncStats(syncKey);
      print('✅ Synchronisation crédits terminée');
      
    } catch (e) {
      print('❌ Erreur synchronisation crédits: $e');
      rethrow;
    } finally {
      _syncMutex.remove(syncKey);
      completer.complete();
    }
  }

  /// Synchronise les routes avec protection anti-race condition
  Future<void> syncRoutes({
    required RoutesRepository routesRepository,
    bool force = false,
  }) async {
    const syncKey = 'routes_sync';
    
    if (!force && !_canSync(syncKey)) {
      print('⏳ Synchronisation routes ignorée (trop fréquente)');
      return;
    }
    
    if (_syncMutex.containsKey(syncKey)) {
      print('⏳ Synchronisation routes déjà en cours, attente...');
      await _syncMutex[syncKey]!.future;
      return;
    }
    
    final completer = Completer<void>();
    _syncMutex[syncKey] = completer;
    
    try {
      print('🔄 Début synchronisation routes...');
      
      await _syncRoutesInternal(routesRepository).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          print('⏰ Timeout synchronisation routes');
          throw TimeoutException('Synchronisation routes timeout');
        },
      );
      
      _updateSyncStats(syncKey);
      print('✅ Synchronisation routes terminée');
      
    } catch (e) {
      print('❌ Erreur synchronisation routes: $e');
      rethrow;
    } finally {
      _syncMutex.remove(syncKey);
      completer.complete();
    }
  }

  /// Synchronise les activités avec protection anti-race condition
  Future<void> syncActivity({
    required ActivityRepository activityRepository,
    bool force = false,
  }) async {
    const syncKey = 'activity_sync';
    
    if (!force && !_canSync(syncKey)) {
      print('⏳ Synchronisation activité ignorée (trop fréquente)');
      return;
    }
    
    if (_syncMutex.containsKey(syncKey)) {
      print('⏳ Synchronisation activité déjà en cours, attente...');
      await _syncMutex[syncKey]!.future;
      return;
    }
    
    final completer = Completer<void>();
    _syncMutex[syncKey] = completer;
    
    try {
      print('🔄 Début synchronisation activité...');
      
      await _syncActivityInternal(activityRepository).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏰ Timeout synchronisation activité');
          throw TimeoutException('Synchronisation activité timeout');
        },
      );
      
      _updateSyncStats(syncKey);
      print('✅ Synchronisation activité terminée');
      
    } catch (e) {
      print('❌ Erreur synchronisation activité: $e');
      rethrow;
    } finally {
      _syncMutex.remove(syncKey);
      completer.complete();
    }
  }

  /// Synchronisation globale avec orchestration intelligente
  Future<void> syncAll({
    required CreditsRepository creditsRepository,
    required RoutesRepository routesRepository,
    required ActivityRepository activityRepository,
    bool force = false,
  }) async {
    const syncKey = 'full_sync';
    
    if (!force && !_canSync(syncKey)) {
      print('⏳ Synchronisation globale ignorée (trop fréquente)');
      return;
    }
    
    if (_syncMutex.containsKey(syncKey)) {
      print('⏳ Synchronisation globale déjà en cours, attente...');
      await _syncMutex[syncKey]!.future;
      return;
    }
    
    final completer = Completer<void>();
    _syncMutex[syncKey] = completer;
    
    try {
      print('🔄 Début synchronisation globale...');
      
      // Synchronisation intelligente par priorité
      await _syncAllInternal(
        creditsRepository: creditsRepository,
        routesRepository: routesRepository,
        activityRepository: activityRepository,
      ).timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          print('⏰ Timeout synchronisation globale');
          throw TimeoutException('Synchronisation globale timeout');
        },
      );
      
      _updateSyncStats(syncKey);
      print('✅ Synchronisation globale terminée');
      
    } catch (e) {
      print('❌ Erreur synchronisation globale: $e');
      rethrow;
    } finally {
      _syncMutex.remove(syncKey);
      completer.complete();
    }
  }

  /// Synchronisation avec debouncing pour éviter les appels répétés
  void debouncedSync({
    required String syncType,
    required Future<void> Function() syncFunction,
    Duration? customDelay,
  }) {
    final delay = customDelay ?? _debounceDelay;
    
    _debounceTimers[syncType]?.cancel();
    _debounceTimers[syncType] = Timer(delay, () {
      syncFunction().catchError((e) {
        print('❌ Erreur synchronisation debouncée $syncType: $e');
      });
    });
  }

  /// Obtient les statistiques de synchronisation
  Map<String, dynamic> getStats() {
    return {
      'sync_counts': Map<String, int>.from(_syncCounts),
      'last_sync_times': _lastSyncTimes.map((k, v) => MapEntry(k, v.toIso8601String())),
      'active_syncs': _syncMutex.keys.toList(),
      'pending_debounced': _debounceTimers.keys.toList(),
    };
  }

  /// Annule toutes les synchronisations en cours
  void cancelAllSyncs() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    
    for (final completer in _syncMutex.values) {
      if (!completer.isCompleted) {
        completer.completeError('Synchronisation annulée');
      }
    }
    _syncMutex.clear();
    
    print('🛑 Toutes les synchronisations annulées');
  }

  // ===== MÉTHODES PRIVÉES =====

  Future<void> _syncCreditsInternal(CreditsRepository creditsRepository) async {
    try {
      final credits = await creditsRepository.getUserCredits(forceRefresh: true);
      await _cache.set('cache_user_credits', credits);
      await _cache.invalidateCreditsCache();
      
      // Invalider les données liées aux crédits
      await _cache.invalidate(pattern: 'credit_transaction');
      await _cache.invalidate(pattern: 'credit_plan');
      
    } catch (e) {
      print('❌ Erreur synchronisation interne crédits: $e');
      rethrow;
    }
  }

  Future<void> _syncRoutesInternal(RoutesRepository routesRepository) async {
    try {
      // ✅ Utiliser la bonne méthode du repository existant
      final routes = await routesRepository.getUserRoutes();
      await _cache.set('cache_saved_routes', routes);
      await _cache.invalidateRoutesCache();
      
      // Invalider les données liées aux routes
      await _cache.invalidate(pattern: 'route_generation');
      await _cache.invalidate(pattern: 'route_sync');
      
    } catch (e) {
      print('❌ Erreur synchronisation interne routes: $e');
      rethrow;
    }
  }

  Future<void> _syncActivityInternal(ActivityRepository activityRepository) async {
    try {
      // ✅ Pour les stats d'activité, on peut passer une liste vide 
      // ou récupérer depuis le cache si disponible
      final stats = await activityRepository.getActivityStats([]);
      await _cache.set('cache_activity_stats', stats);
      await _cache.invalidateActivityCache();
      
      // Invalider les données liées aux activités
      await _cache.invalidate(pattern: 'activity_session');
      
    } catch (e) {
      print('❌ Erreur synchronisation interne activité: $e');
      rethrow;
    }
  }

  Future<void> _syncAllInternal({
    required CreditsRepository creditsRepository,
    required RoutesRepository routesRepository,
    required ActivityRepository activityRepository,
  }) async {
    
    // Phase 1: Synchronisation des données critiques en parallèle
    await Future.wait([
      _syncCreditsInternal(creditsRepository),
      _syncRoutesInternal(routesRepository),
    ]);
    
    // Phase 2: Synchronisation des activités (dépend des routes)
    await _syncActivityInternal(activityRepository);
    
    // Phase 3: Nettoyage intelligent du cache
    await _cache.smartCleanup();
  }

  bool _canSync(String syncKey) {
    final lastSync = _lastSyncTimes[syncKey];
    if (lastSync == null) return true;
    
    return DateTime.now().difference(lastSync) >= _minSyncInterval;
  }

  void _updateSyncStats(String syncKey) {
    _syncCounts[syncKey] = (_syncCounts[syncKey] ?? 0) + 1;
    _lastSyncTimes[syncKey] = DateTime.now();
  }

  /// Dispose le service
  void dispose() {
    cancelAllSyncs();
    print('🧹 SyncService disposé');
  }
}

/// Exception pour les timeouts de synchronisation
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
}