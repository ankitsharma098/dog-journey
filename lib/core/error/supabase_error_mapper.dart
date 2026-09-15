import 'package:supabase_flutter/supabase_flutter.dart';

import 'failure.dart';

/// Every repository's catch block funnels through this so a screen never
/// sees a raw Supabase exception — only the sealed [Failure] the BLoC
/// expects.
Failure mapSupabaseError(Object error) {
  return switch (error) {
    AuthRetryableFetchException _ => const NetworkFailure(),
    AuthException e => _mapAuthError(e),
    PostgrestException e => _mapPostgrestError(e),
    StorageException e => _mapStorageError(e),
    _ => const UnknownFailure(),
  };
}

Failure _mapAuthError(AuthException e) {
  final message = switch (e.code) {
    'invalid_credentials' || 'user_not_found' => 'Incorrect email or password.',
    'user_already_exists' || 'email_exists' =>
      'An account already exists for that email.',
    'weak_password' => 'Choose a stronger password.',
    'validation_failed' => "That email address doesn't look right.",
    'over_request_rate_limit' || 'over_email_send_rate_limit' =>
      'Too many attempts. Try again in a few minutes.',
    _ => 'Sign-in failed.',
  };
  return AuthFailure(message);
}

Failure _mapPostgrestError(PostgrestException e) {
  return switch (e.code) {
    'PGRST116' => const NotFoundFailure(), // .single()/.maybeSingle() found no row
    '42501' => const ServerFailure("You don't have access to that."), // RLS denial
    _ => const ServerFailure(),
  };
}

Failure _mapStorageError(StorageException e) {
  return switch (e.statusCode) {
    '404' => const NotFoundFailure(),
    '403' => const ServerFailure("You don't have access to that."),
    _ => const ServerFailure(),
  };
}
