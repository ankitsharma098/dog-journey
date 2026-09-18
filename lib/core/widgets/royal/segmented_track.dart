import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// The pill-track segmented control used by the Passport tabs and
/// anywhere else the app needs "pick exactly one of a few" rendered as
/// a filled track rather than [SegmentedChoice]'s separate pills. See
/// README § Radii, "segmented track 14, thumb 11".
class SegmentedTrack extends StatelessWidget {
  const SegmentedTrack({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.sheet(brightness),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline(brightness)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index
                        ? AppColors.accent.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labels[i],
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 12,
                      color: i == index
                          ? AppColors.textPrimary(brightness)
                          : AppColors.textSecondary(brightness).withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
