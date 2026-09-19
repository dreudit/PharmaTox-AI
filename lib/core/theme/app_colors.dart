import 'package:flutter/material.dart';

/// Palette chromatique du design system "Aurora Intelligence" (refonte 2026,
/// inspirée d'interfaces IA à dégradés violet/magenta — orbe vocal glossy,
/// surfaces lavande soyeuses, contrastes quasi-noirs).
/// Source unique de vérité : tous les écrans importent ces tokens plutôt
/// que de redéclarer des couleurs locales.
class AppColors {
  AppColors._();

  // Surfaces — dégradé lavande soyeux
  static const Color surfaceBackground = Color(0xFFF7F3FC);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF1E9FA);
  static const Color surfaceContainerHigh = Color(0xFFE4D8F5);
  static const Color surfaceContainerHighest = Color(0xFFD4C2EE);

  // Typographie & Contrastes
  static const Color primaryText = Color(0xFF1B1330); // Violet-nuit quasi-noir
  static const Color secondaryText = Color(0xFF6B5E85); // Gris-violet doux
  static const Color tertiaryText = Color(0xFF9C90B5); // Micro-copies, horodatages
  static const Color outlineLight = Color(0x141B1330); // Bordures translucides ~8%

  // Accents de marque — violet/magenta dégradé (identité "Aurora")
  static const Color accentTeal = Color(0xFF7C3AED); // Violet principal (ex-teal)
  static const Color accentTealSoft = Color(0xFFEDE4FC);
  static const Color accentBlue = Color(0xFFC026D3); // Magenta secondaire (ex-blue)
  static const Color accentBlueSoft = Color(0xFFFAE4F8);

  // Statuts & Alertes médicales (sémantique conservée pour la sécurité clinique)
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningAmberSoft = Color(0xFFFEF3C7);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorRedSoft = Color(0xFFFEE2E2);

  // Verre dépoli (Frosted Glass) pour la navbar flottante
  static const Color glassNavbarBg = Color(0xBFF7F1FC); // Translucide ~75%
  static const Color glassBorder = Color(0x1F1B1330);

  // Dégradé hero : orbe vocal, cartes vedettes, boutons d'action principaux
  static const List<Color> heroGradient = [Color(0xFF7C3AED), Color(0xFFC026D3)];
  static const List<Color> heroGradientSoft = [Color(0xFFEDE4FC), Color(0xFFFAE4F8)];
}
