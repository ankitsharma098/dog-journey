import 'triage_rule.dart';

enum MessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    this.id = '',
    required this.threadId,
    required this.role,
    required this.content,
    this.photoUrls = const [],
    this.matchedRules = const [],
    this.level,
    this.disclaimerVersion,
    this.wasHelpful,
    this.tokensUsed,
    this.createdAt,
    // Streaming-only: content has not been persisted yet
    this.isStreaming = false,
  });

  final String id;
  final String threadId;
  final MessageRole role;
  final String content;
  final List<String> photoUrls;
  final List<String> matchedRules;
  final TriageLevel? level;
  final String? disclaimerVersion;
  final bool? wasHelpful;
  final int? tokensUsed;
  final DateTime? createdAt;
  final bool isStreaming;

  bool get isAssistant => role == MessageRole.assistant;
  bool get isUser => role == MessageRole.user;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        threadId: j['thread_id'] as String,
        role: (j['role'] as String) == 'user'
            ? MessageRole.user
            : MessageRole.assistant,
        content: j['content'] as String,
        photoUrls:
            (j['photo_urls'] as List<dynamic>? ?? const []).cast<String>(),
        matchedRules:
            (j['matched_rules'] as List<dynamic>? ?? const []).cast<String>(),
        level: j['level'] == null
            ? null
            : TriageLevelX.fromString(j['level'] as String),
        disclaimerVersion: j['disclaimer_version'] as String?,
        wasHelpful: j['was_helpful'] as bool?,
        tokensUsed: j['tokens_used'] as int?,
        createdAt: j['created_at'] == null
            ? null
            : DateTime.parse(j['created_at'] as String),
      );

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    bool? wasHelpful,
    String? disclaimerVersion,
    int? tokensUsed,
  }) =>
      ChatMessage(
        id: id,
        threadId: threadId,
        role: role,
        content: content ?? this.content,
        photoUrls: photoUrls,
        matchedRules: matchedRules,
        level: level,
        disclaimerVersion: disclaimerVersion ?? this.disclaimerVersion,
        wasHelpful: wasHelpful ?? this.wasHelpful,
        tokensUsed: tokensUsed ?? this.tokensUsed,
        createdAt: createdAt,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

class ChatThread {
  const ChatThread({
    required this.id,
    required this.userId,
    this.petId,
    this.title,
    this.level,
    this.summary,
    this.petSnapshot = const {},
    this.messageCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String? petId;
  final String? title;
  final TriageLevel? level;
  final String? summary;
  final Map<String, dynamic> petSnapshot;
  final int messageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ChatThread.fromJson(Map<String, dynamic> j) => ChatThread(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        petId: j['pet_id'] as String?,
        title: j['title'] as String?,
        level: j['level'] == null
            ? null
            : TriageLevelX.fromString(j['level'] as String),
        summary: j['summary'] as String?,
        petSnapshot: (j['pet_snapshot'] as Map<String, dynamic>? ?? const {}),
        messageCount: j['message_count'] as int? ?? 0,
        createdAt: j['created_at'] == null
            ? null
            : DateTime.parse(j['created_at'] as String),
        updatedAt: j['updated_at'] == null
            ? null
            : DateTime.parse(j['updated_at'] as String),
      );
}
