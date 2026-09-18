import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../data/models/health_record.dart';
import '../data/repositories/health_record_repository.dart';

enum CareCalendarStatus { loading, loaded, error }

class CareCalendarState {
  const CareCalendarState({
    this.status = CareCalendarStatus.loading,
    this.records = const [],
    this.errorMessage,
  });

  final CareCalendarStatus status;
  final List<HealthRecord> records;
  final String? errorMessage;

  List<HealthRecord> get _due {
    final due = records.where((r) => r.isActive && r.dueOn != null).toList()
      ..sort((a, b) => a.dueOn!.compareTo(b.dueOn!));
    return due;
  }

  List<HealthRecord> get overdue =>
      _due.where((r) => r.dueOn!.isBefore(DateTime.now())).toList();

  List<HealthRecord> get thisMonth {
    final now = DateTime.now();
    final in30Days = now.add(const Duration(days: 30));
    return _due
        .where((r) => !r.dueOn!.isBefore(now) && r.dueOn!.isBefore(in30Days))
        .toList();
  }

  List<HealthRecord> get later {
    final now = DateTime.now();
    final in30Days = now.add(const Duration(days: 30));
    return _due.where((r) => !r.dueOn!.isBefore(in30Days)).toList();
  }

  CareCalendarState copyWith({
    CareCalendarStatus? status,
    List<HealthRecord>? records,
    String? errorMessage,
  }) => CareCalendarState(
    status: status ?? this.status,
    records: records ?? this.records,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

/// Backs the Care calendar screen — groups the same `due_on`-bearing
/// health records Home's "Needs you this week" reads into
/// Overdue / This month / Later, and completes one in place.
class CareCalendarCubit extends Cubit<CareCalendarState> {
  CareCalendarCubit({
    required String petId,
    required HealthRecordRepository healthRecordRepository,
  }) : _petId = petId,
       _healthRecordRepository = healthRecordRepository,
       super(const CareCalendarState()) {
    _load();
  }

  final String _petId;
  final HealthRecordRepository _healthRecordRepository;
  StreamSubscription<Result<List<HealthRecord>>>? _subscription;

  void _load() {
    AppLogger.debug('CareCalendarCubit loading for pet $_petId');
    _subscription = _healthRecordRepository.watchByPet(_petId).listen((result) {
      switch (result) {
        case Ok(:final value):
          emit(state.copyWith(status: CareCalendarStatus.loaded, records: value));
        case Err(:final failure):
          emit(
            state.copyWith(
              status: CareCalendarStatus.error,
              errorMessage: failure.message,
            ),
          );
      }
    });
  }

  Future<void> complete(String recordId) {
    return _healthRecordRepository.markDone(recordId);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
