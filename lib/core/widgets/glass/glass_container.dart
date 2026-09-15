import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The card primitive every panel/sheet/row in the app builds on —
/// matches design-ref/img.png: an opaque near-white card with a large,
/// soft, low-opacity shadow. No backdrop blur; the "glass" read comes
/// from the shadow softness and the blurred blobs behind it
/// ([SoftBlobBackground]), not from translucency on the card itself.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.margin,
    this.border = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  /// Adds a hairline border instead of a shadow — used for cards that
  /// sit inside another card (e.g. a row inside a grouped list) where a
  /// second shadow would look muddy.
  final bool border;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: radius,
        border: border
            ? Border.all(
                color: isDark
                    ? AppColors.cardBorderDark
                    : AppColors.cardBorderLight,
                width: 1,
              )
            : null,
        boxShadow: border
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: child,
    );
  }
}
