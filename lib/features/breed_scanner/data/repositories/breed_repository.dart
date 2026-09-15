import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../../core/logging/app_logger.dart';
import '../models/breed.dart';

/// Loads `assets/data/breeds.json` once and caches it in memory — a
/// bundled reference table (PRD §9), not a Firestore collection, so
/// there's no repeated network read to worry about.
class BreedRepository {
  List<Breed>? _cache;

  Future<List<Breed>> all() async {
    final cached = _cache;
    if (cached != null) return cached;

    AppLogger.debug('BreedRepository loading assets/data/breeds.json');
    final raw = await rootBundle.loadString('assets/data/breeds.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    final breeds = decoded
        .map((e) => Breed.fromJson(e as Map<String, dynamic>))
        .toList();
    AppLogger.info('BreedRepository loaded ${breeds.length} breed(s)');
    _cache = breeds;
    return breeds;
  }

  Future<Breed?> bySlug(String slug) async {
    final breeds = await all();
    for (final breed in breeds) {
      if (breed.slug == slug) return breed;
    }
    return null;
  }

  /// The full list of valid slugs, handed to the vision prompt so a
  /// model result resolves cleanly against this bundled reference
  /// data instead of inventing a name that doesn't join to anything.
  Future<List<String>> allSlugs() async => (await all()).map((b) => b.slug).toList();
}
