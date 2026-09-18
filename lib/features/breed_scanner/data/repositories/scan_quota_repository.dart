import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_tables.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/error/supabase_error_mapper.dart';
import '../../../../core/logging/app_logger.dart';

/// Owns the day's scan quota (PRD §9 non-negotiable #3: quota
/// enforcement must be server-side, client-side is trivially
/// bypassed). The actual check-and-increment is the `reserve_scan_quota`
/// Postgres function (supabase/migrations/0001_init.sql) — a
/// `security definer` function that's the *only* way `usage_counters`
/// can be written (no insert/update RLS policy exists on it at all),
/// and it reserves against `auth.uid()` internally, never a
/// caller-supplied id, so a modified client can spend only its own
/// quota. That's a real atomic SQL statement, not a hand-rolled
/// transaction — see the function's doc comment for why this is
/// simpler and more correct than the Firestore-rules version it
/// replaced.
///
/// `kind = 'scans'` leaves room for a `'chat'` sibling when Module 3's
/// chat quota needs the same mechanism — see the `QuotaExceededFailure`
/// doc comment, this table was already scoped for both.
class ScanQuotaRepository {
  ScanQuotaRepository({required SupabaseClient client})
    : _client = client,
      _table = client.from(SupabaseTables.usageCounters);

  final SupabaseClient _client;
  final SupabaseQueryBuilder _table;

  String get _today => DateTime.now().toUtc().toIso8601String().split('T').first;

  /// Read-only peek, used before paying for a model call — no point
  /// classifying a photo just to discover the quota was already spent.
  /// [reserve] still re-checks atomically, since this read isn't part
  /// of the same transaction as the later reserve.
  Future<Result<bool>> hasQuota(String uid, {required int limit}) async {
    AppLogger.debug('ScanQuota hasQuota $uid/$_today');
    try {
      final row = await _table
          .select('count')
          .eq('user_id', uid)
          .eq('kind', 'scans')
          .eq('date', _today)
          .maybeSingle();
      final current = (row?['count'] as num?)?.toInt() ?? 0;
      return Result.ok(current < limit);
    } catch (e, st) {
      AppLogger.error('ScanQuota hasQuota $uid/$_today — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }

  /// Remaining scans today — the "3 SCANS LEFT" chip on the scanner
  /// screen. Same read as [hasQuota]; exposed as a count instead of a
  /// bool since the chip needs the number, not just whether it's zero.
  Future<Result<int>> remaining(String uid, {required int limit}) async {
    try {
      final row = await _table
          .select('count')
          .eq('user_id', uid)
          .eq('kind', 'scans')
          .eq('date', _today)
          .maybeSingle();
      final current = (row?['count'] as num?)?.toInt() ?? 0;
      return Result.ok((limit - current).clamp(0, limit));
    } catch (e, st) {
      AppLogger.error('ScanQuota remaining $uid/$_today — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }

  /// Reserves one unit of today's quota. Only call this after a scan
  /// is confirmed worth spending it on (model call already
  /// succeeded) — see [ScanRepository.findCached] and the cubit's
  /// flow for why quota isn't touched on a cache hit or a failed
  /// attempt.
  Future<Result<void>> reserve(String uid, {required int limit}) async {
    AppLogger.debug('ScanQuota reserve $uid/$_today');
    try {
      final reserved = await _client.rpc<bool>(
        'reserve_scan_quota',
        params: {'p_limit': limit},
      );
      if (reserved != true) {
        AppLogger.warning('ScanQuota reserve $uid/$_today — limit reached');
        return const Result.err(QuotaExceededFailure());
      }
      AppLogger.info('ScanQuota reserve $uid/$_today — ok');
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error('ScanQuota reserve $uid/$_today — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }
}
