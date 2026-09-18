import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// A section heading with an optional trailing text link — "Needs you
/// this week" / "All care", "Nine years, so far" / "Story".
class SectionLinkHeader extends StatelessWidget {
  const SectionLinkHeader({
    super.key,
    required this.title,
    this.linkLabel,
    this.onLinkTap,
  });

  final String title;
  final String? linkLabel;
  final VoidCallback? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.sectionHeading.copyWith(
              color: AppColors.textPrimary(brightness),
            ),
          ),
        ),
        if (linkLabel != null)
          GestureDetector(
            onTap: onLinkTap,
            child: Text(
              linkLabel!,
              style: AppTextStyles.listRowTitle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.accentLight,
              ),
            ),
          ),
      ],
    );
  }
}
