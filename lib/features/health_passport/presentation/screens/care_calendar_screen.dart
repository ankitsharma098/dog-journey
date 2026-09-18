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
import '../../../../core/widgets/royal/fading_rule.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../bloc/care_calendar_cubit.dart';
import '../../data/models/health_record.dart';
import '../../data/repositories/health_record_repository.dart';

/// The "Care calendar" — Overdue / This month / Later, with a Done
/// action that completes a reminder in place. Reached from Home's
/// "Needs you this week" → "All care" link.
class CareCalendarScreen extends StatelessWidget {
  const CareCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetsBloc, PetsState>(
      builder: (context, petsState) {
        final pet = petsState.activePet;
        if (pet == null) return const SizedBox.shrink();
        return BlocProvider(
          key: ValueKey(pet.id),
          create: (_) => CareCalendarCubit(
            petId: pet.id,
            healthRecordRepository: context.read<HealthRecordRepository>(),
          ),
          child: const _CareCalendarView(),
        );
      },
    );
  }
}

class _CareCalendarView extends StatelessWidget {
  const _CareCalendarView();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GlassScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      body: BlocBuilder<CareCalendarCubit, CareCalendarState>(
        builder: (context, state) {
          if (state.status == CareCalendarStatus.loading) {
            return const AsyncStateView.loading();
          }
          if (state.status == CareCalendarStatus.error) {
            return AsyncStateView.error(
              failure: ServerFailure(
                state.errorMessage ?? 'Something went wrong.',
              ),
            );
          }
          return ListView(
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 14),
                label: const Text('Home'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  foregroundColor: AppColors.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Care calendar',
                style: AppTextStyles.screenTitle.copyWith(
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Nothing quietly lapses. Every due date lives here and nudges you twice.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: 22),
              _CareGroup(
                label: 'Overdue',
                color: AppColors.dangerOn(brightness),
                records: state.overdue,
              ),
              _CareGroup(
                label: 'This month',
                color: AppColors.warningOn(brightness),
                records: state.thisMonth,
              ),
              _CareGroup(
                label: 'Later',
                color: AppColors.textTertiary(brightness),
                records: state.later,
              ),
              if (state.overdue.isEmpty &&
                  state.thisMonth.isEmpty &&
                  state.later.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Nothing due — you\'re all caught up.',
                    style: AppTextStyles.secondaryLine.copyWith(
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CareGroup extends StatelessWidget {
  const _CareGroup({
    required this.label,
    required this.color,
    required this.records,
  });
  final String label;
  final Color color;
  final List<HealthRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EngravedLabel(label, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: FadingRule(
                  color: color.withValues(alpha: 0.3),
                  fadeStart: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final record in records) ...[
            _CareCalendarRow(record: record),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _CareCalendarRow extends StatelessWidget {
  const _CareCalendarRow({required this.record});
  final HealthRecord record;

  IconData get _icon => switch (record.type) {
    RecordType.vaccine => PhosphorIconsFill.syringe,
    RecordType.medication => PhosphorIconsFill.pill,
    RecordType.weight => PhosphorIconsFill.scales,
    _ => PhosphorIconsFill.calendarBlank,
  };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GlassContainer(
      borderRadius: 16,
      border: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(_icon, size: 16, color: AppColors.accentLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: AppTextStyles.listRowTitle.copyWith(
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record.clinicName == null
                      ? _dueLabel(record.dueOn!)
                      : '${_dueLabel(record.dueOn!)} · ${record.clinicName}',
                  style: AppTextStyles.secondaryLine.copyWith(
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () =>
                context.read<CareCalendarCubit>().complete(record.id),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
              foregroundColor: AppColors.accentLight,
              textStyle: AppTextStyles.chipLabel.copyWith(letterSpacing: 0),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _dueLabel(DateTime dueOn) {
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
    return 'Due ${dueOn.day} ${months[dueOn.month - 1]}';
  }
}
