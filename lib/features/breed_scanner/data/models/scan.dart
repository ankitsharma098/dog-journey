/// One entry in a [Scan.result] list — a single breed's share of the
/// mix. Deliberately light (just enough to render a result card and
/// join back to [Breed] by [breedSlug]); the rich trait/health-risk
/// payload lives on `breeds`, not duplicated here.
class BreedMatch {
  const BreedMatch({
    required this.breedSlug,
    required this.name,
    required this.pct,
    required this.confidence,
  });

  final String breedSlug;
  final String name;
  final double pct; // 0-100
  final double confidence; // 0-1

  factory BreedMatch.fromJson(Map<String, dynamic> json) => BreedMatch(
    breedSlug: json['breed_slug'] as String,
    name: json['name'] as String,
    pct: (json['pct'] as num).toDouble(),
    confidence: (json['confidence'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'breed_slug': breedSlug,
    'name': name,
    'pct': pct,
    'confidence': confidence,
  };
}

/// Mirrors supabase/migrations/0001_init.sql `scans`. [result] stays a
/// list of raw maps (matching the `jsonb` column's shape) — it's
/// always read whole, never queried by individual breed.
class Scan {
  const Scan({
    this.id = '',
    required this.userId,
    this.petId,
    this.species = 'dog',
    required this.photoUrl,
    required this.imageHash,
    required this.modelVersion,
    this.status = 'pending',
    this.result = const [],
    this.speciesMatched,
    this.fromCache = false,
    this.errorCode,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String? petId;
  final String species;
  final String photoUrl;
  final String imageHash; // sha256, cache key
  final String modelVersion;
  final String status; // pending | done | failed
  final List<BreedMatch> result; // ordered best first
  final bool? speciesMatched; // false = photo was not a dog
  final bool fromCache;
  final String? errorCode;
  final DateTime? createdAt;

  factory Scan.fromJson(Map<String, dynamic> json) => Scan(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    petId: json['pet_id'] as String?,
    species: json['species'] as String? ?? 'dog',
    photoUrl: json['photo_url'] as String,
    imageHash: json['image_hash'] as String,
    modelVersion: json['model_version'] as String,
    status: json['status'] as String? ?? 'pending',
    result: (json['result'] as List<dynamic>? ?? const [])
        .map((e) => BreedMatch.fromJson(e as Map<String, dynamic>))
        .toList(),
    speciesMatched: json['species_matched'] as bool?,
    fromCache: json['from_cache'] as bool? ?? false,
    errorCode: json['error_code'] as String?,
    createdAt: json['created_at'] == null
        ? null
        : DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'pet_id': petId,
    'species': species,
    'photo_url': photoUrl,
    'image_hash': imageHash,
    'model_version': modelVersion,
    'status': status,
    'result': result.map((e) => e.toJson()).toList(),
    'species_matched': speciesMatched,
    'from_cache': fromCache,
    'error_code': errorCode,
  };

  Scan copyWith({
    String? status,
    List<BreedMatch>? result,
    bool? speciesMatched,
    bool? fromCache,
    String? errorCode,
  }) {
    return Scan(
      id: id,
      userId: userId,
      petId: petId,
      species: species,
      photoUrl: photoUrl,
      imageHash: imageHash,
      modelVersion: modelVersion,
      status: status ?? this.status,
      result: result ?? this.result,
      speciesMatched: speciesMatched ?? this.speciesMatched,
      fromCache: fromCache ?? this.fromCache,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt,
    );
  }
}
