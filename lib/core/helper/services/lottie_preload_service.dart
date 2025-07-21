import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:runaway/core/helper/config/log_config.dart';

/// Service pour précharger les animations Lottie utilisées dans l'application
class LottiePreloadService {
  static final LottiePreloadService _instance = LottiePreloadService._internal();
  static LottiePreloadService get instance => _instance;
  LottiePreloadService._internal();

  // URL de l'animation utilisée dans ModalDialog
  static const String _authModalLottieUrl = "https://cdn.lottielab.com/l/13mdUjaB8g6HWu.json";
  
  // Cache pour stocker l'animation préchargée
  Uint8List? _cachedAuthModalLottie;
  bool _isLoaded = false;
  bool _isLoading = false;

  /// Précharge l'animation Lottie au démarrage de l'application
  Future<void> preloadAuthModalLottie() async {
    if (_isLoaded || _isLoading) return;
    
    _isLoading = true;
    LogConfig.logInfo('🎬 Préchargement de l\'animation Lottie auth modal...');
    
    try {
      final response = await http.get(Uri.parse(_authModalLottieUrl));
      
      if (response.statusCode == 200) {
        _cachedAuthModalLottie = response.bodyBytes;
        _isLoaded = true;
        LogConfig.logSuccess('✅ Animation Lottie auth modal préchargée avec succès');
      } else {
        LogConfig.logError('❌ Erreur HTTP lors du préchargement Lottie: ${response.statusCode}');
      }
    } catch (e) {
      LogConfig.logError('❌ Erreur lors du préchargement Lottie: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Retourne l'animation préchargée ou null si non disponible
  Uint8List? get cachedAuthModalLottie => _cachedAuthModalLottie;
  
  /// Vérifie si l'animation est préchargée et disponible
  bool get isAuthModalLottieLoaded => _isLoaded && _cachedAuthModalLottie != null;
  
  /// URL de fallback pour le réseau si le cache n'est pas disponible
  String get authModalLottieUrl => _authModalLottieUrl;
}