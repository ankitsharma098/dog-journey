class FeedingPlan {
  const FeedingPlan({
    this.id = '',
    required this.petId,
    required this.goal,
    required this.basisWeightKg,
    this.targetWeightKg,
    required this.merFactor,
    required this.dailyKcal,
    required this.treatBudgetKcal,
    this.meals = const [],
    this.notes,
    this.isActive = true,
    this.recalculateAfter,
    this.createdAt,
  });

  final String id;
  final String petId;
  final PlanGoal goal;
  final double basisWeightKg;
  final double? targetWeightKg;
  final double merFactor;
  final int dailyKcal;
  final int treatBudgetKcal;
  final List<Map<String, dynamic>> meals;
  final String? notes;
  final bool isActive;
  final DateTime? recalculateAfter;
  final DateTime? createdAt;

  factory FeedingPlan.fromJson(Map<String, dynamic> j) => FeedingPlan(
        id: j['id'] as String,
        petId: j['pet_id'] as String,
        goal: PlanGoal.fromDb(j['goal'] as String),
        basisWeightKg: (j['basis_weight_kg'] as num).toDouble(),
        targetWeightKg: (j['target_weight_kg'] as num?)?.toDouble(),
        merFactor: (j['mer_factor'] as num).toDouble(),
        dailyKcal: j['daily_kcal'] as int,
        treatBudgetKcal: j['treat_budget_kcal'] as int,
        meals: (j['meals'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>(),
        notes: j['notes'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        recalculateAfter: j['recalculate_after'] == null
            ? null
            : DateTime.parse(j['recalculate_after'] as String),
        createdAt: j['created_at'] == null
            ? null
            : DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'pet_id': petId,
        'goal': goal.dbValue,
        'basis_weight_kg': basisWeightKg,
        if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
        'mer_factor': merFactor,
        'daily_kcal': dailyKcal,
        'treat_budget_kcal': treatBudgetKcal,
        'meals': meals,
        if (notes != null) 'notes': notes,
        'is_active': isActive,
        if (recalculateAfter != null)
          'recalculate_after': recalculateAfter!.toIso8601String().substring(0, 10),
      };
}

enum PlanGoal {
  maintain,
  lose,
  gain,
  growth;

  String get label => switch (this) {
        PlanGoal.maintain => 'Maintain weight',
        PlanGoal.lose => 'Lose weight',
        PlanGoal.gain => 'Gain weight',
        PlanGoal.growth => 'Puppy growth',
      };

  String get dbValue => name;
  static PlanGoal fromDb(String v) => switch (v) {
        'lose' => PlanGoal.lose,
        'gain' => PlanGoal.gain,
        'growth' => PlanGoal.growth,
        _ => PlanGoal.maintain,
      };

  /// MER factor — default fallback if app_config not available.
  double get defaultMerFactor => switch (this) {
        PlanGoal.maintain => 1.6,
        PlanGoal.lose => 1.0,
        PlanGoal.gain => 1.7,
        PlanGoal.growth => 3.0,
      };
}

class FoodLog {
  const FoodLog({
    this.id = '',
    required this.petId,
    this.foodItemId,
    required this.itemText,
    required this.category,
    this.kcal,
    required this.loggedAt,
    required this.loggedById,
  });

  final String id;
  final String petId;
  final String? foodItemId;
  final String itemText;
  final LogCategory category;
  final int? kcal;
  final DateTime loggedAt;
  final String loggedById;

  factory FoodLog.fromJson(Map<String, dynamic> j) => FoodLog(
        id: j['id'] as String,
        petId: j['pet_id'] as String,
        foodItemId: j['food_item_id'] as String?,
        itemText: j['item_text'] as String,
        category: LogCategory.fromDb(j['category'] as String),
        kcal: j['kcal'] as int?,
        loggedAt: DateTime.parse(j['logged_at'] as String),
        loggedById: j['logged_by_id'] as String,
      );

  Map<String, dynamic> toJson() => {
        'pet_id': petId,
        if (foodItemId != null) 'food_item_id': foodItemId,
        'item_text': itemText,
        'category': category.dbValue,
        if (kcal != null) 'kcal': kcal,
        'logged_at': loggedAt.toIso8601String(),
        'logged_by_id': loggedById,
      };
}

enum LogCategory {
  meal,
  treat,
  humanFood,
  toxicAlert;

  String get label => switch (this) {
        LogCategory.meal => 'Meal',
        LogCategory.treat => 'Treat',
        LogCategory.humanFood => 'Human food',
        LogCategory.toxicAlert => 'Toxic alert',
      };

  String get dbValue => switch (this) {
        LogCategory.meal => 'meal',
        LogCategory.treat => 'treat',
        LogCategory.humanFood => 'human_food',
        LogCategory.toxicAlert => 'toxic_alert',
      };

  static LogCategory fromDb(String v) => switch (v) {
        'treat' => LogCategory.treat,
        'human_food' => LogCategory.humanFood,
        'toxic_alert' => LogCategory.toxicAlert,
        _ => LogCategory.meal,
      };
}

/// Loaded from the bundled `food_items.json` asset.
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.kcalPer100g,
    required this.safety,
    required this.notes,
  });

  final String id;
  final String name;
  final String category;
  final int kcalPer100g;
  final FoodSafety safety;
  final String notes;

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        kcalPer100g: (j['kcal_per_100g'] as num).toInt(),
        safety: FoodSafety.fromString(j['safety'] as String),
        notes: j['notes'] as String? ?? '',
      );
}

enum FoodSafety {
  safe,
  caution,
  toxic;

  static FoodSafety fromString(String v) => switch (v) {
        'toxic' => FoodSafety.toxic,
        'caution' => FoodSafety.caution,
        _ => FoodSafety.safe,
      };
}
