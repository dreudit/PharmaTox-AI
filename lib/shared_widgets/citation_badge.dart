import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Pastille numérotée cliquable [1] qui ouvre la Bottom Sheet des sources.
class CitationBadge extends StatelessWidget {
  final int index;
  final VoidCallback? onTap;

  const CitationBadge({
    super.key,
    required this.index,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.accentBlueSoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.accentBlue.withOpacity(0.3),
            width: 0.8,
          ),
        ),
        child: Text(
          '[$index]',
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.accentBlue,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// Badge de réassurance HDS / RLS utilisé dans les en-têtes et la sidebar.
class HdsSecurityPill extends StatelessWidget {
  final String label;

  const HdsSecurityPill({super.key, this.label = 'Isolation RLS active'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentTealSoft,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 12, color: AppColors.accentTeal),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.accentTeal,
            ),
          ),
        ],
      ),
    );
  }
}
