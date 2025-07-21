import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';

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
  static String? getFirstMissingRequirement(BuildContext context, String password) {
    if (!hasMinLength(password)) {
      return context.l10n.requiredCountCharacters(minLength);
    }
    if (!hasUppercase(password)) {
      return context.l10n.requiredCapitalLetter;
    }
    if (!hasLowercase(password)) {
      return context.l10n.requiredMinusculeLetter;
    }
    if (!hasDigit(password)) {
      return context.l10n.requiredDigit;
    }
    if (!hasSymbol(password)) {
      return context.l10n.requiredSymbol;
    }
    return null;
  }
  
  /// Retourne toutes les exigences non respectées
  static List<String> getMissingRequirements(BuildContext context, String password) {
    final missing = <String>[];
    
    if (!hasMinLength(password)) {
      missing.add(context.l10n.minimumCountCharacters(minLength));
    }
    if (!hasUppercase(password)) {
      missing.add(context.l10n.oneCapitalLetter);
    }
    if (!hasLowercase(password)) {
      missing.add(context.l10n.oneMinusculeLetter);
    }
    if (!hasDigit(password)) {
      missing.add(context.l10n.oneDigit);
    }
    if (!hasSymbol(password)) {
      missing.add(context.l10n.oneSymbol);
    }
    
    return missing;
  }
}