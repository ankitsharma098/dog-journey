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
import '../../../../core/widgets/royal/section_link_header.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../bloc/nutrition_cubit.dart';
import '../../data/models/nutrition_models.dart';
import 'food_lookup_screen.dart';
import 'generate_plan_sheet.dart';

/// The Nutrition tab — conic kcal ring, champagne treat-budget bar,
/// and "usuals" quick-add chips. See README § "8. Nutrition".
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetsBloc, PetsState>(
      builder: (context, petsState) {
        final pet = petsState.activePet;
        if (pet == null) return const SizedBox.shrink();
        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final userId = authState is AuthAuthenticated
                ? authState.profile.uid
                : '';
            return BlocProvider(
              key: ValueKey(pet.id),
              create: (_) => NutritionCubit(
                petId: pet.id,
                currentUserId: userId,
                feedingPlanRepository: context.read(),
                foodLogRepository: context.read(),
                foodItemRepository: context.read(),
              ),
              child: _NutritionView(petName: pet.name),
            );
          },
        );
      },
    );
  }
}

class _NutritionView extends StatelessWidget {
  const _NutritionView({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return GlassScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
      body: BlocBuilder<NutritionCubit, NutritionState>(
        builder: (context, state) {
          if (state.status == NutritionStatus.loading) {
            return const AsyncStateView.loading();
          }
          if (state.status == NutritionStatus.error) {
            return AsyncStateView.error(
              failure: ServerFailure(
                state.errorMessage ?? 'Something went wrong.',
              ),
              onRetry: () => context.read<NutritionCubit>().retry(),
            );
          }
          return ListView(
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EngravedLabel('Today'),
                      const SizedBox(height: 3),
                      Text(
                        'Nutrition',
                        style: AppTextStyles.screenTitleCompact.copyWith(
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      final cubit = context.read<NutritionCubit>();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: cubit,
                            child: const FoodLookupScreen(),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppColors.hairline(brightness),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 16,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (state.activePlan == null)
                _GeneratePlanCta(petName: petName)
              else
                _RingCard(state: state),
              const SizedBox(height: 24),
              SectionLinkHeader(title: 'Quick add'),
              const SizedBox(height: 10),
              if (state.quickAddItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Log a meal once and it shows up here for next time.',
                    style: AppTextStyles.secondaryLine.copyWith(
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ),
              _QuickAddRow(items: state.quickAddItems),
              const SizedBox(height: 24),
              Text(
                'Logged today',
                style: AppTextStyles.sectionHeading.copyWith(
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: 10),
              if (state.todayLogs.isEmpty)
                Text(
                  'Nothing logged yet today.',
                  style: AppTextStyles.secondaryLine.copyWith(
                    color: AppColors.textSecondary(brightness),
                  ),
                )
              else
                Column(
                  children: [
                    for (final log in state.todayLogs) ...[
                      _LogRow(log: log),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ring card
// ---------------------------------------------------------------------------
class _RingCard extends StatelessWidget {
  const _RingCard({required this.state});
  final NutritionState state;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final plan = state.activePlan!;
    final target = plan.dailyKcal;
    final consumed = state.totalKcalToday;
    final progress = target == 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    final remaining = (target - consumed).clamp(0, target);
    final treatUsed = state.treatKcalToday;
    final treatBudget = plan.treatBudgetKcal;
    final treatPct = treatBudget == 0
        ? 0.0
        : (treatUsed / treatBudget).clamp(0.0, 1.0);
    final isOver = consumed >= target;

    return GlassContainer(
      borderRadius: 22,
      border: true,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          _KcalRing(
            progress: progress,
            danger: isOver,
            consumed: consumed,
            target: target,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remaining',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10.5,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                Text(
                  '$remaining kcal',
                  style: AppTextStyles.listRowTitle.copyWith(
                    fontSize: 15,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Treat budget',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10.5,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                Text(
                  '$treatUsed / $treatBudget kcal',
                  style: AppTextStyles.listRowTitle.copyWith(
                    fontSize: 15,
                    color: AppColors.champagneOn(brightness),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: treatPct,
                    minHeight: 5,
                    backgroundColor: AppColors.hairline(brightness),
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.champagneOn(brightness),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KcalRing extends StatelessWidget {
  const _KcalRing({
    required this.progress,
    required this.danger,
    required this.consumed,
    required this.target,
  });

  final double progress;
  final bool danger;
  final int consumed;
  final int target;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      width: 124,
      height: 124,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          trackColor: AppColors.hairline(brightness),
          progressColor: danger
              ? AppColors.dangerOn(brightness)
              : AppColors.accent,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$consumed',
                style: AppTextStyles.screenTitle.copyWith(
                  fontSize: 24,
                  color: AppColors.accentLight,
                ),
              ),
              Text(
                'of $target kcal',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
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

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - strokeWidth) / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final fg = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708, // -90deg
        6.2832 * progress, // 360deg * progress
        false,
        fg,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}

// ---------------------------------------------------------------------------
// Quick add
// ---------------------------------------------------------------------------
class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow({required this.items});
  final List<FoodLog> items;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          GestureDetector(
            onTap: () => context.read<NutritionCubit>().logFood(
              itemText: item.itemText,
              category: item.category,
              kcal: item.kcal,
              foodItemId: item.foodItemId,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card(brightness),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.hairline(brightness)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.itemText,
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  if (item.kcal != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${item.kcal}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary(brightness),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        GestureDetector(
          onTap: () => _showLogFood(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              '+ Custom',
              style: AppTextStyles.listRowTitle.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.accentLight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogFood(BuildContext context) {
    final cubit = context.read<NutritionCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _LogFoodSheet()),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});
  final FoodLog log;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GlassContainer(
      borderRadius: 15,
      border: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(
            log.category == LogCategory.treat
                ? PhosphorIconsFill.cookie
                : PhosphorIconsFill.bowlFood,
            size: 16,
            color: AppColors.textSecondary(brightness),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              log.itemText,
              style: AppTextStyles.listRowTitle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(brightness),
              ),
            ),
          ),
          if (log.kcal != null)
            Text(
              '${log.kcal} kcal',
              style: AppTextStyles.listRowTitle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.read<NutritionCubit>().deleteLog(log.id),
            child: Icon(
              PhosphorIconsRegular.x,
              size: 14,
              color: AppColors.dangerOn(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generate plan CTA
// ---------------------------------------------------------------------------
class _GeneratePlanCta extends StatelessWidget {
  const _GeneratePlanCta({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: () {
        // Read before opening the sheet, not inside `builder` — that
        // closure can be re-invoked by the sheet's own route rebuilds
        // after this widget's context has been deactivated (e.g. the
        // parent rebuilding while the sheet is still animating in),
        // and `context.read` on a deactivated context throws "Looking
        // up a deactivated widget's ancestor is unsafe".
        final cubit = context.read<NutritionCubit>();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: const GeneratePlanSheet(),
          ),
        );
      },
      child: GlassContainer(
        borderRadius: 20,
        border: true,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(
                PhosphorIconsFill.calculator,
                color: AppColors.accentLight,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generate feeding plan',
                    style: AppTextStyles.listRowTitle.copyWith(
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Calculate exactly how much to feed $petName',
                    style: AppTextStyles.secondaryLine.copyWith(
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: AppColors.textTertiary(brightness),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Log food sheet (custom entry, for items not in "usuals")
// ---------------------------------------------------------------------------
class _LogFoodSheet extends StatefulWidget {
  const _LogFoodSheet();

  @override
  State<_LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends State<_LogFoodSheet> {
  final _nameCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  LogCategory _category = LogCategory.meal;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sheet(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: AppColors.hairline(brightness))),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 26 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.textPrimary(brightness).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Log food',
            style: AppTextStyles.sheetTitle.copyWith(
              color: AppColors.textPrimary(brightness),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: AppTextStyles.body.copyWith(
              height: 1,
              color: AppColors.textPrimary(brightness),
            ),
            decoration: const InputDecoration(
              hintText: 'e.g. Royal Canin kibble',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kcalCtrl,
            keyboardType: TextInputType.number,
            style: AppTextStyles.body.copyWith(
              height: 1,
              color: AppColors.textPrimary(brightness),
            ),
            decoration: const InputDecoration(
              hintText: 'Calories (kcal, optional)',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: LogCategory.values.map((c) {
              final selected = c == _category;
              return GestureDetector(
                onTap: () => setState(() => _category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.accent
                          : AppColors.hairline(brightness),
                    ),
                  ),
                  child: Text(
                    c.label,
                    style: AppTextStyles.listRowTitle.copyWith(
                      fontSize: 12,
                      color: selected
                          ? AppColors.textPrimary(brightness)
                          : AppColors.textSecondary(brightness),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _saving ? null : _save,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                _saving ? 'Saving…' : 'Log it',
                style: AppTextStyles.listRowTitle.copyWith(
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await context.read<NutritionCubit>().logFood(
      itemText: name,
      category: _category,
      kcal: int.tryParse(_kcalCtrl.text.trim()),
    );
    if (mounted) Navigator.of(context).pop();
  }
}
