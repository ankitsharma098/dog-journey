import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/result.dart';
import '../data/models/nutrition_models.dart';
import '../data/repositories/food_item_repository.dart';
import '../data/repositories/nutrition_repositories.dart';

enum NutritionStatus { loading, loaded, error }

class NutritionState {
  const NutritionState({
    this.status = NutritionStatus.loading,
    this.activePlan,
    this.todayLogs = const [],
    this.foodItems = const [],
    this.errorMessage,
  });

  final NutritionStatus status;
  final FeedingPlan? activePlan;
  final List<FoodLog> todayLogs;
  final List<FoodItem> foodItems;
  final String? errorMessage;

  int get totalKcalToday => todayLogs.fold(0, (sum, l) => sum + (l.kcal ?? 0));
  int get treatKcalToday => todayLogs
      .where(
        (l) =>
            l.category == LogCategory.treat ||
            l.category == LogCategory.humanFood,
      )
      .fold(0, (sum, l) => sum + (l.kcal ?? 0));
  bool get treatBudgetExceeded =>
      activePlan != null && treatKcalToday > activePlan!.treatBudgetKcal;

  NutritionState copyWith({
    NutritionStatus? status,
    FeedingPlan? activePlan,
    List<FoodLog>? todayLogs,
    List<FoodItem>? foodItems,
    String? errorMessage,
  }) => NutritionState(
    status: status ?? this.status,
    activePlan: activePlan ?? this.activePlan,
    todayLogs: todayLogs ?? this.todayLogs,
    foodItems: foodItems ?? this.foodItems,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class NutritionCubit extends Cubit<NutritionState> {
  NutritionCubit({
    required String petId,
    required String currentUserId,
    required FeedingPlanRepository feedingPlanRepository,
    required FoodLogRepository foodLogRepository,
    required FoodItemRepository foodItemRepository,
  }) : _petId = petId,
       _currentUserId = currentUserId,
       _planRepo = feedingPlanRepository,
       _logRepo = foodLogRepository,
       _itemRepo = foodItemRepository,
       super(const NutritionState()) {
    _load();
  }

  final String _petId;
  final String _currentUserId;
  final FeedingPlanRepository _planRepo;
  final FoodLogRepository _logRepo;
  final FoodItemRepository _itemRepo;

  Future<void> _load() async {
    // Fire concurrently, await in sequence — keeps each Result's type
    // instead of the Future.wait<dynamic> cast this replaced.
    final planFuture = _planRepo.getActivePlan(_petId);
    final logsFuture = _logRepo.getDailyLogs(_petId, DateTime.now());
    final itemsFuture = _itemRepo.all();

    final planResult = await planFuture;
    final logsResult = await logsFuture;
    final items = await itemsFuture;
    if (isClosed) return;

    if (planResult case Err(:final failure)) {
      emit(
        state.copyWith(
          status: NutritionStatus.error,
          errorMessage: failure.message,
        ),
      );
      return;
    }
    if (logsResult case Err(:final failure)) {
      emit(
        state.copyWith(
          status: NutritionStatus.error,
          errorMessage: failure.message,
        ),
      );
      return;
    }

    emit(
      NutritionState(
        status: NutritionStatus.loaded,
        activePlan: planResult.fold((v) => v, (_) => null),
        todayLogs: logsResult.fold((v) => v, (_) => <FoodLog>[]),
        foodItems: items,
      ),
    );
  }

  void retry() {
    emit(state.copyWith(status: NutritionStatus.loading));
    _load();
  }

  Future<void> generatePlan({
    required PlanGoal goal,
    required double currentWeightKg,
    double? targetWeightKg,
  }) async {
    final result = await _planRepo.generatePlan(
      petId: _petId,
      goal: goal,
      currentWeightKg: currentWeightKg,
      targetWeightKg: targetWeightKg,
    );
    if (result.isOk && !isClosed) {
      emit(
        state.copyWith(
          status: NutritionStatus.loaded,
          activePlan: result.fold((v) => v, (_) => null),
        ),
      );
    }
  }

  Future<void> logFood({
    required String itemText,
    required LogCategory category,
    int? kcal,
    String? foodItemId,
  }) async {
    final log = FoodLog(
      petId: _petId,
      foodItemId: foodItemId,
      itemText: itemText,
      category: category,
      kcal: kcal,
      loggedAt: DateTime.now(),
      loggedById: _currentUserId,
    );
    final result = await _logRepo.addLog(log);
    if (result.isOk) {
      final updated = await _logRepo.getDailyLogs(_petId, DateTime.now());
      if (!isClosed) {
        emit(
          state.copyWith(
            todayLogs: updated.fold((v) => v, (_) => state.todayLogs),
          ),
        );
      }
    }
  }

  Future<void> deleteLog(String id) async {
    await _logRepo.deleteLog(id);
    if (!isClosed) {
      emit(
        state.copyWith(
          todayLogs: state.todayLogs.where((l) => l.id != id).toList(),
        ),
      );
    }
  }
}
