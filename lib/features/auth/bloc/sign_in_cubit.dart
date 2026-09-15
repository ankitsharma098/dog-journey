import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_form_status.dart';

class SignInState {
  const SignInState({this.status = AuthFormStatus.idle, this.failure});

  final AuthFormStatus status;
  final Failure? failure;

  SignInState copyWith({AuthFormStatus? status, Failure? failure}) {
    return SignInState(
      status: status ?? this.status,
      failure: status == AuthFormStatus.failure ? failure : null,
    );
  }
}

class SignInCubit extends Cubit<SignInState> {
  SignInCubit({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const SignInState());

  final AuthRepository _authRepository;

  Future<void> submit({required String email, required String password}) async {
    emit(state.copyWith(status: AuthFormStatus.submitting));
    final result = await _authRepository.signIn(
      email: email.trim(),
      password: password,
    );
    switch (result) {
      case Ok():
        emit(state.copyWith(status: AuthFormStatus.success));
      case Err(:final failure):
        emit(state.copyWith(status: AuthFormStatus.failure, failure: failure));
    }
  }
}
