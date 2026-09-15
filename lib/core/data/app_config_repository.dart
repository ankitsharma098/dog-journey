import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_tables.dart';
import '../error/result.dart';
import '../logging/app_logger.dart';

/// The `app_config` table (PRD §9): server-side settings so a
/// change — the Gemini model name, the vet-chat system prompt, calorie
/// factors, reminder offsets — is a SQL edit, not an app release.
/// Read-only to clients (see supabase/migrations/0001_init.sql); every
/// key is its own row, `{key, value: <the setting>}`.
class AppConfigRepository {
  AppConfigRepository({required SupabaseClient client})
    : _table = client.from(SupabaseTables.appConfig);

  final SupabaseQueryBuilder _table;

  Future<Result<String>> getString(String key, {required String fallback}) async {
    AppLogger.debug('AppConfig getString $key');
    try {
      final row = await _table.select().eq('key', key).maybeSingle();
      final value = row?['value'] as String?;
      if (value == null) {
        AppLogger.warning('AppConfig $key missing — falling back to $fallback');
        return Result.ok(fallback);
      }
      return Result.ok(value);
    } catch (e, st) {
      AppLogger.error('AppConfig getString $key — failed, using fallback', e, st);
      return Result.ok(fallback);
    }
  }

  Future<Result<int>> getInt(String key, {required int fallback}) async {
    AppLogger.debug('AppConfig getInt $key');
    try {
      final row = await _table.select().eq('key', key).maybeSingle();
      final value = row?['value'] as num?;
      if (value == null) {
        AppLogger.warning('AppConfig $key missing — falling back to $fallback');
        return Result.ok(fallback);
      }
      return Result.ok(value.toInt());
    } catch (e, st) {
      AppLogger.error('AppConfig getInt $key — failed, using fallback', e, st);
      return Result.ok(fallback);
    }
  }
}
