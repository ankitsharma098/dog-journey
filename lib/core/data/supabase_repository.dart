import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../error/failure.dart';
import '../error/result.dart';
import '../error/supabase_error_mapper.dart';
import '../logging/app_logger.dart';

/// The CRUD every feature repository builds on instead of hand-rolling
/// try/catch and Supabase error mapping again per model — the Postgres
/// equivalent of the old `FirestoreRepository<T>`. A feature repository
/// only supplies which table it lives in and how to convert to/from
/// JSON; this owns the rest.
///
/// Unlike the Firestore version, `created_at`/`updated_at` aren't
/// stamped here — the database does that itself (`default now()` /
/// the `set_updated_at()` trigger, see supabase/migrations/0001_init.sql)
/// — and a row's `id` comes back as a normal column in the row map,
/// not a separate value the caller has to thread through, so model
/// `fromJson` takes just the row map now.
abstract class SupabaseRepository<T> {
  SupabaseRepository({
    required SupabaseClient client,
    required String table,
    required T Function(Map<String, dynamic> row) fromJson,
    required Map<String, dynamic> Function(T value) toJson,
  }) : _client = client,
       _table = table,
       _fromJson = fromJson,
       _toJson = toJson;

  final SupabaseClient _client;
  final String _table;
  final T Function(Map<String, dynamic> row) _fromJson;
  final Map<String, dynamic> Function(T value) _toJson;

  @protected
  SupabaseQueryBuilder get table => _client.from(_table);

  T decode(Map<String, dynamic> row) => _fromJson(row);

  Future<Result<T>> getById(String id) async {
    AppLogger.debug('Supabase getById $_table/$id');
    try {
      final row = await table.select().eq('id', id).maybeSingle();
      if (row == null) {
        AppLogger.warning('Supabase getById $_table/$id — not found');
        return const Result.err(NotFoundFailure());
      }
      AppLogger.info('Supabase getById $_table/$id — ok');
      return Result.ok(decode(row));
    } catch (e, st) {
      AppLogger.error('Supabase getById $_table/$id — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }

  Stream<Result<T>> watch(String id) async* {
    AppLogger.debug('Supabase watch $_table/$id — subscribing');
    try {
      final stream = table.stream(primaryKey: ['id']).eq('id', id);
      await for (final rows in stream) {
        if (rows.isEmpty) {
          AppLogger.warning('Supabase watch $_table/$id — not found');
          yield const Result.err(NotFoundFailure());
        } else {
          AppLogger.debug('Supabase watch $_table/$id — emitted');
          yield Result.ok(decode(rows.first));
        }
      }
    } catch (e, st) {
      AppLogger.error('Supabase watch $_table/$id — failed', e, st);
      yield Result.err(mapSupabaseError(e));
    }
  }

  /// [queryBuilder] narrows the live query (`.eq(...)`, `.order(...)`,
  /// `.limit(...)`) on top of the base realtime subscription this
  /// already opens for [_table]. Typed as the common `SupabaseStreamBuilder`
  /// base rather than `SupabaseStreamFilterBuilder` since `.order()`/
  /// `.limit()` return the base type, not the narrower filter type
  /// `.eq()` returns.
  Stream<Result<List<T>>> watchQuery(
    SupabaseStreamBuilder Function(SupabaseStreamFilterBuilder stream) queryBuilder,
  ) async* {
    AppLogger.debug('Supabase watchQuery $_table — subscribing');
    try {
      final stream = queryBuilder(table.stream(primaryKey: ['id']));
      await for (final rows in stream) {
        AppLogger.debug('Supabase watchQuery $_table — ${rows.length} row(s)');
        yield Result.ok(rows.map(decode).toList());
      }
    } catch (e, st) {
      AppLogger.error('Supabase watchQuery $_table — failed', e, st);
      yield Result.err(mapSupabaseError(e));
    }
  }

  /// One-shot equivalent of [watchQuery] — for a call site that just
  /// needs "the current matches," not a live subscription. Typed as
  /// the common `PostgrestTransformBuilder` base rather than
  /// `PostgrestFilterBuilder` for the same reason as [watchQuery]:
  /// `.order()`/`.limit()` return the base type, `.eq()` the narrower one.
  Future<Result<List<T>>> queryOnce(
    PostgrestTransformBuilder<PostgrestList> Function(
      PostgrestFilterBuilder<PostgrestList> query,
    )
    queryBuilder,
  ) async {
    AppLogger.debug('Supabase queryOnce $_table');
    try {
      final rows = await queryBuilder(table.select());
      AppLogger.debug('Supabase queryOnce $_table — ${rows.length} row(s)');
      return Result.ok(rows.map(decode).toList());
    } catch (e, st) {
      AppLogger.error('Supabase queryOnce $_table — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }

  /// Creates the row at the caller-chosen [id] — use where the id
  /// isn't database-generated (e.g. `users.id` must equal the Supabase
  /// auth uid). For a database-generated id use [add].
  Future<Result<void>> create(String id, T value) async {
    AppLogger.debug('Supabase create $_table/$id');
    try {
      await table.insert({..._toJson(value), 'id': id});
      AppLogger.info('Supabase create $_table/$id — ok');
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error('Supabase create $_table/$id — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }

  /// Lets the database generate the id (e.g. a new scan) and returns it.
  Future<Result<String>> add(T value) async {
    AppLogger.debug('Supabase add $_table');
    try {
      final row = await table.insert(_toJson(value)).select().single();
      final id = row['id'] as String;
      AppLogger.info('Supabase add $_table — ok ($id)');
      return Result.ok(id);
    } catch (e, st) {
      AppLogger.error('Supabase add $_table — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }

  /// Merges [data] into the existing row. Takes a raw field map rather
  /// than a whole [T] so a caller can patch one or two fields without
  /// reconstructing the full model.
  Future<Result<void>> updateFields(String id, Map<String, dynamic> data) async {
    AppLogger.debug('Supabase updateFields $_table/$id — ${data.keys}');
    try {
      await table.update(data).eq('id', id);
      AppLogger.info('Supabase updateFields $_table/$id — ok');
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error('Supabase updateFields $_table/$id — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }

  Future<Result<void>> delete(String id) async {
    AppLogger.debug('Supabase delete $_table/$id');
    try {
      await table.delete().eq('id', id);
      AppLogger.info('Supabase delete $_table/$id — ok');
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error('Supabase delete $_table/$id — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }
}
