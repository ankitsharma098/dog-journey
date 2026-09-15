/// Shared by every auth form cubit (sign-in, sign-up, password reset)
/// so screens branch on one status enum instead of each cubit growing
/// its own.
enum AuthFormStatus { idle, submitting, success, failure }

