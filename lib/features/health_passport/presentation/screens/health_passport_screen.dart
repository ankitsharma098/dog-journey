import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/glass/glass_container.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../../core/widgets/royal/engraved_label.dart';
import '../../../../core/widgets/royal/segmented_track.dart';
import '../../../../core/widgets/royal/status_chip.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../../pets/data/models/pet.dart';
import '../../bloc/health_passport_cubit.dart';
import '../../data/models/health_record.dart';
import '../../data/models/vaccine_type.dart';

/// The Health Passport tab — segmented Timeline / Vaccines / Meds /
/// Weight, matching design-ref/design_handoff_royal_redesign/README.md
/// § "3. Health Passport". Adding a record now happens behind the
/// shell's centre FAB (see HomeShell) rather than a local FAB here.
class HealthPassportScreen extends StatelessWidget {
  const HealthPassportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetsBloc, PetsState>(
      builder: (context, petsState) {
        final pet = petsState.activePet;
        if (pet == null) return const _EmptyPassportView();

        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final userId = authState is AuthAuthenticated
                ? authState.profile.uid
                : '';
            return BlocProvider(
              key: ValueKey(pet.id),
              create: (_) => HealthPassportCubit(
                petId: pet.id,
                currentUserId: userId,
                healthRecordRepository: context.read(),
                vaccineTypeRepository: context.read(),
              ),
              child: _PassportView(pet: pet),
            );
          },
        );
      },
    );
  }
}

class _PassportView extends StatefulWidget {
  const _PassportView({required this.pet});
  final Pet pet;

  @override
  State<_PassportView> createState() => _PassportViewState();
}

class _PassportViewState extends State<_PassportView> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return GlassScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EngravedLabel('Health passport'),
                    const SizedBox(height: 3),
                    Text(
                      widget.pet.name,
                      style: AppTextStyles.screenTitleCompact.copyWith(
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              _ExportButton(pet: widget.pet),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedTrack(
            labels: const ['Timeline', 'Vaccines', 'Meds', 'Weight'],
            index: _tabIndex,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BlocBuilder<HealthPassportCubit, HealthPassportState>(
              builder: (context, state) {
                if (state.status == HealthPassportStatus.loading) {
                  return const AsyncStateView.loading();
                }
                if (state.status == HealthPassportStatus.error) {
                  return AsyncStateView.error(
                    failure: ServerFailure(
                      state.errorMessage ?? 'Something went wrong.',
                    ),
                    onRetry: () => context.read<HealthPassportCubit>().retry(),
                  );
                }
                return IndexedStack(
                  index: _tabIndex,
                  children: [
                    _TimelineTab(records: state.records),
                    _VaccinesTab(
                      records: state.vaccines,
                      types: state.vaccineTypes,
                    ),
                    _MedsTab(records: state.medications),
                    _WeightTab(records: state.weightRecords),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------
class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF export — coming soon.')),
        );
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.hairline(brightness)),
        ),
        alignment: Alignment.center,
        child: Icon(
          PhosphorIconsRegular.export,
          size: 16,
          color: AppColors.textSecondary(brightness),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline tab
// ---------------------------------------------------------------------------
class _TimelineTab extends StatelessWidget {
  const _TimelineTab({required this.records});
  final List<HealthRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _EmptyState(
        icon: PhosphorIconsRegular.folderOpen,
        title: 'No records yet',
        subtitle: 'Add a health record from the ＋ menu to start the timeline.',
      );
    }
    final brightness = Theme.of(context).brightness;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 150),
      itemCount: records.length,
      itemBuilder: (context, i) {
        final r = records[i];
        final isLast = i == records.length - 1;
        final dotColor = r.type == RecordType.vaccine
            ? AppColors.champagneOn(brightness)
            : AppColors.accentOn(brightness);
        // IntrinsicHeight gives the Row a finite height to stretch into —
        // without it, a ListView item's unbounded height makes
        // CrossAxisAlignment.stretch degenerate (the rail's Expanded
        // connector line has nothing finite to expand into).
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 22,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1,
                          color: AppColors.hairline(brightness),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: GlassContainer(
                    borderRadius: 16,
                    border: true,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                r.title,
                                style: AppTextStyles.listRowTitle.copyWith(
                                  fontSize: 13.5,
                                  color: AppColors.textPrimary(brightness),
                                ),
                              ),
                            ),
                            Text(
                              _formatDate(r.occurredOn),
                              style: AppTextStyles.mono.copyWith(
                                color: AppColors.textTertiary(brightness),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _subtitle(r),
                          style: AppTextStyles.secondaryLine.copyWith(
                            color: AppColors.textSecondary(brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _subtitle(HealthRecord r) {
    if (r.type == RecordType.weight && r.weightKg != null) {
      return '${r.weightKg!.toStringAsFixed(1)} kg';
    }
    if (r.clinicName != null) return r.clinicName!;
    if (r.dosageText != null) return r.dosageText!;
    return r.type.label;
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Vaccines tab
// ---------------------------------------------------------------------------
class _VaccinesTab extends StatelessWidget {
  const _VaccinesTab({required this.records, required this.types});
  final List<HealthRecord> records;
  final List<VaccineType> types;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _EmptyState(
        icon: PhosphorIconsRegular.syringe,
        title: 'No vaccines recorded',
        subtitle: 'Add a vaccine record to track the immunisation schedule.',
      );
    }
    final brightness = Theme.of(context).brightness;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 150),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = records[i];
        final now = DateTime.now();
        final due = r.dueOn;
        final (label, color) = due == null
            ? ('CURRENT', AppColors.success)
            : due.isBefore(now)
            ? ('OVERDUE', AppColors.dangerOn(brightness))
            : due.difference(now).inDays <= 30
            ? ('DUE SOON', AppColors.warningOn(brightness))
            : ('CURRENT', AppColors.success);

        return GlassContainer(
          borderRadius: 16,
          border: true,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(PhosphorIconsFill.syringe, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: AppTextStyles.listRowTitle.copyWith(
                        fontSize: 13.5,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Given ${_formatDate(r.occurredOn)}',
                      style: AppTextStyles.secondaryLine.copyWith(
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: label,
                background: color.withValues(alpha: 0.14),
                foreground: color,
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Meds tab
// ---------------------------------------------------------------------------
class _MedsTab extends StatelessWidget {
  const _MedsTab({required this.records});
  final List<HealthRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _EmptyState(
        icon: PhosphorIconsRegular.pill,
        title: 'No active medications',
        subtitle: 'Add a medication to track its course.',
      );
    }
    final brightness = Theme.of(context).brightness;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 150),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = records[i];
        final totalDays = r.endsOn?.difference(r.occurredOn).inDays;
        final elapsedDays = totalDays == null
            ? null
            : DateTime.now()
                  .difference(r.occurredOn)
                  .inDays
                  .clamp(0, totalDays);
        final progress = (totalDays != null && totalDays > 0)
            ? elapsedDays! / totalDays
            : null;
        final subtitle = [
          if (r.dosageText != null) r.dosageText,
          if (r.frequencyText != null) r.frequencyText,
        ].whereType<String>().join(' · ');

        return GlassContainer(
          borderRadius: 16,
          border: true,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.title,
                style: AppTextStyles.listRowTitle.copyWith(
                  fontSize: 13.5,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle.isEmpty ? 'Ongoing' : subtitle,
                style: AppTextStyles.secondaryLine.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: AppColors.hairline(brightness),
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Weight tab
// ---------------------------------------------------------------------------
class _WeightTab extends StatelessWidget {
  const _WeightTab({required this.records});
  final List<HealthRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _EmptyState(
        icon: PhosphorIconsRegular.scales,
        title: 'No weight records yet',
        subtitle: 'Add a weight entry to start tracking the trend.',
      );
    }
    final brightness = Theme.of(context).brightness;
    final sorted = [...records]
      ..sort((a, b) => a.occurredOn.compareTo(b.occurredOn));
    final current = sorted.last.weightKg ?? 0;
    final previous = sorted.length > 1
        ? sorted[sorted.length - 2].weightKg
        : null;
    final delta = previous == null ? null : current - previous;
    final window = sorted.length > 6
        ? sorted.sublist(sorted.length - 6)
        : sorted;

    return ListView(
      padding: const EdgeInsets.only(bottom: 150),
      children: [
        GlassContainer(
          borderRadius: 18,
          border: true,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${current.toStringAsFixed(1)} kg',
                    style: AppTextStyles.screenTitle.copyWith(
                      fontSize: 26,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  if (delta != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} since last',
                      style: AppTextStyles.listRowTitle.copyWith(
                        fontSize: 11,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              _WeightBarChart(records: window),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _reading(sorted),
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary(brightness),
          ),
        ),
      ],
    );
  }

  String _reading(List<HealthRecord> sorted) {
    if (sorted.length < 2) return 'Add another weigh-in to see the trend.';
    final first = sorted.first.weightKg ?? 0;
    final last = sorted.last.weightKg ?? 0;
    final diff = last - first;
    if (diff.abs() < 0.3) return 'Weight has held steady over this period.';
    return diff > 0
        ? 'Up ${diff.toStringAsFixed(1)} kg over this period.'
        : 'Down ${diff.abs().toStringAsFixed(1)} kg over this period.';
  }
}

class _WeightBarChart extends StatelessWidget {
  const _WeightBarChart({required this.records});
  final List<HealthRecord> records;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final weights = records.map((r) => r.weightKg ?? 0).toList();
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final range = (maxW - minW).clamp(0.5, double.infinity);

    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final r in records) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 14 + (((r.weightKg ?? 0) - minW) / range) * 76,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.accent, AppColors.accentDeep],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _monthLabel(r.occurredOn),
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 9,
                      color: AppColors.textTertiary(brightness),
                    ),
                  ),
                ],
              ),
            ),
            if (r != records.last) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[d.month - 1];
  }
}

// ---------------------------------------------------------------------------
// Empty states
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textTertiary(brightness)),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.sectionHeading.copyWith(
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.secondaryLine.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPassportView extends StatelessWidget {
  const _EmptyPassportView();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GlassScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsRegular.identificationCard,
                size: 56,
                color: AppColors.textTertiary(brightness),
              ),
              const SizedBox(height: 16),
              Text(
                'No dog selected',
                style: AppTextStyles.sectionHeading.copyWith(
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your dog to track vaccinations, medications, weight and health records.',
                textAlign: TextAlign.center,
                style: AppTextStyles.secondaryLine.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
