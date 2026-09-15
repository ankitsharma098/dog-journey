/// Mirrors `health_records` table (migration 0003). Each
/// RecordType drives different form fields and business logic.
enum RecordType {
  vaccine,
  vetVisit,
  medication,
  weight,
  allergy,
  preventive;

  String get label => switch (this) {
        RecordType.vaccine => 'Vaccine',
        RecordType.vetVisit => 'Vet Visit',
        RecordType.medication => 'Medication',
        RecordType.weight => 'Weight',
        RecordType.allergy => 'Allergy',
        RecordType.preventive => 'Preventive Care',
      };

  String get dbValue => switch (this) {
        RecordType.vaccine => 'vaccine',
        RecordType.vetVisit => 'vet_visit',
        RecordType.medication => 'medication',
        RecordType.weight => 'weight',
        RecordType.allergy => 'allergy',
        RecordType.preventive => 'preventive',
      };

  static RecordType fromDb(String v) => switch (v) {
        'vaccine' => RecordType.vaccine,
        'vet_visit' => RecordType.vetVisit,
        'medication' => RecordType.medication,
        'weight' => RecordType.weight,
        'allergy' => RecordType.allergy,
        'preventive' => RecordType.preventive,
        _ => RecordType.vetVisit,
      };
}

class HealthRecord {
  const HealthRecord({
    this.id = '',
    required this.petId,
    required this.type,
    required this.title,
    required this.occurredOn,
    this.dueOn,
    this.vaccineTypeId,
    this.doseNumber,
    this.weightKg,
    this.bodyScore,
    this.dosageText,
    this.frequencyText,
    this.doseTimes = const [],
    this.endsOn,
    this.clinicName,
    this.costAmount,
    this.notes,
    this.attachmentUrls = const [],
    this.isActive = true,
    required this.createdById,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String petId;
  final RecordType type;
  final String title;
  final DateTime occurredOn;
  final DateTime? dueOn;
  final String? vaccineTypeId;
  final int? doseNumber;
  final double? weightKg;
  final int? bodyScore;
  final String? dosageText;
  final String? frequencyText;
  final List<String> doseTimes; // "HH:MM" strings
  final DateTime? endsOn;
  final String? clinicName;
  final double? costAmount;
  final String? notes;
  final List<String> attachmentUrls;
  final bool isActive;
  final String createdById;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory HealthRecord.fromJson(Map<String, dynamic> j) => HealthRecord(
        id: j['id'] as String,
        petId: j['pet_id'] as String,
        type: RecordType.fromDb(j['type'] as String),
        title: j['title'] as String,
        occurredOn: DateTime.parse(j['occurred_on'] as String),
        dueOn: j['due_on'] == null ? null : DateTime.parse(j['due_on'] as String),
        vaccineTypeId: j['vaccine_type_id'] as String?,
        doseNumber: j['dose_number'] as int?,
        weightKg: (j['weight_kg'] as num?)?.toDouble(),
        bodyScore: j['body_score'] as int?,
        dosageText: j['dosage_text'] as String?,
        frequencyText: j['frequency_text'] as String?,
        doseTimes:
            (j['dose_times'] as List<dynamic>? ?? const []).cast<String>(),
        endsOn: j['ends_on'] == null ? null : DateTime.parse(j['ends_on'] as String),
        clinicName: j['clinic_name'] as String?,
        costAmount: (j['cost_amount'] as num?)?.toDouble(),
        notes: j['notes'] as String?,
        attachmentUrls:
            (j['attachment_urls'] as List<dynamic>? ?? const []).cast<String>(),
        isActive: j['is_active'] as bool? ?? true,
        createdById: j['created_by_id'] as String,
        createdAt: j['created_at'] == null
            ? null
            : DateTime.parse(j['created_at'] as String),
        updatedAt: j['updated_at'] == null
            ? null
            : DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'pet_id': petId,
        'type': type.dbValue,
        'title': title,
        'occurred_on': occurredOn.toIso8601String().substring(0, 10),
        if (dueOn != null)
          'due_on': dueOn!.toIso8601String().substring(0, 10),
        if (vaccineTypeId != null) 'vaccine_type_id': vaccineTypeId,
        if (doseNumber != null) 'dose_number': doseNumber,
        if (weightKg != null) 'weight_kg': weightKg,
        if (bodyScore != null) 'body_score': bodyScore,
        if (dosageText != null) 'dosage_text': dosageText,
        if (frequencyText != null) 'frequency_text': frequencyText,
        'dose_times': doseTimes,
        if (endsOn != null)
          'ends_on': endsOn!.toIso8601String().substring(0, 10),
        if (clinicName != null) 'clinic_name': clinicName,
        if (costAmount != null) 'cost_amount': costAmount,
        if (notes != null) 'notes': notes,
        'attachment_urls': attachmentUrls,
        'is_active': isActive,
        'created_by_id': createdById,
      };

  HealthRecord copyWith({
    String? id,
    String? petId,
    RecordType? type,
    String? title,
    DateTime? occurredOn,
    DateTime? dueOn,
    String? vaccineTypeId,
    int? doseNumber,
    double? weightKg,
    int? bodyScore,
    String? dosageText,
    String? frequencyText,
    List<String>? doseTimes,
    DateTime? endsOn,
    String? clinicName,
    double? costAmount,
    String? notes,
    List<String>? attachmentUrls,
    bool? isActive,
    String? createdById,
  }) => HealthRecord(
        id: id ?? this.id,
        petId: petId ?? this.petId,
        type: type ?? this.type,
        title: title ?? this.title,
        occurredOn: occurredOn ?? this.occurredOn,
        dueOn: dueOn ?? this.dueOn,
        vaccineTypeId: vaccineTypeId ?? this.vaccineTypeId,
        doseNumber: doseNumber ?? this.doseNumber,
        weightKg: weightKg ?? this.weightKg,
        bodyScore: bodyScore ?? this.bodyScore,
        dosageText: dosageText ?? this.dosageText,
        frequencyText: frequencyText ?? this.frequencyText,
        doseTimes: doseTimes ?? this.doseTimes,
        endsOn: endsOn ?? this.endsOn,
        clinicName: clinicName ?? this.clinicName,
        costAmount: costAmount ?? this.costAmount,
        notes: notes ?? this.notes,
        attachmentUrls: attachmentUrls ?? this.attachmentUrls,
        isActive: isActive ?? this.isActive,
        createdById: createdById ?? this.createdById,
      );
}
