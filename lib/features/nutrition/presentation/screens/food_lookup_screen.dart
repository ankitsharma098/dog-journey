import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Food Safety Lookup',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search food or ingredient…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onChanged: _search,
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _results.length,
        itemBuilder: (_, i) => _FoodItemTile(item: _results[i]),
      ),
    );
  }
}

class _FoodItemTile extends StatelessWidget {
  const _FoodItemTile({required this.item});
  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (item.safety) {
      FoodSafety.toxic => (AppColors.danger, Icons.dangerous_rounded, 'TOXIC'),
      FoodSafety.caution =>
        (AppColors.warning, Icons.warning_amber_rounded, 'CAUTION'),
      FoodSafety.safe => (AppColors.success, Icons.check_circle_rounded, 'SAFE'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              item.notes,
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
