import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/health_record.dart';

/// Curved line chart of weight records over time.
/// Uses RepaintBoundary as required by PRD coding standards.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.records});

  final List<HealthRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No weight records yet.\nAdd a weight entry to start tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondaryLight),
          ),
        ),
      );
    }

    final sorted = List<HealthRecord>.from(records)
      ..sort((a, b) => a.occurredOn.compareTo(b.occurredOn));

    final spots = sorted.indexed
        .map((e) => FlSpot(
              e.$1.toDouble(),
              (e.$2.weightKg ?? 0).toDouble(),
            ))
        .toList();

    final minY = (sorted
            .map((r) => r.weightKg ?? 0)
            .reduce((a, b) => a < b ? a : b) *
        0.95);
    final maxY = (sorted
            .map((r) => r.weightKg ?? 0)
            .reduce((a, b) => a > b ? a : b) *
        1.05);

    return RepaintBoundary(
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.dividerLight.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (sorted.length / 4).ceilToDouble().clamp(1, 9999),
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= sorted.length) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      DateFormat('MMM yy').format(sorted[idx].occurredOn),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondaryLight,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2.5,
                dotData: FlDotData(
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.primary,
                    strokeColor: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) {
                  final idx = s.x.toInt();
                  final d = sorted[idx];
                  return LineTooltipItem(
                    '${d.weightKg?.toStringAsFixed(1) ?? '?'} kg\n',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: DateFormat('MMM d, yyyy').format(d.occurredOn),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
