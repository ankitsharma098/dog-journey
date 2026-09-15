/// Loaded from `assets/data/vaccine_types.json` — bundled asset,
/// not a Supabase table. See migration 0003 file header.
class VaccineType {
  const VaccineType({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.isCore,
    required this.description,
    required this.puppySeries,
    this.puppyStartWeeks,
    required this.adultIntervalMonths,
    this.firstAdultDoseMonths,
  });

  final String id;
  final String name;
  final String abbreviation;
  final bool isCore;
  final String description;
  /// Each map: {dose: int, weeks: int, label: String}
  final List<Map<String, dynamic>> puppySeries;
  final int? puppyStartWeeks;
  final int adultIntervalMonths;
  final int? firstAdultDoseMonths;

  bool get hasPuppySeries => puppySeries.isNotEmpty;
  int get nextDoseMonths => adultIntervalMonths;

  factory VaccineType.fromJson(Map<String, dynamic> j) => VaccineType(
        id: j['id'] as String,
        name: j['name'] as String,
        abbreviation: j['abbreviation'] as String,
        isCore: j['is_core'] as bool,
        description: j['description'] as String,
        puppySeries:
            (j['puppy_series'] as List<dynamic>? ?? const [])
                .cast<Map<String, dynamic>>(),
        puppyStartWeeks: j['puppy_start_weeks'] as int?,
        adultIntervalMonths: j['adult_interval_months'] as int,
        firstAdultDoseMonths: j['first_adult_dose_months'] as int?,
      );
}
