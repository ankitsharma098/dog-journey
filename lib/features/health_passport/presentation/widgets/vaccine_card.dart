import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../data/models/health_record.dart';
import '../../data/models/vaccine_type.dart';

/// Shows a vaccine with series progress and next-due urgency.
class VaccineCard extends StatelessWidget {
  const VaccineCard({
    super.key,
    required this.record,
    this.vaccineType,
    this.onTap,
  });

  final HealthRecord record;
  final VaccineType? vaccineType;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final now = DateTime.now();
    final dueOn = record.dueOn;
    final isDue = dueOn != null && dueOn.isBefore(now);
    final isDueSoon = dueOn != null &&
        !isDue &&
        dueOn.difference(now).inDays <= 30;

    final dueBadgeColor = isDue
        ? AppColors.danger
        : isDueSoon
            ? AppColors.warning
            : AppColors.success;

    return GlassCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Vaccine icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.vaccines_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
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
                    ),
                    if (vaccineType != null)
                      Text(
                        vaccineType!.abbreviation +
                            (vaccineType!.isCore ? ' · Core' : ' · Non-core'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: textSecondary,
                            ),
                      ),
                  ],
                ),
              ),
              if (dueOn != null)
                _PillBadge(
                  label: isDue
                      ? 'Overdue'
                      : isDueSoon
                          ? 'Due ${DateFormat('MMM d').format(dueOn)}'
                          : 'Due ${DateFormat('MMM yyyy').format(dueOn)}',
                  color: dueBadgeColor,
                ),
            ],
          ),
          // Series progress if applicable
          if (vaccineType != null &&
              vaccineType!.hasPuppySeries &&
              record.doseNumber != null) ...[
            const SizedBox(height: 12),
            _SeriesProgress(
              total: vaccineType!.puppySeries.length,
              current: record.doseNumber!,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 12, color: textSecondary),
              const SizedBox(width: 4),
              Text(
                'Given ${DateFormat('MMM d, yyyy').format(record.occurredOn)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: textSecondary, fontSize: 11),
              ),
              if (record.clinicName != null) ...[
                Text(' · ', style: TextStyle(color: textSecondary)),
                Icon(Icons.local_hospital_rounded,
                    size: 12, color: textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    record.clinicName!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SeriesProgress extends StatelessWidget {
  const _SeriesProgress({required this.total, required this.current});
  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Series: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
                fontSize: 11,
              ),
        ),
        ...List.generate(total, (i) {
          final done = i < current;
          return Container(
            width: 20,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: done
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
        const SizedBox(width: 4),
        Text(
          '$current / $total',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}
