import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class SuggestionChip extends StatelessWidget {
  const SuggestionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: highlight ? AppColors.softGreenBg : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: highlight ? AppColors.primaryGreen : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: highlight
                ? AppColors.primaryGreenDark
                : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
