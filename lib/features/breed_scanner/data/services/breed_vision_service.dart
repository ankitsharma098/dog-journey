import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../../core/config/app_secrets.dart';
import '../../../../core/data/app_config_repository.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/scan.dart';

/// What one classification call produces, before it's folded into a
/// [Scan] — kept separate from [Scan] because a cache hit skips this
/// entirely and reuses an earlier scan's [Scan.result] instead.
class VisionResult {
  const VisionResult({required this.speciesMatched, required this.matches});

  final bool speciesMatched;
  final List<BreedMatch> matches;
}

/// Wraps `google_generative_ai` (a direct Google AI Studio API key,
/// client-side — see AppSecrets.geminiApiKey's doc comment for why)
/// for BS-1/BS-2: a ranked breed-mix percentage (or a friendly "not a
/// dog" signal), forced into JSON that resolves directly against the
/// bundled `breeds.json` reference data via [BreedMatch.breedSlug].
///
/// PRD §9 non-negotiable #2 — the model name lives in `app_config`,
/// not hardcoded, so a Gemini deprecation is a SQL edit, not a store
/// release. [_fallbackModel] only covers the very first run, before
/// that key is ever set.
class BreedVisionService {
  BreedVisionService({required AppConfigRepository appConfigRepository})
    : _appConfigRepository = appConfigRepository;

  static const String _fallbackModel = 'gemini-3.6-flash';

  /// [Scan.modelVersion] — the cache key's other half alongside the
  /// image hash. Bumped when this prompt/schema changes meaningfully
  /// (so old cached results aren't reused against a different
  /// contract), not on every Gemini model swap via app_config.
  static const String promptVersion = 'breed-scan-v1';

  final AppConfigRepository _appConfigRepository;

  Future<Result<VisionResult>> classify({
    required Uint8List imageBytes,
    required List<String> validSlugs,
  }) async {
    final modelResult = await _appConfigRepository.getString(
      'ai_model',
      fallback: _fallbackModel,
    );
    final modelName = modelResult.fold((value) => value, (_) => _fallbackModel);

    AppLogger.debug('BreedVision classify — model $modelName');
    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: AppSecrets.geminiApiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: _schema,
        ),
      );

      final response = await model.generateContent([
        Content.multi([TextPart(_prompt(validSlugs)), DataPart('image/jpeg', imageBytes)]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        AppLogger.error('BreedVision classify — empty response');
        return const Result.err(
          ServerFailure("Couldn't analyze that photo. Try again."),
        );
      }

      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final speciesMatched = parsed['species_matched'] as bool? ?? false;
      final matches = (parsed['breeds'] as List<dynamic>? ?? const [])
          .map(
            (e) => BreedMatch(
              breedSlug: (e as Map<String, dynamic>)['slug'] as String,
              name: e['name'] as String,
              pct: (e['pct'] as num).toDouble(),
              confidence: (e['confidence'] as num).toDouble(),
            ),
          )
          .toList();

      AppLogger.info(
        'BreedVision classify — speciesMatched=$speciesMatched, ${matches.length} match(es)',
      );
      return Result.ok(VisionResult(speciesMatched: speciesMatched, matches: matches));
    } catch (e, st) {
      AppLogger.error('BreedVision classify — failed', e, st);
      return const Result.err(
        ServerFailure("Couldn't analyze that photo. Try again."),
      );
    }
  }

  Schema get _schema => Schema.object(
    properties: {
      'species_matched': Schema.boolean(
        description: 'true only if the photo clearly contains a dog',
      ),
      'breeds': Schema.array(
        items: Schema.object(
          properties: {
            'slug': Schema.string(description: 'one of the provided valid slugs'),
            'name': Schema.string(),
            'pct': Schema.number(description: '0-100, shares sum to roughly 100'),
            'confidence': Schema.number(description: '0-1, this specific match only'),
          },
        ),
      ),
    },
  );

  String _prompt(List<String> validSlugs) =>
      '''
You are estimating a dog's breed mix from one photo, for a pet-care app.

Rules:
- If the photo does not clearly show a dog (a cat, a person, an object, or too unclear to tell), set species_matched to false and return an empty breeds list.
- Otherwise set species_matched to true and return a ranked list of breed matches, best match first, as a percentage mix that sums to roughly 100.
- Every "slug" you return MUST be exactly one of these known slugs — use "mixed-breed" if you can't confidently narrow it down further: ${validSlugs.join(', ')}.
- confidence is your own certainty in that specific match, 0 to 1 — be honest, not optimistic. A low-confidence best guess is still useful; just say so with a low value rather than rounding up.
- This is a visual best-guess, not a clinical or forensic determination.
''';
}
