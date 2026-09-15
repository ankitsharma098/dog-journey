class TimelineEntry {
  const TimelineEntry({
    this.id = '',
    required this.petId,
    this.templateId,
    required this.entryType,
    this.title,
    this.body,
    required this.entryDate,
    this.photos = const [],
    this.isAutoCreated = false,
    this.shareCount = 0,
    required this.createdById,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String petId;
  final String? templateId;
  final EntryType entryType;
  final String? title;
  final String? body;
  final DateTime entryDate;
  final List<Map<String, dynamic>> photos; // [{url, storage: 'device'|'cloud'}]
  final bool isAutoCreated;
  final int shareCount;
  final String createdById;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isSpecialDay =>
      entryType == EntryType.birthday ||
      entryType == EntryType.gotchaDay ||
      entryType == EntryType.first;

  factory TimelineEntry.fromJson(Map<String, dynamic> j) => TimelineEntry(
        id: j['id'] as String,
        petId: j['pet_id'] as String,
        templateId: j['template_id'] as String?,
        entryType: EntryType.fromDb(j['entry_type'] as String),
        title: j['title'] as String?,
        body: j['body'] as String?,
        entryDate: DateTime.parse(j['entry_date'] as String),
        photos: (j['photos'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>(),
        isAutoCreated: j['is_auto_created'] as bool? ?? false,
        shareCount: j['share_count'] as int? ?? 0,
        createdById: j['created_by_id'] as String,
        createdAt: j['created_at'] == null
            ? null
            : DateTime.parse(j['created_at'] as String),
        updatedAt: j['updated_at'] == null
            ? null
            : DateTime.parse(j['updated_at'] as String),
        deletedAt: j['deleted_at'] == null
            ? null
            : DateTime.parse(j['deleted_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'pet_id': petId,
        if (templateId != null) 'template_id': templateId,
        'entry_type': entryType.dbValue,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        'entry_date': entryDate.toIso8601String().substring(0, 10),
        'photos': photos,
        'is_auto_created': isAutoCreated,
        'created_by_id': createdById,
      };
}

enum EntryType {
  photo,
  milestone,
  gotchaDay,
  birthday,
  first,
  note;

  String get label => switch (this) {
        EntryType.photo => 'Photo',
        EntryType.milestone => 'Milestone',
        EntryType.gotchaDay => 'Gotcha Day 🏠',
        EntryType.birthday => 'Birthday 🎂',
        EntryType.first => 'First',
        EntryType.note => 'Note',
      };

  String get dbValue => switch (this) {
        EntryType.photo => 'photo',
        EntryType.milestone => 'milestone',
        EntryType.gotchaDay => 'gotcha_day',
        EntryType.birthday => 'birthday',
        EntryType.first => 'first',
        EntryType.note => 'note',
      };

  bool get isSpecialDay =>
      this == EntryType.birthday ||
      this == EntryType.gotchaDay ||
      this == EntryType.first;

  static EntryType fromDb(String v) => switch (v) {
        'milestone' => EntryType.milestone,
        'gotcha_day' => EntryType.gotchaDay,
        'birthday' => EntryType.birthday,
        'first' => EntryType.first,
        'note' => EntryType.note,
        _ => EntryType.photo,
      };
}
