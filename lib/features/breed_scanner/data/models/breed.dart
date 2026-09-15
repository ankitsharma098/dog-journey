/// Mirrors db-design/00_core.sql `breeds`. Bundled as a JSON asset
/// (assets/data/breeds.json), not a Firestore collection — see
/// [BreedRepository] and PRD §9 ("reference tables ship as bundled
/// JSON assets — zero reads, works offline"). [id] is the row's
/// `slug` since there's no database to hand out a UUID; it's also
/// what a [Scan] result's `breed_slug` joins against.
class Breed {
  const Breed({
    required this.id,
    this.species = 'dog',
    required this.slug,
    required this.name,
    this.sizeClass = 'medium',
    this.weightKgMin,
    this.weightKgMax,
    this.lifespanYears,
    this.riskFlags = const [],
    this.traits = const {},
    this.healthRisks = const [],
    this.careGuide = const {},
    this.isMixed = false,
  });

  final String id;
  final String species;
  final String slug;
  final String name;
  final String sizeClass; // small | medium | large
  final double? weightKgMin;
  final double? weightKgMax;
  final double? lifespanYears;
  final List<String> riskFlags; // brachycephalic | deep_chested | long_backed
  final Map<String, dynamic> traits; // {energy, shedding, trainability, ...} 1-5
  final List<Map<String, dynamic>> healthRisks; // [{condition, severity, screen}]
  final Map<String, dynamic> careGuide; // {feeding, exercise, grooming}
  final bool isMixed;

  factory Breed.fromJson(Map<String, dynamic> json) => Breed(
    id: json['slug'] as String,
    species: json['species'] as String? ?? 'dog',
    slug: json['slug'] as String,
    name: json['name'] as String,
    sizeClass: json['size_class'] as String? ?? 'medium',
    weightKgMin: (json['weight_kg_min'] as num?)?.toDouble(),
    weightKgMax: (json['weight_kg_max'] as num?)?.toDouble(),
    lifespanYears: (json['lifespan_years'] as num?)?.toDouble(),
    riskFlags: (json['risk_flags'] as List<dynamic>? ?? const []).cast<String>(),
    traits: (json['traits'] as Map<String, dynamic>? ?? const {}),
    healthRisks: (json['health_risks'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>(),
    careGuide: (json['care_guide'] as Map<String, dynamic>? ?? const {}),
    isMixed: json['is_mixed'] as bool? ?? false,
  );
}
