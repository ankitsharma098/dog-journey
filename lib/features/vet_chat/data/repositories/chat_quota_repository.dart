import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_tables.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/error/supabase_error_mapper.dart';
import '../../../../core/logging/app_logger.dart';

/// Owns the day's vet-chat quota — the 'chat' sibling to
/// [ScanQuotaRepository], on the same `usage_counters` table (see
/// supabase/migrations/0001_init.sql's comment reserving `kind='chat'`
/// for this, and 0008_chat_quota.sql's `reserve_chat_quota` RPC).
/// Same atomicity rationale: the actual check-and-increment happens
/// server-side in a `security definer` function keyed off `auth.uid()`,
/// so a modified client can only ever spend its own quota.
class ChatQuotaRepository {
  ChatQuotaRepository({required SupabaseClient client})
    : _client = client,
      _table = client.from(SupabaseTables.usageCounters);

  final SupabaseClient _client;
  final SupabaseQueryBuilder _table;

  String get _today =>
      DateTime.now().toUtc().toIso8601String().split('T').first;

  /// Read-only peek — used to seed the "X / 3 FREE" chip with a real
  /// count when the chat screen (re)opens, instead of always starting
  /// from zero.
  Future<Result<int>> remaining(String uid, {required int limit}) async {
    try {
      final row = await _table
          .select('count')
          .eq('user_id', uid)
          .eq('kind', 'chat')
          .eq('date', _today)
          .maybeSingle();
      final current = (row?['count'] as num?)?.toInt() ?? 0;
      return Result.ok((limit - current).clamp(0, limit));
    } catch (e, st) {
      AppLogger.error('ChatQuota remaining $uid/$_today — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }

  /// Reserves one unit of today's chat quota. Call this only for a
  /// message that will actually count against the free tier —
  /// [VetChatCubit.sendMessage] never calls this for emergency-level
  /// messages.
  Future<Result<void>> reserve(String uid, {required int limit}) async {
    AppLogger.debug('ChatQuota reserve $uid/$_today');
    try {
      final reserved = await _client.rpc<bool>(
        'reserve_chat_quota',
        params: {'p_limit': limit},
      );
      if (reserved != true) {
        AppLogger.warning('ChatQuota reserve $uid/$_today — limit reached');
        return const Result.err(QuotaExceededFailure());
      }
      AppLogger.info('ChatQuota reserve $uid/$_today — ok');
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error('ChatQuota reserve $uid/$_today — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }
}
