import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../bloc/nutrition_cubit.dart';
import '../../data/models/nutrition_models.dart';

/// Bottom sheet to generate or update a feeding plan.
class GeneratePlanSheet extends StatefulWidget {
  const GeneratePlanSheet({super.key});

  @override
  State<GeneratePlanSheet> createState() => _GeneratePlanSheetState();
}

class _GeneratePlanSheetState extends State<GeneratePlanSheet> {
  PlanGoal _goal = PlanGoal.maintain;
  final _weightCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing plan values
    final existing = context.read<NutritionCubit>().state.activePlan;
    if (existing != null) {
      _goal = existing.goal;
      _weightCtrl.text = existing.basisWeightKg.toStringAsFixed(1);
      if (existing.targetWeightKg != null) {
        _targetCtrl.text = existing.targetWeightKg!.toStringAsFixed(1);
      }
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _targetCtrl.dispose();
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
      child: SingleChildScrollView(
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
              'Feeding plan',
              style: AppTextStyles.sheetTitle.copyWith(color: AppColors.textPrimary(brightness)),
            ),
            const SizedBox(height: 4),
            Text(
              'Calorie target uses the Resting Energy Requirement formula '
              '(70 × kg^0.75 × MER factor).',
              style: AppTextStyles.secondaryLine.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PlanGoal.values.map((g) {
                final selected = g == _goal;
                return GestureDetector(
                  onTap: () => setState(() => _goal = g),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: selected ? AppColors.accent.withValues(alpha: 0.18) : Colors.transparent,
                      border: Border.all(
                        color: selected ? AppColors.accent : AppColors.hairline(brightness),
                      ),
                    ),
                    child: Text(
                      g.label,
                      style: AppTextStyles.listRowTitle.copyWith(
                        fontSize: 12.5,
                        color: selected
                            ? AppColors.textPrimary(brightness)
                            : AppColors.textSecondary(brightness),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.body.copyWith(height: 1, color: AppColors.textPrimary(brightness)),
              decoration: const InputDecoration(hintText: 'Current weight (kg) — e.g. 15.5'),
            ),
            if (_goal == PlanGoal.lose || _goal == PlanGoal.gain) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTextStyles.body.copyWith(height: 1, color: AppColors.textPrimary(brightness)),
                decoration: const InputDecoration(hintText: 'Target weight (kg) — e.g. 12.0'),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _saving ? null : _generate,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text(
                  _saving ? 'Calculating…' : 'Generate plan',
                  style: AppTextStyles.listRowTitle.copyWith(color: AppColors.textPrimary(brightness)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    final w = double.tryParse(_weightCtrl.text.trim());
    if (w == null || w <= 0) {
      AppSnackbar.show(context, message: 'Please enter a valid weight.');
      return;
    }
    setState(() => _saving = true);
    await context.read<NutritionCubit>().generatePlan(
      goal: _goal,
      currentWeightKg: w,
      targetWeightKg: double.tryParse(_targetCtrl.text.trim()),
    );
    if (mounted) Navigator.of(context).pop();
  }
}
