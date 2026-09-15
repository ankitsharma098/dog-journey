/// Supabase table names, mapped from supabase/migrations/0001_init.sql.
///
/// Only what's actually wired to app code — `breeds` and every
/// not-yet-built module's tables aren't here. Reference data (breeds,
/// vaccine types, triage rules, toxic items, food items, milestone
/// templates) ships as bundled JSON under assets/data/ instead — see
/// PRD §9.
abstract final class SupabaseTables {
  static const String users = 'users';
  static const String pets = 'pets';
  static const String scans = 'scans';
  static const String usageCounters = 'usage_counters';
  static const String appConfig = 'app_config';
}
