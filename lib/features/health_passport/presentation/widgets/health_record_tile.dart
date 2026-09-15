import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../data/models/health_record.dart';

/// A single health record row in the passport timeline or list.
class HealthRecordTile extends StatelessWidget {
  const HealthRecordTile({
    super.key,
    required this.record,
    this.onTap,
    this.onDelete,
  });

  final HealthRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final now = DateTime.now();
    final isDue = record.dueOn != null && record.dueOn!.isBefore(now);
    final isDueSoon = record.dueOn != null &&
        !isDue &&
        record.dueOn!.difference(now).inDays <= 30;

    return GlassCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Type icon chip
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _iconBg(isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconFor(record.type), color: _iconColor(), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(record),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(record.occurredOn),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: textSecondary, fontSize: 11),
              ),
              if (record.dueOn != null) ...[
                const SizedBox(height: 4),
                _DueBadge(dueOn: record.dueOn!, isDue: isDue, isDueSoon: isDueSoon),
              ],
            ],
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: AppColors.danger,
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(RecordType type) => switch (type) {
        RecordType.vaccine => Icons.vaccines_rounded,
        RecordType.vetVisit => Icons.local_hospital_rounded,
        RecordType.medication => Icons.medication_rounded,
        RecordType.weight => Icons.monitor_weight_outlined,
        RecordType.allergy => Icons.warning_amber_rounded,
        RecordType.preventive => Icons.health_and_safety_rounded,
      };

  Color _iconColor() => switch (record.type) {
        RecordType.vaccine => AppColors.primary,
        RecordType.vetVisit => const Color(0xFF34C759),
        RecordType.medication => const Color(0xFF5856D6),
        RecordType.weight => const Color(0xFF32ADE6),
        RecordType.allergy => AppColors.warning,
        RecordType.preventive => const Color(0xFFFF9F0A),
      };

  Color _iconBg(bool isDark) {
    final base = _iconColor();
    return isDark ? base.withValues(alpha: 0.15) : base.withValues(alpha: 0.1);
  }

  String _subtitle(HealthRecord r) {
    if (r.type == RecordType.weight && r.weightKg != null) {
      return '${r.weightKg!.toStringAsFixed(1)} kg';
    }
    if (r.type == RecordType.vaccine && r.doseNumber != null) {
      return 'Dose ${r.doseNumber}${r.clinicName != null ? ' · ${r.clinicName}' : ''}';
    }
    if (r.type == RecordType.medication && r.dosageText != null) {
      return r.dosageText!;
    }
    return r.clinicName ?? r.type.label;
  }

  String _formatDate(DateTime d) => DateFormat('MMM d, yyyy').format(d);
}

class _DueBadge extends StatelessWidget {
  const _DueBadge({
    required this.dueOn,
    required this.isDue,
    required this.isDueSoon,
  });

  final DateTime dueOn;
  final bool isDue;
  final bool isDueSoon;

  @override
  Widget build(BuildContext context) {
    final color = isDue
        ? AppColors.danger
        : isDueSoon
            ? AppColors.warning
            : AppColors.success;
    final label = isDue
        ? 'Overdue'
        : isDueSoon
            ? 'Due soon'
            : 'Due ${DateFormat('MMM d').format(dueOn)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
