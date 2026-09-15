import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SegmentedChoiceOption<T> {
  const SegmentedChoiceOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// A single-select row of pills — sex, units, plan goal, anywhere the
/// app needs "pick exactly one of a few options" without the overhead
/// of a full dropdown.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentedChoiceOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        for (final option in options) ...[
          Expanded(
            child: InkWell(
              onTap: () => onChanged(option.value),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: option.value == value
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.chipFillDark
                            : AppColors.chipFillLight),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: option.value == value
                        ? Colors.white
                        : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                  ),
                ),
              ),
            ),
          ),
          if (option != options.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
