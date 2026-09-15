/// Shared field validation — every form in the app (auth today, pet
/// forms later) calls these instead of writing its own regex.
abstract final class Validators {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter your email.';
    if (!_emailPattern.hasMatch(trimmed)) {
      return "That email address doesn't look right.";
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter your password.';
    if (v.length < 6) return 'Use at least 6 characters.';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value != password) return "Passwords don't match.";
    return null;
  }
}
