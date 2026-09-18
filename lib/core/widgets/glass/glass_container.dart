import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The card primitive every panel/sheet/row in the app builds on. Royal
/// cards are an opaque surface plus a 1px hairline — "elevation is an
/// edge plus ambient darkness" on dark, and a soft shadow on top of
/// that same hairline on light (see README § Shadows / elevation).
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
    this.margin,
    this.border = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  /// When true, this card sits inside another card (e.g. a row in a
  /// grouped list) — suppress the light-theme shadow so it doesn't
  /// double up.
  final bool border;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card(brightness),
        borderRadius: radius,
        border: Border.all(color: AppColors.hairline(brightness), width: 1),
        boxShadow: (!border && brightness == Brightness.light)
            ? const [
                BoxShadow(
                  color: AppColors.cardShadowLight,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
