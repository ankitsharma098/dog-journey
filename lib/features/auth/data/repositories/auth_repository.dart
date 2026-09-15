import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/result.dart';
import '../../../../core/error/supabase_error_mapper.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/app_user.dart';
import 'user_repository.dart';

/// Masks an email for logs — enough to eyeball which account an event
/// belongs to without writing full addresses to device logs.
String _maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 1) return '***';
  return '${email.substring(0, 2)}***${email.substring(at)}';
}

/// Supabase Auth owns identity; this composes it with [UserRepository]
/// so "sign up" is one call instead of every screen remembering to do
/// both steps.
class AuthRepository {
  AuthRepository({
    required SupabaseClient client,
    required UserRepository userRepository,
  }) : _client = client,
       _userRepository = userRepository;

  final SupabaseClient _client;
  final UserRepository _userRepository;

  Stream<User?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session?.user);

  /// Synchronous current-user read, for the moment right after
  /// subscribing to [authStateChanges] — a broadcast stream doesn't
  /// replay past events to a new listener, so a subscriber that only
  /// waits on the stream can miss a session that was already restored
  /// before it subscribed.
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<Result<User>> signIn({
    required String email,
    required String password,
  }) async {
    AppLogger.debug('Auth signIn ${_maskEmail(email)}');
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      AppLogger.info('Auth signIn ${_maskEmail(email)} — ok');
      return Result.ok(response.user!);
    } catch (e, st) {
      AppLogger.error('Auth signIn ${_maskEmail(email)} — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }

  /// Creates the Supabase Auth account; the mirrored `users` row is
  /// created server-side by a trigger on `auth.users` insert (see
  /// supabase/migrations/0004_auth_user_trigger.sql) rather than by a
  /// client insert here — a client insert needs an active session,
  /// which doesn't exist yet whenever the project requires email
  /// confirmation, and would hit `users_insert`'s RLS check every
  /// time. This only patches the device-specific fields the trigger
  /// can't know (locale/timezone/units), best-effort, when a session
  /// happens to exist already (confirmation off, or already confirmed).
  Future<Result<AppUser>> signUp({
    required String email,
    required String password,
    required String locale,
    required String timezone,
    required String units,
  }) async {
    AppLogger.debug('Auth signUp ${_maskEmail(email)}');
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      final uid = response.user!.id;
      AppLogger.info(
        'Auth signUp ${_maskEmail(email)} — account created ($uid)',
      );

      final profile = AppUser(
        uid: uid,
        email: email,
        locale: locale,
        timezone: timezone,
        units: units,
      );

      if (_client.auth.currentSession != null) {
        final patched = await _userRepository.updateFields(uid, {
          'locale': locale,
          'timezone': timezone,
          'units': units,
        });
        if (patched case Err()) {
          AppLogger.error(
            'Auth signUp ${_maskEmail(email)} — profile field patch failed for $uid',
          );
        }
      } else {
        AppLogger.warning(
          'Auth signUp ${_maskEmail(email)} — no session yet for $uid '
          '(email confirmation pending?); locale/timezone/units left at '
          "the trigger's defaults until sign-in",
        );
      }
      return Result.ok(profile);
    } catch (e, st) {
      AppLogger.error('Auth signUp ${_maskEmail(email)} — failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }

  Future<Result<void>> sendPasswordResetEmail(String email) async {
    AppLogger.debug('Auth sendPasswordResetEmail ${_maskEmail(email)}');
    try {
      await _client.auth.resetPasswordForEmail(email);
      AppLogger.info('Auth sendPasswordResetEmail ${_maskEmail(email)} — ok');
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error(
        'Auth sendPasswordResetEmail ${_maskEmail(email)} — failed',
        e,
        st,
      );
      return Result.err(mapSupabaseError(e));
    }
  }

  Future<void> signOut() {
    AppLogger.info(
      'Auth signOut ${_maskEmail(_client.auth.currentUser?.email ?? '')}',
    );
    return _client.auth.signOut();
  }

  /// Permanently deletes the signed-in user's account. Calls the
  /// `delete_user` RPC (supabase/migrations/0007_delete_account.sql)
  /// rather than the GoTrue Admin API — that needs the service-role
  /// key, which never ships client-side. Deleting `auth.users`
  /// cascades through every table via `users(id)` foreign keys.
  Future<Result<void>> deleteAccount() async {
    AppLogger.info(
      'Auth deleteAccount ${_maskEmail(_client.auth.currentUser?.email ?? '')}',
    );
    try {
      await _client.rpc('delete_user');
      return const Result.ok(null);
    } catch (e, st) {
      AppLogger.error('Auth deleteAccount failed', e, st);
      return Result.err(mapSupabaseError(e));
    }
  }

  Future<Result<AppUser>> fetchProfile(String uid) =>
      _userRepository.getById(uid);
}
