import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../auth/bloc/auth_form_status.dart';
import '../../auth/data/repositories/user_repository.dart';
import '../data/models/pet.dart';
import '../data/repositories/pet_repository.dart';

class AddPetState {
  const AddPetState({this.status = AuthFormStatus.idle, this.failure});

  final AuthFormStatus status;
  final Failure? failure;

  AddPetState copyWith({AuthFormStatus? status, Failure? failure}) {
    return AddPetState(
      status: status ?? this.status,
      failure: status == AuthFormStatus.failure ? failure : null,
    );
  }
}

class AddPetCubit extends Cubit<AddPetState> {
  AddPetCubit({
    required PetRepository petRepository,
    required UserRepository userRepository,
    required String ownerId,
  }) : _petRepository = petRepository,
       _userRepository = userRepository,
       _ownerId = ownerId,
       super(const AddPetState());

  final PetRepository _petRepository;
  final UserRepository _userRepository;
  final String _ownerId;

  Future<void> submit({
    required String name,
    required String sex,
    DateTime? birthdate,
    bool birthdateIsEstimate = false,
    DateTime? adoptedDate,
    String? breedId,
    List<Map<String, dynamic>>? breedMix,
  }) async {
    emit(state.copyWith(status: AuthFormStatus.submitting));

    final result = await _petRepository.add(
      Pet(
        ownerId: _ownerId,
        name: name.trim(),
        sex: sex,
        birthdate: birthdate,
        birthdateIsEstimate: birthdateIsEstimate,
        adoptedDate: adoptedDate,
        breedId: breedId,
        breedMix: breedMix ?? const [],
      ),
    );

    switch (result) {
      case Ok(:final value):
        AppLogger.info('AddPetCubit created pet $value for owner $_ownerId');
        // Best-effort — a failed flag update shouldn't block the pet
        // that was just successfully created.
        unawaited(
          _userRepository
              .updateFields(_ownerId, {'onboarding_done': true})
              .then((_) {}),
        );
        emit(state.copyWith(status: AuthFormStatus.success));
      case Err(:final failure):
        AppLogger.error(
          'AddPetCubit failed to create pet for owner $_ownerId — ${failure.runtimeType}: ${failure.message}',
        );
        emit(state.copyWith(status: AuthFormStatus.failure, failure: failure));
    }
  }
}
