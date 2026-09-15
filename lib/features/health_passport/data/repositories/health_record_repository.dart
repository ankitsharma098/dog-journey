import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_repository.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/health_record.dart';

class HealthRecordRepository extends SupabaseRepository<HealthRecord> {
  HealthRecordRepository({required super.client})
      : _supabase = client,
        super(
          table: 'health_records',
          fromJson: HealthRecord.fromJson,
          toJson: (r) => r.toJson(),
        );

  final SupabaseClient _supabase;

  /// Live stream of all health records for a pet, newest first.
  Stream<Result<List<HealthRecord>>> watchByPet(String petId) {
    return watchQuery(
      (stream) => stream.eq('pet_id', petId).order('occurred_on', ascending: false),
    );
  }

  /// Inserts a health record.
  Future<Result<String>> addRecord(HealthRecord record) async {
    AppLogger.debug('HealthRecordRepository addRecord type=${record.type.dbValue}');
    return add(record);
  }

  /// Records a vaccination via RPC — auto-computes dose number + next due.
  Future<Result<String>> recordVaccination({
    required String petId,
    required String vaccineTypeId,
    required DateTime occurredOn,
    required String createdById,
    int? doseNumber,
    String? clinicName,
    String? notes,
  }) async {
    AppLogger.debug('HealthRecordRepository recordVaccination petId=$petId');
    try {
      final row = await _supabase.rpc('record_vaccination', params: {
        'p_pet_id': petId,
        'p_vaccine_type_id': vaccineTypeId,
        'p_occurred_on': occurredOn.toIso8601String().substring(0, 10),
        'p_created_by_id': createdById,
        if (doseNumber != null) 'p_dose_number': doseNumber,
        if (clinicName != null) 'p_clinic_name': clinicName,
        if (notes != null) 'p_notes': notes,
      }) as Map<String, dynamic>;
      return Result.ok(row['id'] as String);
    } catch (e, st) {
      AppLogger.error('HealthRecordRepository recordVaccination failed', e, st);
      return Result.err(ServerFailure(_extractRpcError(e)));
    }
  }

  /// Syncs reminders for a health record with a due_on.
  Future<Result<void>> syncReminders(String healthRecordId) async {
    AppLogger.debug('HealthRecordRepository syncReminders $healthRecordId');
    try {
      await _supabase
          .rpc('sync_reminders', params: {'p_health_record_id': healthRecordId});
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error('HealthRecordRepository syncReminders failed', e, st);
      return Result.err(ServerFailure(_extractRpcError(e)));
    }
  }

  /// Deactivates a medication (sets is_active = false).
  Future<Result<void>> deactivateMedication(String id) {
    return updateFields(id, {'is_active': false});
  }

  /// Weight records for charting: all weight-type records for a pet, oldest first.
  Future<Result<List<HealthRecord>>> weightHistory(String petId) {
    return queryOnce(
      (q) => q
          .eq('pet_id', petId)
          .eq('type', 'weight')
          .order('occurred_on', ascending: true),
    );
  }

  String _extractRpcError(Object e) {
    if (e is PostgrestException) return e.message;
    return e.toString();
  }
}
