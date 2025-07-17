import 'dart:async';
import 'dart:io';
import 'package:runaway/core/helper/config/log_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runaway/core/errors/api_exceptions.dart';

/// Service de gestion des notifications push
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  
  NotificationService._();
  
  // Clés de stockage
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _fcmTokenKey = 'fcm_token';
  
  // État
  bool _isInitialized = false;
  bool _notificationsEnabled = true; // Par défaut activé
  String? _fcmToken;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get notificationsEnabled => _notificationsEnabled;
  String? get fcmToken => _fcmToken;
  
  /// Initialise le service de notifications
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🔔 Initialisation du service de notifications...');
      
      // Charger les préférences stockées
      await _loadStoredPreferences();
      
      // Initialiser les notifications selon les préférences
      if (_notificationsEnabled) {
        await _initializePushNotifications();
      }
      
      _isInitialized = true;
      LogConfig.logSuccess('Service de notifications initialisé');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur initialisation notifications: $e');
      // Ne pas faire échouer l'app pour les notifications
    }
  }
  
  /// Active/désactive les notifications
  Future<void> toggleNotifications(bool enabled) async {
    try {
      print('🔔 ${enabled ? "Activation" : "Désactivation"} des notifications...');
      
      _notificationsEnabled = enabled;
      
      // Sauvegarder la préférence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsEnabledKey, enabled);
      
      if (enabled) {
        await _initializePushNotifications();
      } else {
        await _disablePushNotifications();
      }
      
      LogConfig.logInfo('Notifications ${enabled ? "activées" : "désactivées"}');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur toggle notifications: $e');
      throw NetworkException('Erreur lors de la modification des notifications: $e');
    }
  }
  
  /// Charge les préférences stockées
  Future<void> _loadStoredPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? true;
    _fcmToken = prefs.getString(_fcmTokenKey);
    
    LogConfig.logInfo('📱 Préférences chargées: notifications=$_notificationsEnabled');
  }
  
  /// Initialise les notifications push (Firebase/FCM)
  Future<void> _initializePushNotifications() async {
    try {
      // SIMULATION - En production, vous utiliseriez:
      // FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      // 1. Demander les permissions
      await _requestNotificationPermissions();
      
      // 2. Obtenir le token FCM
      // _fcmToken = await messaging.getToken();
      _fcmToken = _generateMockToken(); // Simulation
      
      // 3. Sauvegarder le token
      if (_fcmToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_fcmTokenKey, _fcmToken!);
        print('🔑 Token FCM: ${_fcmToken!.substring(0, 20)}...');
      }
      
      // 4. Configurer les handlers
      await _setupNotificationHandlers();
      
    } catch (e) {
      LogConfig.logError('❌ Erreur initialisation push: $e');
      rethrow;
    }
  }
  
  /// Désactive les notifications push
  Future<void> _disablePushNotifications() async {
    try {
      // SIMULATION - En production:
      // await FirebaseMessaging.instance.deleteToken();
      
      _fcmToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fcmTokenKey);
      
      print('🔕 Token FCM supprimé');
      
    } catch (e) {
      LogConfig.logError('❌ Erreur désactivation push: $e');
    }
  }
  
  /// Demande les permissions de notification
  Future<void> _requestNotificationPermissions() async {
    if (Platform.isIOS) {
      // SIMULATION - En production avec firebase_messaging:
      // NotificationSettings settings = await messaging.requestPermission(
      //   alert: true,
      //   badge: true,
      //   sound: true,
      // );
      LogConfig.logInfo('📱 Permissions iOS demandées');
    } else if (Platform.isAndroid) {
      // Les permissions Android sont généralement automatiques
      LogConfig.logInfo('📱 Permissions Android automatiques');
    }
  }
  
  /// Configure les handlers de notifications
  Future<void> _setupNotificationHandlers() async {
    // SIMULATION - En production avec firebase_messaging:
    
    // Handler pour les messages en foreground
    // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //   _handleForegroundMessage(message);
    // });
    
    // Handler pour les messages en arrière-plan
    // FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    //   _handleBackgroundMessage(message);
    // });
    
    LogConfig.logInfo('🔧 Handlers de notifications configurés');
  }
  
  // /// Gère les messages reçus en foreground
  // void _handleForegroundMessage(dynamic message) {
  //   print('📨 Message reçu (foreground): ${message.toString()}');
  //   // Afficher une notification locale
  // }
  
  // /// Gère les messages reçus en arrière-plan
  // void _handleBackgroundMessage(dynamic message) {
  //   print('📨 Message reçu (background): ${message.toString()}');
  //   // Naviguer vers l'écran approprié
  // }
  
  /// Génère un token simulé pour le développement
  String _generateMockToken() {
    return 'mock_fcm_token_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// Nettoie les ressources
  Future<void> dispose() async {
    _isInitialized = false;
    _fcmToken = null;
    LogConfig.logInfo('🗑️ Service de notifications nettoyé');
  }
}