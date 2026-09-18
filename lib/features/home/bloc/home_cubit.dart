import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../breed_scanner/data/models/breed.dart';
import '../../breed_scanner/data/repositories/breed_repository.dart';
import '../../health_passport/data/models/health_record.dart';
import '../../health_passport/data/repositories/health_record_repository.dart';
import '../../nutrition/data/models/nutrition_models.dart';
import '../../nutrition/data/repositories/nutrition_repositories.dart';
import '../../timeline/data/models/timeline_entry.dart';
import '../../timeline/data/repositories/timeline_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum HomeStatus { loading, loaded, error }

class HomeState {
  const HomeState({
    this.status = HomeStatus.loading,
    this.breedName,
    this.latestWeightKg,
    this.records = const [],
    this.memories = const [],
    this.consumedKcal = 0,
    this.targetKcal = 0,
    this.errorMessage,
  });

  final HomeStatus status;
  final String? breedName;
  final double? latestWeightKg;
  final List<HealthRecord> records;
  final List<TimelineEntry> memories;
  final int consumedKcal;
  final int targetKcal;
  final String? errorMessage;

  /// Active, due, soonest first — the "Needs you this week" / Care
  /// calendar source list.
  List<HealthRecord> get dueSoon {
    final due = records.where((r) => r.isActive && r.dueOn != null).toList()
      ..sort((a, b) => a.dueOn!.compareTo(b.dueOn!));
    return due;
  }

  HomeState copyWith({
    HomeStatus? status,
    String? breedName,
    double? latestWeightKg,
    List<HealthRecord>? records,
    List<TimelineEntry>? memories,
    int? consumedKcal,
    int? targetKcal,
    String? errorMessage,
  }) => HomeState(
    status: status ?? this.status,
    breedName: breedName ?? this.breedName,
    latestWeightKg: latestWeightKg ?? this.latestWeightKg,
    records: records ?? this.records,
    memories: memories ?? this.memories,
    consumedKcal: consumedKcal ?? this.consumedKcal,
    targetKcal: targetKcal ?? this.targetKcal,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------
/// Read-only rollup for the Home dashboard tab. Unlike the per-module
/// cubits it borrows data from, this one never writes — every mutation
/// (log food, add a record, complete a reminder) happens on the
/// screen that owns that data, and Home just reflects it next time
/// this tab is rebuilt.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required String petId,
    String? breedId,
    required HealthRecordRepository healthRecordRepository,
    required TimelineRepository timelineRepository,
    required FeedingPlanRepository feedingPlanRepository,
    required FoodLogRepository foodLogRepository,
    required BreedRepository breedRepository,
  }) : _petId = petId,
       _healthRecordRepository = healthRecordRepository,
       _timelineRepository = timelineRepository,
       _feedingPlanRepository = feedingPlanRepository,
       _foodLogRepository = foodLogRepository,
       super(const HomeState()) {
    _load(breedId, breedRepository);
  }

  final String _petId;
  final HealthRecordRepository _healthRecordRepository;
  final TimelineRepository _timelineRepository;
  final FeedingPlanRepository _feedingPlanRepository;
  final FoodLogRepository _foodLogRepository;
  StreamSubscription<Result<List<HealthRecord>>>? _recordsSub;
  StreamSubscription<Result<List<TimelineEntry>>>? _memoriesSub;

  Future<void> _load(String? breedId, BreedRepository breedRepository) async {
    AppLogger.debug('HomeCubit loading for pet $_petId');

    if (breedId != null) {
      breedRepository.bySlug(breedId).then((Breed? breed) {
        if (breed != null && !isClosed) {
          emit(state.copyWith(breedName: breed.name));
        }
      });
    }

    _recordsSub = _healthRecordRepository.watchByPet(_petId).listen((result) {
      switch (result) {
        case Ok(:final value):
          final weights = value.where((r) => r.type == RecordType.weight).toList()
            ..sort((a, b) => a.occurredOn.compareTo(b.occurredOn));
          emit(
            state.copyWith(
              status: HomeStatus.loaded,
              records: value,
              latestWeightKg: weights.isEmpty ? null : weights.last.weightKg,
            ),
          );
        case Err(:final failure):
          AppLogger.error('HomeCubit records stream error — ${failure.message}');
          emit(state.copyWith(status: HomeStatus.error, errorMessage: failure.message));
      }
    });

    _memoriesSub = _timelineRepository.watchByPet(_petId).listen((result) {
      if (result case Ok(:final value)) {
        final sorted = [...value]..sort((a, b) => b.entryDate.compareTo(a.entryDate));
        emit(state.copyWith(memories: sorted.take(6).toList()));
      }
    });

    final planResult = await _feedingPlanRepository.getActivePlan(_petId);
    final logsResult = await _foodLogRepository.getDailyLogs(_petId, DateTime.now());
    if (isClosed) return;
    final plan = planResult.fold((v) => v, (_) => null);
    final logs = logsResult.fold((v) => v, (_) => <FoodLog>[]);
    emit(
      state.copyWith(
        targetKcal: plan?.dailyKcal ?? 0,
        consumedKcal: logs.fold<int>(0, (sum, l) => sum + (l.kcal ?? 0)),
      ),
    );
  }

  @override
  Future<void> close() {
    _recordsSub?.cancel();
    _memoriesSub?.cancel();
    return super.close();
  }
}
