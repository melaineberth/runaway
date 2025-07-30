// lib/core/helper/services/auth_input_validator.dart

import 'package:runaway/core/helper/config/log_config.dart';

/// Service de validation et assainissement des entrées d'authentification
class AuthInputValidator {
  // Patterns de sécurité
  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  );
  
  static final RegExp _suspiciousPatterns = RegExp(
    r'(<script|javascript:|vbscript:|onload=|onerror=|eval\(|union\s+select|drop\s+table|insert\s+into|delete\s+from|update\s+set|--|\|\/\*|\*\/)',
    caseSensitive: false
  );
  
  static final RegExp _sqlPatterns = RegExp(
    r'(\b(select|insert|update|delete|drop|create|alter|exec|execute|union)\b|--|\/\*|\*\/|;|\||&)',
    caseSensitive: false
  );

  /// Valide et assainit l'email
  static ValidationResult validateEmail(String email) {
    if (email.isEmpty) {
      return ValidationResult(false, 'Email requis');
    }
    
    // Nettoyer l'email
    final cleanEmail = _sanitizeInput(email.trim().toLowerCase());
    
    // Vérifier la longueur
    if (cleanEmail.length > 254) {
      LogConfig.logWarning('🔒 Email trop long: ${cleanEmail.length} caractères');
      return ValidationResult(false, 'Email trop long');
    }
    
    // Vérifier le format
    if (!_emailPattern.hasMatch(cleanEmail)) {
      return ValidationResult(false, 'Format email invalide');
    }
    
    // Vérifier les patterns suspects
    if (_containsSuspiciousContent(cleanEmail)) {
      LogConfig.logWarning('🔒 Email suspect détecté: $cleanEmail');
      return ValidationResult(false, 'Email non autorisé');
    }
    
    return ValidationResult(true, null, cleanEmail);
  }
  
  /// Valide et assainit le mot de passe
  static ValidationResult validatePassword(String password) {
    if (password.isEmpty) {
      return ValidationResult(false, 'Mot de passe requis');
    }
    
    // Vérifier la longueur minimum
    if (password.length < 6) {
      return ValidationResult(false, 'Au moins 6 caractères');
    }
    
    // Vérifier la longueur maximum (pour éviter les attaques DoS)
    if (password.length > 128) {
      LogConfig.logWarning('🔒 Mot de passe trop long: ${password.length} caractères');
      return ValidationResult(false, 'Mot de passe trop long');
    }
    
    // Vérifier les patterns suspects
    if (_containsSuspiciousContent(password)) {
      LogConfig.logWarning('🔒 Mot de passe suspect détecté');
      return ValidationResult(false, 'Mot de passe non autorisé');
    }
    
    return ValidationResult(true, null, password);
  }
  
  /// Valide et assainit le nom complet
  static ValidationResult validateFullName(String fullName) {
    if (fullName.isEmpty) {
      return ValidationResult(false, 'Nom requis');
    }
    
    // Nettoyer le nom
    final cleanName = _sanitizeInput(fullName.trim());
    
    // Vérifier la longueur
    if (cleanName.length > 100) {
      LogConfig.logWarning('🔒 Nom trop long: ${cleanName.length} caractères');
      return ValidationResult(false, 'Nom trop long');
    }
    
    // Vérifier les patterns suspects
    if (_containsSuspiciousContent(cleanName)) {
      LogConfig.logWarning('🔒 Nom suspect détecté: $cleanName');
      return ValidationResult(false, 'Nom non autorisé');
    }
    
    // Vérifier les caractères autorisés (lettres, espaces, tirets, apostrophes)
    final namePattern = RegExp(r"^[a-zA-ZÀ-ÿ\s\-'.]+$");
    if (!namePattern.hasMatch(cleanName)) {
      return ValidationResult(false, 'Caractères non autorisés dans le nom');
    }
    
    return ValidationResult(true, null, cleanName);
  }
  
  /// Valide le nom d'utilisateur
  static ValidationResult validateUsername(String username) {
    if (username.isEmpty) {
      return ValidationResult(false, 'Nom d\'utilisateur requis');
    }
    
    // Nettoyer le nom d'utilisateur
    final cleanUsername = _sanitizeInput(username.trim().toLowerCase());
    
    // Vérifier la longueur
    if (cleanUsername.length < 3) {
      return ValidationResult(false, 'Au moins 3 caractères');
    }
    
    if (cleanUsername.length > 30) {
      LogConfig.logWarning('🔒 Username trop long: ${cleanUsername.length} caractères');
      return ValidationResult(false, 'Nom d\'utilisateur trop long');
    }
    
    // Vérifier les patterns suspects
    if (_containsSuspiciousContent(cleanUsername)) {
      LogConfig.logWarning('🔒 Username suspect détecté: $cleanUsername');
      return ValidationResult(false, 'Nom d\'utilisateur non autorisé');
    }
    
    // Vérifier le format (lettres, chiffres, tirets, underscores)
    final usernamePattern = RegExp(r'^[a-z0-9_-]+$');
    if (!usernamePattern.hasMatch(cleanUsername)) {
      return ValidationResult(false, 'Seuls les lettres, chiffres, - et _ sont autorisés');
    }
    
    return ValidationResult(true, null, cleanUsername);
  }
  
  /// Assainit une entrée en supprimant les caractères dangereux
  static String _sanitizeInput(String input) {
    return input
        .replaceAll(RegExp(r'[<>"' + "']"), '') // Supprimer caractères HTML dangereux
        .replaceAll(RegExp(r'\s+'), ' ')    // Normaliser les espaces
        .trim();
  }
  
  /// Vérifie si le contenu contient des patterns suspects
  static bool _containsSuspiciousContent(String content) {
    return _suspiciousPatterns.hasMatch(content) || _sqlPatterns.hasMatch(content);
  }
  
  /// Valide la force du mot de passe (optionnel, pour l'amélioration UX)
  static PasswordStrength evaluatePasswordStrength(String password) {
    if (password.length < 6) {
      return PasswordStrength.weak;
    }
    
    int score = 0;
    
    // Longueur
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    
    // Complexité
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;
    
    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }
}

/// Résultat de validation
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? sanitizedValue;
  
  ValidationResult(this.isValid, this.errorMessage, [this.sanitizedValue]);
}

/// Force du mot de passe
enum PasswordStrength {
  weak,
  medium,
  strong,
}