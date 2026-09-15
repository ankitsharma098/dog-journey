/// Keys inside the `app_config` Firestore collection (one doc per key,
/// value in a `value` field). Lets the vet-chat prompt, model name and
/// calorie factors change without a store release — see PRD §9.2.
abstract final class AppConfigKeys {
  static const String activeSpecies = 'active_species';
  static const String aiModel = 'ai_model';
  static const String vetChatPrompt = 'vet_chat_prompt';
  static const String merFactors = 'mer_factors';
  static const String reminderOffsets = 'reminder_offsets';
  static const String freeScanLimit = 'free_scan_limit';
}
