import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/chat_message.dart';
import '../models/triage_rule.dart';

/// Repository for chat threads and messages.
/// Does NOT extend `SupabaseRepository<T>` because it manages TWO tables
/// (chat_threads + chat_messages) and needs direct client access for RPC calls.
class ChatRepository {
  ChatRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  // -------------------------------------------------------------------
  // Threads
  // -------------------------------------------------------------------

  /// Creates a new chat thread (direct insert; RPC deployed in 0007 migration).
  Future<Result<String>> createThread({
    required String petId,
    required Map<String, dynamic> petSnapshot,
  }) async {
    AppLogger.debug('ChatRepository createThread petId=$petId');
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return const Result.err(AuthFailure());
      final row = await _client
          .from('chat_threads')
          .insert({
            'user_id': uid,
            'pet_id': petId,
            'pet_snapshot': petSnapshot,
          })
          .select()
          .single();
      return Result.ok(row['id'] as String);
    } catch (e, st) {
      AppLogger.error('ChatRepository createThread failed', e, st);
      return Result.err(ServerFailure(_msg(e)));
    }
  }

  /// Gets past threads for the current user, newest first.
  Future<Result<List<ChatThread>>> getThreads() async {
    AppLogger.debug('ChatRepository getThreads');
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return const Result.err(AuthFailure());
      final rows = await _client
          .from('chat_threads')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      return Result.ok(
        (rows as List<dynamic>)
            .map((r) => ChatThread.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
    } catch (e, st) {
      AppLogger.error('ChatRepository getThreads failed', e, st);
      return Result.err(ServerFailure(_msg(e)));
    }
  }

  // -------------------------------------------------------------------
  // Messages
  // -------------------------------------------------------------------

  /// Live stream of messages for a thread, oldest-first.
  Stream<Result<List<ChatMessage>>> watchMessages(String threadId) async* {
    AppLogger.debug('ChatRepository watchMessages threadId=$threadId');
    try {
      final stream = _client
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('thread_id', threadId)
          .order('created_at');
      await for (final rows in stream) {
        yield Result.ok((rows).map((r) => ChatMessage.fromJson(r)).toList());
      }
    } catch (e, st) {
      AppLogger.error('ChatRepository watchMessages failed', e, st);
      yield Result.err(ServerFailure(_msg(e)));
    }
  }

  /// Appends a message. Falls back to direct insert if RPC not deployed yet.
  Future<Result<String>> appendMessage({
    required String threadId,
    required MessageRole role,
    required String content,
    required String disclaimerVersion,
    List<String> photoUrls = const [],
    List<String> matchedRules = const [],
    TriageLevel? level,
    int? tokensUsed,
  }) async {
    AppLogger.debug('ChatRepository appendMessage role=${role.name}');
    try {
      final row = await _client
          .from('chat_messages')
          .insert({
            'thread_id': threadId,
            'role': role.name,
            'content': content,
            'photo_urls': photoUrls,
            'matched_rules': matchedRules,
            if (level != null) 'level': level.dbValue,
            if (tokensUsed != null) 'tokens_used': tokensUsed,
          })
          .select()
          .single();
      return Result.ok(row['id'] as String);
    } catch (e, st) {
      AppLogger.error('ChatRepository appendMessage failed', e, st);
      return Result.err(ServerFailure(_msg(e)));
    }
  }

  /// Submits thumbs-up/down feedback on an assistant message.
  Future<Result<void>> rateFeedback(String messageId, bool helpful) async {
    AppLogger.debug('ChatRepository rateFeedback $messageId helpful=$helpful');
    try {
      await _client
          .from('chat_messages')
          .update({'was_helpful': helpful})
          .eq('id', messageId);
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error('ChatRepository rateFeedback failed', e, st);
      return Result.err(ServerFailure(_msg(e)));
    }
  }

  String _msg(Object e) => e is PostgrestException ? e.message : e.toString();
}
