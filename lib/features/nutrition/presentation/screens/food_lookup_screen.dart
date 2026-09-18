import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/glass_container.dart';
import '../../../../core/widgets/glass/glass_scaffold.dart';
import '../../bloc/nutrition_cubit.dart';
import '../../data/models/nutrition_models.dart';

/// Food safety lookup screen — FREE, offline, bundled JSON.
class FoodLookupScreen extends StatefulWidget {
  const FoodLookupScreen({super.key});

  @override
  State<FoodLookupScreen> createState() => _FoodLookupScreenState();
}

class _FoodLookupScreenState extends State<FoodLookupScreen> {
  final _ctrl = TextEditingController();
  List<FoodItem> _results = [];

  @override
  void initState() {
    super.initState();
    // Show all items by default
    _results = context.read<NutritionCubit>().state.foodItems;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    final all = context.read<NutritionCubit>().state.foodItems;
    setState(() {
      if (q.trim().isEmpty) {
        _results = all;
      } else {
        _results = all
            .where((f) => f.name.toLowerCase().contains(q.toLowerCase()))
            .toList();
      }
    });
  }

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
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.textSecondary(brightness)),
              ),
              Text(
                'Food safety lookup',
                style: AppTextStyles.sheetTitle.copyWith(
                  fontSize: 17,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: AppTextStyles.body.copyWith(height: 1, color: AppColors.textPrimary(brightness)),
            decoration: InputDecoration(
              hintText: 'Search food or ingredient…',
              prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: AppColors.textTertiary(brightness)),
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _FoodItemTile(item: _results[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodItemTile extends StatelessWidget {
  const _FoodItemTile({required this.item});
  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final (color, icon, label) = switch (item.safety) {
      FoodSafety.toxic => (AppColors.dangerOn(brightness), PhosphorIconsFill.skull, 'TOXIC'),
      FoodSafety.caution => (AppColors.warningOn(brightness), PhosphorIconsFill.warning, 'CAUTION'),
      FoodSafety.safe => (AppColors.success, PhosphorIconsFill.checkCircle, 'SAFE'),
    };

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: GlassContainer(
        borderRadius: 14,
        border: true,
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          title: Text(
            item.name,
            style: AppTextStyles.listRowTitle.copyWith(color: AppColors.textPrimary(brightness)),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: AppTextStyles.chipLabel.copyWith(fontSize: 9.5, color: color),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                item.notes,
                style: AppTextStyles.secondaryLine.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
