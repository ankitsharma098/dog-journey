import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/result.dart';
import '../data/models/app_user.dart';
import '../data/repositories/auth_repository.dart';

sealed class AuthEvent {
  const AuthEvent();
}

/// Dispatched once at app start to attach the Supabase Auth listener.
class AuthSubscriptionRequested extends AuthEvent {
  const AuthSubscriptionRequested();
}

class AuthSignedOutRequested extends AuthEvent {
  const AuthSignedOutRequested();
}

class _AuthUserChanged extends AuthEvent {
  const _AuthUserChanged(this.uid);
  final String? uid;
}

sealed class AuthState {
  const AuthState();
}

/// Shown while the first Supabase Auth event hasn't arrived yet — the
/// router keeps a splash up rather than guessing sign-in vs sign-out.
class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.profile);
  final AppUser profile;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthInitial()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested);
    on<_AuthUserChanged>(_onUserChanged);
    on<AuthSignedOutRequested>((event, emit) => _authRepository.signOut());
  }

  final AuthRepository _authRepository;
  StreamSubscription? _authSubscription;

  Future<void> _onSubscriptionRequested(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authSubscription?.cancel();
    _authSubscription = _authRepository.authStateChanges.listen(
      (user) => add(_AuthUserChanged(user?.id)),
    );
    // The stream above is broadcast-only — it won't replay a session
    // restored before this subscription started, so check the
    // synchronous current value too (harmless if the stream also
    // fires for it; _onUserChanged is idempotent).
    add(_AuthUserChanged(_authRepository.currentUserId));
  }

  Future<void> _onUserChanged(
    _AuthUserChanged event,
    Emitter<AuthState> emit,
  ) async {
    final uid = event.uid;
    if (uid == null) {
      emit(const AuthUnauthenticated());
      return;
    }

    // Sign-up writes the `users` row right after creating the Supabase
    // Auth account, so this listener can fire a beat before that write
    // lands. A short retry rides out the race instead of bouncing a
    // brand-new user back to the sign-in screen.
    for (var attempt = 0; attempt < 5; attempt++) {
      final result = await _authRepository.fetchProfile(uid);
      if (result case Ok(:final value)) {
        emit(AuthAuthenticated(value));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    emit(const AuthUnauthenticated());
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
