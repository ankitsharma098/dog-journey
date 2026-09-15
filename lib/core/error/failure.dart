/// Everything a repository can fail with. BLoCs switch on the concrete
/// type to decide copy and recovery action; nobody upstream ever sees a
/// a raw Supabase exception.
sealed class Failure {
  const Failure(this.message);

  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Check your connection and try again.']);
}

final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on our end.']);
}

final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Sign-in failed.']);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = "That doesn't exist anymore."]);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// BS-3 / free-tier scan and chat quota. The UI reacts to this specific
/// type by opening the paywall rather than a generic error toast.
final class QuotaExceededFailure extends Failure {
  const QuotaExceededFailure([
    super.message = "You've hit today's free limit.",
  ]);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something unexpected happened.']);
}
