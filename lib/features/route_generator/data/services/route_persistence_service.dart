// lib/features/route_generator/data/services/route_persistence_service.dart

import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runaway/features/route_generator/domain/models/saved_route.dart';
import 'package:runaway/features/route_generator/data/services/route_cache.dart';

/// Service de persistance avancée pour les parcours
class RoutePersistenceService {
  static RoutePersistenceService? _instance;
  static RoutePersistenceService get instance => _instance ??= RoutePersistenceService._();
  RoutePersistenceService._();

  final RouteCache _cache = RouteCache.instance;
  
  // Configuration de la persistance
  static const int maxBackupVersions = 3;
  static const Duration backupInterval = Duration(hours: 6);
  static const String backupPrefix = 'route_backup_';

  /// Sauvegarde de sécurité des routes critiques
  Future<void> createSecurityBackup(List<SavedRoute> routes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Données de sauvegarde avec métadonnées
      final backupData = {
        'version': '1.0',
        'timestamp': timestamp,
        'routes_count': routes.length,
        'routes': routes.map((r) => r.toJson()).toList(),
        'checksum': _calculateChecksum(routes),
      };
      
      final backupKey = '$backupPrefix$timestamp';
      await prefs.setString(backupKey, jsonEncode(backupData));
      
      // Nettoyer les anciennes sauvegardes
      await _cleanupOldBackups();
      
      print('🛡️ Sauvegarde de sécurité créée: ${routes.length} routes');
      
    } catch (e) {
      print('❌ Erreur création backup: $e');
    }
  }

  /// Restaure depuis la sauvegarde la plus récente
  Future<List<SavedRoute>?> restoreFromLatestBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupKeys = _getBackupKeys(prefs);
      
      if (backupKeys.isEmpty) {
        print('📭 Aucune sauvegarde trouvée');
        return null;
      }
      
      // Trier par timestamp pour obtenir la plus récente
      backupKeys.sort((a, b) => b.compareTo(a));
      
      for (final key in backupKeys) {
        try {
          final backupJson = prefs.getString(key);
          if (backupJson == null) continue;
          
          final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
          final routesList = backupData['routes'] as List;
          final routes = routesList.map((json) => SavedRoute.fromJson(json)).toList();
          
          // Vérifier l'intégrité
          final expectedChecksum = backupData['checksum'] as String;
          final actualChecksum = _calculateChecksum(routes);
          
          if (expectedChecksum == actualChecksum) {
            print('✅ Restauration réussie: ${routes.length} routes');
            return routes;
          } else {
            print('⚠️ Checksum invalide pour $key, tentative suivante...');
          }
          
        } catch (e) {
          print('❌ Erreur lecture backup $key: $e');
          continue;
        }
      }
      
      print('❌ Aucune sauvegarde valide trouvée');
      return null;
      
    } catch (e) {
      print('❌ Erreur restauration backup: $e');
      return null;
    }
  }

  /// Compresse les données pour économiser l'espace
  Future<void> compressOldRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: 30));
      
      // Récupérer toutes les routes en cache
      final routeKeys = prefs.getKeys().where((key) => key.startsWith('route_')).toList();
      final compressedRoutes = <String, dynamic>{};
      
      for (final key in routeKeys) {
        try {
          final routeData = await _cache.getRoute(key.replaceFirst('route_', ''));
          if (routeData != null && routeData.createdAt.isBefore(cutoffDate)) {
            // Compression: garder seulement les métadonnées essentielles
            compressedRoutes[key] = {
              'id': routeData.id,
              'name': routeData.name,
              'distance': routeData.parameters.distanceKm,
              'activity': routeData.parameters.activityType.id,
              'created_at': routeData.createdAt.toIso8601String(),
              'times_used': routeData.timesUsed,
              'compressed': true,
            };
            
            // Supprimer la version complète
            await _cache.removeRoute(routeData.id);
          }
        } catch (e) {
          print('❌ Erreur compression route $key: $e');
        }
      }
      
      if (compressedRoutes.isNotEmpty) {
        await prefs.setString('compressed_routes', jsonEncode(compressedRoutes));
        print('🗜️ ${compressedRoutes.length} routes anciennes compressées');
      }
      
    } catch (e) {
      print('❌ Erreur compression: $e');
    }
  }

  /// Migration intelligente des données
  Future<void> migrateDataFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final version = prefs.getString('data_version') ?? '1.0';
      
      if (version == '1.0') {
        print('🔄 Migration vers format v1.1...');
        
        // Exemple de migration : ajouter des champs manquants
        await _migrateToV11();
        await prefs.setString('data_version', '1.1');
        
        print('✅ Migration vers v1.1 terminée');
      }
      
    } catch (e) {
      print('❌ Erreur migration: $e');
    }
  }

  /// Validation d'intégrité des données
  Future<PersistenceIntegrityReport> validateDataIntegrity() async {
    final report = PersistenceIntegrityReport();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Vérifier les routes en cache
      await _validateCacheIntegrity(report);
      
      // 2. Vérifier les sauvegardes
      await _validateBackupIntegrity(report, prefs);
      
      // 3. Vérifier la cohérence entre caches
      await _validateCacheConsistency(report);
      
      print('🔍 Validation d\'intégrité terminée: ${report.toString()}');
      
    } catch (e) {
      report.errors.add('Erreur validation: $e');
      print('❌ Erreur validation intégrité: $e');
    }
    
    return report;
  }

  /// Optimisation en arrière-plan dans un isolate
  Future<void> performBackgroundOptimization() async {
    if (!kIsWeb) { // Les isolates ne sont pas disponibles sur le web
      try {
        final receivePort = ReceivePort();
        
        await Isolate.spawn(
          _backgroundOptimizationIsolate,
          receivePort.sendPort,
        );
        
        final result = await receivePort.first;
        print('🚀 Optimisation en arrière-plan terminée: $result');
        
      } catch (e) {
        print('❌ Erreur optimisation background: $e');
        // Fallback vers optimisation synchrone
        await _performSynchronousOptimization();
      }
    } else {
      await _performSynchronousOptimization();
    }
  }

  // === MÉTHODES PRIVÉES ===

  List<String> _getBackupKeys(SharedPreferences prefs) {
    return prefs.getKeys()
        .where((key) => key.startsWith(backupPrefix))
        .toList();
  }

  Future<void> _cleanupOldBackups() async {
    final prefs = await SharedPreferences.getInstance();
    final backupKeys = _getBackupKeys(prefs);
    
    if (backupKeys.length > maxBackupVersions) {
      // Trier par timestamp et supprimer les plus anciennes
      backupKeys.sort();
      final toRemove = backupKeys.take(backupKeys.length - maxBackupVersions);
      
      for (final key in toRemove) {
        await prefs.remove(key);
      }
      
      print('🧹 ${toRemove.length} anciennes sauvegardes supprimées');
    }
  }

  String _calculateChecksum(List<SavedRoute> routes) {
    final concatenated = routes.map((r) => '${r.id}${r.name}${r.createdAt}').join();
    return concatenated.hashCode.toString();
  }

  Future<void> _migrateToV11() async {
    // Exemple de migration : ajouter des champs pour la v1.1
    final prefs = await SharedPreferences.getInstance();
    final routeKeys = prefs.getKeys().where((key) => key.startsWith('route_')).toList();
    
    for (final key in routeKeys) {
      try {
        final routeJson = prefs.getString(key);
        if (routeJson != null) {
          final data = jsonDecode(routeJson) as Map<String, dynamic>;
          
          // Ajouter des champs manquants si nécessaire
          if (!data.containsKey('migration_version')) {
            data['migration_version'] = '1.1';
            await prefs.setString(key, jsonEncode(data));
          }
        }
      } catch (e) {
        print('❌ Erreur migration route $key: $e');
      }
    }
  }

  Future<void> _validateCacheIntegrity(PersistenceIntegrityReport report) async {
    try {
      final stats = await _cache.getCacheStats();
      report.totalRoutesInCache = stats.totalRoutes;
      report.cacheSizeBytes = stats.totalSizeBytes;
      
      if (stats.totalRoutes == 0) {
        report.warnings.add('Cache vide');
      }
      
    } catch (e) {
      report.errors.add('Erreur validation cache: $e');
    }
  }

  Future<void> _validateBackupIntegrity(PersistenceIntegrityReport report, SharedPreferences prefs) async {
    final backupKeys = _getBackupKeys(prefs);
    report.backupCount = backupKeys.length;
    
    for (final key in backupKeys) {
      try {
        final backupJson = prefs.getString(key);
        if (backupJson != null) {
          final data = jsonDecode(backupJson);
          report.totalRoutesInBackups += (data['routes_count'] ?? 0) as int;
        }
      } catch (e) {
        report.errors.add('Backup corrompu: $key');
      }
    }
  }

  Future<void> _validateCacheConsistency(PersistenceIntegrityReport report) async {
    // Vérifier la cohérence entre différents niveaux de cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final fastCacheJson = prefs.getString('fast_cache_routes');
      final localCacheJson = prefs.getString('cached_user_routes');
      
      if (fastCacheJson != null && localCacheJson != null) {
        final fastCache = jsonDecode(fastCacheJson)['routes'] as List;
        final localCache = jsonDecode(localCacheJson) as List;
        
        if (fastCache.length != localCache.length) {
          report.warnings.add('Incohérence entre caches rapide et local');
        }
      }
    } catch (e) {
      report.errors.add('Erreur vérification cohérence: $e');
    }
  }

  static void _backgroundOptimizationIsolate(SendPort sendPort) {
    // Optimisations lourdes en arrière-plan
    try {
      // Simulation d'optimisations coûteuses
      // Dans la vraie implémentation, on ferait du nettoyage de cache, etc.
      Future.delayed(Duration(seconds: 2), () {
        sendPort.send('Optimisation terminée');
      });
    } catch (e) {
      sendPort.send('Erreur: $e');
    }
  }

  Future<void> _performSynchronousOptimization() async {
    // Optimisation synchrone (fallback)
    await _cache.cleanupExpiredCache();
    await compressOldRoutes();
    print('🔧 Optimisation synchrone terminée');
  }
}

/// Rapport d'intégrité des données
class PersistenceIntegrityReport {
  int totalRoutesInCache = 0;
  int totalRoutesInBackups = 0;
  int cacheSizeBytes = 0;
  int backupCount = 0;
  final List<String> errors = [];
  final List<String> warnings = [];

  bool get isHealthy => errors.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  @override
  String toString() {
    return 'IntegrityReport(cache: $totalRoutesInCache routes, '
           'backups: $backupCount, errors: ${errors.length}, warnings: ${warnings.length})';
  }
}