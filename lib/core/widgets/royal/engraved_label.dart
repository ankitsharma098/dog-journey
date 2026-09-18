import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// The uppercase, wide-tracked "kicker" used above a screen or card
/// title — "HEALTH PASSPORT", "TODAY", "PAWJOURNEY". Always champagne;
/// see README § Typography, "Engraved label".
class EngravedLabel extends StatelessWidget {
  const EngravedLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.engravedLabel.copyWith(
        color: color ?? AppColors.champagneOn(brightness),
      ),
    );
  }
}
