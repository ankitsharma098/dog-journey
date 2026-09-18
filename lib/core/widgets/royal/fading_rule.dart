import 'package:flutter/material.dart';

/// The 1px champagne hairline that fades to transparent — used on the
/// passport hero card (fades at both ends), the onboarding mark and the
/// Story masthead (centred, fades at both ends), and the Care calendar
/// group headers (fades at the right end only).
class FadingRule extends StatelessWidget {
  const FadingRule({
    super.key,
    required this.color,
    this.height = 1,
    this.fadeStart = true,
    this.fadeEnd = true,
  });

  final Color color;
  final double height;
  final bool fadeStart;
  final bool fadeEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            fadeStart ? color.withValues(alpha: 0) : color,
            color,
            fadeEnd ? color.withValues(alpha: 0) : color,
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
    );
  }
}
