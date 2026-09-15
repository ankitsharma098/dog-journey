import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/nutrition_models.dart';

/// Loads `assets/data/food_items.json` once (bundled, offline, zero API).
/// Used for instant food safety lookup — a FREE feature per PRD.
class FoodItemRepository {
  FoodItemRepository();

  List<FoodItem>? _cache;

  Future<List<FoodItem>> all() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/food_items.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _cache = list.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList();
    return _cache!;
  }

  /// Instant search — name contains [query], case-insensitive.
  Future<List<FoodItem>> search(String query) async {
    if (query.trim().isEmpty) return all();
    final q = query.toLowerCase();
    return (await all()).where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  /// Safety lookup for a specific food name.
  Future<FoodItem?> lookup(String name) async {
    final q = name.toLowerCase();
    return (await all()).cast<FoodItem?>().firstWhere(
          (f) => f!.name.toLowerCase().contains(q),
          orElse: () => null,
        );
  }
}
