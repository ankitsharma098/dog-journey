import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../data/models/pet.dart';
import '../data/repositories/pet_repository.dart';

sealed class PetsEvent {
  const PetsEvent();
}

/// Dispatched once at app start to attach the [AuthBloc] listener.
class PetsSubscriptionRequested extends PetsEvent {
  const PetsSubscriptionRequested();
}

class _PetsOwnerChanged extends PetsEvent {
  const _PetsOwnerChanged(this.ownerId);
  final String? ownerId;
}

class _PetsListChanged extends PetsEvent {
  const _PetsListChanged(this.result);
  final Result<List<Pet>> result;
}

enum PetsStatus { unknown, loaded, error }

class PetsState {
  const PetsState({this.status = PetsStatus.unknown, this.pets = const []});

  final PetsStatus status;
  final List<Pet> pets;

  bool get hasPets => pets.isNotEmpty;

  PetsState copyWith({PetsStatus? status, List<Pet>? pets}) {
    return PetsState(status: status ?? this.status, pets: pets ?? this.pets);
  }
}

/// Mirrors [AuthBloc]'s shape: this is the "heavy" side of pet
/// state — it chains two subscriptions (who's signed in, then that
/// owner's `pets` query) rather than answering a single request/response
/// like [AddPetCubit], so it gets a proper event/state Bloc instead of a
/// Cubit. The router's onboarding gate and the add-pet screen both read
/// this one shared instance instead of each re-querying Firestore.
class PetsBloc extends Bloc<PetsEvent, PetsState> {
  PetsBloc({required PetRepository petRepository, required AuthBloc authBloc})
    : _petRepository = petRepository,
      _authBloc = authBloc,
      super(const PetsState()) {
    on<PetsSubscriptionRequested>(_onSubscriptionRequested);
    on<_PetsOwnerChanged>(_onOwnerChanged);
    on<_PetsListChanged>(_onListChanged);
  }

  final PetRepository _petRepository;
  final AuthBloc _authBloc;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Result<List<Pet>>>? _petsSubscription;

  Future<void> _onSubscriptionRequested(
    PetsSubscriptionRequested event,
    Emitter<PetsState> emit,
  ) async {
    await _authSubscription?.cancel();
    _authSubscription = _authBloc.stream.listen(
      (authState) => add(_PetsOwnerChanged(_ownerIdOf(authState))),
    );
    add(_PetsOwnerChanged(_ownerIdOf(_authBloc.state)));
  }

  String? _ownerIdOf(AuthState authState) =>
      authState is AuthAuthenticated ? authState.profile.uid : null;

  Future<void> _onOwnerChanged(
    _PetsOwnerChanged event,
    Emitter<PetsState> emit,
  ) async {
    await _petsSubscription?.cancel();
    final ownerId = event.ownerId;
    // Reset before the new owner's query resolves — otherwise, for the
    // stretch between unsubscribing the old owner's stream and the new
    // owner's first emission, `state.pets` still holds the PREVIOUS
    // owner's pets (e.g. switching accounts shows the old account's
    // dog instead of routing to onboarding).
    emit(const PetsState());
    if (ownerId == null) {
      _petsSubscription = null;
      return;
    }

    AppLogger.debug('PetsBloc watching pets for owner $ownerId');
    _petsSubscription = _petRepository
        .watchOwnedBy(ownerId)
        .listen((result) => add(_PetsListChanged(result)));
  }

  void _onListChanged(_PetsListChanged event, Emitter<PetsState> emit) {
    switch (event.result) {
      case Ok(:final value):
        AppLogger.info('PetsBloc loaded ${value.length} pet(s)');
        emit(state.copyWith(status: PetsStatus.loaded, pets: value));
      case Err(:final failure):
        AppLogger.error('PetsBloc failed to load pets — ${failure.message}');
        emit(state.copyWith(status: PetsStatus.error));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _petsSubscription?.cancel();
    return super.close();
  }
}
