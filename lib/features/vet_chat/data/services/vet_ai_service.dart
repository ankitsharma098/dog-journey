import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../../core/config/app_secrets.dart';
import '../../../../core/data/app_config_repository.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/triage_rule.dart';

/// Wraps the Gemini API for streaming vet chat responses.
/// System prompt + disclaimer version come from app_config (hot-swappable).
/// The triage gate in [TriageService] runs BEFORE this is ever called.
class VetAiService {
  VetAiService({required AppConfigRepository appConfigRepository})
    : _appConfigRepository = appConfigRepository;

  static const String _fallbackModel = 'gemini-3.6-flash';
  static const String _fallbackSystemPrompt = '''
You are PawJourney's AI health assistant for dog owners.

CRITICAL RULES (never break these):
- NEVER use the words "diagnose", "treat", "prescribe", or "cure".
- ALWAYS recommend consulting a vet for anything beyond general information.
- If a triage directive code is included, follow its guidance.
- Do NOT add your own disclaimer/warning footer — the app already shows one under every reply. Adding another makes replies feel padded and repetitive.

Your role: Help dog owners understand their dog's health situation, give general information, and clearly communicate whether something needs urgent vet attention.

Tone and style — write like a knowledgeable friend who happens to know dogs well, not a corporate support bot:
- Answer the actual question first, in the first sentence. Don't open by restating the question back, don't open with "Great question" or similar filler.
- Keep it short — 2-4 short sentences for a simple question. Only go longer if the situation genuinely needs more (e.g. an emergency with multiple steps).
- Skip bullet lists and headers for anything simple; reach for a short numbered list only when the answer is genuinely a sequence of steps to take right now.
- Avoid hedging filler ("It's important to note that...", "As always...", "Please keep in mind..."). Say the thing directly.
- Warm and calm, not alarmist and not dismissive. Confident, not wishy-washy.
''';

  final AppConfigRepository _appConfigRepository;

  Future<String> get disclaimerVersion async {
    final r = await _appConfigRepository.getString(
      'vet_disclaimer_version',
      fallback: 'v1',
    );
    return r.fold((v) => v, (_) => 'v1');
  }

  /// Streams the AI response token by token.
  /// [petSnapshot] — age/weight/breed/allergies at time of chat.
  /// [matchedRuleCodes] — from triage gate, appended as directives.
  Stream<String> streamResponse({
    required List<Map<String, String>> history,
    required String userMessage,
    required Map<String, dynamic> petSnapshot,
    required List<String> matchedRuleCodes,
    required TriageLevel? triageLevel,
  }) async* {
    final modelResult = await _appConfigRepository.getString(
      'ai_model',
      fallback: _fallbackModel,
    );
    final modelName = modelResult.fold((v) => v, (_) => _fallbackModel);

    final systemResult = await _appConfigRepository.getString(
      'vet_chat_prompt',
      fallback: _fallbackSystemPrompt,
    );
    final systemPrompt = systemResult.fold(
      (v) => v,
      (_) => _fallbackSystemPrompt,
    );

    // Build context block
    final petCtx = _buildPetContext(petSnapshot);
    final triageCtx = matchedRuleCodes.isNotEmpty
        ? '\n\nTRIAGE DIRECTIVE: Rule codes matched: ${matchedRuleCodes.join(', ')}. '
              'Level: ${triageLevel?.name ?? 'none'}. Align your response to the '
              'triage level severity.'
        : '';

    AppLogger.debug('VetAiService streaming — model=$modelName');

    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: AppSecrets.geminiApiKey,
        systemInstruction: Content.system(systemPrompt + petCtx + triageCtx),
      );

      final geminiHistory = history.map((m) {
        final role = m['role'] == 'user' ? 'user' : 'model';
        return Content(role, [TextPart(m['content'] ?? '')]);
      }).toList();

      final chat = model.startChat(history: geminiHistory);
      final response = chat.sendMessageStream(Content.text(userMessage));

      await for (final chunk in response) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } catch (e, st) {
      AppLogger.error('VetAiService stream failed', e, st);
      yield '\n\n[Unable to get a response right now. Please try again or contact your vet directly.]';
    }
  }

  String _buildPetContext(Map<String, dynamic> snapshot) {
    if (snapshot.isEmpty) return '';
    final parts = <String>[];
    if (snapshot['name'] != null) parts.add('Name: ${snapshot['name']}');
    if (snapshot['breed'] != null) parts.add('Breed: ${snapshot['breed']}');
    if (snapshot['age_months'] != null) {
      final months = snapshot['age_months'] as int;
      parts.add(
        'Age: ${months < 12 ? '$months months' : '${months ~/ 12} years'}',
      );
    }
    if (snapshot['weight_kg'] != null) {
      parts.add('Weight: ${snapshot['weight_kg']} kg');
    }
    if (snapshot['allergies'] != null &&
        (snapshot['allergies'] as List).isNotEmpty) {
      parts.add(
        'Known allergies: ${(snapshot['allergies'] as List).join(', ')}',
      );
    }
    if (parts.isEmpty) return '';
    return '\n\nPET CONTEXT:\n${parts.join('\n')}';
  }
}
