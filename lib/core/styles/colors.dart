import 'package:flutter/material.dart';

class AppColors {
  // Thème CLAIR
  static const Color primary = Color.fromARGB(255, 196, 119, 255); // Violet conservé
  static const Color secondary = Color(0xFF2E2A5C); // Bleu
  static const Color binary = Color(0xFFA3D8FF); // Bleu
  static const Color thirty = Color(0xFFFFB3E9); // Bleu
  static const Color background = Color(0xFFF9F9F9); // Gris très clair
  static const Color surface = Color(0xFFFFFFFF); // Blanc
  static const Color textPrimary = Color(0xFF2D3436); // Noir-gris foncé
  static const Color textSecondary = Color.fromARGB(255, 145, 145, 145); // Gris moyen
  static const Color success = Color(0xFF00CEC9); // Turquoise
  static const Color danger = Color(0xFFD63031); // Rouge
}

class AppColorsDark {
  // Thème SOMBRE
  static const Color primary = Color.fromARGB(255, 196, 119, 255); // Même violet pour cohérence
  static const Color secondary = Color(0xFF2E2A5C); // Bleu
  static const Color binary = Color(0xFFA3D8FF); // Bleu
  static const Color thirty = Color(0xFFFFB3E9);
  static const Color background = Color(0xFF121212); // Noir très sombre
  static const Color surface = Color(0xFF1E1E1E); // Gris très sombre
  static const Color textPrimary = Color(0xFFECECEC); // Blanc cassé
  static const Color textSecondary = Color.fromARGB(255, 118, 118, 118); // Gris clair
  static const Color success = Color.fromARGB(255, 92, 225, 77); // Turquoise plus claire
  static const Color danger = Color(0xFFFF5252); // Rouge plus claire
}