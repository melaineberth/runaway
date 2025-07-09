import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gérer les limitations des utilisateurs non connectés
class GuestLimitationService {
  static const String _keyGuestGenerations = 'guest_generations_count';
  static const String _keyFirstUseDate = 'guest_first_use_date';
  static const int _maxGuestGenerations = 2; // 2 générations gratuites pour les guests
  static const Duration _limitPeriod = Duration(days: 30); // Période de 30 jours

  static GuestLimitationService? _instance;
  static GuestLimitationService get instance => _instance ??= GuestLimitationService._();
  GuestLimitationService._();

  /// Vérifie si un utilisateur non connecté peut générer une route
  Future<bool> canGuestGenerate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Récupérer les données stockées
      final generationsCount = prefs.getInt(_keyGuestGenerations) ?? 0;
      final firstUseDateString = prefs.getString(_keyFirstUseDate);
      
      // Si c'est la première utilisation, initialiser
      if (firstUseDateString == null) {
        await _initializeGuestData(prefs);
        return true; // Première génération autorisée
      }
      
      final firstUseDate = DateTime.parse(firstUseDateString);
      final now = DateTime.now();
      
      // Vérifier si la période de limitation est expirée
      if (now.difference(firstUseDate) > _limitPeriod) {
        // Réinitialiser le compteur après la période
        await _resetGuestData(prefs);
        return true;
      }
      
      // Vérifier si l'utilisateur a encore des générations disponibles
      return generationsCount < _maxGuestGenerations;
      
    } catch (e) {
      print('❌ Erreur vérification limitation guest: $e');
      return false; // En cas d'erreur, refuser par sécurité
    }
  }

  /// Consomme une génération pour un utilisateur non connecté
  Future<bool> consumeGuestGeneration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Vérifier d'abord si la génération est possible
      if (!await canGuestGenerate()) {
        return false;
      }
      
      // Récupérer le compteur actuel
      final currentCount = prefs.getInt(_keyGuestGenerations) ?? 0;
      
      // Incrémenter le compteur
      await prefs.setInt(_keyGuestGenerations, currentCount + 1);
      
      print('💳 Génération guest consommée: ${currentCount + 1}/$_maxGuestGenerations');
      return true;
      
    } catch (e) {
      print('❌ Erreur consommation génération guest: $e');
      return false;
    }
  }

  /// Retourne le nombre de générations restantes pour un guest
  Future<int> getRemainingGuestGenerations() async {
    try {
      if (!await canGuestGenerate()) {
        return 0;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final used = prefs.getInt(_keyGuestGenerations) ?? 0;
      return _maxGuestGenerations - used;
      
    } catch (e) {
      print('❌ Erreur récupération générations restantes: $e');
      return 0;
    }
  }

  /// Retourne des informations détaillées sur le statut guest
  Future<GuestLimitationStatus> getGuestStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final generationsCount = prefs.getInt(_keyGuestGenerations) ?? 0;
      final firstUseDateString = prefs.getString(_keyFirstUseDate);
      
      if (firstUseDateString == null) {
        return GuestLimitationStatus(
          generationsUsed: 0,
          generationsRemaining: _maxGuestGenerations,
          limitReached: false,
          resetDate: null,
        );
      }
      
      final firstUseDate = DateTime.parse(firstUseDateString);
      final resetDate = firstUseDate.add(_limitPeriod);
      final now = DateTime.now();
      
      // Si la période est expirée, retourner un statut réinitialisé
      if (now.isAfter(resetDate)) {
        return GuestLimitationStatus(
          generationsUsed: 0,
          generationsRemaining: _maxGuestGenerations,
          limitReached: false,
          resetDate: null,
        );
      }
      
      final remaining = _maxGuestGenerations - generationsCount;
      
      return GuestLimitationStatus(
        generationsUsed: generationsCount,
        generationsRemaining: remaining.clamp(0, _maxGuestGenerations),
        limitReached: remaining <= 0,
        resetDate: resetDate,
      );
      
    } catch (e) {
      print('❌ Erreur récupération statut guest: $e');
      return GuestLimitationStatus(
        generationsUsed: _maxGuestGenerations,
        generationsRemaining: 0,
        limitReached: true,
        resetDate: null,
      );
    }
  }

  /// Nettoie les données guest lors de la connexion
  Future<void> clearGuestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyGuestGenerations);
      await prefs.remove(_keyFirstUseDate);
      print('🧹 Données guest nettoyées');
    } catch (e) {
      print('❌ Erreur nettoyage données guest: $e');
    }
  }

  /// Initialise les données pour un nouvel utilisateur guest
  Future<void> _initializeGuestData(SharedPreferences prefs) async {
    await prefs.setInt(_keyGuestGenerations, 0);
    await prefs.setString(_keyFirstUseDate, DateTime.now().toIso8601String());
    print('🆕 Données guest initialisées');
  }

  /// Réinitialise les données après expiration de la période
  Future<void> _resetGuestData(SharedPreferences prefs) async {
    await prefs.setInt(_keyGuestGenerations, 0);
    await prefs.setString(_keyFirstUseDate, DateTime.now().toIso8601String());
    print('🔄 Données guest réinitialisées après expiration');
  }

  // Getters statiques pour l'UI
  static int get maxGuestGenerations => _maxGuestGenerations;
  static Duration get limitPeriod => _limitPeriod;
}

/// Modèle pour le statut de limitation guest
class GuestLimitationStatus {
  final int generationsUsed;
  final int generationsRemaining;
  final bool limitReached;
  final DateTime? resetDate;

  const GuestLimitationStatus({
    required this.generationsUsed,
    required this.generationsRemaining,
    required this.limitReached,
    this.resetDate,
  });

  /// Formate la date de reset pour l'affichage
  String? get formattedResetDate {
    if (resetDate == null) return null;
    
    final now = DateTime.now();
    final difference = resetDate!.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else {
      return 'Bientôt';
    }
  }

  @override
  String toString() {
    return 'GuestLimitationStatus(used: $generationsUsed, remaining: $generationsRemaining, limitReached: $limitReached, resetIn: $formattedResetDate)';
  }
}