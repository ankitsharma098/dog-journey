import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/device_locale.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_form_status.dart';

class SignUpState {
  const SignUpState({this.status = AuthFormStatus.idle, this.failure});

  final AuthFormStatus status;
  final Failure? failure;

  SignUpState copyWith({AuthFormStatus? status, Failure? failure}) {
    return SignUpState(
      status: status ?? this.status,
      failure: status == AuthFormStatus.failure ? failure : null,
    );
  }
}

class SignUpCubit extends Cubit<SignUpState> {
  SignUpCubit({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const SignUpState());

  final AuthRepository _authRepository;

  Future<void> submit({required String email, required String password}) async {
    emit(state.copyWith(status: AuthFormStatus.submitting));

    final result = await _authRepository.signUp(
      email: email.trim(),
      password: password,
      locale: DeviceLocale.locale(),
      timezone: await DeviceLocale.timezone(),
      units: DeviceLocale.units(),
    );

    switch (result) {
      case Ok():
        emit(state.copyWith(status: AuthFormStatus.success));
      case Err(:final failure):
        emit(state.copyWith(status: AuthFormStatus.failure, failure: failure));
    }
  }
}
