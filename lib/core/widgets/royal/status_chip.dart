import 'package:flutter/material.dart';

import '../../theme/app_text_styles.dart';

/// A small uppercase status pill — "12 DAYS", "OVERDUE", "DUE SOON",
/// "3 SCANS LEFT". [background]/[foreground] are supplied by the
/// caller since the colour carries the meaning (warning/danger/champagne
/// tint/accent tint) rather than the chip itself picking one.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.chipLabel.copyWith(color: foreground),
      ),
    );
  }
}
