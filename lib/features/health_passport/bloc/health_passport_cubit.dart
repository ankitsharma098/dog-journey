import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../data/models/health_record.dart';
import '../data/models/vaccine_type.dart';
import '../data/repositories/health_record_repository.dart';
import '../data/repositories/vaccine_type_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum HealthPassportStatus { loading, loaded, error }

class HealthPassportState {
  const HealthPassportState({
    this.status = HealthPassportStatus.loading,
    this.records = const [],
    this.vaccineTypes = const [],
    this.errorMessage,
  });

  final HealthPassportStatus status;
  final List<HealthRecord> records;
  final List<VaccineType> vaccineTypes;
  final String? errorMessage;

  List<HealthRecord> get vaccines =>
      records.where((r) => r.type == RecordType.vaccine).toList();
  List<HealthRecord> get medications => records
      .where((r) => r.type == RecordType.medication && r.isActive)
      .toList();
  List<HealthRecord> get weightRecords =>
      records.where((r) => r.type == RecordType.weight).toList();

  HealthPassportState copyWith({
    HealthPassportStatus? status,
    List<HealthRecord>? records,
    List<VaccineType>? vaccineTypes,
    String? errorMessage,
  }) => HealthPassportState(
    status: status ?? this.status,
    records: records ?? this.records,
    vaccineTypes: vaccineTypes ?? this.vaccineTypes,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------
class HealthPassportCubit extends Cubit<HealthPassportState> {
  HealthPassportCubit({
    required String petId,
    required String currentUserId,
    required HealthRecordRepository healthRecordRepository,
    required VaccineTypeRepository vaccineTypeRepository,
  }) : _petId = petId,
       _currentUserId = currentUserId,
       _healthRecordRepository = healthRecordRepository,
       _vaccineTypeRepository = vaccineTypeRepository,
       super(const HealthPassportState()) {
    _load();
  }

  final String _petId;
  final String _currentUserId;
  final HealthRecordRepository _healthRecordRepository;
  final VaccineTypeRepository _vaccineTypeRepository;
  StreamSubscription<Result<List<HealthRecord>>>? _subscription;

  void _load() {
    AppLogger.debug('HealthPassportCubit loading for pet $_petId');
    _vaccineTypeRepository.all().then((types) {
      if (!isClosed) emit(state.copyWith(vaccineTypes: types));
    });

    _subscription = _healthRecordRepository.watchByPet(_petId).listen((result) {
      switch (result) {
        case Ok(:final value):
          AppLogger.info(
            'HealthPassportCubit loaded ${value.length} record(s)',
          );
          emit(
            state.copyWith(status: HealthPassportStatus.loaded, records: value),
          );
        case Err(:final failure):
          AppLogger.error(
            'HealthPassportCubit stream error — ${failure.message}',
          );
          emit(
            state.copyWith(
              status: HealthPassportStatus.error,
              errorMessage: failure.message,
            ),
          );
      }
    });
  }

  void retry() {
    emit(state.copyWith(status: HealthPassportStatus.loading));
    _subscription?.cancel();
    _load();
  }

  Future<Result<String>> addRecord(HealthRecord record) async {
    final result = await _healthRecordRepository.addRecord(
      record.copyWith(petId: _petId, createdById: _currentUserId),
    );
    if (result case Ok(:final value)) {
      // Sync reminders if there's a due date
      if (record.dueOn != null) {
        await _healthRecordRepository.syncReminders(value);
      }
    }
    return result;
  }

  Future<Result<String>> recordVaccination({
    required String vaccineTypeId,
    required DateTime occurredOn,
    int? doseNumber,
    String? clinicName,
    String? notes,
  }) {
    return _healthRecordRepository.recordVaccination(
      petId: _petId,
      vaccineTypeId: vaccineTypeId,
      occurredOn: occurredOn,
      createdById: _currentUserId,
      doseNumber: doseNumber,
      clinicName: clinicName,
      notes: notes,
    );
  }

  Future<Result<void>> deleteRecord(String id) {
    return _healthRecordRepository.delete(id);
  }

  Future<Result<void>> deactivateMedication(String id) {
    return _healthRecordRepository.deactivateMedication(id);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
