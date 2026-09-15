import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The soft, low-opacity color blobs behind every screen in
/// design-ref/img.png. Built from radial gradients (not ImageFilter.blur)
/// so it costs nothing to keep mounted behind scrolling content.
class SoftBlobBackground extends StatelessWidget {
  const SoftBlobBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Scaffold.body hands its child loose constraints, not tight ones —
    // without this SizedBox.expand, a short child (anything that isn't
    // Center/Expanded, e.g. a scrollable form) leaves this Container
    // sized to the content instead of the screen, and Flutter's raw
    // canvas (black) shows through below it.
    return SizedBox.expand(
      child: Container(
        color: isDark ? AppColors.canvasDark : AppColors.canvasLight,
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -100,
              child: _Blob(color: AppColors.blobCool, size: 320, dark: isDark),
            ),
            Positioned(
              bottom: -100,
              left: -120,
              child: _Blob(color: AppColors.blobWarm, size: 340, dark: isDark),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size, required this.dark});

  final Color color;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: dark ? 0.16 : 0.35),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
