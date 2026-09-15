import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The dismissible-looking pill filters from the Nutrition screen in
/// design-ref/img.png: selected = white fill, orange text, check icon;
/// unselected = light gray fill, dark text, close icon.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.cardDark : AppColors.cardLight)
              : (isDark ? AppColors.chipFillDark : AppColors.chipFillLight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isSelected ? Icons.check_rounded : Icons.close_rounded,
              size: 16,
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }
}
