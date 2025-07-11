class PasswordValidator {
  static const int minLength = 8;
  
  /// Vérifie si le mot de passe respecte toutes les exigences
  static bool isValid(String password) {
    return hasMinLength(password) &&
           hasUppercase(password) &&
           hasLowercase(password) &&
           hasDigit(password) &&
           hasSymbol(password);
  }
  
  /// Vérifie la longueur minimale
  static bool hasMinLength(String password) {
    return password.length >= minLength;
  }
  
  /// Vérifie la présence d'une majuscule
  static bool hasUppercase(String password) {
    return password.contains(RegExp(r'[A-Z]'));
  }
  
  /// Vérifie la présence d'une minuscule
  static bool hasLowercase(String password) {
    return password.contains(RegExp(r'[a-z]'));
  }
  
  /// Vérifie la présence d'un chiffre
  static bool hasDigit(String password) {
    return password.contains(RegExp(r'[0-9]'));
  }
  
  /// Vérifie la présence d'un symbole
  static bool hasSymbol(String password) {
    return password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  }
  
  /// Retourne la première exigence non respectée
  static String? getFirstMissingRequirement(String password) {
    if (!hasMinLength(password)) {
      return 'Au moins $minLength caractères requis';
    }
    if (!hasUppercase(password)) {
      return 'Au moins une majuscule requise';
    }
    if (!hasLowercase(password)) {
      return 'Au moins une minuscule requise';
    }
    if (!hasDigit(password)) {
      return 'Au moins un chiffre requis';
    }
    if (!hasSymbol(password)) {
      return 'Au moins un symbole requis';
    }
    return null;
  }
  
  /// Retourne toutes les exigences non respectées
  static List<String> getMissingRequirements(String password) {
    final missing = <String>[];
    
    if (!hasMinLength(password)) {
      missing.add('Minimum $minLength caractères');
    }
    if (!hasUppercase(password)) {
      missing.add('Une majuscule');
    }
    if (!hasLowercase(password)) {
      missing.add('Une minuscule');
    }
    if (!hasDigit(password)) {
      missing.add('Un chiffre');
    }
    if (!hasSymbol(password)) {
      missing.add('Un symbole');
    }
    
    return missing;
  }
}