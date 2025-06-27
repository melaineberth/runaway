import 'dart:async';
import 'package:flutter/foundation.dart';

/// Utilitaires pour optimiser les performances du cache
class CachePerformanceUtils {
  static const Duration _debounceInterval = Duration(milliseconds: 250);
  static final Map<String, Timer> _activeTimers = {};
  static final Map<String, Completer<void>> _pendingOperations = {};

  /// Debounce pour éviter les appels trop fréquents
  static void debounce(
    String key,
    VoidCallback callback, {
    Duration? delay,
  }) {
    // Annuler le timer précédent s'il existe
    _activeTimers[key]?.cancel();
    
    // Créer un nouveau timer
    _activeTimers[key] = Timer(delay ?? _debounceInterval, () {
      callback();
      _activeTimers.remove(key);
    });
  }

  /// Évite les opérations simultanées pour la même clé
  static Future<T> singleOperation<T>(
    String key,
    Future<T> Function() operation,
  ) async {
    // Si une opération est déjà en cours, attendre qu'elle se termine
    if (_pendingOperations.containsKey(key)) {
      await _pendingOperations[key]!.future;
      throw Exception('Operation already in progress for key: $key');
    }

    // Créer un nouveau completer pour cette opération
    final completer = Completer<void>();
    _pendingOperations[key] = completer;

    try {
      final result = await operation();
      completer.complete();
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingOperations.remove(key);
    }
  }

  /// Nettoie tous les timers actifs
  static void cleanup() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    
    for (final completer in _pendingOperations.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _pendingOperations.clear();
  }
}
