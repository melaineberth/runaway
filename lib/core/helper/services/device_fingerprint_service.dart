import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:runaway/core/helper/config/log_config.dart';

/// Service pour créer une empreinte unique de l'appareil
class DeviceFingerprintService {
  static DeviceFingerprintService? _instance;
  static DeviceFingerprintService get instance => _instance ??= DeviceFingerprintService._();
  
  DeviceFingerprintService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  /// Génère une empreinte unique de l'appareil
  Future<Map<String, String>> generateDeviceFingerprint() async {
    try {
      LogConfig.logInfo('🔍 Génération empreinte appareil');
      
      if (Platform.isAndroid) {
        return await _generateAndroidFingerprint();
      } else if (Platform.isIOS) {
        return await _generateIOSFingerprint();
      } else {
        return _generateFallbackFingerprint();
      }
      
    } catch (e) {
      LogConfig.logError('❌ Erreur génération empreinte: $e');
      return _generateFallbackFingerprint();
    }
  }

  /// Génère l'empreinte pour Android
  Future<Map<String, String>> _generateAndroidFingerprint() async {
    final androidInfo = await _deviceInfo.androidInfo;
    
    // Utiliser des identifiants qui ne changent pas même après réinstallation
    final fingerprintData = {
      'brand': androidInfo.brand,
      'model': androidInfo.model,
      'manufacturer': androidInfo.manufacturer,
      'product': androidInfo.product,
      'hardware': androidInfo.hardware,
      'bootloader': androidInfo.bootloader,
      'board': androidInfo.board,
      'display': androidInfo.display,
      'fingerprint': androidInfo.fingerprint,
      // Éviter androidInfo.id car il peut changer après factory reset
    };

    // Créer un hash stable à partir de ces données
    final fingerprintString = fingerprintData.values
        .where((value) => value.isNotEmpty)
        .join('|');
    
    final bytes = utf8.encode(fingerprintString);
    final hash = sha256.convert(bytes).toString();
    
    LogConfig.logInfo('📱 Empreinte Android générée: ${hash.substring(0, 8)}...');
    
    return {
      'device_fingerprint': hash,
      'device_model': androidInfo.model,
      'device_manufacturer': androidInfo.manufacturer,
      'platform': 'android',
    };
  }

  /// Génère l'empreinte pour iOS
  Future<Map<String, String>> _generateIOSFingerprint() async {
    final iosInfo = await _deviceInfo.iosInfo;
    
    // Utiliser des identifiants stables sur iOS
    final fingerprintData = {
      'model': iosInfo.model,
      'systemName': iosInfo.systemName,
      'systemVersion': iosInfo.systemVersion,
      'localizedModel': iosInfo.localizedModel,
      'utsname_machine': iosInfo.utsname.machine,
      'utsname_sysname': iosInfo.utsname.sysname,
      // Éviter identifierForVendor car il peut changer
    };

    final fingerprintString = fingerprintData.values
        .where((value) => value.isNotEmpty)
        .join('|');
    
    final bytes = utf8.encode(fingerprintString);
    final hash = sha256.convert(bytes).toString();
    
    LogConfig.logInfo('📱 Empreinte iOS générée: ${hash.substring(0, 8)}...');
    
    return {
      'device_fingerprint': hash,
      'device_model': iosInfo.model,
      'device_manufacturer': 'Apple',
      'platform': 'ios',
    };
  }

  /// Génère une empreinte de fallback pour autres plateformes
  Map<String, String> _generateFallbackFingerprint() {
    final platformName = Platform.operatingSystem;
    final fallbackString = '${platformName}_fallback_${DateTime.now().millisecondsSinceEpoch ~/ 86400000}'; // Change chaque jour
    
    final bytes = utf8.encode(fallbackString);
    final hash = sha256.convert(bytes).toString();
    
    LogConfig.logInfo('📱 Empreinte fallback générée: ${hash.substring(0, 8)}...');
    
    return {
      'device_fingerprint': hash,
      'device_model': 'unknown',
      'device_manufacturer': 'unknown',
      'platform': platformName,
    };
  }

  /// Vérifie si les données d'empreinte sont valides
  bool isValidFingerprint(Map<String, String> fingerprint) {
    return fingerprint.containsKey('device_fingerprint') && 
           fingerprint['device_fingerprint']!.isNotEmpty &&
           fingerprint.containsKey('platform') &&
           fingerprint['platform']!.isNotEmpty;
  }
}