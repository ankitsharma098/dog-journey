/// Mirrors one entry from `assets/data/triage_rules.json`.
/// The `level` here maps to the Postgres `triage_level` enum.
enum TriageLevel { emergency, urgent, routine, info }

extension TriageLevelX on TriageLevel {
  String get dbValue => name;
  static TriageLevel fromString(String v) => switch (v) {
        'emergency' => TriageLevel.emergency,
        'urgent' => TriageLevel.urgent,
        'routine' => TriageLevel.routine,
        _ => TriageLevel.info,
      };
}

class TriageRule {
  const TriageRule({
    required this.code,
    required this.level,
    required this.patterns,
    required this.negatePatterns,
    required this.breedFlags,
    required this.headline,
    required this.actionText,
  });

  final String code;
  final TriageLevel level;
  final List<String> patterns;
  final List<String> negatePatterns;
  final List<String> breedFlags;
  final String headline;
  final String actionText;

  factory TriageRule.fromJson(Map<String, dynamic> j) => TriageRule(
        code: j['code'] as String,
        level: TriageLevelX.fromString(j['level'] as String),
        patterns: (j['patterns'] as List<dynamic>).cast<String>(),
        negatePatterns:
            (j['negate_patterns'] as List<dynamic>? ?? const []).cast<String>(),
        breedFlags:
            (j['breed_flags'] as List<dynamic>? ?? const []).cast<String>(),
        headline: j['headline'] as String,
        actionText: j['action_text'] as String,
      );
}

class TriageResult {
  const TriageResult({
    required this.level,
    required this.headline,
    required this.actionText,
    required this.matchedCodes,
  });

  final TriageLevel level;
  final String headline;
  final String actionText;
  final List<String> matchedCodes;

  bool get isEmergency => level == TriageLevel.emergency;
  bool get isUrgent => level == TriageLevel.urgent;
}
