import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Flat canvas behind every screen — the Royal system's "Nocturne
/// ground" is a solid deep ink colour, not the decorative blurred
/// blobs of the previous glass look. Kept as its own widget (rather
/// than inlining `Container(color: ...)` at each call site) so a
/// future screen-specific radial gradient (onboarding, paywall) can
/// still layer on top of a single source of truth for the base colour.
class SoftBlobBackground extends StatelessWidget {
  const SoftBlobBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Scaffold.body hands its child loose constraints, not tight ones —
    // without this SizedBox.expand, a short child (anything that isn't
    // Center/Expanded, e.g. a scrollable form) leaves this Container
    // sized to the content instead of the screen, and Flutter's raw
    // canvas (black) shows through below it.
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.canvas(brightness),
        child: child,
      ),
    );
  }
}
