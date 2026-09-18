import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Barre de navigation flottante "Capsule Frosted Glass".
/// Présente sur les trois onglets principaux : Chat, Bibliothèque, Réglages.
class FloatingCapsuleNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const FloatingCapsuleNav({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 16.0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.glassNavbarBg,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.65),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryText.withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavCapsuleItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    isActive: currentIndex == 0,
                    onTap: () => onIndexChanged(0),
                    tooltip: 'Chat Clinique',
                  ),
                  const SizedBox(width: 8),
                  _NavCapsuleItem(
                    icon: Icons.local_library_outlined,
                    activeIcon: Icons.local_library_rounded,
                    isActive: currentIndex == 1,
                    onTap: () => onIndexChanged(1),
                    tooltip: 'Bibliothèque RAG',
                  ),
                  const SizedBox(width: 8),
                  _NavCapsuleItem(
                    icon: Icons.tune_rounded,
                    activeIcon: Icons.tune_rounded,
                    isActive: currentIndex == 2,
                    onTap: () => onIndexChanged(2),
                    tooltip: 'Paramètres & Sources',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCapsuleItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;

  const _NavCapsuleItem({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.surfaceContainerLowest
                : Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primaryText.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Icon(
            isActive ? activeIcon : icon,
            size: 22,
            color: isActive ? AppColors.primaryText : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}
