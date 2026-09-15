import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/app_config_repository.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/nutrition_models.dart';

class FeedingPlanRepository {
  FeedingPlanRepository({
    required SupabaseClient client,
    required AppConfigRepository appConfigRepository,
  }) : _client = client,
       _appConfig = appConfigRepository;

  final SupabaseClient _client;
  final AppConfigRepository _appConfig;

  /// RER = 70 × weight^0.75 × MER factor.
  /// weight-loss uses TARGET weight as basis; stores all inputs for explainability.
  Future<Result<FeedingPlan>> generatePlan({
    required String petId,
    required PlanGoal goal,
    required double currentWeightKg,
    double? targetWeightKg,
  }) async {
    AppLogger.debug('FeedingPlanRepository generatePlan goal=${goal.dbValue}');
    try {
      // MER factor from app_config or fallback
      final merResult = await _appConfig.getString(
        'mer_factors',
        fallback: '',
      );
      double merFactor = goal.defaultMerFactor;
      if (merResult.isOk) {
        // app_config stores JSON: {"maintain":1.6,"lose":1.0,"gain":1.7,"growth":3.0}
        final raw = merResult.fold((v) => v, (_) => '');
        if (raw.isNotEmpty) {
          try {
            final map = Map<String, dynamic>.from(
              // Simple parse
              RegExp(r'"(\w+)"\s*:\s*([\d.]+)').allMatches(raw).fold(<String, dynamic>{},
                  (m, match) => m..['${match.group(1)}'] = double.parse(match.group(2)!)),
            );
            merFactor = (map[goal.dbValue] as double?) ?? goal.defaultMerFactor;
          } catch (_) {}
        }
      }

      // Basis weight: for weight loss, use target weight
      final basisWeight = goal == PlanGoal.lose && targetWeightKg != null
          ? targetWeightKg
          : currentWeightKg;

      // RER = 70 × weight(kg)^0.75
      final rer = 70.0 * math.pow(basisWeight, 0.75);
      final dailyKcal = (rer * merFactor).round();
      // 10% treat rule
      final treatBudget = (dailyKcal * 0.1).round();

      // Deactivate existing active plan
      await _client
          .from('feeding_plans')
          .update({'is_active': false})
          .eq('pet_id', petId)
          .eq('is_active', true);

      // Insert new plan
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return const Result.err(AuthFailure());

      // recalculate_after: 30 days from now (on next weight update)
      final recalcAfter = DateTime.now().add(const Duration(days: 30));

      final row = await _client.from('feeding_plans').insert({
        'pet_id': petId,
        'goal': goal.dbValue,
        'basis_weight_kg': basisWeight,
        if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
        'mer_factor': merFactor,
        'daily_kcal': dailyKcal,
        'treat_budget_kcal': treatBudget,
        'meals': _defaultMeals(dailyKcal),
        'is_active': true,
        'recalculate_after': recalcAfter.toIso8601String().substring(0, 10),
      }).select().single();

      AppLogger.info(
          'FeedingPlanRepository plan generated — ${dailyKcal}kcal/day');
      return Result.ok(FeedingPlan.fromJson(row));
    } catch (e, st) {
      AppLogger.error('FeedingPlanRepository generatePlan failed', e, st);
      return Result.err(ServerFailure(e is PostgrestException ? e.message : e.toString()));
    }
  }

  Future<Result<FeedingPlan?>> getActivePlan(String petId) async {
    try {
      final row = await _client
          .from('feeding_plans')
          .select()
          .eq('pet_id', petId)
          .eq('is_active', true)
          .maybeSingle();
      if (row == null) return const Result.ok(null);
      return Result.ok(FeedingPlan.fromJson(row));
    } catch (e, st) {
      AppLogger.error('FeedingPlanRepository getActivePlan failed', e, st);
      return Result.err(ServerFailure(e.toString()));
    }
  }

  List<Map<String, dynamic>> _defaultMeals(int dailyKcal) => [
        {'name': 'Morning', 'kcal': (dailyKcal * 0.5).round(), 'time': '08:00'},
        {'name': 'Evening', 'kcal': (dailyKcal * 0.5).round(), 'time': '18:00'},
      ];
}

class FoodLogRepository {
  FoodLogRepository({required SupabaseClient client}) : _client = client;
  final SupabaseClient _client;

  Future<Result<String>> addLog(FoodLog log) async {
    try {
      final row = await _client
          .from('food_logs')
          .insert(log.toJson())
          .select()
          .single();
      return Result.ok(row['id'] as String);
    } catch (e, st) {
      AppLogger.error('FoodLogRepository addLog failed', e, st);
      return Result.err(ServerFailure(e.toString()));
    }
  }

  Future<Result<List<FoodLog>>> getDailyLogs(String petId, DateTime day) async {
    try {
      final dayStr = day.toIso8601String().substring(0, 10);
      final rows = await _client
          .from('food_logs')
          .select()
          .eq('pet_id', petId)
          .gte('logged_at', '${dayStr}T00:00:00')
          .lte('logged_at', '${dayStr}T23:59:59')
          .order('logged_at');
      return Result.ok(
          (rows as List<dynamic>).map((r) => FoodLog.fromJson(r as Map<String, dynamic>)).toList());
    } catch (e, st) {
      AppLogger.error('FoodLogRepository getDailyLogs failed', e, st);
      return Result.err(ServerFailure(e.toString()));
    }
  }

  Future<Result<void>> deleteLog(String id) async {
    try {
      await _client.from('food_logs').delete().eq('id', id);
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error('FoodLogRepository deleteLog failed', e, st);
      return Result.err(ServerFailure(e.toString()));
    }
  }
}
