import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../theme/app_colors.dart';

/// The gold-outlined paw crest used on Splash, Onboarding and the
/// Sign in brand row — see design-ref/design_handoff_royal_redesign/
/// README.md § "0a. Splash", "0b. Sign in".
class RoyalCrest extends StatelessWidget {
  const RoyalCrest({super.key, this.size = 34, this.borderAlpha = 0.55});

  final double size;
  final double borderAlpha;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final champagne = AppColors.champagneOn(brightness);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: champagne.withValues(alpha: borderAlpha)),
        color: champagne.withValues(alpha: 0.07),
      ),
      alignment: Alignment.center,
      child: Icon(PhosphorIconsFill.pawPrint, size: size * 0.42, color: champagne),
    );
  }
}
