import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum SnackbarType { info, success, warning, error }

class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.info,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color backgroundColor;
    IconData icon;
    Color iconColor;

    switch (type) {
      case SnackbarType.success:
        backgroundColor = AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1);
        icon = Icons.check_circle_rounded;
        iconColor = AppColors.success;
        break;
      case SnackbarType.warning:
        backgroundColor = AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.1);
        icon = Icons.warning_rounded;
        iconColor = AppColors.warning;
        break;
      case SnackbarType.error:
        backgroundColor = AppColors.danger.withValues(alpha: isDark ? 0.2 : 0.1);
        icon = Icons.error_rounded;
        iconColor = AppColors.danger;
        break;
      case SnackbarType.info:
      default:
        backgroundColor = isDark ? AppColors.cardDark : AppColors.cardLight;
        icon = Icons.info_rounded;
        iconColor = AppColors.primary;
        break;
    }

    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
