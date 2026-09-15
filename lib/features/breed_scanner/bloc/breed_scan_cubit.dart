import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/app_config_repository.dart';
import '../../../core/data/supabase_storage_service.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../pets/data/repositories/pet_repository.dart';
import '../data/models/scan.dart';
import '../data/repositories/breed_repository.dart';
import '../data/repositories/scan_quota_repository.dart';
import '../data/repositories/scan_repository.dart';
import '../data/services/breed_vision_service.dart';
import '../data/services/image_prep_service.dart';

/// One user-triggered pipeline per invocation (pick → compress/hash →
/// cache check → quota check → classify → save) — a single linear
/// lifecycle, not a long-lived stream subscription, so this is a
/// Cubit with a richer status enum rather than a Bloc (see
/// [PetsBloc]/[AuthBloc] for the shape that *does* warrant a Bloc).
enum ScanPhase {
  idle,
  preparing,
  checkingCache,
  checkingQuota,
  classifying,
  saving,
  success,
  notADog,
  quotaExceeded,
  savedToPet,
  failure,
}

class BreedScanState {
  const BreedScanState({
    this.phase = ScanPhase.idle,
    this.matches = const [],
    this.fromCache = false,
    this.failure,
    this.scanId,
  });

  final ScanPhase phase;
  final List<BreedMatch> matches;
  final bool fromCache;
  final Failure? failure;
  final String? scanId;

  BreedScanState copyWith({
    ScanPhase? phase,
    List<BreedMatch>? matches,
    bool? fromCache,
    Failure? failure,
    String? scanId,
  }) {
    return BreedScanState(
      phase: phase ?? this.phase,
      matches: matches ?? this.matches,
      fromCache: fromCache ?? this.fromCache,
      failure: phase == ScanPhase.failure || phase == ScanPhase.quotaExceeded
          ? (failure ?? this.failure)
          : null,
      scanId: scanId ?? this.scanId,
    );
  }
}

class BreedScanCubit extends Cubit<BreedScanState> {
  BreedScanCubit({
    required String ownerId,
    required ImagePrepService imagePrepService,
    required ScanRepository scanRepository,
    required ScanQuotaRepository scanQuotaRepository,
    required BreedVisionService breedVisionService,
    required BreedRepository breedRepository,
    required AppConfigRepository appConfigRepository,
    required PetRepository petRepository,
    required SupabaseStorageService storageService,
  }) : _ownerId = ownerId,
       _imagePrepService = imagePrepService,
       _scanRepository = scanRepository,
       _scanQuotaRepository = scanQuotaRepository,
       _breedVisionService = breedVisionService,
       _breedRepository = breedRepository,
       _appConfigRepository = appConfigRepository,
       _petRepository = petRepository,
       _storageService = storageService,
       super(const BreedScanState());

  final String _ownerId;
  final ImagePrepService _imagePrepService;
  final ScanRepository _scanRepository;
  final ScanQuotaRepository _scanQuotaRepository;
  final BreedVisionService _breedVisionService;
  final BreedRepository _breedRepository;
  final AppConfigRepository _appConfigRepository;
  final PetRepository _petRepository;
  final SupabaseStorageService _storageService;

  Future<void> scan(XFile photo) async {
    emit(const BreedScanState(phase: ScanPhase.preparing));
    final prepared = await _imagePrepService.prepare(photo);

    emit(state.copyWith(phase: ScanPhase.checkingCache));
    final cacheResult = await _scanRepository.findCached(
      _ownerId,
      prepared.hash,
      BreedVisionService.promptVersion,
    );
    final cached = cacheResult.fold((value) => value, (_) => null);

    if (cached != null) {
      AppLogger.info('BreedScan cache hit — skipping model call and quota spend');
      await _persistScan(
        photoBytes: prepared.bytes,
        hash: prepared.hash,
        speciesMatched: cached.speciesMatched ?? false,
        matches: cached.result,
        fromCache: true,
      );
      return;
    }

    emit(state.copyWith(phase: ScanPhase.checkingQuota));
    final limitResult = await _appConfigRepository.getInt('free_scan_limit', fallback: 3);
    final limit = limitResult.fold((value) => value, (_) => 3);

    final quotaCheck = await _scanQuotaRepository.hasQuota(_ownerId, limit: limit);
    // A quota *read* failure fails open — don't block a legit user over
    // a flaky read; [reserve] re-checks transactionally regardless, so
    // this is only ever a fast-fail optimization, never the real gate.
    final hasQuota = quotaCheck.fold((value) => value, (_) => true);
    if (!hasQuota) {
      emit(state.copyWith(phase: ScanPhase.quotaExceeded, failure: const QuotaExceededFailure()));
      return;
    }

    emit(state.copyWith(phase: ScanPhase.classifying));
    final validSlugs = await _breedRepository.allSlugs();
    final visionResult = await _breedVisionService.classify(
      imageBytes: prepared.bytes,
      validSlugs: validSlugs,
    );

    switch (visionResult) {
      case Err(:final failure):
        emit(state.copyWith(phase: ScanPhase.failure, failure: failure));
      case Ok(:final value) when !value.speciesMatched:
        // BS-2: a friendly rejection costs nothing — only a confirmed
        // dog scan spends quota.
        await _persistScan(
          photoBytes: prepared.bytes,
          hash: prepared.hash,
          speciesMatched: false,
          matches: const [],
          fromCache: false,
        );
      case Ok(:final value):
        final reserved = await _scanQuotaRepository.reserve(_ownerId, limit: limit);
        if (reserved case Err(:final failure)) {
          emit(state.copyWith(phase: ScanPhase.quotaExceeded, failure: failure));
          return;
        }
        await _persistScan(
          photoBytes: prepared.bytes,
          hash: prepared.hash,
          speciesMatched: true,
          matches: value.matches,
          fromCache: false,
        );
    }
  }

  Future<void> _persistScan({
    required Uint8List photoBytes,
    required String hash,
    required bool speciesMatched,
    required List<BreedMatch> matches,
    required bool fromCache,
  }) async {
    emit(state.copyWith(phase: ScanPhase.saving));

    final String photoUrl;
    try {
      photoUrl = await _storageService.upload(photoBytes, '$_ownerId/scans/$hash.jpg');
    } catch (e, st) {
      AppLogger.error('BreedScan photo upload failed', e, st);
      emit(
        state.copyWith(
          phase: ScanPhase.failure,
          failure: const ServerFailure('Could not save that photo. Try again.'),
        ),
      );
      return;
    }

    final created = await _scanRepository.add(
      Scan(
        userId: _ownerId,
        photoUrl: photoUrl,
        imageHash: hash,
        modelVersion: BreedVisionService.promptVersion,
        status: 'done',
        result: matches,
        speciesMatched: speciesMatched,
        fromCache: fromCache,
      ),
    );

    switch (created) {
      case Ok(:final value):
        emit(
          state.copyWith(
            phase: speciesMatched ? ScanPhase.success : ScanPhase.notADog,
            matches: matches,
            fromCache: fromCache,
            scanId: value,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(phase: ScanPhase.failure, failure: failure));
    }
  }

  /// Back to [ScanPhase.idle] — called once the caller has finished
  /// reacting to a terminal phase (navigated to the result screen and
  /// back, shown a snackbar), so revisiting this tab shows the picker
  /// again instead of a stale result. The cubit is a long-lived
  /// singleton-per-screen-visit like [AddPetCubit], not recreated on
  /// every tab switch, so this has to be explicit.
  void reset() => emit(const BreedScanState());

  /// Save the scan result onto an existing pet (BS-6): writes
  /// `breed_id` (top match) + the full `breed_mix`.
  Future<void> saveToPet(String petId) async {
    if (state.matches.isEmpty) return;
    final top = state.matches.first;
    final breed = await _breedRepository.bySlug(top.breedSlug);

    final result = await _petRepository.updateFields(petId, {
      'breed_id': breed?.id,
      'breed_mix': state.matches
          .map((m) => {'breed_id': m.breedSlug, 'name': m.name, 'pct': m.pct})
          .toList(),
    });

    switch (result) {
      case Ok():
        emit(state.copyWith(phase: ScanPhase.savedToPet));
      case Err(:final failure):
        emit(state.copyWith(phase: ScanPhase.failure, failure: failure));
    }
  }
}
