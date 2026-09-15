import 'failure.dart';

/// A lightweight `Either<Failure, T>` without pulling in dartz. Repository
/// methods return this instead of throwing, so a BLoC never needs a
/// try/catch around a data call — it pattern-matches instead.
///
/// ```dart
/// final result = await petRepository.getPet(id);
/// switch (result) {
///   case Ok(:final value): emit(PetLoaded(value));
///   case Err(:final failure): emit(PetError(failure));
/// }
/// ```
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) {
    return switch (this) {
      Ok<T>(:final value) => onOk(value),
      Err<T>(:final failure) => onErr(failure),
    };
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
