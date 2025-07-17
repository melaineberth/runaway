import 'dart:async';
import 'dart:math';

import 'package:runaway/core/helper/config/log_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gérer l'affichage intelligent des invitations à l'inscription
class ConversionService {
  static ConversionService? _instance;
  static ConversionService get instance => _instance ??= ConversionService._();
  
  ConversionService._();
  
  // Clés de stockage
  static const String _lastPromptDateKey = 'last_conversion_prompt_date';
  static const String _promptCountKey = 'conversion_prompt_count';
  static const String _routesGeneratedKey = 'routes_generated_count';
  static const String _activityViewsKey = 'activity_views_count';
  static const String _sessionStartKey = 'session_start_time';
  static const String _userDeclinedKey = 'user_declined_prompts';
  
  // Configuration
  static const int _minSessionTimeMinutes = 3; // Minimum 3 min d'utilisation
  static const int _maxPromptsPerDay = 2; // Maximum 2 fois par jour
  static const int _maxPromptsTotal = 8; // Maximum 8 fois au total
  static const int _cooldownHours = 4; // Attendre 4h entre les prompts
  static const int _routesThreshold = 2; // Après 2 routes générées
  static const int _activityThreshold = 3; // Après 3 vues d'activités
  
  // État
  bool _isInitialized = false;
  DateTime? _sessionStart;
  int _routesGenerated = 0;
  int _activityViews = 0;
  bool _userDeclined = false;
  
  // 🆕 AJOUT : Completer pour l'initialisation asynchrone
  Completer<void>? _initializationCompleter;
  
  /// 🔧 NOUVELLE MÉTHODE : Attend que l'initialisation soit terminée
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    
    // Si une initialisation est en cours, attendre qu'elle se termine
    if (_initializationCompleter != null) {
      await _initializationCompleter!.future;
      return;
    }
    
    // Sinon, initialiser maintenant
    await initializeSession();
  }
  
  /// Initialise le service pour une nouvelle session
  Future<void> initializeSession() async {
    if (_isInitialized) return;
    
    // 🆕 AJOUT : Créer le completer pour signaler la fin d'initialisation
    _initializationCompleter = Completer<void>();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 🔧 AMÉLIORATION : Vérifier s'il y a déjà une session active aujourd'hui
      final storedSessionStart = prefs.getInt(_sessionStartKey);
      final now = DateTime.now();
      
      if (storedSessionStart != null) {
        final storedDate = DateTime.fromMillisecondsSinceEpoch(storedSessionStart);
        final isToday = storedDate.year == now.year && 
                       storedDate.month == now.month && 
                       storedDate.day == now.day;
        
        if (isToday) {
          // Continuer la session du jour
          _sessionStart = storedDate;
          LogConfig.logInfo('🔄 Reprise de session du jour : $_sessionStart');
        } else {
          // Nouvelle session
          _sessionStart = now;
          await prefs.setInt(_sessionStartKey, _sessionStart!.millisecondsSinceEpoch);
          print('🆕 Nouvelle session démarrée : $_sessionStart');
        }
      } else {
        // Première session
        _sessionStart = now;
        await prefs.setInt(_sessionStartKey, _sessionStart!.millisecondsSinceEpoch);
        print('🎉 Première session initialisée : $_sessionStart');
      }
      
      // Charger les données persistées
      _routesGenerated = prefs.getInt(_routesGeneratedKey) ?? 0;
      _activityViews = prefs.getInt(_activityViewsKey) ?? 0;
      _userDeclined = prefs.getBool(_userDeclinedKey) ?? false;
      
      _isInitialized = true;
      
      // 🆕 AJOUT : Signaler que l'initialisation est terminée
      _initializationCompleter?.complete();
      _initializationCompleter = null;
      
      LogConfig.logInfo(' 📈 ConversionService initialized - Session: ${_getSessionDuration()}min, Routes: $_routesGenerated, Activities: $_activityViews');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur initialisation ConversionService: $e');
      // 🆕 AJOUT : Signaler l'erreur au completer
      _initializationCompleter?.completeError(e);
      _initializationCompleter = null;
    }
  }
  
  /// 🆕 NOUVELLE MÉTHODE : Obtient la durée de session actuelle
  int _getSessionDuration() {
    if (_sessionStart == null) return 0;
    return DateTime.now().difference(_sessionStart!).inMinutes;
  }
  
  /// Enregistre qu'une route a été générée
  Future<void> trackRouteGenerated() async {
    // 🔧 MODIFICATION : Attendre l'initialisation avant de continuer
    await _ensureInitialized();
    
    if (_userDeclined) return;
    
    _routesGenerated++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_routesGeneratedKey, _routesGenerated);
    
    print('🗺️ Route générée (#$_routesGenerated) - Session: ${_getSessionDuration()}min');
  }
  
  /// Enregistre qu'une page d'activité a été consultée
  Future<void> trackActivityView() async {
    // 🔧 MODIFICATION : Attendre l'initialisation avant de continuer
    await _ensureInitialized();
    
    if (_userDeclined) return;
    
    _activityViews++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activityViewsKey, _activityViews);
    
    LogConfig.logInfo('📊 Activité consultée (#$_activityViews) - Session: ${_getSessionDuration()}min');
  }
  
  /// Vérifie si on doit afficher une invitation
  Future<bool> shouldShowConversionPrompt() async {
    // 🔧 MODIFICATION : Attendre l'initialisation avant de continuer
    await _ensureInitialized();
    
    if (_userDeclined) return false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Vérifier les limites générales
      final totalPrompts = prefs.getInt(_promptCountKey) ?? 0;
      if (totalPrompts >= _maxPromptsTotal) {
        LogConfig.logInfo('🚫 Limite totale de prompts atteinte');
        return false;
      }
      
      // 2. Vérifier le cooldown
      final lastPromptTime = prefs.getInt(_lastPromptDateKey);
      if (lastPromptTime != null) {
        final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptTime);
        final hoursSinceLastPrompt = DateTime.now().difference(lastPrompt).inHours;
        
        if (hoursSinceLastPrompt < _cooldownHours) {
          print('🕐 Cooldown actif (${_cooldownHours - hoursSinceLastPrompt}h restantes)');
          return false;
        }
      }
      
      // 3. Vérifier les prompts du jour
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      final todayPrompts = prefs.getInt('prompts_$todayKey') ?? 0;
      
      if (todayPrompts >= _maxPromptsPerDay) {
        print('📅 Limite quotidienne atteinte');
        return false;
      }
      
      // 4. 🔧 AMÉLIORATION : Vérification plus robuste du temps de session
      final sessionDurationMinutes = _getSessionDuration();
      if (sessionDurationMinutes < _minSessionTimeMinutes) {
        LogConfig.logInfo('⏱️ Session trop courte ($sessionDurationMinutes/$_minSessionTimeMinutes min)');
        return false;
      }
      
      // 5. Vérifier les conditions d'engagement
      final hasEnoughRoutes = _routesGenerated >= _routesThreshold;
      final hasEnoughActivityViews = _activityViews >= _activityThreshold;
      
      if (!hasEnoughRoutes && !hasEnoughActivityViews) {
        LogConfig.logInfo(' 📈 Pas assez d\'engagement (Routes: $_routesGenerated/$_routesThreshold, Activités: $_activityViews/$_activityThreshold)');
        return false;
      }
      
      // 6. Probabilité aléatoire pour rendre moins prévisible
      final random = Random();
      final shouldShow = random.nextDouble() < 0.7; // 70% de chance
      
      if (!shouldShow) {
        print('🎲 Probabilité aléatoire: non');
        return false;
      }
      
      LogConfig.logInfo('Conditions réunies pour afficher le prompt (Session: ${sessionDurationMinutes}min)');
      return true;
      
    } catch (e) {
      LogConfig.logError('❌ Erreur vérification prompt: $e');
      return false;
    }
  }
  
  /// Enregistre qu'un prompt a été affiché
  Future<void> recordPromptShown() async {
    await _ensureInitialized(); // 🔧 AJOUT
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      // Incrémenter le compteur total
      final totalPrompts = (prefs.getInt(_promptCountKey) ?? 0) + 1;
      await prefs.setInt(_promptCountKey, totalPrompts);
      
      // Sauvegarder la date du dernier prompt
      await prefs.setInt(_lastPromptDateKey, now.millisecondsSinceEpoch);
      
      // Incrémenter le compteur du jour
      final todayKey = '${now.year}-${now.month}-${now.day}';
      final todayPrompts = (prefs.getInt('prompts_$todayKey') ?? 0) + 1;
      await prefs.setInt('prompts_$todayKey', todayPrompts);
      
      LogConfig.logInfo('📝 Prompt enregistré (#$totalPrompts total, #$todayPrompts aujourd\'hui)');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur enregistrement prompt: $e');
    }
  }
  
  /// Enregistre que l'utilisateur a refusé (temporairement moins de prompts)
  Future<void> recordUserDeclined() async {
    await _ensureInitialized(); // 🔧 AJOUT
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userDeclinedKey, true);
      _userDeclined = true;
      
      print('👎 Utilisateur a refusé - réduction temporaire des prompts');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur enregistrement refus: $e');
    }
  }
  
  /// Remet à zéro le refus utilisateur (par exemple après une semaine)
  Future<void> resetUserDeclined() async {
    await _ensureInitialized(); // 🔧 AJOUT
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userDeclinedKey, false);
      _userDeclined = false;
      
      LogConfig.logInfo('🔄 Reset du statut de refus utilisateur');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur reset refus: $e');
    }
  }
  
  /// Obtient des statistiques pour le debug
  Future<Map<String, dynamic>> getDebugStats() async {
    await _ensureInitialized(); // 🔧 AJOUT
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final totalPrompts = prefs.getInt(_promptCountKey) ?? 0;
      final lastPromptTime = prefs.getInt(_lastPromptDateKey);
      
      return {
        'initialized': _isInitialized,
        'session_duration_minutes': _getSessionDuration(),
        'routes_generated': _routesGenerated,
        'activity_views': _activityViews,
        'total_prompts': totalPrompts,
        'user_declined': _userDeclined,
        'last_prompt': lastPromptTime != null 
            ? DateTime.fromMillisecondsSinceEpoch(lastPromptTime).toString()
            : 'never',
        'session_start': _sessionStart?.toString() ?? 'not_set',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  /// Nettoie les ressources
  void dispose() {
    _isInitialized = false;
    _sessionStart = null;
    _initializationCompleter?.complete();
    _initializationCompleter = null;
    LogConfig.logInfo('🗑️ ConversionService disposed');
  }
}