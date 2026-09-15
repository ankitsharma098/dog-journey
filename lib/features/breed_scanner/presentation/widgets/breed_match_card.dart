import 'package:flutter/material.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/scan.dart';
import '../../data/repositories/breed_repository.dart';

/// One breed's share of a scan result. Percentage/confidence come
/// from the scan itself; the health-risk line is a lookup against the
/// bundled `breeds.json` reference data by [BreedMatch.breedSlug] —
/// `scans.result` only stores the light {slug, name, pct, confidence}
/// shape (db-design/01_breed_scanner.sql), the rich payload lives on
/// `breeds`.
class BreedMatchCard extends StatelessWidget {
  const BreedMatchCard({super.key, required this.match});

  final BreedMatch match;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lowConfidence = match.confidence < 0.6;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(match.name, style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(
                '${match.pct.round()}%',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (match.pct / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: isDark ? AppColors.chipFillDark : AppColors.chipFillLight,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          if (lowConfidence) ...[
            const SizedBox(height: 8),
            Text(
              'Best guess — lower confidence match',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ],
          FutureBuilder(
            future: getIt<BreedRepository>().bySlug(match.breedSlug),
            builder: (context, snapshot) {
              final risks = snapshot.data?.healthRisks ?? const [];
              if (risks.isEmpty) return const SizedBox.shrink();
              final names = risks
                  .map((r) => r['condition'] as String? ?? '')
                  .where((s) => s.isNotEmpty)
                  .join(', ');
              if (names.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Common health watch-outs: $names',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
