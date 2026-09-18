import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/supabase_storage_service.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../data/models/timeline_entry.dart';
import '../data/repositories/timeline_repository.dart';

// Group entries by month+year
Map<String, List<TimelineEntry>> _groupByMonth(List<TimelineEntry> entries) {
  final map = <String, List<TimelineEntry>>{};
  for (final e in entries) {
    final key =
        '${e.entryDate.year}-${e.entryDate.month.toString().padLeft(2, '0')}';
    map.putIfAbsent(key, () => []).add(e);
  }
  return map;
}

enum TimelineStatus { loading, loaded, error }

class TimelineState {
  const TimelineState({
    this.status = TimelineStatus.loading,
    this.entries = const [],
    this.errorMessage,
  });

  final TimelineStatus status;
  final List<TimelineEntry> entries;
  final String? errorMessage;

  Map<String, List<TimelineEntry>> get grouped => _groupByMonth(entries);
  List<String> get monthKeys =>
      grouped.keys.toList()..sort((a, b) => b.compareTo(a));

  TimelineState copyWith({
    TimelineStatus? status,
    List<TimelineEntry>? entries,
    String? errorMessage,
  }) => TimelineState(
    status: status ?? this.status,
    entries: entries ?? this.entries,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class TimelineCubit extends Cubit<TimelineState> {
  TimelineCubit({
    required String petId,
    required String currentUserId,
    required TimelineRepository timelineRepository,
    required SupabaseStorageService storageService,
  }) : _petId = petId,
       _currentUserId = currentUserId,
       _repository = timelineRepository,
       _storageService = storageService,
       super(const TimelineState()) {
    _subscribe();
  }

  final String _petId;
  final String _currentUserId;
  final TimelineRepository _repository;
  final SupabaseStorageService _storageService;
  StreamSubscription<Result<List<TimelineEntry>>>? _sub;

  void _subscribe() {
    _sub = _repository.watchByPet(_petId).listen((result) {
      switch (result) {
        case Ok(:final value):
          AppLogger.info('TimelineCubit loaded ${value.length} entries');
          emit(state.copyWith(status: TimelineStatus.loaded, entries: value));
        case Err(:final failure):
          AppLogger.error('TimelineCubit error — ${failure.message}');
          emit(
            state.copyWith(
              status: TimelineStatus.error,
              errorMessage: failure.message,
            ),
          );
      }
    });
  }

  void retry() {
    emit(state.copyWith(status: TimelineStatus.loading));
    _sub?.cancel();
    _subscribe();
  }

  Future<Result<String>> addEntry(
    TimelineEntry entry, {
    Uint8List? photoBytes,
  }) async {
    // The presentation layer doesn't know the pet/user context, so it
    // always hands us an entry with blank petId/createdById — fill
    // those in from what the cubit was constructed with rather than
    // trusting the caller (entry.toJson() always has these keys
    // populated, blank or not, so a containsKey check here can't tell
    // the difference).
    var photos = entry.photos;
    if (photoBytes != null) {
      try {
        // Path must be prefixed with the *user's* uid, not the pet's —
        // the `photos_insert` RLS policy (0001_init.sql) checks
        // `(storage.foldername(name))[1] = auth.uid()`, and a pet id
        // there would make every real upload fail silently.
        final url = await _storageService.upload(
          photoBytes,
          '$_currentUserId/memories/$_petId/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        photos = [
          {'url': url, 'storage': 'supabase'},
        ];
      } catch (e, st) {
        // Fails open — the memory is still worth saving without its
        // photo rather than losing the caption/date over an upload
        // hiccup.
        AppLogger.error('TimelineCubit photo upload failed', e, st);
      }
    }
    return _repository.addEntry(
      TimelineEntry(
        petId: _petId,
        entryType: entry.entryType,
        title: entry.title,
        body: entry.body,
        entryDate: entry.entryDate,
        photos: photos,
        createdById: _currentUserId,
      ),
    );
  }

  Future<void> deleteEntry(String id) => _repository.softDelete(id);

  Future<void> shareEntry(String id) => _repository.incrementShareCount(id);

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
