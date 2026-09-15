import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../bloc/nutrition_cubit.dart';
import '../../data/models/nutrition_models.dart';
import '../../../../core/widgets/app_snackbar.dart';

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
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.cardDark
            : AppColors.cardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Feeding Plan',
              style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Calorie target is calculated using the Resting Energy Requirement formula (70 × kg^0.75 × MER factor).',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Goal selector
            Text('Goal', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PlanGoal.values.map((g) => ChoiceChip(
                label: Text(g.label),
                selected: g == _goal,
                onSelected: (v) { if (v) setState(() => _goal = g); },
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: g == _goal ? AppColors.primary : AppColors.textSecondaryLight,
                  fontWeight: g == _goal ? FontWeight.w600 : FontWeight.normal,
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Current weight (kg)',
                hintText: 'e.g. 15.5',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_goal == PlanGoal.lose || _goal == PlanGoal.gain) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Target weight (kg)',
                  hintText: 'e.g. 12.0',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: _saving ? 'Calculating…' : 'Generate Plan',
              onPressed: _saving ? null : _generate,
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
