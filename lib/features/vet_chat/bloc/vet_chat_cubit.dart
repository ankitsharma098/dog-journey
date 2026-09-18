import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../billing/bloc/billing_cubit.dart';
import '../data/models/chat_message.dart';
import '../data/models/triage_rule.dart';
import '../data/repositories/chat_quota_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/services/triage_service.dart';
import '../data/services/vet_ai_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum VetChatPhase {
  idle,
  triage, // deterministic gate running (<500ms)
  streaming, // Gemini streaming response
  done,
  error,
}

class VetChatState {
  const VetChatState({
    this.phase = VetChatPhase.idle,
    this.threadId,
    this.messages = const [],
    this.streamingContent = '',
    this.triageResult,
    this.quotaUsed = 0,
    this.quotaLimit = 3,
    this.errorMessage,
  });

  final VetChatPhase phase;
  final String? threadId;
  final List<ChatMessage> messages;
  final String streamingContent;
  final TriageResult? triageResult;
  final int quotaUsed;
  final int quotaLimit;
  final String? errorMessage;

  bool get isEmergency => triageResult?.isEmergency ?? false;
  bool get quotaExceeded => quotaUsed >= quotaLimit;
  bool get hasActiveThread => threadId != null;

  VetChatState copyWith({
    VetChatPhase? phase,
    String? threadId,
    List<ChatMessage>? messages,
    String? streamingContent,
    TriageResult? triageResult,
    bool clearTriage = false,
    int? quotaUsed,
    int? quotaLimit,
    String? errorMessage,
  }) => VetChatState(
    phase: phase ?? this.phase,
    threadId: threadId ?? this.threadId,
    messages: messages ?? this.messages,
    streamingContent: streamingContent ?? this.streamingContent,
    triageResult: clearTriage ? null : (triageResult ?? this.triageResult),
    quotaUsed: quotaUsed ?? this.quotaUsed,
    quotaLimit: quotaLimit ?? this.quotaLimit,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------
class VetChatCubit extends Cubit<VetChatState> {
  VetChatCubit({
    required String petId,
    required String currentUserId,
    required Map<String, dynamic> petSnapshot,
    required ChatRepository chatRepository,
    required ChatQuotaRepository chatQuotaRepository,
    required TriageService triageService,
    required VetAiService vetAiService,
    required BillingCubit billingCubit,
    String? breedId,
  }) : _petId = petId,
       _currentUserId = currentUserId,
       _petSnapshot = petSnapshot,
       _chatRepository = chatRepository,
       _chatQuotaRepository = chatQuotaRepository,
       _triageService = triageService,
       _vetAiService = vetAiService,
       _billingCubit = billingCubit,
       _breedId = breedId,
       super(const VetChatState()) {
    _init();
  }

  final String _petId;
  final String _currentUserId;
  final Map<String, dynamic> _petSnapshot;
  final ChatRepository _chatRepository;
  final ChatQuotaRepository _chatQuotaRepository;
  final TriageService _triageService;
  final VetAiService _vetAiService;
  final BillingCubit _billingCubit;
  final String? _breedId;

  StreamSubscription<dynamic>? _messageSubscription;
  // Synchronous re-entrancy guard — `state.phase` only flips to
  // `.triage` after the first `await` below, so a double-tap (or a
  // slow first frame) landing before that state change lets two
  // sendMessage() calls run concurrently: two user-message rows, two
  // AI requests, and what looks like "the same question answered
  // twice" in the thread. `isBusy` in the UI is derived from `phase`
  // and can't close this gap on its own.
  bool _sending = false;

  void _init() {
    // Preload triage rules in background so first match is instant
    _triageService.preload();
    // Seed the real remaining count — without this, every fresh
    // cubit (e.g. after leaving and re-entering the Chat tab) would
    // start believing quotaUsed=0 regardless of what was actually
    // spent today.
    _chatQuotaRepository
        .remaining(_currentUserId, limit: state.quotaLimit)
        .then((result) {
          if (isClosed) return;
          if (result case Ok(:final value)) {
            emit(state.copyWith(quotaUsed: state.quotaLimit - value));
          }
        });
  }

  // -------------------------------------------------------------------
  // Start a new thread
  // -------------------------------------------------------------------
  Future<void> startThread() async {
    if (state.hasActiveThread) return;
    AppLogger.debug('VetChatCubit startThread');
    final result = await _chatRepository.createThread(
      petId: _petId,
      petSnapshot: _petSnapshot,
    );
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(threadId: value));
        _subscribeToMessages(value);
      case Err(:final failure):
        emit(
          state.copyWith(
            phase: VetChatPhase.error,
            errorMessage: failure.message,
          ),
        );
    }
  }

  void _subscribeToMessages(String threadId) {
    _messageSubscription?.cancel();
    _messageSubscription = _chatRepository.watchMessages(threadId).listen((
      result,
    ) {
      switch (result) {
        case Ok(:final value):
          // A realtime refresh lands mid-stream more often than not —
          // the just-inserted user message and this listener firing
          // race independently of the AI response finishing. The
          // streaming placeholder isn't persisted, so a bare
          // `messages: value` would silently drop it here, and the
          // streaming-update loop below would then be overwriting the
          // wrong (real, persisted) message at that index — which is
          // exactly what put the assistant's reply above the user's
          // own question. Re-appending it after every DB-backed list
          // keeps it pinned last regardless of when this fires.
          final streaming = state.messages.where((m) => m.isStreaming);
          emit(state.copyWith(messages: [...value, ...streaming]));
        case Err():
          break;
      }
    });
  }

  // -------------------------------------------------------------------
  // Send a message — triage gate FIRST, then quota, then AI
  // -------------------------------------------------------------------
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _sending) return;
    _sending = true;
    try {
      await _sendMessage(text);
    } finally {
      _sending = false;
    }
  }

  Future<void> _sendMessage(String text) async {
    // Ensure thread exists
    if (!state.hasActiveThread) {
      await startThread();
      if (!state.hasActiveThread) return;
    }
    final threadId = state.threadId!;

    // 1. Run triage gate (deterministic, <500ms)
    emit(state.copyWith(phase: VetChatPhase.triage));
    final triage = await _triageService.match(text, breedId: _breedId);
    final isEmergency = triage?.isEmergency ?? false;

    // 2. Write user message to DB
    final disclaimerVersion = await _vetAiService.disclaimerVersion;
    await _chatRepository.appendMessage(
      threadId: threadId,
      role: MessageRole.user,
      content: text,
      disclaimerVersion: disclaimerVersion,
      matchedRules: triage?.matchedCodes ?? const [],
      level: triage?.level,
    );

    // 3. Update state with triage result BEFORE any quota check
    emit(state.copyWith(phase: VetChatPhase.streaming, triageResult: triage));

    // 4. Quota check — HARD RULE: emergency messages NEVER blocked by
    // quota, and Pro subscribers never hit the free-tier daily cap at
    // all (the "PRO · UNLIMITED" chip was previously cosmetic only —
    // this reserve call ran unconditionally regardless of billing
    // status, so a paying subscriber still got cut off at 3/day).
    // Reserved server-side (reserve_chat_quota, security definer,
    // keyed off auth.uid()) so a modified client can't just skip this
    // check the way the old in-memory-only counter could.
    if (!isEmergency && !_billingCubit.state.isPro) {
      final reserved = await _chatQuotaRepository.reserve(
        _currentUserId,
        limit: state.quotaLimit,
      );
      if (reserved case Err()) {
        emit(
          state.copyWith(phase: VetChatPhase.done, quotaUsed: state.quotaLimit),
        );
        return; // UI shows paywall
      }
      emit(state.copyWith(quotaUsed: state.quotaUsed + 1));
    }

    // 5. Stream AI response
    final history = state.messages
        .map((m) => {'role': m.role.name, 'content': m.content})
        .toList();

    final buffer = StringBuffer();
    final streamingMsg = ChatMessage(
      threadId: threadId,
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
    );

    // Add streaming placeholder to message list
    final msgsWithStreaming = [...state.messages, streamingMsg];
    emit(state.copyWith(messages: msgsWithStreaming));

    await for (final chunk in _vetAiService.streamResponse(
      history: history,
      userMessage: text,
      petSnapshot: _petSnapshot,
      matchedRuleCodes: triage?.matchedCodes ?? const [],
      triageLevel: triage?.level,
    )) {
      buffer.write(chunk);
      // Replace by identity (isStreaming), not by trailing index — a
      // realtime message refresh can land between chunks and change
      // what's actually last in state.messages.
      final updatedMsgs = [
        for (final m in state.messages)
          if (m.isStreaming)
            streamingMsg.copyWith(content: buffer.toString())
          else
            m,
      ];
      if (!isClosed) emit(state.copyWith(messages: updatedMsgs));
    }

    // 6. Persist final assistant message
    final finalContent = buffer.toString();
    await _chatRepository.appendMessage(
      threadId: threadId,
      role: MessageRole.assistant,
      content: finalContent,
      disclaimerVersion: disclaimerVersion,
      matchedRules: triage?.matchedCodes ?? const [],
      level: triage?.level,
    );

    if (!isClosed) emit(state.copyWith(phase: VetChatPhase.done));
  }

  Future<void> rateFeedback(String messageId, bool helpful) async {
    await _chatRepository.rateFeedback(messageId, helpful);
  }

  void clearTriage() {
    emit(state.copyWith(clearTriage: true));
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}
