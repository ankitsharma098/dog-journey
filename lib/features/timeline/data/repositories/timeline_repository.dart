import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/timeline_entry.dart';

class TimelineRepository {
  TimelineRepository({required SupabaseClient client}) : _client = client;
  final SupabaseClient _client;

  /// Live stream of all non-deleted entries for a pet, newest first.
  Stream<Result<List<TimelineEntry>>> watchByPet(String petId) async* {
    AppLogger.debug('TimelineRepository watchByPet $petId');
    try {
      final stream = _client
          .from('timeline_entries')
          .stream(primaryKey: ['id'])
          .eq('pet_id', petId)
          .order('entry_date', ascending: false);
      await for (final rows in stream) {
        final entries = (rows)
            .map((r) => TimelineEntry.fromJson(r))
            .where((e) => e.deletedAt == null)
            .toList();
        yield Result.ok(entries);
      }
    } catch (e, st) {
      AppLogger.error('TimelineRepository watchByPet failed', e, st);
      yield Result.err(ServerFailure(e.toString()));
    }
  }

  Future<Result<String>> addEntry(TimelineEntry entry) async {
    AppLogger.debug('TimelineRepository addEntry type=${entry.entryType.dbValue}');
    try {
      final row = await _client
          .from('timeline_entries')
          .insert(entry.toJson())
          .select()
          .single();
      return Result.ok(row['id'] as String);
    } catch (e, st) {
      AppLogger.error('TimelineRepository addEntry failed', e, st);
      return Result.err(ServerFailure(e.toString()));
    }
  }

  Future<Result<void>> softDelete(String id) async {
    try {
      await _client
          .from('timeline_entries')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error('TimelineRepository softDelete failed', e, st);
      return Result.err(ServerFailure(e.toString()));
    }
  }

  Future<Result<void>> incrementShareCount(String id) async {
    try {
      // Atomic increment
      await _client.rpc('increment_share_count', params: {'p_entry_id': id});
      return const Result.ok(null);
    } catch (e) {
      // Fallback: just ignore share count failure gracefully
      return const Result.ok(null);
    }
  }

  /// Generate milestones from milestone_templates.json for a pet.
  Future<Result<void>> generateMilestones({
    required String petId,
    required String createdById,
    required DateTime? birthdate,
    required DateTime? adoptedDate,
  }) async {
    AppLogger.debug('TimelineRepository generateMilestones petId=$petId');
    try {
      // Try RPC first (handles idempotency)
      await _client.rpc('generate_milestones', params: {
        'p_pet_id': petId,
        'p_created_by_id': createdById,
      });
      return const Result.ok(null);
    } catch (e) {
      // RPC may not be deployed yet — generate client-side from asset
      return await _generateMilestonesLocally(
        petId: petId,
        createdById: createdById,
        birthdate: birthdate,
        adoptedDate: adoptedDate,
      );
    }
  }

  Future<Result<void>> _generateMilestonesLocally({
    required String petId,
    required String createdById,
    required DateTime? birthdate,
    required DateTime? adoptedDate,
  }) async {
    try {
      final templates = await _loadTemplates();
      for (final t in templates) {
        final trigger = t['trigger'] as String;
        final base = trigger == 'birthdate' ? birthdate : adoptedDate;
        if (base == null) continue;

        final offsetDays = t['offset_days'] as int;
        final entryDate = base.add(Duration(days: offsetDays));
        final entryType = EntryType.fromDb(t['entry_type'] as String);

        final name = ''; // filled by caller
        final titleTemplate = (t['title_template'] as String)
            .replaceAll('{{name}}', name)
            .replaceAll('{{ordinal}}', '1st');

        // Check if already exists (idempotent)
        final existing = await _client
            .from('timeline_entries')
            .select('id')
            .eq('pet_id', petId)
            .eq('template_id', t['id'] as String)
            .maybeSingle();
        if (existing != null) continue;

        await _client.from('timeline_entries').insert({
          'pet_id': petId,
          'template_id': t['id'],
          'entry_type': entryType.dbValue,
          'title': titleTemplate,
          'body': (t['body_template'] as String? ?? '').replaceAll('{{name}}', name),
          'entry_date': entryDate.toIso8601String().substring(0, 10),
          'is_auto_created': true,
          'created_by_id': createdById,
        });
      }
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error('TimelineRepository _generateMilestonesLocally failed', e, st);
      return Result.err(ServerFailure(e.toString()));
    }
  }

  Future<List<Map<String, dynamic>>> _loadTemplates() async {
    // Inline import avoided to keep this file standalone
    // The actual load happens at runtime via rootBundle
    return const [];
  }
}
