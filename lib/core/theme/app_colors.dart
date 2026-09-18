import 'package:flutter/material.dart';

/// Palette chromatique du design system "Serene Clinical Intelligence".
/// Source unique de vérité : tous les écrans importent ces tokens plutôt
/// que de redéclarer des couleurs locales.
class AppColors {
  AppColors._();

  // Surfaces minérales et conteneurs soyeux
  static const Color surfaceBackground = Color(0xFFF8FAFA);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F4);
  static const Color surfaceContainerHigh = Color(0xFFE4E7E7);
  static const Color surfaceContainerHighest = Color(0xFFD8DADA);

  // Typographie & Contrastes cliniques
  static const Color primaryText = Color(0xFF1E2A38); // Ardoise nuit profond
  static const Color secondaryText = Color(0xFF536371); // Gris clinique doux
  static const Color tertiaryText = Color(0xFF8A97A4); // Micro-copies, horodatages
  static const Color outlineLight = Color(0x141E2A38); // Bordures translucides ~8%

  // Accents cliniques & RAG
  static const Color accentTeal = Color(0xFF0D9488); // Validation RAG, indexé
  static const Color accentTealSoft = Color(0xFFCCFBF1); // Fond de pastille RAG
  static const Color accentBlue = Color(0xFF0284C7); // Surlignage citations [1]
  static const Color accentBlueSoft = Color(0xFFE0F2FE); // Fond pastilles filtres

  // Statuts & Alertes médicales
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningAmberSoft = Color(0xFFFEF3C7);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorRedSoft = Color(0xFFFEE2E2);

  // Verre dépoli (Frosted Glass) pour la navbar flottante
  static const Color glassNavbarBg = Color(0xBFEEEEF0); // Translucide ~75%
  static const Color glassBorder = Color(0x1F1E2A38);
}
