/// Mirrors supabase/migrations/0001_init.sql `pets`. `species` is
/// always `'dog'` in this build — the column exists so the same schema
/// ships CatJourney later (PRD §13) without a picker cluttering v1's
/// UI. `breedId` is a `breeds.json` slug (e.g. "golden-retriever"), not
/// a foreign key — breeds are a bundled asset, never a database table.
class Pet {
  const Pet({
    this.id = '',
    required this.ownerId,
    this.species = 'dog',
    required this.name,
    this.sex = 'unknown',
    this.birthdate,
    this.birthdateIsEstimate = false,
    this.adoptedDate,
    this.isNeutered,
    this.photoUrl,
    this.breedId,
    this.breedMix = const [],
    this.weightKg,
    this.allergies = const [],
  });

  final String id;
  final String ownerId;
  final String species;
  final String name;
  final String sex; // male | female | unknown
  final DateTime? birthdate;
  final bool birthdateIsEstimate;
  final DateTime? adoptedDate;
  final bool? isNeutered;
  final String? photoUrl;
  final String? breedId;
  final List<Map<String, dynamic>> breedMix; // [{breed_id, name, pct}]
  final double? weightKg;
  final List<String> allergies;

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
    id: json['id'] as String,
    ownerId: json['owner_id'] as String,
    species: json['species'] as String? ?? 'dog',
    name: json['name'] as String,
    sex: json['sex'] as String? ?? 'unknown',
    birthdate: json['birthdate'] == null
        ? null
        : DateTime.parse(json['birthdate'] as String),
    birthdateIsEstimate: json['birthdate_is_estimate'] as bool? ?? false,
    adoptedDate: json['adopted_date'] == null
        ? null
        : DateTime.parse(json['adopted_date'] as String),
    isNeutered: json['is_neutered'] as bool?,
    photoUrl: json['photo_url'] as String?,
    breedId: json['breed_id'] as String?,
    breedMix: (json['breed_mix'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>(),
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    allergies: (json['allergies'] as List<dynamic>? ?? const []).cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'owner_id': ownerId,
    'species': species,
    'name': name,
    'sex': sex,
    'birthdate': birthdate?.toIso8601String(),
    'birthdate_is_estimate': birthdateIsEstimate,
    'adopted_date': adoptedDate?.toIso8601String(),
    'is_neutered': isNeutered,
    'photo_url': photoUrl,
    'breed_id': breedId,
    'breed_mix': breedMix,
    'weight_kg': weightKg,
    'allergies': allergies,
  };
}
