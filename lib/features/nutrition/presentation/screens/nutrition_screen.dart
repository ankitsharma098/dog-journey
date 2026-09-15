import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../../../core/widgets/glass/glass_container.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../pets/bloc/pets_bloc.dart';
import '../../bloc/nutrition_cubit.dart';
import '../../data/models/nutrition_models.dart';
import 'food_lookup_screen.dart';
import 'generate_plan_sheet.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetsBloc, PetsState>(
      builder: (context, petsState) {
        final pet = petsState.pets.isNotEmpty ? petsState.pets.first : null;
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
    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          'Nutrition',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Food lookup',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<NutritionCubit>(),
                  child: const FoodLookupScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              // kcal ring + plan summary
              _KcalRingCard(state: state),
              const SizedBox(height: 12),
              // Treat counter
              if (state.activePlan != null) ...[
                _TreatCounterCard(state: state),
                const SizedBox(height: 12),
              ],
              // Today's food log
              _TodayLogCard(state: state),
              const SizedBox(height: 12),
              // Plan action
              if (state.activePlan == null) _GeneratePlanCta(petName: petName),
            ],
          );
        },
      ),
      floatingActionButton: BlocBuilder<NutritionCubit, NutritionState>(
        builder: (context, state) => FloatingActionButton.extended(
          heroTag: 'nutritionFab',
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.restaurant_rounded),
          label: const Text('Log Food'),
          onPressed: () => _showLogFood(context),
        ),
      ),
    );
  }

  void _showLogFood(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<NutritionCubit>(),
        child: const _LogFoodSheet(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// kcal Ring Card
// ---------------------------------------------------------------------------
class _KcalRingCard extends StatelessWidget {
  const _KcalRingCard({required this.state});
  final NutritionState state;

  @override
  Widget build(BuildContext context) {
    final plan = state.activePlan;
    final target = plan?.dailyKcal ?? 0;
    final consumed = state.totalKcalToday;
    final progress = target == 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    final remaining = (target - consumed).clamp(0, target);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Daily Calories',
                style: GoogleFonts.sora(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              if (plan != null)
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => BlocProvider.value(
                      value: context.read<NutritionCubit>(),
                      child: const GeneratePlanSheet(),
                    ),
                  ),
                  child: Text(
                    'Edit plan',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Ring chart
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sections: [
                          PieChartSectionData(
                            value: progress * 100,
                            color: progress >= 1.0
                                ? AppColors.danger
                                : AppColors.primary,
                            radius: 18,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: (1 - progress) * 100,
                            color: AppColors.primary.withValues(alpha: 0.1),
                            radius: 18,
                            showTitle: false,
                          ),
                        ],
                        centerSpaceRadius: 45,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$consumed',
                          style: GoogleFonts.sora(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'kcal',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow(
                      label: 'Target',
                      value: plan != null ? '$target kcal' : '—',
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      label: 'Remaining',
                      value: plan != null ? '$remaining kcal' : '—',
                      color: remaining == 0
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      label: 'Treat budget',
                      value: plan != null
                          ? '${plan.treatBudgetKcal} kcal'
                          : '—',
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondaryLight,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Treat Counter
// ---------------------------------------------------------------------------
class _TreatCounterCard extends StatelessWidget {
  const _TreatCounterCard({required this.state});
  final NutritionState state;

  @override
  Widget build(BuildContext context) {
    final plan = state.activePlan!;
    final treatKcal = state.treatKcalToday;
    final budget = plan.treatBudgetKcal;
    final exceeded = state.treatBudgetExceeded;

    return GlassCard(
      child: Row(
        children: [
          Icon(
            exceeded ? Icons.warning_rounded : Icons.cookie_rounded,
            color: exceeded ? AppColors.warning : AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exceeded ? 'Treat budget exceeded!' : 'Treat counter',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: exceeded
                        ? AppColors.warning
                        : AppColors.textPrimaryLight,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$treatKcal / $budget kcal (10% rule)',
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 12,
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

// ---------------------------------------------------------------------------
// Today's Food Log
// ---------------------------------------------------------------------------
class _TodayLogCard extends StatelessWidget {
  const _TodayLogCard({required this.state});
  final NutritionState state;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Food Log",
            style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (state.todayLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Nothing logged yet today.',
                  style: TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...state.todayLogs.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      log.category == LogCategory.treat
                          ? Icons.cookie_rounded
                          : Icons.restaurant_rounded,
                      size: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.itemText,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (log.kcal != null)
                      Text(
                        '${log.kcal} kcal',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () =>
                          context.read<NutritionCubit>().deleteLog(log.id),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generate Plan CTA
// ---------------------------------------------------------------------------
class _GeneratePlanCta extends StatelessWidget {
  const _GeneratePlanCta({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: context.read<NutritionCubit>(),
          child: const GeneratePlanSheet(),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calculate_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate feeding plan',
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Calculate exactly how much to feed $petName',
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondaryLight,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Log Food Bottom Sheet (inline)
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
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.cardDark
            : AppColors.cardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Log Food',
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Food item',
              hintText: 'e.g. Royal Canin kibble',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kcalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: InputDecoration(
              labelText: 'Calories (kcal, optional)',
              hintText: 'e.g. 350',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: LogCategory.values
                .map(
                  (c) => ChoiceChip(
                    label: Text(c.label),
                    selected: c == _category,
                    onSelected: (v) {
                      if (v) setState(() => _category = c);
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Log'),
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
