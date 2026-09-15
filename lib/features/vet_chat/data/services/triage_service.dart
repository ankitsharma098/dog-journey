import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../core/logging/app_logger.dart';
import '../models/triage_rule.dart';

/// Deterministic triage gate — PRD §7.3 "Urgency is deterministic,
/// never model-decided." Loaded once from the bundled JSON asset and
/// cached; matching is synchronous (~0ms), never touches the network.
///
/// Match algorithm:
///  1. Lowercase the full message text.
///  2. For each rule (rules are pre-sorted by level severity: emergency first).
///  3.   If ALL `patterns` appear as substrings AND NONE of `negatePatterns` appear → match.
///  4. Return the first (highest-severity) match, or null.
///
/// Accept: PRD §3 — "chocolate/xylitol/grapes" → emergency.
class TriageService {
  TriageService();

  List<TriageRule>? _rules;

  Future<List<TriageRule>> _loadRules() async {
    if (_rules != null) return _rules!;
    AppLogger.debug('TriageService loading triage_rules.json');
    final raw = await rootBundle.loadString('assets/data/triage_rules.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _rules = list
        .map((e) => TriageRule.fromJson(e as Map<String, dynamic>))
        .toList()
      // Sort: emergency → urgent → routine → info (highest risk first)
      ..sort((a, b) => _levelWeight(a.level).compareTo(_levelWeight(b.level)));
    AppLogger.info('TriageService loaded ${_rules!.length} rules');
    return _rules!;
  }

  /// Synchronous match after rules have been loaded once.
  /// Call [preload] at app start or chat screen init so the first
  /// real match has no latency.
  Future<void> preload() async => _loadRules();

  /// Returns the highest-severity [TriageResult] that matches [text],
  /// or null if no rule matches. Guaranteed < 500ms (all in-memory).
  Future<TriageResult?> match(String text, {String? breedId}) async {
    final rules = await _loadRules();
    final lower = text.toLowerCase();

    TriageResult? best;
    final allMatched = <String>[];

    for (final rule in rules) {
      // Skip breed-specific rules if breedId doesn't match
      if (rule.breedFlags.isNotEmpty &&
          breedId != null &&
          !rule.breedFlags.contains(breedId)) {
        // Still allow if breed is not specified (null) — be inclusive
        if (breedId.isNotEmpty) continue;
      }

      final allPatternsMatch =
          rule.patterns.every((p) => lower.contains(p.toLowerCase()));
      if (!allPatternsMatch) continue;

      final anyNegateMatch =
          rule.negatePatterns.any((n) => lower.contains(n.toLowerCase()));
      if (anyNegateMatch) continue;

      allMatched.add(rule.code);

      // Keep the first (highest-severity) match for headline + action
      best ??= TriageResult(
        level: rule.level,
        headline: rule.headline,
        actionText: rule.actionText,
        matchedCodes: allMatched,
      );
    }

    if (best != null && allMatched.length > 1) {
      // Rebuild with all matched codes
      return TriageResult(
        level: best.level,
        headline: best.headline,
        actionText: best.actionText,
        matchedCodes: allMatched,
      );
    }

    return best;
  }

  int _levelWeight(TriageLevel l) => switch (l) {
        TriageLevel.emergency => 0,
        TriageLevel.urgent => 1,
        TriageLevel.routine => 2,
        TriageLevel.info => 3,
      };
}
