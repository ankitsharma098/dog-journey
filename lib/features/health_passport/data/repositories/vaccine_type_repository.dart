import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/vaccine_type.dart';

/// Loads `assets/data/vaccine_types.json` once and caches in memory.
/// Same offline-first pattern as BreedRepository — no Supabase reads.
class VaccineTypeRepository {
  VaccineTypeRepository();

  List<VaccineType>? _cache;

  Future<List<VaccineType>> all() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/vaccine_types.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _cache = list.map((e) => VaccineType.fromJson(e as Map<String, dynamic>)).toList();
    return _cache!;
  }

  Future<VaccineType?> byId(String id) async {
    final all_ = await all();
    try {
      return all_.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<VaccineType>> coreVaccines() async {
    final all_ = await all();
    return all_.where((v) => v.isCore).toList();
  }
}
