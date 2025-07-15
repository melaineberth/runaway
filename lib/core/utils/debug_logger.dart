import 'package:flutter/foundation.dart';
import 'package:runaway/config/secure_config.dart';

class DebugLogger {
  static bool get _shouldLog => kDebugMode || !SecureConfig.kIsProduction;
  
  static void log(String message, {String prefix = '🔍'}) {
    if (_shouldLog) {
      print('$prefix $message');
    }
  }
  
  static void success(String message) {
    log(message, prefix: '✅');
  }
  
  static void warning(String message) {
    log(message, prefix: '⚠️');
  }
  
  static void error(String message) {
    log(message, prefix: '❌');
  }
  
  static void info(String message) {
    log(message, prefix: 'ℹ️');
  }
  
  static void debug(String message) {
    if (kDebugMode) {
      log(message, prefix: '🐛');
    }
  }
}
